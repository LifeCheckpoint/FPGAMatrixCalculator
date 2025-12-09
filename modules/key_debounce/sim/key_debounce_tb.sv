`timescale 1ns / 1ps

module key_debounce_tb;

    // Parameters
    parameter CNT_MAX = 20; // Shorten for simulation

    // Signals
    reg clk;
    reg rst_n;
    reg key_in;
    wire key_out;

    // DUT Instantiation
    key_debounce #(
        .CNT_MAX(CNT_MAX)
    ) u_key_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in),
        .key_out(key_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        key_in = 1;
        #100;
        rst_n = 1;
        #100;

        // 1. Press key (High -> Low) with jitter
        $display("Test: Key Press (Jitter -> Stable Low)");
        repeat(5) begin
            key_in = ~key_in; // Jitter
            #($urandom_range(10, 50));
        end
        key_in = 0; // Stable Low
        #500; // Wait for debounce

        // 2. Release key (Low -> High) with jitter
        $display("Test: Key Release (Jitter -> Stable High)");
        repeat(5) begin
            key_in = ~key_in; // Jitter
            #($urandom_range(10, 50));
        end
        key_in = 1; // Stable High
        #500; // Wait for debounce

        $display("Test Finished");
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time=%t | rst_n=%b | key_in=%b | key_out=%b | cnt=%d", 
                 $time, rst_n, key_in, key_out, u_key_debounce.cnt);
    end

endmodule
