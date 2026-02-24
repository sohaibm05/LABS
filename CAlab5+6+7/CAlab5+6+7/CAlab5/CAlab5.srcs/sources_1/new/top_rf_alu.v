`timescale 1ns / 1ps

module top_rf_alu_tb;
    reg clk;
    reg reset_btn;
    reg [15:0] switches;
    wire [15:0] leds;
    wire [6:0] seg;
    wire [3:0] an;

    top uut (
        .clk(clk),
        .reset_btn(reset_btn),
        .switches(switches),
        .leds(leds),
        .seg(seg),
        .an(an)
    );

    initial clk = 0;
    always #5 clk = ~clk;

//    initial begin
//        reset_btn = 0;
//        switches = 0;

//        // Reset Pulse
//        #100;
//        reset_btn = 1;
//        #100;
//        reset_btn = 0;
        
//        $display("Reset applied. FSM running...");

//        // Wait for FSM to reach S_DONE
//        #5000; 

//        $display("Final ALU Result: %h", uut.alu_result);
        
//        if (uut.alu_result == 32'h00000000) // Result of AND operation
//            $display("PASS: Integrated sequence completed.");
        
//        $finish;
//    end

    initial begin
        // Initialize Inputs
        reset_btn = 0;
        switches = 0;

        // Reset Pulse
        #100;
        reset_btn = 1;
        #100;
        reset_btn = 0;
        
        $display("--- Starting Lab 7 Integrated Simulation ---");

        // Monitor the FSM and display results when states change
        // We wait for the 'S_DONE' state (6)
        wait(uut.state == 3'd6); 

        $display("\nFinal Verification at S_DONE:");
        $display("Register x1 contains: %h", uut.u_regfile.regs[1]);
        $display("Register x2 contains: %h", uut.u_regfile.regs[2]);
        $display("ALU Result (AND): %h", uut.alu_result);
        $display("Zero Flag: %b", uut.alu_zero);
        
        if (uut.alu_result == 32'h00000000 && uut.alu_zero == 1'b1)
            $display("\nPASS: Integrated sequence completed successfully.");
        else
            $display("\nFAIL: Result or Zero flag mismatch.");
        
        #100;
        $finish;
    end
endmodule