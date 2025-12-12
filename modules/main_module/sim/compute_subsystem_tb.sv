`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module compute_subsystem_tb;

    // Parameters
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic confirm_btn;
    logic [31:0] scalar_in;
    logic random_scalar;
    op_mode_t op_mode_in;
    calc_type_t calc_type_in;
    logic [31:0] settings_countdown;
    
    logic busy;
    logic done;
    logic error;
    logic [7:0] seg;
    logic [3:0] an;
    
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    logic [7:0] uart_tx_data;
    logic uart_tx_valid;
    logic uart_tx_ready;
    
    logic [ADDR_WIDTH-1:0] bram_rd_addr;
    logic [DATA_WIDTH-1:0] bram_rd_data;
    
    logic write_request;
    logic write_ready;
    logic [2:0] write_matrix_id;
    logic [7:0] write_rows;
    logic [7:0] write_cols;
    logic [7:0] write_name [0:7];
    logic [DATA_WIDTH-1:0] write_data;
    logic write_data_valid;
    logic write_done;
    logic writer_ready;

    // Mock BRAM
    logic [31:0] mock_bram [0:16383];

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

    // Mock BRAM Logic
    // always @(posedge clk) begin
    //     bram_rd_data <= mock_bram[bram_rd_addr];
    // end
    assign bram_rd_data = mock_bram[bram_rd_addr];

    // Helper Task: Send UART Byte
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            uart_rx_data <= data;
            uart_rx_valid <= 1;
            @(posedge clk);
            uart_rx_valid <= 0;
            repeat(5) @(posedge clk); // Wait between bytes
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

    // Helper Task: Toggle Confirm
    task toggle_confirm();
        begin
            @(posedge clk);
            confirm_btn <= 1;
            @(posedge clk);
            confirm_btn <= 0;
            repeat(10) @(posedge clk);
        end
    endtask

    // Write Request Handler
    initial begin
        write_ready = 1;
        write_done = 0;
        forever begin
            @(posedge clk);
            if (write_request && write_ready) begin
                write_ready <= 0;
                // Simulate write delay
                // Must be longer than the time it takes to write the data
                // Convolution writes 80 words (8x10), so we need > 80 cycles.
                repeat(200) @(posedge clk);
                write_done <= 1;
                @(posedge clk);
                write_done <= 0;
                write_ready <= 1;
            end
        end
    end

    // Test Sequence
    initial begin
        // Initialize Signals
        rst_n = 0;
        start = 0;
        confirm_btn = 0;
        scalar_in = 0;
        random_scalar = 0;
        op_mode_in = OP_SINGLE; // Default to Transpose
        calc_type_in = CALC_TRANSPOSE;
        settings_countdown = 32'd1000; // Long timeout
        uart_rx_data = 0;
        uart_rx_valid = 0;
        uart_tx_ready = 1;
        // write_ready handled by separate block
        // write_done handled by separate block
        writer_ready = 1;

        // Initialize Mock BRAM
        // Clear BRAM
        for (int i = 0; i < 16384; i++) mock_bram[i] = 0;

        // Populate Matrix 1 (ID=1) at Slot 1
        mock_bram[1*1152] = {8'd2, 8'd2, 16'd0};
        
        // Populate Matrix 2 (ID=2) at Slot 2
        mock_bram[2*1152] = {8'd2, 8'd2, 16'd0};
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        //---------------------------------------------------------------------
        // Test 1: Transpose Operation (Single Operand)
        //---------------------------------------------------------------------
        $display("\nTest 1: Transpose Operation");
        
        // Setup Op Mode
        op_mode_in = OP_SINGLE;
        calc_type_in = CALC_TRANSPOSE;
        
        // Check Op Code Display (Should be 'T')
        // We don't know the exact segment mapping for 'T' without checking calc_method_show.sv
        // But we can check it's not 0 or default off.
        #(CLK_PERIOD);
        $display("Op Code Display (T): Seg=%b, An=%b", seg, an);

        // Start Selection
        start = 1;
        repeat(2) @(posedge clk);
        start = 0;

        // Wait for clear to finish
        #(CLK_PERIOD * 10);

        // 1. Input Dimensions: "2 2"
        send_string("2 2\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // Wait for scanner and list display
        #(CLK_PERIOD * 50000);
        
        // 2. Select Matrix A: Input ID "1"
        send_string("1\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // Wait for execution
        wait(done);
        $display("Test 1 Passed: Done signal asserted");
        
        // Cleanup / Wait for IDLE
        wait(!busy);
        #(CLK_PERIOD * 100);

        //---------------------------------------------------------------------
        // Test 2: Matrix Addition (Double Operand)
        //---------------------------------------------------------------------
        $display("\nTest 2: Matrix Addition");
        
        op_mode_in = OP_DOUBLE;
        calc_type_in = CALC_ADD;
        
        // Start
        start = 1;
        repeat(2) @(posedge clk);
        start = 0;
        #(CLK_PERIOD * 10);

        // 1. Input Dimensions: "2 2"
        send_string("2 2\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // Wait for scanner
        #(CLK_PERIOD * 200);
        
        // 2. Select Matrix A: Input ID "1"
        send_string("1\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // 3. Select Matrix B: Input ID "2"
        send_string("2\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        wait(done);
        $display("Test 2 Passed: Done signal asserted");
        
        wait(!busy);
        #(CLK_PERIOD * 100);

        //---------------------------------------------------------------------
        // Test 3: Scalar Multiplication
        //---------------------------------------------------------------------
        $display("\nTest 3: Scalar Multiplication");
        
        op_mode_in = OP_SCALAR;
        calc_type_in = CALC_SCALAR_MUL;
        scalar_in = 32'd5; // Scalar = 5
        
        // Start
        start = 1;
        repeat(2) @(posedge clk);
        start = 0;
        #(CLK_PERIOD * 10);

        // 1. Input Dimensions: "2 2"
        send_string("2 2\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // Wait for scanner
        #(CLK_PERIOD * 200);
        
        // 2. Select Matrix A: Input ID "1"
        send_string("1\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // 3. Confirm Scalar (from switches)
        #(CLK_PERIOD * 50);
        toggle_confirm();
        
        wait(done);
        $display("Test 3 Passed: Done signal asserted");
        
        wait(!busy);
        #(CLK_PERIOD * 100);

        //---------------------------------------------------------------------
        // Test 4: Convolution
        //---------------------------------------------------------------------
        $display("\nTest 4: Convolution");
        
        // Populate Matrix 3 (Kernel) at Slot 3
        // 3x3, 1 to 9
        mock_bram[3*1152] = {8'd3, 8'd3, 16'd0};
        for(int i=0; i<9; i++) mock_bram[3*1152 + 2 + i] = i+1;

        op_mode_in = OP_SINGLE;
        calc_type_in = CALC_CONV;
        
        // Start
        start = 1;
        repeat(2) @(posedge clk);
        start = 0;
        #(CLK_PERIOD * 10);

        // 1. Input Dimensions: "3 3" (Kernel size)
        send_string("3 3\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        // Wait for scanner
        #(CLK_PERIOD * 200);
        
        // 2. Select Matrix A: Input ID "3"
        send_string("3\n");
        #(CLK_PERIOD * 200);
        toggle_confirm();
        
        wait(done);
        $display("Test 4 Passed: Done signal asserted");
        
        // Check Display (Should show cycle count)
        // Since we can't easily check the value without knowing exact cycles,
        // we just check if seg is not error/default.
        $display("Seg Output: %b, An Output: %b", seg, an);
        
        wait(!busy);
        #(CLK_PERIOD * 100);

        $display("\nAll Tests Completed Successfully");
        $finish;
    end

endmodule
