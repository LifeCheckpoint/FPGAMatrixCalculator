`timescale 1ns / 1ps

// Testbench for ASCII Validator
module ascii_validator_tb;

    // Parameters
    parameter MAX_PAYLOAD = 2048;
    
    // Clock and reset
    logic        clk;
    logic        rst_n;
    
    // Input from uart_packet_handler
    logic [7:0]  payload_data;
    logic        payload_valid;
    logic        payload_last;
    logic        payload_ready;
    
    // Character buffer for downstream
    logic [7:0]  char_buffer [0:MAX_PAYLOAD-1];
    logic [15:0] buffer_length;
    
    // Output status
    logic        done;
    logic        invalid;
    
    // Test statistics
    integer pass_count = 0;
    integer fail_count = 0;
    
    // DUT instantiation
    ascii_validator #(
        .MAX_PAYLOAD(MAX_PAYLOAD)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .payload_data  (payload_data),
        .payload_valid (payload_valid),
        .payload_last  (payload_last),
        .payload_ready (payload_ready),
        .char_buffer   (char_buffer),
        .buffer_length (buffer_length),
        .done          (done),
        .invalid       (invalid)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Send a byte
    task send_byte(input logic [7:0] data, input logic is_last);
        begin
            @(posedge clk);
            payload_data <= data;
            payload_valid <= 1'b1;
            payload_last <= is_last;
            $display("[%t] TX: data='%c' (0x%h), last=%0b", $time, data, data, is_last);
            @(posedge clk);
            while (!payload_ready) @(posedge clk);
            payload_valid <= 1'b0;
            payload_last <= 1'b0;
        end
    endtask
    
    // Task: Send a string
    task send_string(input string str);
        integer i;
        begin
            $display("\n[%t] Sending string: '%s' (length=%0d)", $time, str, str.len());
            for (i = 0; i < str.len(); i = i + 1) begin
                send_byte(str[i], (i == str.len() - 1));
            end
        end
    endtask
    
    // Task: Wait for processing done
    task wait_done();
        begin
            @(posedge clk);
            while (!done) @(posedge clk);
            $display("[%t] Validation done: buffer_length=%0d, invalid=%0b", 
                     $time, buffer_length, invalid);
        end
    endtask
    
    // Task: Verify buffer contents
    task verify_buffer(input string expected_str);
        integer i;
        logic match;
        begin
            match = 1'b1;
            if (buffer_length != expected_str.len()) begin
                $display("[%t] FAIL: buffer_length=%0d, expected=%0d", 
                         $time, buffer_length, expected_str.len());
                match = 1'b0;
                fail_count = fail_count + 1;
            end else begin
                for (i = 0; i < expected_str.len(); i = i + 1) begin
                    if (char_buffer[i] != expected_str[i]) begin
                        $display("[%t] FAIL: buffer[%0d]='%c' (0x%h), expected='%c' (0x%h)", 
                                 $time, i, char_buffer[i], char_buffer[i], 
                                 expected_str[i], expected_str[i]);
                        match = 1'b0;
                    end
                end
                if (match) begin
                    $display("[%t] PASS: Buffer contents match expected string", $time);
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask
    
    // Task: Check invalid flag
    task check_invalid(input logic expected);
        begin
            if (invalid == expected) begin
                $display("[%t] PASS: invalid flag = %0b (as expected)", $time, invalid);
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] FAIL: invalid flag = %0b, expected = %0b", $time, invalid, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("ascii_validator Testbench");
        $display("MAX_PAYLOAD=%0d", MAX_PAYLOAD);
        $display("========================================\n");
        
        // Initialize signals
        rst_n = 0;
        payload_data = 8'd0;
        payload_valid = 1'b0;
        payload_last = 1'b0;
        
        // Reset
        $display("[%t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%t] Reset released\n", $time);
        
        // Test 1: Valid digits only
        $display("\n========== Test 1: Valid digits only ==========");
        send_string("123456789");
        wait_done();
        verify_buffer("123456789");
        check_invalid(1'b0);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 2: Valid with spaces
        $display("\n========== Test 2: Valid with spaces ==========");
        send_string("123 456 789");
        wait_done();
        verify_buffer("123 456 789");
        check_invalid(1'b0);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 3: Valid with minus signs
        $display("\n========== Test 3: Valid with minus signs ==========");
        send_string("-123 456 -789");
        wait_done();
        verify_buffer("-123 456 -789");
        check_invalid(1'b0);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 4: Invalid - alphabetic characters
        $display("\n========== Test 4: Invalid - alphabetic ==========");
        send_string("123ABC456");
        wait_done();
        check_invalid(1'b1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 5: Invalid - special characters
        $display("\n========== Test 5: Invalid - special chars ==========");
        send_string("123!456");
        wait_done();
        check_invalid(1'b1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 6: Invalid - dot/decimal point (not allowed)
        $display("\n========== Test 6: Invalid - decimal point ==========");
        send_string("123.456");
        wait_done();
        check_invalid(1'b1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 7: Empty payload
        $display("\n========== Test 7: Empty payload ==========");
        @(posedge clk);
        payload_data <= 8'h00;
        payload_valid <= 1'b1;
        payload_last <= 1'b1;
        @(posedge clk);
        payload_valid <= 1'b0;
        payload_last <= 1'b0;
        wait_done();
        if (buffer_length == 1) begin
            $display("[%t] PASS: Empty handled (buffer_length=1)", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[%t] FAIL: Expected buffer_length=1, got %0d", $time, buffer_length);
            fail_count = fail_count + 1;
        end
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 8: Mix of valid characters
        $display("\n========== Test 8: Complex valid string ==========");
        send_string("  -100 0 200  -300  ");
        wait_done();
        verify_buffer("  -100 0 200  -300  ");
        check_invalid(1'b0);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 9: Invalid - mixed invalid chars
        $display("\n========== Test 9: Multiple invalid chars ==========");
        send_string("12+34=46");
        wait_done();
        check_invalid(1'b1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 10: All zeros
        $display("\n========== Test 10: All zeros ==========");
        send_string("0 0 0 0");
        wait_done();
        verify_buffer("0 0 0 0");
        check_invalid(1'b0);
        
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
    
    // Monitor done signal
    always @(posedge clk) begin
        if (done) begin
            $display("[%t] >>> DONE asserted", $time);
        end
    end
    
    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule