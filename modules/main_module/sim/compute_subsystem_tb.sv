`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module compute_subsystem_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst_n;
    reg start;
    reg confirm_btn;
    reg [31:0] scalar_in;
    reg random_scalar;
    op_mode_t op_mode_in;
    calc_type_t calc_type_in;
    reg [31:0] settings_countdown;
    
    wire busy;
    wire done;
    wire error;
    wire [7:0] seg;
    wire [3:0] an;
    
    reg [7:0] uart_rx_data;
    reg uart_rx_valid;
    wire [7:0] uart_tx_data;
    wire uart_tx_valid;
    reg uart_tx_ready;
    
    wire [ADDR_WIDTH-1:0] bram_rd_addr;
    reg [DATA_WIDTH-1:0] bram_rd_data;
    
    wire write_request;
    reg write_ready;
    wire [2:0] write_matrix_id;
    wire [7:0] write_rows;
    wire [7:0] write_cols;
    wire [7:0] write_name [0:7];
    wire [DATA_WIDTH-1:0] write_data;
    wire write_data_valid;
    reg write_done;
    reg writer_ready;

    // DUT Instantiation
    compute_subsystem #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .random_scalar(random_scalar),
        .op_mode_in(op_mode_in),
        .calc_type_in(calc_type_in),
        .settings_countdown(settings_countdown),
        .busy(busy),
        .done(done),
        .error(error),
        .seg(seg),
        .an(an),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .bram_rd_addr(bram_rd_addr),
        .bram_rd_data(bram_rd_data),
        .write_request(write_request),
        .write_ready(write_ready),
        .write_matrix_id(write_matrix_id),
        .write_rows(write_rows),
        .write_cols(write_cols),
        .write_name(write_name),
        .write_data(write_data),
        .write_data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper Task: Send UART Byte
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data = data;
            uart_rx_valid = 1;
            @(posedge clk);
            uart_rx_valid = 0;
            repeat(5) @(posedge clk);
        end
    endtask

    // Helper Task: Send String
    task send_string(input string str);
        integer i;
        begin
            for (i = 0; i < str.len(); i++) begin
                send_byte(str[i]);
            end
        end
    endtask

    // BRAM Response Logic
    always @(posedge clk) begin
        // Mock BRAM content
        // Address 1152 (ID=1): 2x2 Matrix
        if (bram_rd_addr == 1152) begin
            // Metadata: Rows=2, Cols=2
            bram_rd_data <= {8'd2, 8'd2, 16'd0};
        end else if (bram_rd_addr >= 1152 + 2 && bram_rd_addr < 1152 + 6) begin
            // Data: 1, 2, 3, 4
            bram_rd_data <= bram_rd_addr - 1152 - 1; 
        end else begin
            bram_rd_data <= 0;
        end
    end

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        confirm_btn = 0;
        scalar_in = 0;
        random_scalar = 0;
        op_mode_in = OP_SINGLE;
        calc_type_in = CALC_TRANSPOSE;
        settings_countdown = 1000; // Long enough
        uart_rx_data = 0;
        uart_rx_valid = 0;
        uart_tx_ready = 1;
        write_ready = 1;
        write_done = 0;
        writer_ready = 1;
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        //---------------------------------------------------------------------
        // Test 1: Transpose Operation
        //---------------------------------------------------------------------
        $display("Test 1: Transpose Operation");
        
        // Start Selection
        start = 1;
        @(posedge clk);
        start = 0;
        
        // 1. Input Dimensions: "2 2"
        send_string("2 2 ");
        
        // Confirm Dimensions
        #(CLK_PERIOD * 20);
        confirm_btn = 1;
        #(CLK_PERIOD);
        confirm_btn = 0;
        
        // Wait for Scanner (It should find Matrix 1)
        #(CLK_PERIOD * 100);
        
        // 2. Select Matrix A: "1"
        send_string("1 ");
        
        // Confirm Selection
        #(CLK_PERIOD * 20);
        confirm_btn = 1;
        #(CLK_PERIOD);
        confirm_btn = 0;
        
        // Wait for Validation and Execution Start
        wait(dut.u_selector.state == DONE);
        // Selector goes to DONE, then Compute Subsystem starts Executor.
        
        // Wait for Write Request from Executor
        wait(write_request);
        $display("Executor Write Request: ID=%d, Rows=%d, Cols=%d", write_matrix_id, write_rows, write_cols);
        
        // Simulate Write
        @(posedge clk);
        write_ready = 0;
        repeat(4) @(posedge write_data_valid);
        
        #(CLK_PERIOD * 10);
        write_done = 1;
        write_ready = 1;
        @(posedge clk);
        write_done = 0;
        
        wait(done);
        $display("Compute Subsystem Done");
        
        $finish;
    end

endmodule
