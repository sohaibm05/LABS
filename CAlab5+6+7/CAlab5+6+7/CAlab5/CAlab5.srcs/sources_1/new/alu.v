`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 03:41:55 PM
// Design Name: 
// Module Name: alu
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


module alu_1bit(
        input a, // 1bit operand A
        input b, // 1 bit operand B
        input cin, // carry in from previous bit
        input [3:0] op, // operation selector
        output reg res, // 1 bit result
        output reg cout // carry out to next bit  
    );
    always @(*) begin
    // Default values to prevent latches
        res = 1'b0;
        cout = 1'b0;
        case(op)
            4'b0000: begin // add
                res = a ^ b ^ cin; // sum
                cout = (a & b) | (cin & (a^b)); // carry
                end
            4'b0001: begin //sub
                res = a ^ b ^ cin;
                cout = (a & b) | (cin & (a^b));
                end
             4'b0010: res = a & b; // and
             4'b0011: res = a | b; // or 
             4'b0100: res = a ^ b; // xor
             default: res = 1'b0;
       endcase
       end         
endmodule
