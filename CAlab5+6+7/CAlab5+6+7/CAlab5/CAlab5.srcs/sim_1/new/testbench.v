`timescale 1ns / 1ps

module testbench;

    // Inputs
    reg clk;
    reg reset_btn;
    reg [15:0] switches;

    // Outputs
    wire [15:0] leds;

    // DUT Instance
    top uut (
        .clk(clk),
        .reset_btn(reset_btn),
        .switches(switches),
        .leds(leds)
    );

    // --- CRITICAL: OVERRIDE PARAMETERS FOR SIMULATION ---
    // The design waits 100,000,000 cycles for 1 second. 
    // In simulation, we must force this to be small (e.g., 2 or 4) to see counting.
    // referencing the instance path: uut.u_clkdiv
    defparam uut.u_clkdiv.ONE_HZ_LIMIT = 4;
    defparam uut.u_clkdiv.REFRESH_LIMIT = 2;

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        reset_btn = 0;
        switches = 0;

        // Wait for global reset / stabilization
        #100;
        
        // --- GLOBAL RESET INITIALIZATION ---
        $display("Applying Global Reset...");
        reset_btn = 1; 
        #100; // Hold reset to clear X states
        reset_btn = 0;
        #100;
        $display("System Initialized.");

        // --- Case 1: Simple Countdown (5 -> 0) ---
        $display("Starting Case 1: Countdown 5 -> 0");
        switches = 16'd5;
        #50; // Wait for FSM to pick it up (State -> COUNTDOWN)
        switches = 16'd0; // Clear input to prevent looping
        
        // Wait for countdown to finish 
        // With limit=4, each count takes ~40ns. 5 counts = 200ns.
        #500; 
        
        if (leds === 16'd0) $display("Case 1 Passed: Countdown finished and LEDs off");
        else $display("Case 1 Check: LEDs are %d", leds);


        // --- Case 2: Mid-Count Reset (8 -> Reset) ---
        $display("Starting Case 2: Countdown 8 -> Reset");
        switches = 16'd8;
        #50; // Start counting
        switches = 16'd0; // Clear input
        #40; // Let it count a bit
        
        $display("Asserting Reset...");
        reset_btn = 1;
        #100; // Hold for debouncer
        reset_btn = 0;
        
        // Wait for FSM to react
        #50;
        
        if (leds === 16'd0) $display("Case 2 Passed: Reset cleared LEDs");
        else $display("Error Case 2: LEDs are %d", leds);


        // --- Case 3: Stability Test (Input Change Ignored) ---
        $display("Starting Case 3: Stability Test (New inputs should be ignored during countdown)");
        switches = 16'd20; // Start countdown from 20
        #50;
        switches = 16'd0; // Clear initial input
        #40;
        
        $display("Changing switches to 5 mid-count...");
        switches = 16'd5; // Distractor input
        #100;
        
        switches = 16'd0; // Clear distractor
        #100;
        
        // Check: Should be counting down from 20, NOT 5 or 0.
        if (leds > 16'd5) $display("Case 3 Passed: Counter ignored new input (Current: %d)", leds);
        else $display("Error Case 3: Counter jumped! (Current: %d)", leds);
        
        #500;
        $finish;
    end

endmodule
