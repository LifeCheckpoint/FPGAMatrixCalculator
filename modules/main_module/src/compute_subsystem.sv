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
    input  logic                  writer_ready,
    output logic [7:0]            debug_leds // New debug output
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    
    // Selector Outputs
    logic selector_result_valid;
    logic selector_abort;
    calc_type_t selector_result_op;
    logic [2:0] selector_matrix_a;
    logic [2:0] selector_matrix_b;
    logic [31:0] selector_scalar;
    logic [ADDR_WIDTH-1:0] selector_bram_addr;
    logic selector_led_error;
    logic [7:0] selector_seg;
    logic [3:0] selector_an;
    logic [4:0] selector_state;
    
    // Executor Outputs
    logic executor_busy;
    logic executor_done;
    logic [ADDR_WIDTH-1:0] executor_bram_addr;
    logic [31:0] executor_cycle_count;
    
    // Display Logic
    logic [3:0] bcd_out [0:3];
    logic [7:0] seg_ctrl;
    logic [3:0] an_ctrl;
    logic [1:0] display_mode;
    logic [2:0] method_sel;
    
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
    
    // Clear buffer only when selector requests it.
    // Removing 'start' prevents clearing the buffer when user presses S4 to confirm pre-loaded data.
    assign buf_clear = selector_clear_req;
    
    logic pkt_last;
    assign pkt_last = uart_rx_valid && (uart_rx_data == 8'h0A || uart_rx_data == 8'h0D);

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
        .pkt_payload_last(pkt_last),
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
        .ADDR_WIDTH(ADDR_WIDTH)
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
        .seg(selector_seg),
        .an(selector_an),
        .result_valid(selector_result_valid),
        .abort(selector_abort),
        .result_op(selector_result_op),
        .result_matrix_a(selector_matrix_a),
        .result_matrix_b(selector_matrix_b),
        .result_scalar(selector_scalar),
        .current_state(selector_state)
    );
    
    assign debug_leds = {num_count[3:0], selector_state[3:0]};
    
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
        .write_done(write_done),
        .cycle_count(executor_cycle_count)
    );

    //-------------------------------------------------------------------------
    // Display Controller
    //-------------------------------------------------------------------------

    // Mux for BCD input: Show num_count during selection, cycle_count during/after execution
    logic [15:0] bcd_in;
    always_comb begin
        if (state == SELECTING) begin
            bcd_in = {5'b0, num_count};
        end else begin
            bcd_in = executor_cycle_count[15:0];
        end
    end

    bin_to_bcd u_bcd (
        .clk(clk),
        .rst_n(rst_n),
        .bin_in(bcd_in),
        .bcd_out(bcd_out)
    );
    
    // Map calc_type to method_sel (3 bits)
    // CALC_TRANSPOSE (0) -> 0
    // CALC_ADD (1) -> 1
    // CALC_MUL (2) -> 2
    // CALC_SCALAR_MUL (3) -> 3
    // CALC_CONV (4) -> 4
    assign method_sel = 3'(calc_type_in);
    
    // Display Mode Logic
    // Mode 0: Seg7 (Cycle Count / Num Count)
    // Mode 1: Calc Method (Op Code)
    always_comb begin
        if (state == SELECTING) begin
            display_mode = 2'd0; // Show Num Count
        end else if (state == DONE_STATE && selector_result_op == CALC_CONV) begin
            display_mode = 2'd0; // Show Cycle Count
        end else begin
            display_mode = 2'd1; // Show Op Code
        end
    end

    led_display_ctrl u_display_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .display_mode(display_mode),
        .seg7_valid(1'b1),
        .bcd_data_0(bcd_out[0]),
        .bcd_data_1(bcd_out[1]),
        .bcd_data_2(bcd_out[2]),
        .bcd_data_3(bcd_out[3]),
        .method_sel(method_sel),
        .seg(seg_ctrl),
        .an(an_ctrl)
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
                    else if (selector_abort) state <= IDLE;
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
    
    // Display Mux
    // Priority:
    // 1. Selector Error/Countdown (selector_led_error)
    // 2. Display Controller (Cycle Count or Op Code)
    always_comb begin
        if (selector_led_error) begin
            seg = selector_seg;
            an = selector_an;
        end else begin
            seg = seg_ctrl;
            an = an_ctrl;
        end
    end

    // BRAM Read Address Mux
    // When executing, Executor controls BRAM. When selecting, Selector controls BRAM.
    assign bram_rd_addr = (state == EXECUTING) ? executor_bram_addr : selector_bram_addr;

endmodule
