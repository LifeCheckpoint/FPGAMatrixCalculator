`timescale 1ns / 1ps

// Testbench for ASCII Number Separator Top Module
module ascii_num_sep_top_tb;

    // Clock and reset
    logic        clk;
    logic        rst_n;
    
    // Buffer clear signal
    logic        buf_clear;
    
    // UART packet payload interface
    logic [7:0]  pkt_payload_data;
    logic        pkt_payload_valid;
    logic        pkt_payload_last;
    logic        pkt_payload_ready;
    
    // RAM read interface
    logic [10:0] rd_addr;
    logic [31:0] rd_data;
    
    // Status outputs
    logic        processing;
    logic        done;
    logic        invalid;
    logic [10:0] num_count;
    
    // DUT instantiation
    ascii_num_sep_top #(
        .MAX_PAYLOAD(2048),
        .DATA_WIDTH(32),
        .DEPTH(2048),
        .ADDR_WIDTH(11)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .buf_clear          (buf_clear),
        .pkt_payload_data   (pkt_payload_data),
        .pkt_payload_valid  (pkt_payload_valid),
        .pkt_payload_last   (pkt_payload_last),
        .pkt_payload_ready  (pkt_payload_ready),
        .rd_addr            (rd_addr),
        .rd_data            (rd_data),
        .processing         (processing),
        .done               (done),
        .invalid            (invalid),
        .num_count          (num_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Task to send a byte
    task send_byte(input logic [7:0] data, input logic is_last);
        begin
            @(posedge clk);
            pkt_payload_data <= data;
            pkt_payload_valid <= 1'b1;
            pkt_payload_last <= is_last;
            @(posedge clk);
            while (!pkt_payload_ready) @(posedge clk);
            pkt_payload_valid <= 1'b0;
            pkt_payload_last <= 1'b0;
        end
    endtask
    
    // Task to send a string
    task send_string(input string str);
        integer i;
        begin
            for (i = 0; i < str.len(); i = i + 1) begin
                send_byte(str[i], (i == str.len() - 1));
            end
        end
    endtask
    
    // Task to wait for processing done
    task wait_done();
        begin
            @(posedge clk);
            while (!done) @(posedge clk);
            $display("[%t] Processing done! num_count=%0d, invalid=%0b", 
                     $time, num_count, invalid);
        end
    endtask
    
    // Task to read and verify RAM
    task read_ram(input integer addr, input integer expected);
        begin
            @(posedge clk);
            rd_addr <= addr;
            @(posedge clk);
            @(posedge clk);  // Wait for read latency
            if (rd_data == expected) begin
                $display("[%t] RAM[%0d] = %0d (PASS)", $time, addr, rd_data);
            end else begin
                $display("[%t] RAM[%0d] = %0d, expected %0d (FAIL)", 
                         $time, addr, rd_data, expected);
            end
        end
    endtask
    
    // Main test
    initial begin
        $display("========================================");
        $display("ASCII Number Separator Testbench");
        $display("========================================");
        
        // Initialize signals
        rst_n = 0;
        buf_clear = 0;
        pkt_payload_data = 8'd0;
        pkt_payload_valid = 1'b0;
        pkt_payload_last = 1'b0;
        rd_addr = 11'd0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 0: Clear buffer before use (NEW - recommended practice)
        $display("\n[%t] Test 0: Clear buffer RAM", $time);
        @(posedge clk);
        buf_clear <= 1'b1;
        @(posedge clk);
        buf_clear <= 1'b0;
        $display("  Waiting for buffer clear (2048 cycles)...");
        repeat(2048) @(posedge clk);
        $display("  Buffer cleared");
        
        // Test 1: Simple positive numbers
        $display("\n[%t] Test 1: Positive numbers '123 456 789'", $time);
        send_string("123 456 789");
        wait_done();
        read_ram(0, 123);
        read_ram(1, 456);
        read_ram(2, 789);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 2: Negative numbers
        $display("\n[%t] Test 2: Negative numbers '-123 456 -789'", $time);
        send_string("-123 456 -789");
        wait_done();
        read_ram(0, -123);
        read_ram(1, 456);
        read_ram(2, -789);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 3: Multiple spaces
        $display("\n[%t] Test 3: Multiple spaces '100  200   300'", $time);
        send_string("100  200   300");
        wait_done();
        read_ram(0, 100);
        read_ram(1, 200);
        read_ram(2, 300);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 4: Leading and trailing spaces
        $display("\n[%t] Test 4: Leading/trailing spaces '  42  '", $time);
        send_string("  42  ");
        wait_done();
        read_ram(0, 42);
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 5: Invalid character
        $display("\n[%t] Test 5: Invalid character '123 ABC 456'", $time);
        send_string("123 ABC 456");
        wait_done();
        if (invalid) begin
            $display("[%t] Invalid flag correctly set (PASS)", $time);
        end else begin
            $display("[%t] Invalid flag not set (FAIL)", $time);
        end
        
        // Reset for next test
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Test 6: Large numbers
        $display("\n[%t] Test 6: Large numbers '2147483647 -2147483648'", $time);
        send_string("2147483647 -2147483648");
        wait_done();
        read_ram(0, 2147483647);
        read_ram(1, -2147483648);
        
        // Finish
        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================");
        
        repeat(20) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule