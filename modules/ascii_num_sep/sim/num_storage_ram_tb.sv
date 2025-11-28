`timescale 1ns / 1ps

// Testbench for Number Storage RAM
module num_storage_ram_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 2048;
    parameter ADDR_WIDTH = 11;
    
    // Clock and reset
    logic                    clk;
    logic                    rst_n;
    
    // Write port
    logic                    wr_en;
    logic [ADDR_WIDTH-1:0]   wr_addr;
    logic [DATA_WIDTH-1:0]   wr_data;
    
    // Read port
    logic [ADDR_WIDTH-1:0]   rd_addr;
    logic [DATA_WIDTH-1:0]   rd_data;
    
    // Test statistics
    integer pass_count = 0;
    integer fail_count = 0;
    
    // DUT instantiation
    num_storage_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (wr_en),
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),
        .rd_addr    (rd_addr),
        .rd_data    (rd_data)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Write data to RAM
    task write_ram(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            wr_en <= 1'b1;
            wr_addr <= addr;
            wr_data <= data;
            $display("[%t] WRITE: addr=%0d, data=%0d (0x%h)", $time, addr, $signed(data), data);
            @(posedge clk);
            wr_en <= 1'b0;
        end
    endtask
    
    // Task: Read and verify data from RAM
    task read_verify(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] expected);
        begin
            @(posedge clk);
            rd_addr <= addr;
            @(posedge clk);
            @(posedge clk);  // Wait for read latency
            if (rd_data == expected) begin
                $display("[%t] READ PASS: addr=%0d, data=%0d (expected=%0d)", 
                         $time, addr, $signed(rd_data), $signed(expected));
                pass_count = pass_count + 1;
            end else begin
                $display("[%t] READ FAIL: addr=%0d, data=%0d, expected=%0d", 
                         $time, addr, $signed(rd_data), $signed(expected));
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("num_storage_ram Testbench");
        $display("DATA_WIDTH=%0d, DEPTH=%0d, ADDR_WIDTH=%0d", DATA_WIDTH, DEPTH, ADDR_WIDTH);
        $display("========================================\n");
        
        // Initialize signals
        rst_n = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        rd_addr = 0;
        
        // Reset
        $display("[%t] Applying reset...", $time);
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%t] Reset released\n", $time);
        
        // Test 1: Basic write and read
        $display("[%t] Test 1: Basic single write/read", $time);
        write_ram(11'd0, 32'd123);
        read_verify(11'd0, 32'd123);
        $display("");
        
        // Test 2: Multiple sequential writes
        $display("[%t] Test 2: Sequential writes", $time);
        write_ram(11'd10, 32'd100);
        write_ram(11'd11, 32'd200);
        write_ram(11'd12, 32'd300);
        read_verify(11'd10, 32'd100);
        read_verify(11'd11, 32'd200);
        read_verify(11'd12, 32'd300);
        $display("");
        
        // Test 3: Negative numbers
        $display("[%t] Test 3: Negative numbers", $time);
        write_ram(11'd20, -32'd123);
        write_ram(11'd21, -32'd456);
        read_verify(11'd20, -32'd123);
        read_verify(11'd21, -32'd456);
        $display("");
        
        // Test 4: Overwrite same address
        $display("[%t] Test 4: Overwrite test", $time);
        write_ram(11'd30, 32'd111);
        read_verify(11'd30, 32'd111);
        write_ram(11'd30, 32'd222);
        read_verify(11'd30, 32'd222);
        $display("");
        
        // Test 5: Boundary addresses
        $display("[%t] Test 5: Boundary addresses", $time);
        write_ram(11'd0, 32'd1);
        write_ram(11'd2047, 32'd2047);
        read_verify(11'd0, 32'd1);
        read_verify(11'd2047, 32'd2047);
        $display("");
        
        // Test 6: Large values
        $display("[%t] Test 6: Large values", $time);
        write_ram(11'd100, 32'h7FFFFFFF);  // Max positive
        write_ram(11'd101, 32'h80000000);  // Min negative
        read_verify(11'd100, 32'h7FFFFFFF);
        read_verify(11'd101, 32'h80000000);
        $display("");
        
        // Test 7: Simultaneous read/write to different addresses
        $display("[%t] Test 7: Concurrent read/write", $time);
        write_ram(11'd200, 32'd999);
        @(posedge clk);
        rd_addr <= 11'd100;  // Read from previously written address
        wr_en <= 1'b1;
        wr_addr <= 11'd201;
        wr_data <= 32'd888;
        @(posedge clk);
        wr_en <= 1'b0;
        @(posedge clk);
        $display("[%t] Concurrent read result: addr=100, data=%0d", $time, $signed(rd_data));
        read_verify(11'd201, 32'd888);
        $display("");
        
        // Print summary
        $display("========================================");
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
        #50000;  // 50us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule