`timescale 1ns / 1ps

module debouncer(
    input clk,
    input pbin,     
    output pbout  
    );

    reg pbSync1, pbSync2;
    always @(posedge clk) begin
        pbSync1 <= pbin;
        pbSync2 <= pbSync1;
    end

    reg slowPulse;
    reg [29:0] counter = 0;
    always @(posedge clk) begin
        if(counter == 1) begin
            counter <= 0;
            slowPulse <= 1;
        end
        else begin
            counter <= counter + 1;
            slowPulse <= 0;
        end 
    end

    reg Q0, Q1, Q2;
    always @(posedge clk) begin
        if (slowPulse) begin
            Q0 <= pbSync2; 
            Q1 <= Q0;
            Q2 <= Q1;
        end
    end

    wire pbDebounced = Q0 & Q1 & Q2; 
   

    reg pbPressed_d;
    always @(posedge clk) pbPressed_d <= pbDebounced;
    
    assign pbout = pbDebounced & ~pbPressed_d; // 1-cycle active-high pulse



endmodule
