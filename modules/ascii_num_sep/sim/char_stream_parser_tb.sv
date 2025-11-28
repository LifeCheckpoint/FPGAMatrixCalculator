`timescale 1ns / 1ps

// Testbench for Character Stream Parser
module char_stream_parser_tb;

    // Parameters
    parameter MAX_PAYLOAD = 2048;
    
    // Clock and reset
    logic        clk;
    logic        rst_n;
    
    // Control input
    logic        start;
    logic [15:0] total_length;
    
    // Character buffer
    logic [7:0]  char_buffer [0:MAX_PAYLOAD-1];
    
    // Control to ascii_to_int32
    logic        num_start;
    logic [7:0]  num_char;
    logic        num_valid;
    logic        num_end;
    
    // Feedback from ascii_to_int32
    logic        result_valid;
    
    // Status
    logic [10:0] num_count;
    logic        parse_done;
    
    // Test statistics
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Collected numbers for verification
    integer collected_numbers [0:2047];
    integer collected_count;
    logic [7:0] collected_chars [0:100];
    integer char_index;
    logic collect_active;
    
    // DUT instantiation
    char_stream_parser #(
        .MAX_PAYLOAD(MAX_PAYLOAD)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .total_length (total_length),
        .char_buffer  (char_buffer),
        .num_start    (num_start),
        .num_char     (num_char),
        .num_valid    (num_valid),
        .num_end      (num_end),
        .result_valid (result_valid),
        .num_count    (num_count),
        .parse_done   (parse_done)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Load string into buffer
    task load_buffer(input string str);
        integer i;
        begin
            total_length = str.len();
            for (i = 0; i < str.len(); i = i + 1) begin
                char_buffer[i] = str[i];
            end
            $display("[%t] Buffer loaded: '%s' (length=%0d)", $time, str, str.len());
        end
    endtask
    
    // Task: Start parsing
    task start_parse();
        begin
            @(posedge clk);
            start <= 1'b1;
            $display("[%t] START signal sent", $time);
            @(posedge clk);
            start <= 1'b0;
        end
    endtask
    
    // Task: Simulate converter response
    task automatic simulate_converter();
        begin
            fork
                begin
                    forever begin
                        @(posedge clk);
                        if (num_end) begin
                            // Simulate conversion delay
                            repeat(2) @(posedge clk);
                            result_valid <= 1'b1;
                            $display("[%t] Converter: result_valid asserted", $time);
                            @(posedge clk);
                            result_valid <= 1'b0;
                        end
                    end
                end
            join_none
        end
    endtask
    
    // Monitor and collect character sequences
    always @(posedge clk) begin
        if (num_start) begin
            $display("[%t] >>> NUM_START", $time);
            char_index = 0;
            collect_active = 1'b1;
        end
        
        if (num_valid) begin
            $display("[%t] >>> NUM_CHAR: '%c' (0x%h)", $time, num_char, num_char);
            if (collect_active) begin
                collected_chars[char_index] = num_char;
                char_index = char_index + 1;
            end
        end
        
        if (num_end) begin
            string num_str;
            $display("[%t] >>> NUM_END", $time);
            if (collect_active) begin
                num_str = "";
                for (int i = 0; i < char_index; i = i + 1) begin
                    num_str = {num_str, string'(collected_chars[i])};
                end
                $display("[%t] Number collected: '%s'", $time, num_str);
                collect_active = 1'b0;
            end
        end
        
        if (parse_done) begin
            $display("[%t] >>> PARSE_DONE, num_count=%0d", $time, num_count);
        end
    end
    
    // Task: Wait for parse done
    task wait_parse_done();
        begin
            @(posedge clk);
            while (!parse_done) @(posedge clk);
            $display("[%t] Parsing complete: num_count=%0d", $time, num_count);
        end
    endtask
    
    // Task: Verify number count
    task verify_count(input integer expected);
        begin
            if (num_count == expected) begin
                $display("[%t] PASS: num_count=%0d (expected=%0d)", $time, num_count, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] FAIL: num_count=%0d, expected=%0d", $time, num_count, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("char_stream_parser Testbench");
        $display("MAX_PAYLOAD=%0d", MAX_PAYLOAD);
        $display("========================================\n");
        
        // Initialize signals
        rst_n = 0;
        start = 0;
        total_length = 0;
        result_valid = 0;
        collected_count = 0;
        char_index = 0;
        collect_active = 0;
        
        // Reset
        $display("[%t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%t] Reset released\n", $time);
        
        // Start converter simulator
        simulate_converter();
        
        // Test 1: Single number
        $display("\n========== Test 1: Single number ==========");
        load_buffer("123");
        start_parse();
        wait_parse_done();
        verify_count(1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 2: Multiple numbers with single spaces
        $display("\n========== Test 2: Multiple numbers ==========");
        load_buffer("123 456 789");
        start_parse();
        wait_parse_done();
        verify_count(3);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 3: Numbers with multiple spaces
        $display("\n========== Test 3: Multiple spaces ==========");
        load_buffer("100  200   300");
        start_parse();
        wait_parse_done();
        verify_count(3);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 4: Leading spaces
        $display("\n========== Test 4: Leading spaces ==========");
        load_buffer("  123 456");
        start_parse();
        wait_parse_done();
        verify_count(2);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 5: Trailing spaces
        $display("\n========== Test 5: Trailing spaces ==========");
        load_buffer("123 456  ");
        start_parse();
        wait_parse_done();
        verify_count(2);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 6: Leading and trailing spaces
        $display("\n========== Test 6: Leading & trailing spaces ==========");
        load_buffer("  42  ");
        start_parse();
        wait_parse_done();
        verify_count(1);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 7: Negative numbers
        $display("\n========== Test 7: Negative numbers ==========");
        load_buffer("-123 456 -789");
        start_parse();
        wait_parse_done();
        verify_count(3);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 8: Mixed spacing
        $display("\n========== Test 8: Complex spacing ==========");
        load_buffer("  -100 0 200  -300  ");
        start_parse();
        wait_parse_done();
        verify_count(4);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 9: Many numbers
        $display("\n========== Test 9: Many numbers ==========");
        load_buffer("1 2 3 4 5 6 7 8 9 10");
        start_parse();
        wait_parse_done();
        verify_count(10);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 10: Single digit numbers
        $display("\n========== Test 10: Single digits ==========");
        load_buffer("0 1 2 3 4 5");
        start_parse();
        wait_parse_done();
        verify_count(6);
        
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
    
    // Timeout watchdog
    initial begin
        #200000;  // 200us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule