`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 03:41:55 PM
// Design Name: 
// Module Name: topLAB6
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

module ALU_wrapper(
    input [31:0] A, // 32 bit operand A
    input [31:0] B, // 32 bit operand B
    input [3:0] ALUControl, // operation selector
    output reg [31:0] ALUResult, // Output
    output Zero
);
    wire [31:0] bit_res;
    wire [32:0] carry;
    
    // set first carry in as 1 if we are subtracting
    assign carry[0] = (ALUControl == 4'b0001) ? 1'b1 : 1'b0;
    
    parameter Size = 32;
    genvar i; 
    generate
        for (i = 0; i< Size; i = i + 1) begin: gen_alu
            alu_1bit b_alu (.a(A[i]),
                     // INVERT B here if the operation is SUB (4'b0001)
                     .b((ALUControl == 4'b0001) ? ~B[i] : B[i]),
                     .cin(carry[i]),
                     .op(ALUControl),
                     .res(bit_res[i]),
                     .cout(carry[i+1])
                     );
            end 
        endgenerate
                     
    // Final Mux to handle Results including shifting
    always @(*) begin
        case (ALUControl)
            4'b0101: ALUResult = A << B [4:0]; // SLL left shift
            4'b0110: ALUResult = A >> B [4:0]; // SLL right shfit
            default: ALUResult = bit_res;
        endcase 
    end 
    
    assign Zero = (ALUResult ==32'b0);        
endmodule            