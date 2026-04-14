`timescale 1ns / 1ps
 
 
module TopLevelProcessor (
    input wire clk,
    input wire reset_btn,     // MATCHES XDC
    input wire [15:0] sw,     // MATCHES XDC
    output wire [15:0] led,    // MATCHES XDC
    output wire [3:0] an,     // NEW
    output wire [6:0] seg     // NEW
);
 
    // ==========================================
    // Internal Signals
    // ==========================================
    // Map the XDC ports to your internal logic names here
    wire rst = reset_btn;
    wire [15:0] switches = sw;
    wire [15:0] leds;
//    assign led = leds;
 
    wire [31:0] PC;
    wire [31:0] PCplus4;
    wire [31:0] branchTarget;
    wire [31:0] nextPC;
    wire PCWrite = 1'b1; // Always 1 for Single-Cycle
    wire [31:0] instruction;
    wire [6:0]  opcode   = instruction[6:0];
    wire [4:0]  rs1      = instruction[19:15];
    wire [4:0]  rs2      = instruction[24:20];
    wire [4:0]  rd       = instruction[11:7];
    wire [2:0]  funct3   = instruction[14:12];
    wire isRType         = (opcode == 7'b0110011);
    wire [31:0] readData1, readData2, writeData;
    wire RegWrite;
    wire [31:0] ALUInputB, ALUResult;
    wire ALUZero;
    wire [3:0]  ALUControl;
    wire [1:0]  ALUOp;
    wire ALUSrc;
    wire [31:0] dataMemoryRead, dataMemoryWrite, memoryAddress;
    wire MemRead, MemWrite, Branch, Jump, Jalr;
    wire [1:0]  MemtoReg;
    wire [31:0] immediate;
    wire [2:0]  immType;
 
    // We turn the debug signals into internal wires instead of output ports
    // so they don't take up physical FPGA pins!
    wire [31:0] debugPC = PC;
    wire [31:0] debugInstruction = instruction;
    wire [31:0] debugALUResult = ALUResult;

    // --- NEW CLOCK DIVIDER: 100MHz to 1kHz ---
    reg [25:0] clk_counter = 0;
    reg slow_clk = 0;
    always @(posedge clk) begin
        if (clk_counter == 49999) begin
            clk_counter <= 0;
            slow_clk <= ~slow_clk;
        end else begin
            clk_counter <= clk_counter + 1;
        end
    end
    // -----------------------------------------
    // ==========================================
    // Instruction Fetch Stage
    // ==========================================
    ProgramCounter pc_unit (
        .clk(slow_clk), .rst(rst), // change to slow clock for fpga
        .nextPC(nextPC), .PCWrite(PCWrite), .PC(PC)
    );
    pcAdder pc_adder (
        .PC(PC), .PCplus4(PCplus4)
    );
    instructionMemory #(.OPERAND_LENGTH(31)) instr_mem (
        .instAddress(PC), 
        .instruction(instruction)
    );
 
    // ==========================================
    // Instruction Decode & Control
    // ==========================================
    MainControl main_control (
        .opcode(opcode),
        .RegWrite(RegWrite),
        .ALUOp(ALUOp),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .MemtoReg(MemtoReg),
        .Branch(Branch),
        .Jump(Jump),
        .Jalr(Jalr)
    );
    ALUControl alu_control (
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7_bit(instruction[30] & isRType), // Prevents ADDI from acting as SUB
        .ALUControlOut(ALUControl)
    );
 
    assign immType = (opcode == 7'b0100011) ? 3'b001 : // S-type
                     (opcode == 7'b1100011) ? 3'b010 : // B-type
                     (opcode == 7'b1101111) ? 3'b011 : // J-type (JAL)
                     (opcode == 7'b0110111) ? 3'b100 : // NEW: U-type (LUI)
                     3'b000;                           // I-type/R-type default
    immGen imm_gen (
        .instruction(instruction),
        .immType(immType),
        .immediate(immediate)
    );
    RegisterFile reg_file ( // change to slow clock for fpga
        .clk(slow_clk), .rst(rst),
        .WriteEnable(RegWrite),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .WriteData(writeData),
        .ReadData1(readData1), .ReadData2(readData2)
    );
 
    // ==========================================
    // Execute Stage
    // ==========================================
    assign ALUInputB = ALUSrc ? immediate : readData2;
    ALU alu_unit (
        .A(readData1), .B(ALUInputB),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult),
        .Zero(ALUZero)
    );
    branchAdder branch_adder (
        .PC(PC), .immExtended(immediate), .branchTarget(branchTarget)
    );
    // Evaluate BEQ (000) or BNE (001)
    wire branchCondition = (funct3 == 3'b000) ? ALUZero :
                           (funct3 == 3'b001) ? ~ALUZero : 1'b0;
    wire takeBranchOrJump = (Branch & branchCondition) | Jump;
    wire [31:0] targetPC = Jalr ? {ALUResult[31:1], 1'b0} : branchTarget;
    mux2 #(.WIDTH(32)) pc_mux (
        .in0(PCplus4), .in1(targetPC),
        .sel(takeBranchOrJump),
        .out(nextPC)
    );
 
    // ==========================================
    // Memory & I/O Stage
    // ==========================================
    assign memoryAddress = ALUResult;
    assign dataMemoryWrite = readData2;
    wire DataMemSelect, LEDWrite, SwitchReadEnable;
    AddressDecoder addr_decoder (
        .address(memoryAddress),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .DataMemSelect(DataMemSelect),
        .LEDSelect(LEDWrite),
        .SwitchSelect(SwitchReadEnable)
    );
    DataMemory data_mem (
        .clk(slow_clk), // change to slow clock for fpga
        .MemWrite(MemWrite & DataMemSelect), // Guard against overwriting on LED write
        .address(memoryAddress),
        .write_data(dataMemoryWrite),
        .read_data(dataMemoryRead)
    );
    leds led_interface (
        .clk(slow_clk), .rst(rst), // change to slow clock for fpga
        .writeData(dataMemoryWrite),
        .writeEnable(LEDWrite),
        .leds(leds)
    );
 
    // ==========================================
    // Write Back Stage
    // ==========================================
    wire [31:0] finalReadData;
    assign finalReadData = SwitchReadEnable ? {16'b0, switches} : dataMemoryRead;
    // 00: ALU, 01: Mem/IO, 10: PC+4 (For JAL/JALR), 11: Immediate (For LUI)
    assign writeData = (MemtoReg == 2'b01) ? finalReadData :
                       (MemtoReg == 2'b10) ? PCplus4 :
                       (MemtoReg == 2'b11) ? immediate : // NEW: LUI Path
                       ALUResult;

    // ==========================================
    // Output Routing (Normal vs Debug Mode)
    // ==========================================
    // Bundle the control signals for Task B demonstration
    // led[15]=RegWrite, led[14]=MemRead, led[13]=MemWrite, led[12]=Branch, 
    // led[11]=Jump, led[10]=Jalr, led[9]=ALUSrc, led[8:7]=MemtoReg, 
    // led[4]=ALUZero, led[3:0]=ALUControl
    wire [15:0] debug_signals = {
        RegWrite, MemRead, MemWrite, Branch, 
        Jump, Jalr, ALUSrc, MemtoReg[1:0], 
        2'b00, ALUZero, ALUControl[3:0]
    };
 
    // If sw[15] is UP, show debug flags. If DOWN, show normal LEDs.
    assign led = sw[15] ? debug_signals : leds;
 
    // If sw[15] is UP, show PC on 7-seg. If DOWN, show normal LEDs output.
    wire [15:0] display_value = sw[15] ? PC[15:0] : leds;
 
    // Instantiate the 7-Segment Controller (Uses fast clk)
    SevenSegmentControl display_unit (
        .clk(clk), 
        .rst(rst),
        .value(display_value),
        .an(an),
        .seg(seg)
    );                   
 
endmodule
 
// ==============================================================
// Sub-Modules
// ==============================================================
 
module ProgramCounter (
    input wire clk, input wire rst,
    input wire [31:0] nextPC, input wire PCWrite,
    output reg [31:0] PC
);
    always @(posedge clk) begin
        if (rst) PC <= 32'b0;
        else if (PCWrite) PC <= nextPC;
    end
endmodule
 
module pcAdder (
    input wire [31:0] PC, output wire [31:0] PCplus4
);
    assign PCplus4 = PC + 32'd4;
endmodule
 
module branchAdder (
    input wire [31:0] PC, 
    input wire [31:0] immExtended, 
    output wire [31:0] branchTarget
);
    // immExtended already contains the trailing 0 from the immGen.
    // Do not shift it again!
    assign branchTarget = PC + immExtended;
endmodule
 
module mux2 #(parameter WIDTH = 32) (
    input wire [WIDTH-1:0] in0, input wire [WIDTH-1:0] in1,
    input wire sel, output wire [WIDTH-1:0] out
);
    assign out = sel ? in1 : in0;
endmodule
 
module immGen (
    input  wire [31:0] instruction,
    input  wire [2:0]  immType, // CHANGED: Expanded to 3 bits
    output reg  [31:0] immediate
);
    wire [11:0] i_imm = instruction[31:20];
    wire [6:0]  s_hi  = instruction[31:25];
    wire [4:0]  s_lo  = instruction[11:7];
    wire [12:0] b_raw = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [20:0] j_raw = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    // NEW: U-Type extraction
    wire [31:0] u_imm = {instruction[31:12], 12'b0};
 
    always @(*) begin
        case (immType)
            3'b000: immediate = {{20{i_imm[11]}}, i_imm};       // I-type
            3'b001: immediate = {{20{s_hi[6]}},   s_hi, s_lo};  // S-type
            3'b010: immediate = {{19{b_raw[12]}},  b_raw};      // B-type
            3'b011: immediate = {{11{j_raw[20]}},  j_raw};      // J-type
            3'b100: immediate = u_imm;                          // NEW: U-type (LUI)
            default: immediate = 32'b0;
        endcase
    end
endmodule
 
module RegisterFile (
    input clk, input rst, input WriteEnable,
    input [4:0] rs1, input [4:0] rs2, input [4:0] rd,
    input [31:0] WriteData,
    output [31:0] ReadData1, output [31:0] ReadData2
);
    reg [31:0] regs [31:0];
    integer i;
 
    always @(posedge clk) begin
        if (rst) begin
            regs[0] <= 32'b0;
            for (i = 1; i < 32; i = i + 1) regs[i] <= 32'b0;
        end else if (WriteEnable && rd != 5'd0) begin
            regs[rd] <= WriteData;
        end
    end
    assign ReadData1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign ReadData2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];
endmodule
 
module MainControl(
    input [6:0] opcode,
    output reg RegWrite, output reg [1:0] ALUOp,
    output reg MemRead, output reg MemWrite, output reg ALUSrc,
    output reg [1:0] MemtoReg, output reg Branch, output reg Jump, output reg Jalr
);
    always @(*) begin
        RegWrite = 0; ALUOp = 2'b00; MemRead = 0; MemWrite = 0; 
        ALUSrc = 0; MemtoReg = 2'b00; Branch = 0; Jump = 0; Jalr = 0;
 
        case(opcode)
            7'b0110011: begin RegWrite = 1; ALUOp = 2'b10; end // R-type
            7'b0010011: begin RegWrite = 1; ALUSrc = 1; ALUOp = 2'b10; end // I-type
            7'b0000011: begin RegWrite = 1; ALUSrc = 1; MemtoReg = 2'b01; MemRead = 1; end // Load
            7'b0100011: begin ALUSrc = 1; MemWrite = 1; end // Store
            7'b1100011: begin Branch = 1; ALUOp = 2'b01; end // Branch
            7'b1101111: begin RegWrite = 1; Jump = 1; MemtoReg = 2'b10; end // JAL
            7'b1100111: begin RegWrite = 1; Jump = 1; Jalr = 1; ALUSrc = 1; MemtoReg = 2'b10; end // JALR
            7'b0110111: begin RegWrite = 1; MemtoReg = 2'b11; end // NEW: LUI
            default: ; 
        endcase
    end
endmodule
 
module ALUControl(
    input [1:0] ALUOp, input [2:0] funct3, input funct7_bit, output reg [3:0] ALUControlOut
);
    always @(*) begin
        case(ALUOp)
            2'b00: ALUControlOut = 4'b0010; // Ld/St/JALR
            2'b01: ALUControlOut = 4'b0110; // Branch 
            2'b10: begin
                case(funct3)
                    3'b000: ALUControlOut = (funct7_bit) ? 4'b0110 : 4'b0010;
                    3'b111: ALUControlOut = 4'b0000;
                    3'b110: ALUControlOut = 4'b0001;
                    3'b100: ALUControlOut = 4'b0011;
                    3'b001: ALUControlOut = 4'b1000;
                    3'b101: ALUControlOut = 4'b1001;
                    default: ALUControlOut = 4'b1111; 
                endcase
            end
            default: ALUControlOut = 4'b1111;
        endcase
    end
endmodule
 
module ALU (
    input [31:0] A, input [31:0] B, input [3:0] ALUControl,
    output reg [31:0] ALUResult, output wire Zero
);
    assign Zero = (ALUResult == 0);
    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = A & B;
            4'b0001: ALUResult = A | B;
            4'b0010: ALUResult = A + B;
            4'b0110: ALUResult = A - B;
            4'b0011: ALUResult = A ^ B;
            4'b1000: ALUResult = A << B[4:0];
            4'b1001: ALUResult = A >> B[4:0];
            default: ALUResult = 32'b0;
        endcase
    end
endmodule
 
module AddressDecoder (
    input [31:0] address, input MemRead, input MemWrite,
    output DataMemSelect, output LEDSelect, output SwitchSelect
);
    assign DataMemSelect = ~address[9];                                  // 0x000 - 0x1FF
    assign LEDSelect     = (address[9:8] == 2'b10) & MemWrite; // 0x200 - 0x2FF (10 in binary is 2)
    assign SwitchSelect  = (address[9:8] == 2'b11) & MemRead;  // 0x300 - 0x3FF (11 in binary is 3)
endmodule
 
module DataMemory (
    input clk, input MemWrite, input [31:0] address, input [31:0] write_data,
    output [31:0] read_data
);
    reg [31:0] mem [0:511];
    always @(posedge clk) begin
        // RISC-V uses Byte-Addressing. Word index is address[10:2]
        if (MemWrite) mem[address[10:2]] <= write_data;
    end
    assign read_data = mem[address[10:2]];
endmodule
 
module leds (
    input clk, input rst, input [31:0] writeData, input writeEnable,
    output reg [15:0] leds
);
    always @(posedge clk) begin
        if (rst) leds <= 16'b0;
        else if (writeEnable) leds <= writeData[15:0];
    end
endmodule
 
module instructionMemory #(parameter OPERAND_LENGTH = 31) (
    input  [OPERAND_LENGTH:0] instAddress,
    output reg [31:0] instruction
);
    reg [7:0] memory [0:255];
    always @(*) begin
        instruction = { memory[instAddress + 3], memory[instAddress + 2],
                        memory[instAddress + 1], memory[instAddress + 0] };
    end
    integer i;
//     FIBONCACCI CALCULATOR TASK C
//    initial begin
//        for (i = 0; i < 256; i = i + 1) memory[i] = 8'h00;
 
//        // --- SETUP ---
//        // 0x00: addi sp, zero, 508
//        memory[  0] = 8'h13; memory[  1] = 8'h01; memory[  2] = 8'hC0; memory[  3] = 8'h1F;
//        // 0x04: addi x26, zero, 768 (s10 = Switches)
//        memory[  4] = 8'h13; memory[  5] = 8'h0D; memory[  6] = 8'h00; memory[  7] = 8'h30;
//        // 0x08: addi x27, zero, 512 (s11 = LEDs)
//        memory[  8] = 8'h93; memory[  9] = 8'h0D; memory[ 10] = 8'h00; memory[ 11] = 8'h20;
 
//        // --- MAIN_LOOP ---
//        // 0x0C: lw x10, 0(x26)
//        memory[ 12] = 8'h03; memory[ 13] = 8'h25; memory[ 14] = 8'h0D; memory[ 15] = 8'h00;
//        // 0x10: beq x10, zero, -4
//        memory[ 16] = 8'hE3; memory[ 17] = 8'h0E; memory[ 18] = 8'h05; memory[ 19] = 8'hFE;
//        // 0x14: jal x1, 24 (Call fib at 0x2C)
//        memory[ 20] = 8'hEF; memory[ 21] = 8'h00; memory[ 22] = 8'h80; memory[ 23] = 8'h01;
//        // 0x18: sw x10, 0(x27)
//        memory[ 24] = 8'h23; memory[ 25] = 8'hA0; memory[ 26] = 8'hAD; memory[ 27] = 8'h00;
 
//        // --- WAIT_RESET ---
//        // 0x1C: lw x5, 0(x26)
//        memory[ 28] = 8'h83; memory[ 29] = 8'h22; memory[ 30] = 8'h0D; memory[ 31] = 8'h00;
//        // 0x20: bne x5, zero, -4
//        memory[ 32] = 8'hE3; memory[ 33] = 8'h9E; memory[ 34] = 8'h02; memory[ 35] = 8'hFE;
//        // 0x24: sw zero, 0(x27)
//        memory[ 36] = 8'h23; memory[ 37] = 8'hA0; memory[ 38] = 8'h0D; memory[ 39] = 8'h00;
//        // 0x28: jal zero, -28 (Jump to 0x0C)
//        memory[ 40] = 8'h6F; memory[ 41] = 8'hF0; memory[ 42] = 8'h5F; memory[ 43] = 8'hFE;
 
//        // --- SUBROUTINE: FIB ---
//        // 0x2C: addi sp, sp, -12
//        memory[ 44] = 8'h13; memory[ 45] = 8'h01; memory[ 46] = 8'h41; memory[ 47] = 8'hFF;
//        // 0x30: sw x1, 8(sp)
//        memory[ 48] = 8'h23; memory[ 49] = 8'h24; memory[ 50] = 8'h11; memory[ 51] = 8'h00;
//        // 0x34: sw x8, 4(sp)
//        memory[ 52] = 8'h23; memory[ 53] = 8'h22; memory[ 54] = 8'h81; memory[ 55] = 8'h00;
//        // 0x38: sw x9, 0(sp)
//        memory[ 56] = 8'h23; memory[ 57] = 8'h20; memory[ 58] = 8'h91; memory[ 59] = 8'h00;
 
//        // 0x3C: addi x5, zero, 1
//        memory[ 60] = 8'h93; memory[ 61] = 8'h02; memory[ 62] = 8'h10; memory[ 63] = 8'h00;
//        // 0x40: beq x10, x5, 40 (Jump to 0x68 fib_done)
//        memory[ 64] = 8'h63; memory[ 65] = 8'h04; memory[ 66] = 8'h55; memory[ 67] = 8'h02;
 
//        // 0x44: addi x8, zero, 0
//        memory[ 68] = 8'h13; memory[ 69] = 8'h04; memory[ 70] = 8'h00; memory[ 71] = 8'h00;
//        // 0x48: addi x9, zero, 1
//        memory[ 72] = 8'h93; memory[ 73] = 8'h04; memory[ 74] = 8'h10; memory[ 75] = 8'h00;
//        // 0x4C: addi x10, x10, -1
//        memory[ 76] = 8'h13; memory[ 77] = 8'h05; memory[ 78] = 8'hF5; memory[ 79] = 8'hFF;
 
//        // --- FIB_LOOP ---
//        // 0x50: add x5, x8, x9
//        memory[ 80] = 8'hB3; memory[ 81] = 8'h02; memory[ 82] = 8'h94; memory[ 83] = 8'h00;
//        // 0x54: addi x8, x9, 0
//        memory[ 84] = 8'h13; memory[ 85] = 8'h84; memory[ 86] = 8'h04; memory[ 87] = 8'h00;
//        // 0x58: addi x9, x5, 0
//        memory[ 88] = 8'h93; memory[ 89] = 8'h84; memory[ 90] = 8'h02; memory[ 91] = 8'h00;
//        // 0x5C: addi x10, x10, -1
//        memory[ 92] = 8'h13; memory[ 93] = 8'h05; memory[ 94] = 8'hF5; memory[ 95] = 8'hFF;
//        // 0x60: bne x10, zero, -16 (Jump to 0x50)
//        memory[ 96] = 8'hE3; memory[ 97] = 8'h18; memory[ 98] = 8'h05; memory[ 99] = 8'hFE;
 
//        // 0x64: addi x10, x9, 0
//        memory[100] = 8'h13; memory[101] = 8'h85; memory[102] = 8'h04; memory[103] = 8'h00;
 
//        // --- FIB_DONE ---
//        // 0x68: lw x9, 0(sp)
//        memory[104] = 8'h83; memory[105] = 8'h24; memory[106] = 8'h01; memory[107] = 8'h00;
//        // 0x6C: lw x8, 4(sp)
//        memory[108] = 8'h03; memory[109] = 8'h24; memory[110] = 8'h41; memory[111] = 8'h00;
//        // 0x70: lw x1, 8(sp)
//        memory[112] = 8'h83; memory[113] = 8'h20; memory[114] = 8'h81; memory[115] = 8'h00;
//        // 0x74: addi sp, sp, 12
//        memory[116] = 8'h13; memory[117] = 8'h01; memory[118] = 8'hC1; memory[119] = 8'h00;
//        // 0x78: jalr zero, x1, 0
//        memory[120] = 8'h67; memory[121] = 8'h80; memory[122] = 8'h00; memory[123] = 8'h00;
//    end


//    ============= TASK A COUNTDOWN ===========
 
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 8'h00;
 
        // Base memory from your Lab 10 initialization 
        // 0x00: addi x2, x0, 252     # sp = 0xFC
        memory[  0] = 8'h13; memory[  1] = 8'h01; memory[  2] = 8'hC0; memory[  3] = 8'h0F;
        // 0x04: addi x5, x0, 768     # x5 = switch address (0x300)
        memory[  4] = 8'h93; memory[  5] = 8'h02; memory[  6] = 8'h00; memory[  7] = 8'h30;
        // 0x08: addi x6, x0, 512     # x6 = LED address (0x200)
        memory[  8] = 8'h13; memory[  9] = 8'h03; memory[ 10] = 8'h00; memory[ 11] = 8'h20;
        // 0x0C: sw x0, 0(x6)         # clear LEDs on startup
        memory[ 12] = 8'h23; memory[ 13] = 8'h20; memory[ 14] = 8'h03; memory[ 15] = 8'h00;
 
        // 0x10: lw x7, 0(x5)         # read switches
        memory[ 16] = 8'h83; memory[ 17] = 8'hA3; memory[ 18] = 8'h02; memory[ 19] = 8'h00;
        // 0x14: beq x7, x0, -4       # if 0, loop back to IDLE
        memory[ 20] = 8'hE3; memory[ 21] = 8'h8E; memory[ 22] = 8'h03; memory[ 23] = 8'hFE;
        // 0x18: sw x7, 0(x6)         # display switch value on LEDs
        memory[ 24] = 8'h23; memory[ 25] = 8'h20; memory[ 26] = 8'h73; memory[ 27] = 8'h00;
        // 0x1C: add x10, x7, x0      # x10 = switch value (subroutine arg)
        memory[ 28] = 8'h33; memory[ 29] = 8'h85; memory[ 30] = 8'h03; memory[ 31] = 8'h00;
        // 0x20: addi x2, x2, -8      # push stack (caller frame)
        memory[ 32] = 8'h13; memory[ 33] = 8'h01; memory[ 34] = 8'h81; memory[ 35] = 8'hFF;
        // 0x24: sw x1, 4(x2)         # save ra on stack
        memory[ 36] = 8'h23; memory[ 37] = 8'h22; memory[ 38] = 8'h11; memory[ 39] = 8'h00;
        // 0x28: sw x10, 0(x2)        # save argument on stack
        memory[ 40] = 8'h23; memory[ 41] = 8'h20; memory[ 42] = 8'hA1; memory[ 43] = 8'h00;
        // 0x2C: jal x1, +36          # call COUNTDOWN_SUB at 0x50
        memory[ 44] = 8'hEF; memory[ 45] = 8'h00; memory[ 46] = 8'h40; memory[ 47] = 8'h02;
        // 0x30: lw x1, 4(x2)         # restore ra
        memory[ 48] = 8'h83; memory[ 49] = 8'h20; memory[ 50] = 8'h41; memory[ 51] = 8'h00;
        // 0x34: addi x2, x2, 8       # pop caller stack frame
        memory[ 52] = 8'h13; memory[ 53] = 8'h01; memory[ 54] = 8'h81; memory[ 55] = 8'h00;
        // 0x38: jal x0, +4           # jump to WAIT_RELEASE at 0x3C
        memory[ 56] = 8'h6F; memory[ 57] = 8'h00; memory[ 58] = 8'h40; memory[ 59] = 8'h00;
 
        // WAIT_RELEASE State (PC = 0x3C)
        // 0x3C: lw x8, 0(x5)         # read current switch value
        memory[ 60] = 8'h03; memory[ 61] = 8'hA4; memory[ 62] = 8'h02; memory[ 63] = 8'h00;
        // 0x40: bne x8, x0, -4       # if non-zero, loop back to WAIT_RELEASE
        memory[ 64] = 8'hE3; memory[ 65] = 8'h1E; memory[ 66] = 8'h04; memory[ 67] = 8'hFE;
        // 0x44: jal x0, -52          # jump back to IDLE at 0x10
        memory[ 68] = 8'h6F; memory[ 69] = 8'hF0; memory[ 70] = 8'hDF; memory[ 71] = 8'hFC;
        // padding
        memory[ 72] = 8'h13; memory[ 73] = 8'h00; memory[ 74] = 8'h00; memory[ 75] = 8'h00;
        memory[ 76] = 8'h13; memory[ 77] = 8'h00; memory[ 78] = 8'h00; memory[ 79] = 8'h00;
 
        // COUNTDOWN_SUB Subroutine (PC = 0x50)
        // 0x50: addi x2, x2, -16     # allocate 4-word stack frame
        memory[ 80] = 8'h13; memory[ 81] = 8'h01; memory[ 82] = 8'h01; memory[ 83] = 8'hFF;
        // 0x54: sw x1, 12(x2)        # save ra
        memory[ 84] = 8'h23; memory[ 85] = 8'h26; memory[ 86] = 8'h11; memory[ 87] = 8'h00;
        // 0x58: sw x5, 8(x2)         # save switch addr
        memory[ 88] = 8'h23; memory[ 89] = 8'h24; memory[ 90] = 8'h51; memory[ 91] = 8'h00;
        // 0x5C: sw x6, 4(x2)         # save LED addr
        memory[ 92] = 8'h23; memory[ 93] = 8'h22; memory[ 94] = 8'h61; memory[ 95] = 8'h00;
        // 0x60: sw x10, 0(x2)        # save original count
        memory[ 96] = 8'h23; memory[ 97] = 8'h20; memory[ 98] = 8'hA1; memory[ 99] = 8'h00;
 
        // COUNTDOWN_LOOP (PC = 0x64)
        // 0x64: sw x10, 0(x6)        # leds = current count
        memory[100] = 8'h23; memory[101] = 8'h20; memory[102] = 8'hA3; memory[103] = 8'h00;
        // 0x68: beq x10, x0, +24     # if count == 0 jump to COUNTDOWN_DONE
        memory[104] = 8'h63; memory[105] = 8'h0C; memory[106] = 8'h05; memory[107] = 8'h00;
        // 0x6C: addi x8, x0, 500     # load delay count
        memory[108] = 8'h13; memory[109] = 8'h04; memory[110] = 8'h40; memory[111] = 8'h1F;
 
        // DELAY_LOOP (PC = 0x70)
        // 0x70: addi x8, x8, -1      # decrement delay counter
        memory[112] = 8'h13; memory[113] = 8'h04; memory[114] = 8'hF4; memory[115] = 8'hFF;
        // 0x74: bne x8, x0, -4       # loop back to DELAY_LOOP
        memory[116] = 8'hE3; memory[117] = 8'h1E; memory[118] = 8'h04; memory[119] = 8'hFE;
        // 0x78: addi x10, x10, -1    # count--
        memory[120] = 8'h13; memory[121] = 8'h05; memory[122] = 8'hF5; memory[123] = 8'hFF;
        // 0x7C: jal x0, -24          # jump back to COUNTDOWN_LOOP
        memory[124] = 8'h6F; memory[125] = 8'hF0; memory[126] = 8'h9F; memory[127] = 8'hFE;
 
        // COUNTDOWN_DONE (PC = 0x80)
        // 0x80: sw x0, 0(x6)         # clear LEDs
        memory[128] = 8'h23; memory[129] = 8'h20; memory[130] = 8'h03; memory[131] = 8'h00;
        // 0x84: lw x10, 0(x2)        # restore original count
        memory[132] = 8'h03; memory[133] = 8'h25; memory[134] = 8'h01; memory[135] = 8'h00;
        // 0x88: lw x6, 4(x2)         # restore LED address
        memory[136] = 8'h03; memory[137] = 8'h23; memory[138] = 8'h41; memory[139] = 8'h00;
        // 0x8C: lw x5, 8(x2)         # restore switch address
        memory[140] = 8'h83; memory[141] = 8'h22; memory[142] = 8'h81; memory[143] = 8'h00;
        // 0x90: lw x1, 12(x2)        # restore ra
        memory[144] = 8'h83; memory[145] = 8'h20; memory[146] = 8'hC1; memory[147] = 8'h00;
        // 0x94: addi x2, x2, 16      # free subroutine stack frame
        memory[148] = 8'h13; memory[149] = 8'h01; memory[150] = 8'h01; memory[151] = 8'h01;
        // 0x98: jalr x0, x1, 0       # return to caller
        memory[152] = 8'h67; memory[153] = 8'h80; memory[154] = 8'h00; memory[155] = 8'h00;
    end


//     task b quick show of alu signals
//    initial begin
//    for (i = 0; i < 256; i = i + 1) memory[i] = 8'h00;
//    // 0x00: lui x5, 0x0000A (MemtoReg = 11)
//    memory[0] = 8'h37; memory[1] = 8'hA2; memory[2] = 8'h00; memory[3] = 8'h00;
//    // 0x04: jal x1, 8 (Jump to subroutine at 0x0C. Jump flag = 1)
//    memory[4] = 8'hEF; memory[5] = 8'h00; memory[6] = 8'h80; memory[7] = 8'h00;
//    // 0x08: jal x0, -8 (Jump back to main at 0x00)
//    memory[8] = 8'h6F; memory[9] = 8'hF0; memory[10] = 8'h9F; memory[11] = 8'hFF;
//    // --- SUBROUTINE ---
//    // 0x0C: jalr x0, x1, 0 (Jump back to caller at 0x08. Jalr flag = 1)
//    memory[12] = 8'h67; memory[13] = 8'h80; memory[14] = 8'h00; memory[15] = 8'h00;
//    end

endmodule