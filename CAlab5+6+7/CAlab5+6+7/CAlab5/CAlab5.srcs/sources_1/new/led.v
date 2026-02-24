`timescale 1ns / 1ps

module led(
    input clk,
    input rst,
    input [31:0] writeData,
    input writeEnable,
    input readEnable,
    input [29:0] memAddress,
    
    output reg  [31:0] readData = 0, // not to be read       
    output reg [15:0] leds
    );
    
    reg [7:0] ledData [3:0];
    
    always @(posedge clk) begin
        if(writeEnable) begin 
        	ledData[0] <= writeData[7:0];
        	ledData[1] <= writeData[15:8];
        // do nothing on readEnable (output device only)
        end 
    end
    
    always @(*) begin
        if (rst) leds = 16'b0;
        else leds = {ledData[1], ledData[0]};
    end
endmodule


