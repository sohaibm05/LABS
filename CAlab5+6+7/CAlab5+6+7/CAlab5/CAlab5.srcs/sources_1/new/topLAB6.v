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

module top_lab6(
    // btnc - for FSM trigger
    input clk, input btnc, input rst, input [15:0] sw, output [15:0] led_out
    );        
    // internal signals
    wire btn_pulse;
    wire [31:0] A = 32'h10101010;
    wire [31:0] B = 32'h01010101;
    reg  [3:0]  latch_control;
    wire [31:0] alu_result;
    wire zero_flag;
    
    // combine alu_result and zero_flag to send into leds
    wire [31:0] combined_data = {alu_result[30:0], zero_flag};
    // debounce btn
    debouncer btn_db (.clk(clk), .pbin(btnc),.pbout(btn_pulse));
    // latch logic
    always @(posedge clk) begin
        if (btn_pulse) begin
            latch_control <= sw[3:0];
        end
    end        
    
    ALU_wrapper my_alu(.A(A),.B(B), .ALUControl(latch_control), .ALUResult(alu_result), .Zero(zero_flag));
    led my_led_interface (
        //                  Data to be written to LED registers,                
        .clk(clk),.rst(rst),.writeData(combined_data),.writeEnable(btn_pulse),.readEnable(1'b0),.memAddress(30'b0),.readData(),.leds(led_out)
    );
endmodule    