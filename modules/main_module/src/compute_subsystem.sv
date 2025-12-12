`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module compute_subsystem #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control
    input  logic                  start, // Starts the selection process
    input  logic                  confirm_btn,
    input  logic [31:0]           scalar_in, // From switches/GPIO
    input  logic                  random_scalar,
    input  op_mode_t              op_mode_in,
    input  calc_type_t            calc_type_in,
    input  logic [31:0]           settings_countdown,
    
    // Status
    output logic                  busy,
    output logic                  done,
    output logic                  error,
    output logic [7:0]            seg,
    output logic [3:0]            an,
    
    // UART Interface
    input  logic [7:0]            uart_rx_data,
    input  logic                  uart_rx_valid,
    output logic [7:0]            uart_tx_data,
    output logic                  uart_tx_valid,
    input  logic                  uart_tx_ready,
    
    // BRAM Read Interface
    output logic [ADDR_WIDTH-1:0] bram_rd_addr,
    input  logic [DATA_WIDTH-1:0] bram_rd_data,
    
    // Storage Manager Write Interface
    output logic                  write_request,
    input  logic                  write_ready,
    output logic [2:0]            write_matrix_id,
    output logic [7:0]            write_rows,
    output logic [7:0]            write_cols,
    output logic [7:0]            write_name [0:7],
    output logic [DATA_WIDTH-1:0] write_data,
    output logic                  write_data_valid,
    input  logic                  write_done,
    input  logic                  writer_ready
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    
    // Selector Outputs
    logic selector_result_valid;
    calc_type_t selector_result_op;
    logic [2:0] selector_matrix_a;
    logic [2:0] selector_matrix_b;
    logic [31:0] selector_scalar;
    logic [ADDR_WIDTH-1:0] selector_bram_addr;
    logic selector_led_error;
    
    // Executor Outputs
    logic executor_busy;
    logic executor_done;
    logic [ADDR_WIDTH-1:0] executor_bram_addr;
    
    // State Machine for Coordination
    typedef enum logic [1:0] {
        IDLE,
        SELECTING,
        EXECUTING,
        DONE_STATE
    } state_t;
    
    state_t state;
    
    //-------------------------------------------------------------------------
    // Input Buffer (ascii_num_sep_top)
    //-------------------------------------------------------------------------
    
    logic buf_clear;
    logic [3:0] buf_rd_addr;
    logic [31:0] buf_rd_data;
    logic [10:0] num_count;
    logic selector_clear_req;
    
    // Clear buffer on start (entry) or when selector requests it
    assign buf_clear = start || selector_clear_req;
    
    ascii_num_sep_top #(
        .MAX_PAYLOAD(64),
        .DEPTH(16),
        .ADDR_WIDTH(4)
    ) u_input_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .buf_clear(buf_clear),
        .pkt_payload_data(uart_rx_data),
        .pkt_payload_valid(uart_rx_valid),
        .pkt_payload_last(uart_rx_valid && (uart_rx_data == 8'h0A || uart_rx_data == 8'h0D)),
        .pkt_payload_ready(),
        .rd_addr(buf_rd_addr),
        .rd_data(buf_rd_data),
        .processing(),
        .done(),
        .invalid(),
        .num_count(num_count)
    );

    //-------------------------------------------------------------------------
    // Matrix Operation Selector
    //-------------------------------------------------------------------------
    
    matrix_op_selector #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BUF_ADDR_WIDTH(4)
    ) u_selector (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .confirm_btn(confirm_btn),
        .scalar_in(scalar_in),
        .random_scalar(random_scalar),
        .op_mode_in(op_mode_in),
        .calc_type_in(calc_type_in),
        .countdown_time_in(settings_countdown),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data),
        .num_count(num_count),
        .buf_clear_req(selector_clear_req),
        .bram_addr(selector_bram_addr),
        .bram_data(bram_rd_data),
        .led_error(selector_led_error),
        .seg(seg),
        .an(an),
        .result_valid(selector_result_valid),
        .result_op(selector_result_op),
        .result_matrix_a(selector_matrix_a),
        .result_matrix_b(selector_matrix_b),
        .result_scalar(selector_scalar)
    );
    
    //-------------------------------------------------------------------------
    // Matrix Operation Executor
    //-------------------------------------------------------------------------
    
    // Executor starts when Selector finishes successfully
    logic executor_start;
    assign executor_start = selector_result_valid;
    
    matrix_op_executor #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_executor (
        .clk(clk),
        .rst_n(rst_n),
        .start(executor_start),
        .op_type(selector_result_op), // Use the validated op type
        .matrix_a(selector_matrix_a),
        .matrix_b(selector_matrix_b),
        .scalar_in(selector_scalar),
        .busy(executor_busy),
        .done(executor_done),
        .bram_read_addr(executor_bram_addr),
        .bram_data_out(bram_rd_data),
        .write_request(write_request),
        .write_ready(write_ready),
        .write_matrix_id(write_matrix_id),
        .write_rows(write_rows),
        .write_cols(write_cols),
        .write_name(write_name),
        .write_data(write_data),
        .write_data_valid(write_data_valid),
        .writer_ready(writer_ready),
        .write_done(write_done)
    );
    
    //-------------------------------------------------------------------------
    // Coordination Logic
    //-------------------------------------------------------------------------
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= SELECTING;
                end
                SELECTING: begin
                    if (selector_result_valid) state <= EXECUTING;
                end
                EXECUTING: begin
                    if (executor_done) state <= DONE_STATE;
                end
                DONE_STATE: begin
                    // Hold done for one cycle or wait for reset?
                    // For now, just go back to IDLE or wait for next start
                    if (!start) state <= IDLE; 
                end
            endcase
        end
    end
    
    // Output Assignments
    assign busy = (state == SELECTING) || (state == EXECUTING);
    assign done = (state == DONE_STATE);
    assign error = selector_led_error; // Pass through error from selector
    
    // BRAM Read Address Mux
    // When executing, Executor controls BRAM. When selecting, Selector controls BRAM.
    assign bram_rd_addr = (state == EXECUTING) ? executor_bram_addr : selector_bram_addr;

endmodule
