`timescale 1ns / 1ps

// Integrated testbench:
// - Instantiates RegisterFile and ALU_wrapper
// - Uses an FSM to perform a deterministic sequence of operations

module RF_ALU_FSM_tb;

    // Clock / reset
    reg clk;
    reg rst;

    // Register file control
    reg         rf_WriteEnable;
    reg  [4:0]  rf_rs1;
    reg  [4:0]  rf_rs2;
    reg  [4:0]  rf_rd;
    reg  [31:0] rf_WriteData;
    wire [31:0] rf_ReadData1;
    wire [31:0] rf_ReadData2;

    // ALU control
    reg  [3:0]  ALUControl;
    wire [31:0] ALUResult;
    wire        Zero;

    // Instantiate Register File
    RegisterFile rf (
        .clk(clk),
        .rst(rst),
        .WriteEnable(rf_WriteEnable),
        .rs1(rf_rs1),
        .rs2(rf_rs2),
        .rd(rf_rd),
        .WriteData(rf_WriteData),
        .ReadData1(rf_ReadData1),
        .ReadData2(rf_ReadData2)
    );

    // Instantiate ALU
    ALU_wrapper alu (
        .A(rf_ReadData1),
        .B(rf_ReadData2),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult),
        .Zero(Zero)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // FSM states
    localparam IDLE        = 4'd0,
               WRITE_CONST = 4'd1,
               ADD_OP      = 4'd2,
               SUB_OP      = 4'd3,
               AND_OP      = 4'd4,
               OR_OP       = 4'd5,
               XOR_OP      = 4'd6,
               SLL_OP      = 4'd7,
               SRL_OP      = 4'd8,
               BEQ_CHECK   = 4'd9,
               RAW_TEST1   = 4'd10,
               RAW_TEST2   = 4'd11,
               DONE        = 4'd12;

    reg [3:0] state;

    // For simple checking
    reg [31:0] constA;
    reg [31:0] constB;

    initial begin
        // Initialize constants
        constA = 32'h10101010;
        constB = 32'h01010101;

        // Init signals
        clk            = 0;
        rst            = 1'b1;
        rf_WriteEnable = 1'b0;
        rf_rs1         = 5'd0;
        rf_rs2         = 5'd0;
        rf_rd          = 5'd0;
        rf_WriteData   = 32'd0;
        ALUControl     = 4'b0000;
        state          = IDLE;

        // Release reset after a few cycles
        #20;
        rst = 1'b0;
    end

    // Simple helpers for writing registers from FSM
    task fsm_write_reg(input [4:0] addr, input [31:0] data);
    begin
        rf_WriteEnable <= 1'b1;
        rf_rd          <= addr;
        rf_WriteData   <= data;
    end
    endtask

    task fsm_stop_write;
    begin
        rf_WriteEnable <= 1'b0;
        rf_rd          <= 5'd0;
        rf_WriteData   <= 32'd0;
    end
    endtask

    // FSM sequential logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            fsm_stop_write();
        end else begin
            case (state)
                IDLE: begin
                    // Prepare to write constants
                    state <= WRITE_CONST;
                end

                // Write constants into x1, x2, x3
                WRITE_CONST: begin
                    // x1 = constA, x2 = constB, x3 = 5
                    fsm_write_reg(5'd1, constA);
                    state <= ADD_OP;
                end

                // ADD: x4 = x1 + x2
                ADD_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd2;
                    ALUControl <= 4'b0000; // ADD
                    // Write result next cycle to x4
                    fsm_write_reg(5'd4, ALUResult);
                    state <= SUB_OP;
                end

                // SUB: x5 = x1 - x2
                SUB_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd2;
                    ALUControl <= 4'b0001; // SUB
                    fsm_write_reg(5'd5, ALUResult);
                    state <= AND_OP;
                end

                // AND: x6 = x1 & x2
                AND_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd2;
                    ALUControl <= 4'b0010; // AND
                    fsm_write_reg(5'd6, ALUResult);
                    state <= OR_OP;
                end

                // OR: x7 = x1 | x2
                OR_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd2;
                    ALUControl <= 4'b0011; // OR
                    fsm_write_reg(5'd7, ALUResult);
                    state <= XOR_OP;
                end

                // XOR: x8 = x1 ^ x2
                XOR_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd2;
                    ALUControl <= 4'b0100; // XOR
                    fsm_write_reg(5'd8, ALUResult);
                    state <= SLL_OP;
                end

                // SLL: x9 = x1 << (x3[4:0])
                SLL_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd3;     // shift amount
                    ALUControl <= 4'b0101;  // SLL
                    fsm_write_reg(5'd9, ALUResult);
                    state <= SRL_OP;
                end

                // SRL: x10 = x1 >> (x3[4:0])
                SRL_OP: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd1;
                    rf_rs2     <= 5'd3;     // shift amount
                    ALUControl <= 4'b0110;  // SRL
                    fsm_write_reg(5'd10, ALUResult);
                    state <= BEQ_CHECK;
                end

                // BEQ-style check: compare x4 with itself, set x11 flag
                BEQ_CHECK: begin
                    fsm_stop_write();
                    rf_rs1     <= 5'd4;
                    rf_rs2     <= 5'd4;     // always equal
                    ALUControl <= 4'b0001;  // SUB, Zero should be 1

                    if (Zero) begin
                        fsm_write_reg(5'd11, 32'h1);  // flag = 1 when equal
                    end else begin
                        fsm_write_reg(5'd11, 32'h0);
                    end

                    state <= RAW_TEST1;
                end

                // RAW test 1: write x12, then read it next cycle
                RAW_TEST1: begin
                    // Write some value into x12
                    fsm_write_reg(5'd12, 32'h12345678);
                    state <= RAW_TEST2;
                end

                RAW_TEST2: begin
                    // Stop write and read back x12 (read-after-write)
                    fsm_stop_write();
                    rf_rs1 <= 5'd12;
                    rf_rs2 <= 5'd0;

                    state <= DONE;
                end

                DONE: begin
                    fsm_stop_write();
                    // Remain in DONE
                    state <= DONE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Simple monitors / checks
    initial begin
        $display("Starting RF_ALU_FSM_tb...");
        $monitor("T=%0t state=%0d rs1=%0d rs2=%0d rd=%0d ALUCtrl=%b A=%h B=%h Res=%h Zero=%b",
                 $time, state, rf_rs1, rf_rs2, rf_rd, ALUControl,
                 rf_ReadData1, rf_ReadData2, ALUResult, Zero);

        // Let simulation run for a while, then do a few checks
        #500;

        // Basic post-checks (non-exhaustive)
        // Check that x11 flag is set (BEQ passed)
        rf_rs1 = 5'd11;
        #1;
        if (rf_ReadData1 !== 32'h1)
            $display("WARNING: BEQ-style flag (x11) not set as expected. Got %h", rf_ReadData1);
        else
            $display("PASS: BEQ-style flag x11 = %h", rf_ReadData1);

        // Check RAW test value in x12
        rf_rs1 = 5'd12;
        #1;
        if (rf_ReadData1 !== 32'h12345678)
            $display("WARNING: RAW test for x12 failed. Got %h", rf_ReadData1);
        else
            $display("PASS: RAW test x12 = %h", rf_ReadData1);

        $display("RF_ALU_FSM_tb completed.");
        #50;
        $finish;
    end

endmodule

