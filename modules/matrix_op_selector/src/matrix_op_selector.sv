`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module matrix_op_selector #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control
    input  logic                  start,
    input  logic                  confirm_btn,
    input  logic [31:0]           scalar_in,
    input  logic                  random_scalar, // New input for random scalar selection
    input  op_mode_t              op_mode_in, // From op_mode_controller
    input  calc_type_t            calc_type_in, // From op_mode_controller
    input  logic [31:0]           countdown_time_in, // From settings
    
    // UART Interface
    output logic [7:0]            uart_tx_data,
    output logic                  uart_tx_valid,
    input  logic                  uart_tx_ready,
    
    // Buffer Interface
    output logic [3:0]            buf_rd_addr, // Fixed width 4 to match previous internal logic
    input  logic [31:0]           buf_rd_data,
    input  logic [10:0]           num_count,
    output logic                  buf_clear_req,

    // BRAM Interface
    output logic [ADDR_WIDTH-1:0] bram_addr,
    input  logic [31:0]           bram_data,
    
    // Status / Output
    output logic                  led_error,
    output logic [7:0]            seg,
    output logic [3:0]            an,
    
    // Result Output
    output logic                  result_valid,
    output logic                  abort, // Signal to abort operation
    output calc_type_t            result_op,
    output logic [2:0]            result_matrix_a,
    output logic [2:0]            result_matrix_b,
    output logic [31:0]           result_scalar,
    output logic [4:0]            current_state // Debug output
);

    // Internal Signals
    state_t state;
    assign current_state = state;
    logic [7:0] target_m, target_n;
    logic [7:0] valid_mask;
    logic [2:0] selected_a, selected_b;
    logic [31:0] selected_scalar;
    
    // Submodule Control Signals
    logic scanner_start, scanner_done, scanner_busy;
    logic [ADDR_WIDTH-1:0] scanner_addr;
    
    logic reader_start, reader_done, reader_busy;
    logic [2:0] reader_id;
    logic [ADDR_WIDTH-1:0] reader_addr;
    logic [7:0] reader_ascii;
    logic reader_ascii_valid;

    logic info_start, info_done, info_busy;
    logic [ADDR_WIDTH-1:0] info_addr;
    logic [7:0] info_ascii;
    logic info_ascii_valid;
    
    logic timer_start, timer_timeout, timer_led;
    logic [7:0] timer_seg;
    logic [3:0] timer_an;
    
    logic [31:0] rand_val;
    
    // Input Parser Signals
    logic input_clear;
    logic [31:0] input_data;
    logic [10:0] input_count;
    logic [3:0] input_rd_addr;
    
    assign buf_clear_req = input_clear;
    assign buf_rd_addr = input_rd_addr;
    assign input_data = buf_rd_data;
    assign input_count = num_count;
    
    // Matrix Scanner Instance
    matrix_scanner #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_scanner (
        .clk(clk),
        .rst_n(rst_n),
        .start(scanner_start),
        .target_rows(target_m),
        .target_cols(target_n),
        .bram_addr(scanner_addr),
        .bram_data(bram_data),
        .valid_mask(valid_mask),
        .done(scanner_done),
        .busy(scanner_busy)
    );
    
    // Matrix Reader Instance
    matrix_reader #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_reader (
        .clk(clk),
        .rst_n(rst_n),
        .start(reader_start),
        .matrix_id(reader_id),
        .busy(reader_busy),
        .done(reader_done),
        .bram_addr(reader_addr),
        .bram_data(bram_data),
        .ascii_data(reader_ascii),
        .ascii_valid(reader_ascii_valid),
        .ascii_ready(uart_tx_ready)
    );

    // Matrix Info Reader Instance
    matrix_info_reader #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_info_reader (
        .clk(clk),
        .rst_n(rst_n),
        .start(info_start),
        .busy(info_busy),
        .done(info_done),
        .bram_addr(info_addr),
        .bram_data(bram_data),
        .ascii_data(info_ascii),
        .ascii_valid(info_ascii_valid),
        .ascii_ready(uart_tx_ready)
    );
    
    // Random Generator
    logic [31:0] rand_out_array [0:0];
    
    xorshift32 #(
        .NUM_OUTPUTS(1)
    ) u_rand (
        .clk(clk),
        .rst_n(rst_n),
        .start(1'b1), // Always run to get good entropy
        .seed(32'hDEADBEEF),
        .random_out(rand_out_array)
    );
    
    assign rand_val = rand_out_array[0];
    
    // Countdown Timer
    countdown_timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .start(timer_start),
        .duration(countdown_time_in[15:0]),
        .timeout(timer_timeout),
        .led_error(timer_led),
        .seg(timer_seg),
        .an(timer_an)
    );
    
    // Output Muxing
    assign led_error = timer_led;
    assign seg = timer_seg;
    assign an = timer_an;
    
    // UART TX Mux
    always_comb begin
        if (info_busy) begin
            uart_tx_data = info_ascii;
            uart_tx_valid = info_ascii_valid;
        end else begin
            uart_tx_data = reader_ascii;
            uart_tx_valid = reader_ascii_valid;
        end
    end
    
    // BRAM Address Mux
    always_comb begin
        if (scanner_busy) bram_addr = scanner_addr;
        else if (reader_busy) bram_addr = reader_addr;
        else if (info_busy) bram_addr = info_addr;
        else bram_addr = 0;
    end
    
    // Helper for Random Selection
    function logic [2:0] get_random_valid_id(logic [7:0] mask, logic [2:0] start_idx);
        for (int i = 0; i < 8; i++) begin
            logic [2:0] idx;
            idx = start_idx + i; // Overflow wraps around 3 bits
            if (mask[idx]) return idx;
        end
        return 0; // Should not happen if mask is not 0
    endfunction

    // Main FSM
    logic [2:0] list_idx;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scanner_start <= 0;
            reader_start <= 0;
            info_start <= 0;
            timer_start <= 0;
            input_clear <= 0;
            result_valid <= 0;
            list_idx <= 0;
            target_m <= 0;
            target_n <= 0;
            selected_a <= 0;
            selected_b <= 0;
            selected_scalar <= 0;
            input_rd_addr <= 0;
        end else begin
            // Default pulses
            scanner_start <= 0;
            reader_start <= 0;
            info_start <= 0;
            timer_start <= 0;
            input_clear <= 0;
            result_valid <= 0;
            abort <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Start by showing matrix info
                        info_start <= 1;
                        state <= WAIT_INFO;
                    end
                end

                WAIT_INFO: begin
                    if (info_done) begin
                        // After showing info, proceed to check input buffer
                        if (input_count >= 2) begin
                            input_rd_addr <= 0;
                            state <= WAIT_M;
                        end else begin
                            // Data insufficient or invalid from previous operations.
                            // Must clear input buffer to unlock validator for new input.
                            input_clear <= 1;
                            state <= GET_DIMS;
                        end
                    end
                end
                
                GET_DIMS: begin
                    // Wait for 2 numbers (m, n) and confirm
                    if (confirm_btn) begin
                        if (input_count >= 2) begin
                            // Read m
                            input_rd_addr <= 0;
                            state <= WAIT_M;
                        end else begin
                            // User pressed confirm but data is missing.
                            // Since we can't append to a closed packet, we must clear and ask for retry.
                            input_clear <= 1;
                        end
                    end
                end
                
                WAIT_M: begin
                    state <= READ_M;
                end
                
                READ_M: begin // Read m
                     target_m <= input_data[7:0];
                     input_rd_addr <= 1;
                     state <= WAIT_N;
                end
                
                WAIT_N: begin
                    state <= READ_N;
                end
                
                READ_N: begin // Read n
                     target_n <= input_data[7:0];
                     input_clear <= 1; // Clear buffer for next input
                     state <= SCAN_MATRICES;
                end
                
                SCAN_MATRICES: begin
                    scanner_start <= 1;
                    state <= WAIT_SCANNER; // Wait for scanner start
                end
                
                WAIT_SCANNER: begin
                    if (scanner_done) begin
                        if (valid_mask == 0) begin
                            // No valid matrices found
                            state <= ERROR_WAIT;
                            timer_start <= 1;
                        end else begin
                            list_idx <= 0;
                            state <= DISPLAY_LIST;
                        end
                    end
                end
                
                DISPLAY_LIST: begin
                    if (valid_mask[list_idx]) begin
                        reader_id <= list_idx;
                        reader_start <= 1;
                        state <= WAIT_READER_LIST; // Wait for reader
                    end else begin
                        // Skip invalid
                        if (list_idx == 7) begin
                            input_clear <= 1; // Clear for next input
                            state <= SELECT_A;
                        end else begin
                            list_idx <= list_idx + 1;
                        end
                    end
                end
                
                WAIT_READER_LIST: begin // Wait for reader done
                    if (reader_done) begin
                        if (list_idx == 7) begin
                            input_clear <= 1;
                            state <= SELECT_A;
                        end else begin
                            list_idx <= list_idx + 1;
                            state <= DISPLAY_LIST;
                        end
                    end
                end
                
                SELECT_A: begin
                    if (confirm_btn) begin
                        if (input_count >= 1) begin
                            input_rd_addr <= 0;
                            state <= WAIT_ID_A;
                        end else begin
                            input_clear <= 1;
                        end
                    end
                end
                
                WAIT_ID_A: begin
                    state <= READ_ID_A;
                end
                
                READ_ID_A: begin // Read ID A
                    logic signed [31:0] id_in;
                    id_in = input_data;
                    
                    if (id_in == -1) begin
                        // Random
                        selected_a <= get_random_valid_id(valid_mask, rand_val[2:0]);
                        input_clear <= 1;
                        state <= DISPLAY_A;
                    end else if (id_in >= 0 && id_in <= 7 && valid_mask[id_in[2:0]]) begin
                        selected_a <= id_in[2:0];
                        input_clear <= 1;
                        state <= DISPLAY_A;
                    end else begin
                        // Invalid ID
                        timer_start <= 1;
                        state <= ERROR_WAIT;
                    end
                end
                
                DISPLAY_A: begin
                    reader_id <= selected_a;
                    reader_start <= 1;
                    // Wait for reader
                    state <= WAIT_READER_A;
                end
                
                WAIT_READER_A: begin
                    if (reader_done) state <= CHECK_MODE;
                end
                
                CHECK_MODE: begin
                    if (op_mode_in == OP_SINGLE) begin
                        state <= VALIDATE;
                    end else if (op_mode_in == OP_DOUBLE) begin
                        // Do not clear input here, to allow type-ahead during Display A
                        state <= SELECT_B;
                    end else begin // OP_SCALAR
                        state <= SELECT_SCALAR;
                    end
                end
                
                SELECT_B: begin
                    if (confirm_btn) begin
                        if (input_count >= 1) begin
                            input_rd_addr <= 0;
                            state <= WAIT_ID_B;
                        end else begin
                            input_clear <= 1;
                        end
                    end
                end
                
                WAIT_ID_B: begin
                    state <= READ_ID_B;
                end
                
                READ_ID_B: begin // Read ID B
                    logic signed [31:0] id_in;
                    id_in = input_data;
                    
                    if (id_in == -1) begin
                        selected_b <= get_random_valid_id(valid_mask, rand_val[5:3]);
                        input_clear <= 1;
                        state <= DISPLAY_B;
                    end else if (id_in >= 0 && id_in <= 7 && valid_mask[id_in[2:0]]) begin
                        selected_b <= id_in[2:0];
                        input_clear <= 1;
                        state <= DISPLAY_B;
                    end else begin
                        timer_start <= 1;
                        state <= ERROR_WAIT;
                    end
                end
                
                DISPLAY_B: begin
                    reader_id <= selected_b;
                    reader_start <= 1;
                    state <= WAIT_READER_B;
                end
                
                WAIT_READER_B: begin
                    if (reader_done) state <= VALIDATE;
                end
                
                SELECT_SCALAR: begin
                    // Wait for confirm button to lock in scalar from switches/input
                    if (confirm_btn) begin
                        // Check if we should use random scalar
                        if (random_scalar) begin
                             selected_scalar <= rand_val % 10;
                        end else begin
                             selected_scalar <= scalar_in;
                        end
                        state <= VALIDATE;
                    end
                end
                
                VALIDATE: begin
                    logic valid;
                    valid = 1'b1;
                    
                    // Matrix Multiplication: A(m,n) * B(m,n) requires n == m (since we filtered for same dims)
                    // Actually, standard matrix mul is A(m,n) * B(p,q) where n==p.
                    // But here we filtered ALL matrices to be (target_m, target_n).
                    // So A is (m,n) and B is (m,n).
                    // For A*B to be valid, n must equal m.
                    if (calc_type_in == CALC_MUL) begin
                        if (target_m != target_n) valid = 1'b0;
                    end

                    // Convolution requires 3x3 kernel
                    if (calc_type_in == CALC_CONV) begin
                        if (target_m != 3 || target_n != 3) valid = 1'b0;
                    end
                    
                    if (valid) begin
                        state <= DONE;
                    end else begin
                        timer_start <= 1;
                        state <= ERROR_WAIT;
                    end
                end
                
                ERROR_WAIT: begin
                    if (timer_timeout) begin
                        state <= IDLE; // Timeout -> Reset
                        abort <= 1;
                    end else if (confirm_btn) begin
                        // Retry
                        input_clear <= 1;
                        if (valid_mask == 0)
                            state <= GET_DIMS;
                        else
                            state <= SELECT_A; // Go back to start of selection
                    end
                end
                
                DONE: begin
                    result_valid <= 1;
                    result_op <= calc_type_in;
                    result_matrix_a <= selected_a;
                    result_matrix_b <= selected_b;
                    result_scalar <= selected_scalar;
                    state <= IDLE;
                end
                
            endcase
        end
    end

endmodule
