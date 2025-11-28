`timescale 1ns / 1ps

// Testbench for Data Write Controller
module data_write_controller_tb;

    // Clock and reset
    logic                    clk;
    logic                    rst_n;
    
    // Data input from ascii_to_int32
    logic signed [31:0]      data_in;
    logic                    data_valid;
    
    // Expected count from parser
    logic [10:0]             total_count;
    logic                    parse_done;
    
    // RAM write interface
    logic                    ram_wr_en;
    logic [10:0]             ram_wr_addr;
    logic [31:0]             ram_wr_data;
    
    // Status
    logic [10:0]             write_count;
    logic                    all_done;
    
    // Test statistics
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Expected write tracking
    logic [31:0] expected_writes [0:2047];
    integer expected_write_count;
    
    // DUT instantiation
    data_write_controller dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .data_in     (data_in),
        .data_valid  (data_valid),
        .total_count (total_count),
        .parse_done  (parse_done),
        .ram_wr_en   (ram_wr_en),
        .ram_wr_addr (ram_wr_addr),
        .ram_wr_data (ram_wr_data),
        .write_count (write_count),
        .all_done    (all_done)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Send data
    task send_data(input logic signed [31:0] data);
        begin
            @(posedge clk);
            data_in <= data;
            data_valid <= 1'b1;
            $display("[%t] TX: data=%0d", $time, data);
            @(posedge clk);
            data_valid <= 1'b0;
        end
    endtask
    
    // Task: Set parse done
    task set_parse_done(input logic [10:0] count);
        begin
            @(posedge clk);
            total_count <= count;
            parse_done <= 1'b1;
            $display("[%t] Parse done set: total_count=%0d", $time, count);
        end
    endtask
    
    // Task: Wait for all done
    task wait_all_done();
        begin
            @(posedge clk);
            while (!all_done) @(posedge clk);
            $display("[%t] All done asserted", $time);
        end
    endtask
    
    // Task: Verify write count
    task verify_write_count(input logic [10:0] expected);
        begin
            if (write_count == expected) begin
                $display("[%t] PASS: write_count=%0d (expected=%0d)", $time, write_count, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] FAIL: write_count=%0d, expected=%0d", $time, write_count, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Monitor write operations
    always @(posedge clk) begin
        if (ram_wr_en) begin
            $display("[%t] >>> RAM WRITE: addr=%0d, data=%0d", $time, ram_wr_addr, $signed(ram_wr_data));
            // Store for verification
            expected_writes[ram_wr_addr] = ram_wr_data;
        end
        if (all_done) begin
            $display("[%t] >>> ALL_DONE asserted", $time);
        end
    end
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("data_write_controller Testbench");
        $display("========================================\n");
        
        // Initialize signals
        rst_n = 0;
        data_in = 32'd0;
        data_valid = 1'b0;
        total_count = 11'd0;
        parse_done = 1'b0;
        expected_write_count = 0;
        
        // Reset
        $display("[%t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%t] Reset released\n", $time);
        
        // Test 1: Single write
        $display("\n========== Test 1: Single write ==========");
        send_data(32'd123);
        @(posedge clk);
        verify_write_count(11'd1);
        set_parse_done(11'd1);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 2: Multiple sequential writes
        $display("\n========== Test 2: Sequential writes ==========");
        send_data(32'd100);
        send_data(32'd200);
        send_data(32'd300);
        @(posedge clk);
        verify_write_count(11'd3);
        set_parse_done(11'd3);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 3: Negative numbers
        $display("\n========== Test 3: Negative numbers ==========");
        send_data(-32'd123);
        send_data(32'd456);
        send_data(-32'd789);
        @(posedge clk);
        verify_write_count(11'd3);
        set_parse_done(11'd3);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 4: Writes with gaps
        $display("\n========== Test 4: Writes with gaps ==========");
        send_data(32'd1);
        repeat(5) @(posedge clk);  // Gap
        send_data(32'd2);
        repeat(3) @(posedge clk);  // Gap
        send_data(32'd3);
        @(posedge clk);
        verify_write_count(11'd3);
        set_parse_done(11'd3);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 5: Many writes
        $display("\n========== Test 5: Many writes (10 items) ==========");
        for (int i = 0; i < 10; i++) begin
            send_data(i * 10);
        end
        @(posedge clk);
        verify_write_count(11'd10);
        set_parse_done(11'd10);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 6: Parse done before all writes (edge case)
        $display("\n========== Test 6: Parse done timing ==========");
        send_data(32'd111);
        send_data(32'd222);
        set_parse_done(11'd3);  // Set done for 3, but only 2 written
        send_data(32'd333);
        wait_all_done();
        verify_write_count(11'd3);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 7: Large numbers
        $display("\n========== Test 7: Large numbers ==========");
        send_data(32'h7FFFFFFF);  // Max positive
        send_data(32'h80000000);  // Min negative
        send_data(32'd0);
        @(posedge clk);
        verify_write_count(11'd3);
        set_parse_done(11'd3);
        wait_all_done();
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 8: Address increment verification
        $display("\n========== Test 8: Address sequence ==========");
        for (int i = 0; i < 5; i++) begin
            send_data(1000 + i);
            @(posedge clk);
            if (ram_wr_addr == i) begin
                $display("[%t] PASS: Address %0d correct", $time, i);
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] FAIL: Address should be %0d, got %0d", $time, i, ram_wr_addr);
                fail_count = fail_count + 1;
            end
        end
        set_parse_done(11'd5);
        wait_all_done();
        
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
        #100000;  // 100us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule