`timescale 1ns / 1ps

module seven_segment(
    input  clk,
    input  rst,
    input  enable_refresh,  // ~500 Hz pulse
    input  [15:0] val,  // 16-bit value to display in hex
    output reg [6:0] seg,   // Cathodes (active-low): a-g
    output reg [3:0] an  // Anodes   (active-low): 4 digits
);

    reg [1:0] digit_sel = 0; // Which digit is active (0-3)
    reg [3:0] hex_digit;  // Current 4-bit nibble

    //  Digit Multiplexer 
    always @(posedge clk) begin
        if (rst)
            digit_sel <= 0;
        else if (enable_refresh)
            digit_sel <= digit_sel + 1;
    end

    // Select which nibble to display 
    always @(*) begin
        case (digit_sel)
            2'd0: hex_digit = val[3:0];
            2'd1: hex_digit = val[7:4];
            2'd2: hex_digit = val[11:8];
            2'd3: hex_digit = val[15:12];
            default: hex_digit = 4'h0;
        endcase
    end

    //  Anode control (active-low: 0 = ON) 
    always @(*) begin
        case (digit_sel)
            2'd0: an = 4'b1110;
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111;
            default: an = 4'b1111;
        endcase
    end

    // Hex to 7-Segment Decoder (active-low: 0 = segment ON) 
    //     Segment order: seg[6:0] = {g, f, e, d, c, b, a}
    always @(*) begin
        case (hex_digit)
            4'h0: seg = 7'b1000000;  // 0
            4'h1: seg = 7'b1111001;  // 1
            4'h2: seg = 7'b0100100;  // 2
            4'h3: seg = 7'b0110000;  // 3
            4'h4: seg = 7'b0011001;  // 4
            4'h5: seg = 7'b0010010;  // 5
            4'h6: seg = 7'b0000010;  // 6
            4'h7: seg = 7'b1111000;  // 7
            4'h8: seg = 7'b0000000;  // 8
            4'h9: seg = 7'b0010000;  // 9
            4'hA: seg = 7'b0001000;  // A
            4'hB: seg = 7'b0000011;  // b
            4'hC: seg = 7'b1000110;  // C
            4'hD: seg = 7'b0100001;  // d
            4'hE: seg = 7'b0000110;  // E
            4'hF: seg = 7'b0001110;  // F
            default: seg = 7'b1111111; // all off
        endcase
    end

endmodule
