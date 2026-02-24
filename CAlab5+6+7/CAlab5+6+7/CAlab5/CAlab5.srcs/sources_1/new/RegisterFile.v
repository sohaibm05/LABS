`timescale 1ns / 1ps

// 32 x 32-bit Register File following RV32I conventions
// - x0 (regs[0]) is hardwired to 0: reads always return 0, writes are ignored
// - Two asynchronous read ports
// - One synchronous write port

module RegisterFile (
    input              clk,
    input              rst,          // synchronous reset, clears x1..x31 to 0
    input              WriteEnable,
    input      [4:0]   rs1,
    input      [4:0]   rs2,
    input      [4:0]   rd,
    input      [31:0]  WriteData,
    output     [31:0]  ReadData1,
    output     [31:0]  ReadData2
);

    // 32 registers of 32 bits each
    reg [31:0] regs [31:0];

    integer i;

    // Synchronous write + synchronous reset
    always @(posedge clk) begin
        if (rst) begin
            // x0 is always 0, clear x1..x31
            regs[0] <= 32'b0;
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (WriteEnable) begin
            // Ignore writes to x0
            if (rd != 5'd0) begin
                regs[rd] <= WriteData;
            end
        end
    end

    // Asynchronous read ports with x0 hardwired to zero
    assign ReadData1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign ReadData2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

endmodule

