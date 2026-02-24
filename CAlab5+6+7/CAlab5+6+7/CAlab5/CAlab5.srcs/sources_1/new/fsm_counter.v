`timescale 1ns / 1ps

module fsm_counter(
    input clk,
    input reset,    // Synchronous reset pulse/signal
    input enable, // 1 Hz enable pulse
    input [15:0] switches, // Input from switches module
    output reg [15:0] leds  // Output to LED module
    );

    // State definitions
    localparam IDLE         = 2'd0;
    localparam COUNTDOWN    = 2'd1;
    localparam WAIT_RELEASE = 2'd2;

    reg [1:0] state;
    reg [15:0] counter;

    // FSM and Counter Logic
    always @(posedge clk) begin
        if (reset) begin
            state   <= IDLE;
            counter <= 16'b0;
            leds    <= 16'b0;
        end
        else begin
            case (state)
                // IDLE: Wait for a non-zero switch input 
                IDLE: begin
                    leds <= 16'b0;
                    if (switches != 16'b0) begin
                        counter <= switches;   // Load counter with switch value
                        leds    <= switches;   // Show the initial value immediately
                        state   <= COUNTDOWN;
                    end
                end

                //  COUNTDOWN: Decrement once per enable pulse 
                COUNTDOWN: begin
                    leds <= counter;  // Always show current counter value
                    if (enable) begin
                        if (counter == 16'b0) begin
                            state <= WAIT_RELEASE;
                        end
                        else begin
                            counter <= counter - 1'b1;
                        end
                    end
                end

                // WAIT_RELEASE: Done counting, wait for switches to go to 0 ----
                WAIT_RELEASE: begin
                    leds <= 16'b0;             // LEDs off after countdown is done
                    if (switches == 16'b0) begin
                        state <= IDLE;         // Ready for new input
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
