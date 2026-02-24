`timescale 1ns / 1ps

// Standalone testbench for RegisterFile

module RegisterFile_tb;

    // DUT signals
    reg         clk;
    reg         rst;
    reg         WriteEnable;
    reg  [4:0]  rs1;
    reg  [4:0]  rs2;
    reg  [4:0]  rd;
    reg  [31:0] WriteData;
    wire [31:0] ReadData1;
    wire [31:0] ReadData2;

    // Instantiate DUT
    RegisterFile uut (
        .clk(clk),
        .rst(rst),
        .WriteEnable(WriteEnable),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .WriteData(WriteData),
        .ReadData1(ReadData1),
        .ReadData2(ReadData2)
    );

    // Clock generation (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Simple task to write a register (except x0)
    task write_reg(input [4:0] addr, input [31:0] data);
    begin
        @(negedge clk);
        WriteEnable = 1'b1;
        rd          = addr;
        WriteData   = data;
        @(negedge clk);
        WriteEnable = 1'b0;
        rd          = 5'd0;
        WriteData   = 32'b0;
    end
    endtask

    // Simple task to set read addresses
    task set_reads(input [4:0] a1, input [4:0] a2);
    begin
        rs1 = a1;
        rs2 = a2;
        #1; // allow propagation
    end
    endtask

    initial begin
        // Initialize
        clk         = 0;
        rst         = 0;
        WriteEnable = 0;
        rs1         = 0;
        rs2         = 0;
        rd          = 0;
        WriteData   = 0;

        // Apply reset
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;

        // i. Write a value to a register and read it back
        write_reg(5'd5, 32'hDEADBEEF);
        set_reads(5'd5, 5'd0);
        #1;
        if (ReadData1 !== 32'hDEADBEEF)
            $display("ERROR: Write/read mismatch for x5. Got %h", ReadData1);
        else
            $display("PASS: Write/read for x5 = %h", ReadData1);

        // ii. Attempt to write to x0 and verify it remains zero
        write_reg(5'd0, 32'hFFFFFFFF);
        set_reads(5'd0, 5'd0);
        #1;
        if (ReadData1 !== 32'h0 || ReadData2 !== 32'h0)
            $display("ERROR: x0 was modified! R1=%h R2=%h", ReadData1, ReadData2);
        else
            $display("PASS: x0 remains 0 after write attempt");

        // iii. Simultaneous two read ports: write x6 and x7, then read both
        write_reg(5'd6, 32'h11111111);
        write_reg(5'd7, 32'h22222222);
        set_reads(5'd6, 5'd7);
        #1;
        if (ReadData1 !== 32'h11111111 || ReadData2 !== 32'h22222222)
            $display("ERROR: dual read mismatch. R1=%h R2=%h", ReadData1, ReadData2);
        else
            $display("PASS: dual read x6/x7 OK");

        // iv. Overwrite a register and verify old value is replaced
        write_reg(5'd8, 32'hAAAAAAAA);
        write_reg(5'd8, 32'hBBBBBBBB);
        set_reads(5'd8, 5'd0);
        #1;
        if (ReadData1 !== 32'hBBBBBBBB)
            $display("ERROR: overwrite failed for x8. Got %h", ReadData1);
        else
            $display("PASS: overwrite x8 OK = %h", ReadData1);

        // v. Reset behavior: verify registers clear
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        set_reads(5'd5, 5'd6);
        #1;
        if (ReadData1 !== 32'h0 || ReadData2 !== 32'h0)
            $display("ERROR: reset failed to clear registers. R1=%h R2=%h", ReadData1, ReadData2);
        else
            $display("PASS: reset cleared registers");

        $display("RegisterFile_tb completed.");
        #20;
        $finish;
    end

endmodule

