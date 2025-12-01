`timescale 1ns / 1ps

module counting_down_tb;

    reg clk;
    reg rst_n;
    reg [15:0] time_in;
    reg start;
    wire stop;
    wire [7:0] seg;
    wire [3:0] an;

    counting_down uut (
        .clk(clk),
        .rst_n(rst_n),
        .time_in(time_in),
        .start(start),
        .stop(stop),
        .seg(seg),
        .an(an)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Counting Down Test Start ===");
        
        rst_n = 0;
        start = 0;
        time_in = 16'd0;
        #50;
        
        $display("[%0t] Reset released", $time);
        rst_n = 1;
        #50;
        
        $display("[%0t] Start countdown from 1 seconds", $time);
        time_in = 16'd1;
        start = 1;
        #20;
        start = 0;
        
        wait(stop);
        $display("[%0t] Countdown complete! Stop signal received", $time);
        #100;
        
        $display("[%0t] Start countdown from 1 seconds", $time);
        time_in = 16'd3;
        start = 1;
        #20;
        start = 0;
        
        wait(stop);
        $display("[%0t] Countdown complete! Stop signal received", $time);
        #100;
        
        $display("[%0t] Test reset during countdown", $time);
        time_in = 16'd10;
        start = 1;
        #20;
        start = 0;
        #200;
        
        $display("[%0t] Assert reset", $time);
        rst_n = 0;
        #50;
        $display("[%0t] Release reset", $time);
        rst_n = 1;
        #100;
        
        $display("=== Counting Down Test Complete ===");
        $finish;
    end

    always @(posedge stop) begin
        $display("[%0t] *** STOP signal asserted ***", $time);
    end

endmodule