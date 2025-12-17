`timescale 1ns / 1ps

module input_subsystem #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control
    input  logic                  mode_is_input,
    input  logic                  mode_is_gen,
    input  logic                  mode_is_settings,
    input  logic                  start, // Pulse
    
    // Status
    output logic                  busy,
    output logic                  done,
    output logic                  error,
    
    // UART Input (for buffer)
    input  logic [7:0]            uart_rx_data,
    input  logic                  uart_rx_valid,
    
    // Settings Interface (Outputs from Settings RAM)
    output logic [31:0]           settings_max_row,
    output logic [31:0]           settings_max_col,
    output logic [31:0]           settings_data_min,
    output logic [31:0]           settings_data_max,
    output logic [31:0]           settings_countdown,
    
    // Storage Manager Write Interface
    output logic                  write_request,
    input  logic                  write_ready,
    output logic [2:0]            matrix_id,
    output logic [7:0]            actual_rows,
    output logic [7:0]            actual_cols,
    output logic [7:0]            matrix_name [0:7],
    output logic [DATA_WIDTH-1:0] data_in,
    output logic                  data_valid,
    input  logic                  write_done,
    input  logic                  writer_ready,
    
    // Storage Manager Read Interface (for finding empty slots)
    output logic [ADDR_WIDTH-1:0] storage_rd_addr,
    input  logic [DATA_WIDTH-1:0] storage_rd_data
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    
    // Buffer RAM Interface
    logic                  buf_clear;
    logic [10:0]           buf_rd_addr;
    logic [31:0]           buf_rd_data;
    logic [10:0]           num_count;
    
    // Sub-module Status
    logic input_busy, input_done, input_error;
    logic gen_busy, gen_done, gen_error;
    logic settings_busy, settings_done, settings_error;
    logic ascii_busy; // Busy signal from ascii_num_sep_top
    
    // Sub-module Write Requests
    logic input_wr_req, gen_wr_req;
    logic [2:0] input_mat_id, gen_mat_id;
    logic [7:0] input_rows, gen_rows;
    logic [7:0] input_cols, gen_cols;
    logic [7:0] input_name[0:7], gen_name[0:7];
    logic [31:0] input_data_out, gen_data_out;
    logic input_data_valid, gen_data_valid;
    
    // Sub-module Read Requests
    logic [ADDR_WIDTH-1:0] input_rd_addr, gen_rd_addr;
    
    // Buffer Read Arbitration
    logic [10:0] input_buf_addr, gen_buf_addr, settings_buf_addr;
    
    // Mode Change Detection for Buffer Clear
    logic [2:0] current_mode;
    logic [2:0] last_mode;
    
    assign current_mode = {mode_is_settings, mode_is_gen, mode_is_input};
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_mode <= 3'd0;
        end else begin
            last_mode <= current_mode;
        end
    end

    //-------------------------------------------------------------------------
    // Global Input Buffer (ascii_num_sep_top)
    //-------------------------------------------------------------------------
    
    // Clear buffer when mode changes OR when operation completes successfully OR on error
    // This allows consecutive operations without switching modes and prevents deadlock on error
    // Note: settings_error is persistent, so we don't include it to avoid locking the buffer
    assign buf_clear = (current_mode != last_mode) || settings_done || input_done || gen_done || input_error || gen_error;
    
    // Generate payload_last on terminator (newline/CR)
    wire internal_pkt_last;
    assign internal_pkt_last = (uart_rx_valid == 1'b1) && ((uart_rx_data == 8'h0A) || (uart_rx_data == 8'h0D));

    always @(internal_pkt_last) begin
        $display("[%0t] internal_pkt_last changed to %b (valid=%b, data=%h)", $time, internal_pkt_last, uart_rx_valid, uart_rx_data);
    end

    always @(posedge clk) begin
        if (uart_rx_valid) begin
            $display("[%0t] Input Subsystem: Data=%h, Valid=%b, Last=%b", $time, uart_rx_data, uart_rx_valid, internal_pkt_last);
        end
    end

    ascii_num_sep_top #(
        .MAX_PAYLOAD(1200),
        .DATA_WIDTH(32),
        .DEPTH(2048),
        .ADDR_WIDTH(11)
    ) u_input_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .buf_clear(buf_clear),
        .pkt_payload_data(uart_rx_data),
        .pkt_payload_valid(uart_rx_valid),
        .pkt_payload_last(internal_pkt_last),
        .pkt_payload_ready(),
        .rd_addr(buf_rd_addr),
        .rd_data(buf_rd_data),
        .processing(ascii_busy),
        .done(),
        .invalid(),
        .num_count(num_count)
    );
    
    // Buffer Read Address Mux
    always_comb begin
        if (mode_is_input) buf_rd_addr = input_buf_addr;
        else if (mode_is_gen) buf_rd_addr = gen_buf_addr;
        else if (mode_is_settings) buf_rd_addr = settings_buf_addr;
        else buf_rd_addr = 0;
    end

    //-------------------------------------------------------------------------
    // Settings Handler
    //-------------------------------------------------------------------------
    
    settings_data_handler u_settings_handler (
        .clk(clk),
        .rst_n(rst_n),
        .start(start && mode_is_settings),
        .busy(settings_busy),
        .done(settings_done),
        .error(settings_error),
        .buf_rd_addr(settings_buf_addr),
        .buf_rd_data(buf_rd_data),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .settings_countdown(settings_countdown)
    );

    //-------------------------------------------------------------------------
    // Matrix Input Handler
    //-------------------------------------------------------------------------
    
    matrix_input_handler u_input_handler (
        .clk(clk),
        .rst_n(rst_n),
        .start(start && mode_is_input),
        .error(input_error),
        .busy(input_busy),
        .done(input_done),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .buf_rd_addr(input_buf_addr),
        .buf_rd_data(buf_rd_data),
        .write_request(input_wr_req),
        .write_ready(write_ready), // Shared ready signal
        .matrix_id(input_mat_id),
        .actual_rows(input_rows),
        .actual_cols(input_cols),
        .matrix_name(input_name),
        .data_in(input_data_out),
        .data_valid(input_data_valid),
        .write_done(write_done),   // Shared done signal
        .writer_ready(writer_ready), // Shared ready signal
        .clear_request(), // Not connected for now, or handle internally
        .clear_done(1'b1), // Mock
        .clear_matrix_id(),
        .storage_rd_addr(input_rd_addr),
        .storage_rd_data(storage_rd_data)
    );

    //-------------------------------------------------------------------------
    // Matrix Random Generation Handler
    //-------------------------------------------------------------------------
    
    matrix_rand_gen_handler u_gen_handler (
        .clk(clk),
        .rst_n(rst_n),
        .start(start && mode_is_gen),
        .error(gen_error),
        .busy(gen_busy),
        .done(gen_done),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .buf_rd_addr(gen_buf_addr),
        .buf_rd_data(buf_rd_data),
        .write_request(gen_wr_req),
        .write_ready(write_ready),
        .matrix_id(gen_mat_id),
        .actual_rows(gen_rows),
        .actual_cols(gen_cols),
        .matrix_name(gen_name),
        .data_in(gen_data_out),
        .data_valid(gen_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .storage_rd_addr(gen_rd_addr),
        .storage_rd_data(storage_rd_data)
    );

    //-------------------------------------------------------------------------
    // Output Arbitration
    //-------------------------------------------------------------------------
    
    // Status Mux
    always_comb begin
        // Global busy includes parsing busy
        if (mode_is_input) begin
            busy = input_busy || ascii_busy;
            done = input_done;
            error = input_error;
        end else if (mode_is_gen) begin
            busy = gen_busy || ascii_busy;
            done = gen_done;
            error = gen_error;
        end else if (mode_is_settings) begin
            busy = settings_busy || ascii_busy;
            done = settings_done;
            error = settings_error;
        end else begin
            busy = ascii_busy;
            done = 0;
            error = 0;
        end
    end
    
    // Write Interface Mux
    always_comb begin
        if (mode_is_input) begin
            write_request = input_wr_req;
            matrix_id = input_mat_id;
            actual_rows = input_rows;
            actual_cols = input_cols;
            matrix_name = input_name;
            data_in = input_data_out;
            data_valid = input_data_valid;
        end else if (mode_is_gen) begin
            write_request = gen_wr_req;
            matrix_id = gen_mat_id;
            actual_rows = gen_rows;
            actual_cols = gen_cols;
            matrix_name = gen_name;
            data_in = gen_data_out;
            data_valid = gen_data_valid;
        end else begin
            write_request = 0;
            matrix_id = 0;
            actual_rows = 0;
            actual_cols = 0;
            matrix_name = '{default:0};
            data_in = 0;
            data_valid = 0;
        end
    end
    
    // Storage Read Address Mux (for finding empty slots)
    always_comb begin
        if (mode_is_input) storage_rd_addr = input_rd_addr;
        else if (mode_is_gen) storage_rd_addr = gen_rd_addr;
        else storage_rd_addr = 0;
    end

endmodule
