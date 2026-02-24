`timescale 1ns / 1ps

module clock_divider #(
    parameter ONE_HZ_LIMIT  = 100_000_000,  // 100 MHz -> 1 Hz
    parameter REFRESH_LIMIT = 200_000       // 100 MHz -> ~500 Hz refresh
)(
    input  clk,
    input  rst,
    output reg enable_1hz    = 0,
    output reg enable_refresh = 0
);

    // --- 1 Hz Enable ---
    reg [26:0] cnt_1hz = 0;
    always @(posedge clk) begin
        if (rst) begin
            cnt_1hz    <= 0;
            enable_1hz <= 0;
        end else if (cnt_1hz == ONE_HZ_LIMIT - 1) begin
            cnt_1hz    <= 0;
            enable_1hz <= 1;
        end else begin
            cnt_1hz    <= cnt_1hz + 1;
            enable_1hz <= 0;
        end
    end

    // --- ~500 Hz Refresh Enable ---
    reg [17:0] cnt_refresh = 0;
    always @(posedge clk) begin
        if (rst) begin
            cnt_refresh    <= 0;
            enable_refresh <= 0;
        end else if (cnt_refresh == REFRESH_LIMIT - 1) begin
            cnt_refresh    <= 0;
            enable_refresh <= 1;
        end else begin
            cnt_refresh    <= cnt_refresh + 1;
            enable_refresh <= 0;
        end
    end

endmodule
