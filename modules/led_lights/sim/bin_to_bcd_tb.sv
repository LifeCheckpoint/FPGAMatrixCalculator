`timescale 1ns / 1ps

module bin_to_bcd_tb;

    reg clk;
    reg rst_n;
    reg [15:0] bin_in;
    wire [3:0] bcd_out [0:3];

    bin_to_bcd uut (
        .clk(clk),
        .rst_n(rst_n),
        .bin_in(bin_in),
        .bcd_out(bcd_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task display_bcd;
        integer i;
        begin
            // Wait for conversion (approx 20 cycles)
            repeat(20) @(posedge clk);
            
            $write("[%0t] Input: %4d => BCD: ", $time, bin_in);
            for (i = 3; i >= 0; i = i - 1) begin // Print from MSB to LSB
                if (bcd_out[i] == 4'd15)
                    $write("_ ");
                else
                    $write("%1d ", bcd_out[i]);
            end
            $display("");
        end
    endtask

    initial begin
        $display("=== Binary to BCD Conversion Test Start ===");
        $display("Note: '_' represents leading zero suppression (value = 15)");
        
        rst_n = 0;
        bin_in = 16'd0;
        #20;
        rst_n = 1;
        #20;
        
        bin_in = 16'd0;
        display_bcd();
        
        bin_in = 16'd5;
        display_bcd();
        
        bin_in = 16'd42;
        display_bcd();
        
        bin_in = 16'd305;
        display_bcd();
        
        bin_in = 16'd1234;
        display_bcd();
        
        bin_in = 16'd5678;
        display_bcd();
        
        bin_in = 16'd9999;
        display_bcd();
        
        $display("=== Binary to BCD Conversion Test Complete ===");
        $finish;
    end

endmodule
