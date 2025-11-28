`timescale 1ns / 1ps

// Testbench for ASCII to INT32 Converter
module ascii_to_int32_tb;

    // Clock and reset
    logic                clk;
    logic                rst_n;
    
    // Control interface
    logic                start;
    logic [7:0]          char_in;
    logic                char_valid;
    logic                num_end;
    
    // Output
    logic signed [31:0]  result;
    logic                result_valid;
    
    // Test statistics
    integer pass_count = 0;
    integer fail_count = 0;
    
    // DUT instantiation
    ascii_to_int32 dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .char_in     (char_in),
        .char_valid  (char_valid),
        .num_end     (num_end),
        .result      (result),
        .result_valid(result_valid)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Send start signal
    task send_start();
        begin
            @(posedge clk);
            start <= 1'b1;
            $display("[%t] START signal sent", $time);
            @(posedge clk);
            start <= 1'b0;
        end
    endtask
    
    // Task: Send a character
    task send_char(input logic [7:0] c);
        begin
            @(posedge clk);
            char_in <= c;
            char_valid <= 1'b1;
            $display("[%t] CHAR sent: '%c' (0x%h)", $time, c, c);
            @(posedge clk);
            char_valid <= 1'b0;
        end
    endtask
    
    // Task: Send end signal
    task send_end();
        begin
            @(posedge clk);
            num_end <= 1'b1;
            $display("[%t] END signal sent", $time);
            @(posedge clk);
            num_end <= 1'b0;
        end
    endtask
    
    // Task: Wait for result and verify
    task wait_result(input logic signed [31:0] expected);
        begin
            @(posedge clk);
            while (!result_valid) @(posedge clk);
            if (result == expected) begin
                $display("[%t] RESULT PASS: got=%0d, expected=%0d", $time, result, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] RESULT FAIL: got=%0d, expected=%0d", $time, result, expected);
                fail_count = fail_count + 1;
            end
            @(posedge clk);
        end
    endtask
    
    // Task: Convert a number string
    task convert_number(input string num_str, input logic signed [31:0] expected);
        integer i;
        begin
            $display("\n[%t] Converting '%s' (expected: %0d)", $time, num_str, expected);
            send_start();
            for (i = 0; i < num_str.len(); i = i + 1) begin
                send_char(num_str[i]);
            end
            send_end();
            wait_result(expected);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("ascii_to_int32 Testbench");
        $display("========================================\n");
        
        // Initialize signals
        rst_n = 0;
        start = 0;
        char_in = 8'd0;
        char_valid = 0;
        num_end = 0;
        
        // Reset
        $display("[%t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%t] Reset released", $time);
        
        // Test 1: Single digit
        $display("\n========== Test 1: Single digit ==========");
        convert_number("0", 0);
        convert_number("5", 5);
        convert_number("9", 9);
        
        // Test 2: Multiple digits
        $display("\n========== Test 2: Multiple digits ==========");
        convert_number("12", 12);
        convert_number("123", 123);
        convert_number("1234", 1234);
        convert_number("98765", 98765);
        
        // Test 3: Negative numbers
        $display("\n========== Test 3: Negative numbers ==========");
        convert_number("-1", -1);
        convert_number("-12", -12);
        convert_number("-123", -123);
        convert_number("-9876", -9876);
        
        // Test 4: Large numbers
        $display("\n========== Test 4: Large numbers ==========");
        convert_number("1000000", 1000000);
        convert_number("2147483647", 2147483647);  // Max int32
        convert_number("-2147483648", -2147483648); // Min int32
        
        // Test 5: Numbers with leading zeros (should work)
        $display("\n========== Test 5: Leading zeros ==========");
        convert_number("007", 7);
        convert_number("0042", 42);
        convert_number("-0100", -100);
        
        // Test 6: Zero
        $display("\n========== Test 6: Zero variations ==========");
        convert_number("0", 0);
        convert_number("-0", 0);
        convert_number("00000", 0);
        
        // Test 7: Sequential conversions
        $display("\n========== Test 7: Sequential conversions ==========");
        convert_number("111", 111);
        convert_number("222", 222);
        convert_number("-333", -333);
        convert_number("444", 444);
        
        // Test 8: Edge case - just minus sign (should give 0)
        $display("\n========== Test 8: Edge cases ==========");
        $display("\n[%t] Converting '-' (minus only, expected: 0)", $time);
        send_start();
        send_char("-");
        send_end();
        wait_result(0);
        
        // Print summary
        $display("\n========================================");
        $display("Test Summary:");
        $display("  PASS: %0d", pass_count);
        $display("  FAIL: %0d", fail_count);
        if (fail_count == 0) begin
            $display("  Result: ALL TESTS PASSED!");
        end else begin
            $display("  Result: SOME TESTS FAILED!");
        end
        $display("========================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Monitor state changes
    always @(posedge clk) begin
        if (result_valid) begin
            $display("[%t] >>> Output ready: result=%0d", $time, result);
        end
    end
    
    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule