`timescale 1ns / 1ps

module led_display_ctrl_tb;

    reg clk;
    reg rst_n;
    reg [1:0] display_mode;
    reg seg7_valid;
    reg [3:0] bcd_data_0;
    reg [3:0] bcd_data_1;
    reg [3:0] bcd_data_2;
    reg [3:0] bcd_data_3;
    reg [2:0] method_sel;
    wire [7:0] seg;
    wire [3:0] an;

    led_display_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .display_mode(display_mode),
        .seg7_valid(seg7_valid),
        .bcd_data_0(bcd_data_0),
        .bcd_data_1(bcd_data_1),
        .bcd_data_2(bcd_data_2),
        .bcd_data_3(bcd_data_3),
        .method_sel(method_sel),
        .seg(seg),
        .an(an)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== LED Display Controller Test Start ===");
        
        // Initialize
        rst_n = 0;
        display_mode = 0;
        seg7_valid = 0;
        bcd_data_0 = 0;
        bcd_data_1 = 0;
        bcd_data_2 = 0;
        bcd_data_3 = 0;
        method_sel = 0;
        #20;
        
        $display("[%0t] Reset released", $time);
        rst_n = 1;
        #20;
        
        // Test Mode 0: Seg7 Display
        $display("[%0t] Testing Mode 0: Seg7 Display (1234)", $time);
        display_mode = 0;
        seg7_valid = 1;
        bcd_data_0 = 4'd1;
        bcd_data_1 = 4'd2;
        bcd_data_2 = 4'd3;
        bcd_data_3 = 4'd4;
        #200; // Wait a bit, scanning won't complete but we check initial state
        
        // Test Mode 1: Calc Method Show
        $display("[%0t] Testing Mode 1: Calc Method Show", $time);
        display_mode = 1;
        
        // T
        method_sel = 0;
        $display("[%0t] Show T", $time);
        #100;
        
        // A
        method_sel = 1;
        $display("[%0t] Show A", $time);
        #100;
        
        // B
        method_sel = 2;
        $display("[%0t] Show B", $time);
        #100;
        
        // C
        method_sel = 3;
        $display("[%0t] Show C", $time);
        #100;
        
        // J
        method_sel = 4;
        $display("[%0t] Show J", $time);
        #100;
        
        // Test Mode 2: OFF
        $display("[%0t] Testing Mode 2: OFF", $time);
        display_mode = 2;
        #100;
        
        $display("=== LED Display Controller Test Complete ===");
        $finish;
    end

    // Monitor changes
    always @(seg or an) begin
        $display("[%0t] Mode=%d Sel=%d AN=%b SEG=%b", $time, display_mode, method_sel, an, seg);
    end

endmodule
