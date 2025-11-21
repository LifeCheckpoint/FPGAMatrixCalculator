`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_mul #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [2:0]               matrix_a_id,
    input  logic [2:0]               matrix_b_id,
    output logic                     busy,
    output matrix_op_status_e        status,

    output logic [ADDR_WIDTH-1:0]    read_addr,
    input  logic [DATA_WIDTH-1:0]    data_out,

    output logic                     write_request,
    input  logic                     write_ready,
    output logic [2:0]               matrix_id,
    output logic [7:0]               actual_rows,
    output logic [7:0]               actual_cols,
    output logic [7:0]               matrix_name [0:7],
    output logic [DATA_WIDTH-1:0]    data_in,
    output logic                     data_valid,
    input  logic                     writer_ready,
    input  logic                     write_done
);

    typedef enum logic [5:0] {
        STATE_IDLE,
        STATE_CHECK_IDS,
        STATE_READ_A_META_ADDR,
        STATE_READ_A_META_WAIT,
        STATE_READ_B_META_ADDR,
        STATE_READ_B_META_WAIT,
        STATE_VALIDATE,
        STATE_WAIT_WRITE_READY,
        STATE_ASSERT_WRITE_REQ,
        STATE_WAIT_WRITER_ENABLE,
        STATE_PREPARE_A_ADDR,
        STATE_WAIT_A_DATA,
        STATE_PREPARE_B_ADDR,
        STATE_WAIT_B_DATA,
        STATE_MAC,
        STATE_WAIT_WRITER_FOR_RESULT,
        STATE_ADVANCE_RESULT_INDEX,
        STATE_WAIT_WRITE_DONE,
        STATE_DONE
    } state_t;

    state_t state, state_next;

    localparam logic [ADDR_WIDTH-1:0] META_OFFSET = ADDR_WIDTH'(MATRIX_METADATA_WORDS);

    logic [ADDR_WIDTH-1:0] read_addr_reg;
    logic [ADDR_WIDTH-1:0] matrix_a_base, matrix_b_base;

    logic [2:0] matrix_a_id_lat, matrix_b_id_lat;

    matrix_shape_t shape_a, shape_b;
    logic [15:0]   elem_count_a, elem_count_b;
    logic [15:0]   total_elements;

    logic [15:0]   rows_a_ext, cols_a_ext;
    logic [15:0]   rows_b_ext, cols_b_ext;

    logic [15:0]   row_idx;
    logic [15:0]   col_idx;
    logic [15:0]   k_idx;

    logic [15:0]   processed_elements;

    logic [DATA_WIDTH-1:0] operand_a_word;
    logic [DATA_WIDTH-1:0] operand_b_word;
    logic [DATA_WIDTH-1:0] result_word;

    logic signed [DATA_WIDTH-1:0] operand_a_s;
    logic signed [DATA_WIDTH-1:0] operand_b_s;
    logic signed [(2*DATA_WIDTH)-1:0] mult_full;
    logic signed [(2*DATA_WIDTH)-1:0] accumulator;
    logic signed [(2*DATA_WIDTH)-1:0] accumulator_next;

    logic [ADDR_WIDTH-1:0] addr_a_data;
    logic [ADDR_WIDTH-1:0] addr_b_data;

    logic                   accept_start;
    logic                   validation_pass;
    logic                   set_status;
    matrix_op_status_e      status_value;
    matrix_op_status_e      status_reg;

    logic                   k_cycle_last;

    localparam logic [7:0] RESULT_NAME [0:7] = '{
        8'h4d, // M
        8'h55, // U
        8'h4c, // L
        8'h52, // R
        8'h45, // E
        8'h53, // S
        8'h00,
        8'h00
    };

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_a (
        .matrix_id(matrix_a_id_lat),
        .base_addr(matrix_a_base)
    );

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_b (
        .matrix_id(matrix_b_id_lat),
        .base_addr(matrix_b_base)
    );

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi++) begin : gen_name_const
            assign matrix_name[gi] = RESULT_NAME[gi];
        end
    endgenerate

    assign matrix_id     = 3'd0;
    assign read_addr     = read_addr_reg;
    assign write_request = (state == STATE_ASSERT_WRITE_REQ);
    assign data_valid    = (state == STATE_WAIT_WRITER_FOR_RESULT);
    assign data_in       = result_word;
    assign busy          = (state != STATE_IDLE);
    assign status        = status_reg;

    assign rows_a_ext = {8'd0, shape_a.rows};
    assign cols_a_ext = {8'd0, shape_a.cols};
    assign rows_b_ext = {8'd0, shape_b.rows};
    assign cols_b_ext = {8'd0, shape_b.cols};

    assign elem_count_a = shape_element_count(shape_a);
    assign elem_count_b = shape_element_count(shape_b);

    assign actual_rows = shape_a.rows;
    assign actual_cols = shape_b.cols;

    assign addr_a_data = indexed_data_addr(
        matrix_a_base,
        shape_a,
        row_idx,
        k_idx
    );

    assign addr_b_data = indexed_data_addr(
        matrix_b_base,
        shape_b,
        k_idx,
        col_idx
    );

    assign operand_a_s = operand_a_word;
    assign operand_b_s = operand_b_word;
    assign mult_full   = operand_a_s * operand_b_s;
    assign accumulator_next = (k_idx == 16'd0) ? mult_full : (accumulator + mult_full);

    assign k_cycle_last = (k_idx + 16'd1 == cols_a_ext);

    assign accept_start = (state == STATE_IDLE) && start;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= STATE_IDLE;
            read_addr_reg     <= '0;
            matrix_a_id_lat   <= 3'd0;
            matrix_b_id_lat   <= 3'd0;
            shape_a           <= MATRIX_SHAPE_ZERO;
            shape_b           <= MATRIX_SHAPE_ZERO;
            row_idx           <= 16'd0;
            col_idx           <= 16'd0;
            k_idx             <= 16'd0;
            processed_elements<= 16'd0;
            total_elements    <= 16'd0;
            operand_a_word    <= '0;
            operand_b_word    <= '0;
            result_word       <= '0;
            accumulator       <= '0;
            status_reg        <= MATRIX_OP_STATUS_IDLE;
        end else begin
            state <= state_next;

            if (accept_start) begin
                matrix_a_id_lat    <= matrix_a_id;
                matrix_b_id_lat    <= matrix_b_id;
                shape_a            <= MATRIX_SHAPE_ZERO;
                shape_b            <= MATRIX_SHAPE_ZERO;
                row_idx            <= 16'd0;
                col_idx            <= 16'd0;
                k_idx              <= 16'd0;
                processed_elements <= 16'd0;
                total_elements     <= 16'd0;
                operand_a_word     <= '0;
                operand_b_word     <= '0;
                result_word        <= '0;
                accumulator        <= '0;
                status_reg         <= MATRIX_OP_STATUS_BUSY;
            end

            if (validation_pass) begin
                row_idx            <= 16'd0;
                col_idx            <= 16'd0;
                k_idx              <= 16'd0;
                processed_elements <= 16'd0;
                total_elements     <= rows_a_ext * cols_b_ext;
                accumulator        <= '0;
            end

            case (state)
                STATE_READ_A_META_ADDR: read_addr_reg <= matrix_a_base;
                STATE_READ_B_META_ADDR: read_addr_reg <= matrix_b_base;
                STATE_PREPARE_A_ADDR:   read_addr_reg <= addr_a_data;
                STATE_PREPARE_B_ADDR:   read_addr_reg <= addr_b_data;
                default: begin end
            endcase

            if (state == STATE_READ_A_META_WAIT) begin
                shape_a <= decode_shape_word(data_out);
            end

            if (state == STATE_READ_B_META_WAIT) begin
                shape_b <= decode_shape_word(data_out);
            end

            if (state == STATE_WAIT_A_DATA) begin
                operand_a_word <= data_out;
            end

            if (state == STATE_WAIT_B_DATA) begin
                operand_b_word <= data_out;
            end

            if (state == STATE_MAC) begin
                accumulator <= accumulator_next;
                if (k_cycle_last) begin
                    result_word <= accumulator_next[DATA_WIDTH-1:0];
                    accumulator <= '0;
                end
            end

            if (state == STATE_MAC) begin
                if (k_cycle_last) begin
                    k_idx <= 16'd0;
                end else begin
                    k_idx <= k_idx + 16'd1;
                end
            end else if (state == STATE_WAIT_WRITER_FOR_RESULT && writer_ready) begin
                k_idx <= 16'd0;
            end

            if (state == STATE_WAIT_WRITER_FOR_RESULT && writer_ready) begin
                processed_elements <= processed_elements + 16'd1;
            end

            if (state == STATE_ADVANCE_RESULT_INDEX) begin
                if (col_idx + 16'd1 < cols_b_ext) begin
                    col_idx <= col_idx + 16'd1;
                end else begin
                    col_idx <= 16'd0;
                    row_idx <= row_idx + 16'd1;
                end
            end

            if (set_status) begin
                status_reg <= status_value;
            end
        end
    end

    always_comb begin
        state_next      = state;
        set_status      = 1'b0;
        status_value    = status_reg;
        validation_pass = 1'b0;

        unique case (state)
            STATE_IDLE: begin
                if (start) begin
                    state_next = STATE_CHECK_IDS;
                end
            end

            STATE_CHECK_IDS: begin
                if (!is_valid_operand_id(matrix_a_id_lat) || !is_valid_operand_id(matrix_b_id_lat)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_ID;
                    state_next   = STATE_DONE;
                end else begin
                    state_next = STATE_READ_A_META_ADDR;
                end
            end

            STATE_READ_A_META_ADDR: state_next = STATE_READ_A_META_WAIT;
            STATE_READ_A_META_WAIT: state_next = STATE_READ_B_META_ADDR;
            STATE_READ_B_META_ADDR: state_next = STATE_READ_B_META_WAIT;
            STATE_READ_B_META_WAIT: state_next = STATE_VALIDATE;

            STATE_VALIDATE: begin
                if (elem_count_a == 16'd0 || elem_count_b == 16'd0 ||
                    shape_a.rows == 8'd0 || shape_a.cols == 8'd0 ||
                    shape_b.rows == 8'd0 || shape_b.cols == 8'd0) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_EMPTY;
                    state_next   = STATE_DONE;
                end else if (!is_data_capacity_ok(elem_count_a) || !is_data_capacity_ok(elem_count_b)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_FORMAT;
                    state_next   = STATE_DONE;
                end else if (cols_a_ext != rows_b_ext) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_DIM;
                    state_next   = STATE_DONE;
                end else if ((rows_a_ext * cols_b_ext) > MATRIX_DATA_CAPACITY) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_FORMAT;
                    state_next   = STATE_DONE;
                end else begin
                    validation_pass = 1'b1;
                    state_next      = STATE_WAIT_WRITE_READY;
                end
            end

            STATE_WAIT_WRITE_READY: begin
                if (write_ready) begin
                    state_next = STATE_ASSERT_WRITE_REQ;
                end
            end

            STATE_ASSERT_WRITE_REQ: begin
                state_next = STATE_WAIT_WRITER_ENABLE;
            end

            STATE_WAIT_WRITER_ENABLE: begin
                if (writer_ready) begin
                    state_next = STATE_PREPARE_A_ADDR;
                end
            end

            STATE_PREPARE_A_ADDR: state_next = STATE_WAIT_A_DATA;
            STATE_WAIT_A_DATA:    state_next = STATE_PREPARE_B_ADDR;
            STATE_PREPARE_B_ADDR: state_next = STATE_WAIT_B_DATA;
            STATE_WAIT_B_DATA:    state_next = STATE_MAC;

            STATE_MAC: begin
                if (k_cycle_last) begin
                    state_next = STATE_WAIT_WRITER_FOR_RESULT;
                end else begin
                    state_next = STATE_PREPARE_A_ADDR;
                end
            end

            STATE_WAIT_WRITER_FOR_RESULT: begin
                if (writer_ready) begin
                    state_next = STATE_ADVANCE_RESULT_INDEX;
                end
            end

            STATE_ADVANCE_RESULT_INDEX: begin
                if (processed_elements >= total_elements) begin
                    state_next = STATE_WAIT_WRITE_DONE;
                end else begin
                    state_next = STATE_PREPARE_A_ADDR;
                end
            end

            STATE_WAIT_WRITE_DONE: begin
                if (write_done) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_SUCCESS;
                    state_next   = STATE_DONE;
                end
            end

            STATE_DONE: begin
                state_next = STATE_IDLE;
            end

            default: begin
                set_status   = 1'b1;
                status_value = MATRIX_OP_STATUS_ERR_INTERNAL;
                state_next   = STATE_IDLE;
            end
        endcase
    end

endmodule