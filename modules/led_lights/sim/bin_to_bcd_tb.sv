`timescale 1ns / 1ps

module bin_to_bcd_tb;

    reg [15:0] bin_in;
    wire [3:0] bcd_out [0:3];

    bin_to_bcd uut (
        .bin_in(bin_in),
        .bcd_out(bcd_out)
    );

    task display_bcd;
        integer i;
        begin
            $write("[%0t] Input: %4d => BCD: ", $time, bin_in);
            for (i = 0; i < 4; i = i + 1) begin
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
        
        bin_in = 16'd0;
        #10;
        display_bcd();
        
        bin_in = 16'd5;
        #10;
        display_bcd();
        
        bin_in = 16'd42;
        #10;
        display_bcd();
        
        bin_in = 16'd305;
        #10;
        display_bcd();
        
        bin_in = 16'd1234;
        #10;
        display_bcd();
        
        bin_in = 16'd5678;
        #10;
        display_bcd();
        
        bin_in = 16'd9999;
        #10;
        display_bcd();
        
        $display("=== Binary to BCD Conversion Test Complete ===");
        $finish;
    end

endmodule