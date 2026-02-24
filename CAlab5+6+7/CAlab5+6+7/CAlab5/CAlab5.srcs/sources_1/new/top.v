`timescale 1ns / 1ps

module top(
    input clk,
    input reset_btn,        
    input [15:0] switches,  
    output [15:0] leds,     
    output [6:0] seg,       
    output [3:0] an         
    );

    // Internal Signals
    wire reset_debounced;
    wire enable_1hz;
    wire enable_refresh;
    
    // Register File & ALU Wiring
    wire [31:0] rf_ReadData1, rf_ReadData2;
    reg rf_WriteEnable;
    reg [4:0] rf_rs1, rf_rs2, rf_rd;
    reg [31:0] rf_WriteData;
    
    wire [31:0] alu_result;
    wire alu_zero;
    reg [3:0] alu_control;

    // FSM States
    localparam S_IDLE = 3'd0, S_WRITE_X1 = 3'd1, S_WRITE_X2 = 3'd2, 
               S_ADD = 3'd3, S_SUB = 3'd4, S_AND = 3'd5, S_DONE = 3'd6;
    reg [2:0] state = S_IDLE;

    // Debouncer for Reset
    debouncer u_debouncer (
        .clk(clk),
        .pbin(reset_btn),
        .pbout(reset_debounced)
    );

    // Clock Divider (Small limit for fast simulation)
    clock_divider #(.ONE_HZ_LIMIT(10)) u_clkdiv ( 
        .clk(clk),
        .rst(reset_debounced),
        .enable_1hz(enable_1hz),
        .enable_refresh(enable_refresh)
    );

    // Register File Instance [cite: 33, 35]
    RegisterFile u_regfile (
        .clk(clk),
        .rst(reset_debounced),
        .WriteEnable(rf_WriteEnable),
        .rs1(rf_rs1), .rs2(rf_rs2), .rd(rf_rd),
        .WriteData(rf_WriteData),
        .ReadData1(rf_ReadData1), .ReadData2(rf_ReadData2)
    );

    // ALU Instance [cite: 45]
    ALU_wrapper u_alu (
        .A(rf_ReadData1),
        .B(rf_ReadData2),
        .ALUControl(alu_control),
        .ALUResult(alu_result),
        .Zero(alu_zero)
    );

    // FSM Control Logic [cite: 46, 51]
    always @(posedge clk) begin
        if (reset_debounced) begin
            state <= S_IDLE;
            rf_WriteEnable <= 0;
        end else if (enable_1hz) begin
            case (state)
                S_IDLE: state <= S_WRITE_X1;
                
                S_WRITE_X1: begin // Write 0x10101010 to x1 [cite: 47, 87]
                    rf_WriteEnable <= 1; rf_rd <= 5'd1; 
                    rf_WriteData <= 32'h10101010;
                    state <= S_WRITE_X2;
                end
                
                S_WRITE_X2: begin // Write 0x01010101 to x2 [cite: 47, 88]
                    rf_rd <= 5'd2; 
                    rf_WriteData <= 32'h01010101;
                    state <= S_ADD;
                end
                
                S_ADD: begin // x1 + x2 [cite: 48]
                    rf_WriteEnable <= 0;
                    rf_rs1 <= 5'd1; rf_rs2 <= 5'd2;
                    alu_control <= 4'b0000;
                    state <= S_SUB;
                end

                S_SUB: begin // x1 - x2 [cite: 48]
                    alu_control <= 4'b0001;
                    state <= S_AND;
                end

                S_AND: begin // x1 & x2 [cite: 48]
                    alu_control <= 4'b0010;
                    state <= S_DONE;
                end

                S_DONE: state <= S_DONE;
            endcase
        end
    end

    // Output Mapping [cite: 85, 94]
    assign leds = alu_result[15:0]; 

    seven_segment u_7seg (
        .clk(clk), .rst(reset_debounced),
        .enable_refresh(enable_refresh),
        .val(alu_result[15:0]),
        .seg(seg), .an(an)
    );

endmodule