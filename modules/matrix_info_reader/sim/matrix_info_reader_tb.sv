`timescale 1ns / 1ps

module matrix_info_reader_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter ADDR_WIDTH = 14;
    
    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic busy;
    logic done;
    logic [ADDR_WIDTH-1:0] bram_addr;
    logic [31:0] bram_data;
    logic [7:0] ascii_data;
    logic ascii_valid;
    logic ascii_ready;
    
    // BRAM Simulation
    logic [31:0] bram_mem [0:8191];
    
    // DUT Instance
    matrix_info_reader #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .busy(busy),
        .done(done),
        .bram_addr(bram_addr),
        .bram_data(bram_data),
        .ascii_data(ascii_data),
        .ascii_valid(ascii_valid),
        .ascii_ready(ascii_ready)
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // BRAM Logic (Read Latency = 1)
    always_ff @(posedge clk) begin
        bram_data <= bram_mem[bram_addr];
    end
    
    // Monitor Logic
    initial begin
        $display("Time | Char | Hex");
        forever begin
            @(posedge clk);
            if (ascii_valid && ascii_ready) begin
                if (ascii_data == 8'h0A)
                    $display("%t | \\n   | %h", $time, ascii_data);
                else
                    $write("%c", ascii_data);
            end
        end
    end
    
    // Test Stimulus
    initial begin
        // Initialize BRAM
        // ID 0: 2x2
        bram_mem[0*BLOCK_SIZE] = {8'd2, 8'd2, 16'd0};
        // ID 1: 4x5
        bram_mem[1*BLOCK_SIZE] = {8'd4, 8'd5, 16'd0};
        // ID 2: 4x5
        bram_mem[2*BLOCK_SIZE] = {8'd4, 8'd5, 16'd0};
        // ID 3: 2x2
        bram_mem[3*BLOCK_SIZE] = {8'd2, 8'd2, 16'd0};
        // ID 4: Empty (0x0)
        bram_mem[4*BLOCK_SIZE] = 32'd0;
        // ID 5: 3x3
        bram_mem[5*BLOCK_SIZE] = {8'd3, 8'd3, 16'd0};
        // ID 6: Empty
        bram_mem[6*BLOCK_SIZE] = 32'd0;
        // ID 7: 2x2
        bram_mem[7*BLOCK_SIZE] = {8'd2, 8'd2, 16'd0};
        
        // Reset
        rst_n = 0;
        start = 0;
        ascii_ready = 0;
        #20;
        rst_n = 1;
        #20;
        
        // Test 1: Read Info
        $display("\n--- Test 1: Read Matrix Info ---");
        start = 1;
        ascii_ready = 1;
        #10;
        start = 0;
        
        wait(done);
        #20;
        
        $display("\n\nTest Complete");
        $finish;
    end

endmodule
