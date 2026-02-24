`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2026 12:13:59 PM
// Design Name: 
// Module Name: ALU_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU_tb;
    // Declare inputs as REG and outputs as WIRE
    reg [31:0] A; 
    reg [31:0] B; 
    reg [3:0] ALUControl; 
    
    wire [31:0] ALUResult;
    wire Zero;
    
    // Instantiate unit under test
    ALU_wrapper uut(.A(A), .B(B), .ALUControl(ALUControl), .ALUResult(ALUResult), .Zero(Zero));
    
    // Test
    initial begin
        // Initialize inputs
        A = 32'h0; B = 32'h0; ALUControl = 4'b0000;
        
        #20;
        // -----------ADD-----------
        A = 32'd10; B = 32'd5; ALUControl = 4'b0000;
        #10;
        // ----------SUB------------
        ALUControl = 4'b0001;
        #10;
        // ----------AND---------
        A = 32'hF0F0F0F0; B = 32'h0F0F0F0F; ALUControl = 4'b0010;
        #10;
        // ----------OR---------
        A = 32'hF0F0FFF0; B = 32'h0FFF0F0F; ALUControl = 4'b0011;
        #10;
        // ----------XOR---------
        A = 32'hF0FDFEF0; B = 32'h0F0F0F0F; ALUControl = 4'b0100;
        #10;
        // ----------SLL---------
        A = 32'h00000001; B = 32'd4; ALUControl = 4'b0101;
        #10;
        // ----------SRL---------
        A = 32'hFF00FF00; B = 32'd4; ALUControl = 4'b0110;
        
        #20;
        $finish;
    end
    
    // TCL Display
    initial begin 
        $monitor("TIME=%t | A = %h B = %h Ctrl = %b | Res=%h Zero =%b",
                $time, A, B, ALUControl, ALUResult, Zero);
        end             
endmodule
