`timescale 1ns / 1ps

module onehot_decoder(
    input  [15:0] switches,
    output reg [15:0] decoded_value
);

    // Count how many switches are on
    integer i;
    reg [4:0] count;
    reg [3:0] position;
    
    always @(*) begin
        count = 0;
        position = 0;
        
        // Find which switch is on and count total
        for (i = 0; i < 16; i = i + 1) begin
            if (switches[i]) begin
                count = count + 1;
                position = i[3:0];
            end
        end
        
        // Only valid if exactly ONE switch is on
        if (count == 1) begin
            decoded_value = {12'b0, position};  // Output the switch index
        end
        else begin
            decoded_value = 16'b0;  // Invalid: 0 or multiple switches
        end
    end

endmodule
