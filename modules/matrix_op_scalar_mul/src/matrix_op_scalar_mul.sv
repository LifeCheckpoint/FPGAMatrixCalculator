`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_scalar_mul #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [2:0]               matrix_src_id,
    input  logic [2:0]               matrix_scalar_id,
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

    typedef enum logic [4:0] {
        STATE_IDLE,
        STATE_CHECK_IDS,
        STATE_READ_SRC_META_ADDR,
        STATE_READ_SRC_META_WAIT,
        STATE_READ_SCLR_META_ADDR,
        STATE_READ_SCLR_META_WAIT,
        STATE_VALIDATE,
        STATE_READ_SCLR_DATA_ADDR,
        STATE_READ_SCLR_DATA_WAIT,
        STATE_WAIT_WRITE_READY,
        STATE_ASSERT_WRITE_REQ,
        STATE_WAIT_WRITER_ENABLE,
        STATE_PREPARE_SRC_ADDR,
        STATE_WAIT_SRC_DATA,
        STATE_WRITE_DATA,
        STATE_CHECK_NEXT,
        STATE_WAIT_WRITE_DONE,
        STATE_DONE
    } state_t;

    state_t state, state_next;

    localparam logic [ADDR_WIDTH-1:0] META_OFFSET = ADDR_WIDTH'(MATRIX_METADATA_WORDS);

    logic [ADDR_WIDTH-1:0] read_addr_reg;
    logic [ADDR_WIDTH-1:0] matrix_src_base, matrix_scalar_base;
    logic [ADDR_WIDTH-1:0] matrix_src_data_addr;

    logic [2:0] matrix_src_id_lat, matrix_scalar_id_lat;

    matrix_shape_t         shape_src, shape_scalar;
    logic [15:0]           elem_count_src, elem_count_scalar;
    logic [15:0]           total_elements;
    logic [15:0]           element_index;

    logic [DATA_WIDTH-1:0] operand_src_word;
    logic [DATA_WIDTH-1:0] scalar_word;

    logic signed [DATA_WIDTH-1:0] operand_src_s;
    logic signed [DATA_WIDTH-1:0] scalar_s;
    logic signed [(2*DATA_WIDTH)-1:0] product_full;
    logic signed [DATA_WIDTH-1:0] product_trunc;

    matrix_op_status_e status_reg;
    logic accept_start;
    logic validation_pass;
    logic set_status;
    matrix_op_status_e status_value;

    localparam logic [7:0] RESULT_NAME [0:7] = '{
        8'h53, // S
        8'h43, // C
        8'h41, // A
        8'h4c, // L
        8'h52, // R
        8'h45, // E
        8'h53, // S
        8'h00
    };

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_src (
        .matrix_id(matrix_src_id_lat),
        .base_addr(matrix_src_base)
    );

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) getter_scalar (
        .matrix_id(matrix_scalar_id_lat),
        .base_addr(matrix_scalar_base)
    );

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi++) begin : gen_name_const
            assign matrix_name[gi] = RESULT_NAME[gi];
        end
    endgenerate

    assign matrix_id     = 3'd0;
    assign actual_rows   = shape_src.rows;
    assign actual_cols   = shape_src.cols;
    assign elem_count_src    = shape_element_count(shape_src);
    assign elem_count_scalar = shape_element_count(shape_scalar);
    assign read_addr     = read_addr_reg;
    assign busy          = (state != STATE_IDLE);
    assign status        = status_reg;
    assign write_request = (state == STATE_ASSERT_WRITE_REQ);
    assign data_valid    = (state == STATE_WRITE_DATA);
    assign data_in       = product_trunc;

    assign matrix_src_data_addr = matrix_src_base + META_OFFSET + element_index[ADDR_WIDTH-1:0];

    assign operand_src_s = operand_src_word;
    assign scalar_s      = scalar_word;
    assign product_full  = operand_src_s * scalar_s;
    assign product_trunc = product_full[DATA_WIDTH-1:0];

    assign accept_start = (state == STATE_IDLE) && start;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= STATE_IDLE;
            read_addr_reg       <= '0;
            matrix_src_id_lat   <= 3'd0;
            matrix_scalar_id_lat<= 3'd0;
            shape_src           <= MATRIX_SHAPE_ZERO;
            shape_scalar        <= MATRIX_SHAPE_ZERO;
            operand_src_word    <= '0;
            scalar_word         <= '0;
            element_index       <= 16'd0;
            total_elements      <= 16'd0;
            status_reg          <= MATRIX_OP_STATUS_IDLE;
        end else begin
            state <= state_next;

            if (accept_start) begin
                matrix_src_id_lat    <= matrix_src_id;
                matrix_scalar_id_lat <= matrix_scalar_id;
                shape_src            <= MATRIX_SHAPE_ZERO;
                shape_scalar         <= MATRIX_SHAPE_ZERO;
                operand_src_word     <= '0;
                scalar_word          <= '0;
                element_index        <= 16'd0;
                total_elements       <= 16'd0;
                status_reg           <= MATRIX_OP_STATUS_BUSY;
            end

            if (validation_pass) begin
                total_elements <= elem_count_src;
                element_index  <= 16'd0;
            end

            case (state)
                STATE_READ_SRC_META_ADDR:   read_addr_reg <= matrix_src_base;
                STATE_READ_SCLR_META_ADDR:  read_addr_reg <= matrix_scalar_base;
                STATE_READ_SCLR_DATA_ADDR:  read_addr_reg <= matrix_scalar_base + META_OFFSET;
                STATE_PREPARE_SRC_ADDR:     read_addr_reg <= matrix_src_data_addr;
                default: begin end
            endcase

            if (state == STATE_READ_SRC_META_WAIT) begin
                shape_src <= decode_shape_word(data_out);
            end

            if (state == STATE_READ_SCLR_META_WAIT) begin
                shape_scalar <= decode_shape_word(data_out);
            end

            if (state == STATE_READ_SCLR_DATA_WAIT) begin
                scalar_word <= data_out;
            end

            if (state == STATE_WAIT_SRC_DATA) begin
                operand_src_word <= data_out;
            end

            if (state == STATE_WRITE_DATA && writer_ready) begin
                element_index <= element_index + 16'd1;
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
                if (!is_valid_operand_id(matrix_src_id_lat) ||
                    !is_valid_operand_id(matrix_scalar_id_lat)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_ID;
                    state_next   = STATE_DONE;
                end else begin
                    state_next = STATE_READ_SRC_META_ADDR;
                end
            end

            STATE_READ_SRC_META_ADDR:  state_next = STATE_READ_SRC_META_WAIT;
            STATE_READ_SRC_META_WAIT:  state_next = STATE_READ_SCLR_META_ADDR;
            STATE_READ_SCLR_META_ADDR: state_next = STATE_READ_SCLR_META_WAIT;
            STATE_READ_SCLR_META_WAIT: state_next = STATE_VALIDATE;

            STATE_VALIDATE: begin
                if (elem_count_src == 16'd0 ||
                    shape_src.rows == 8'd0 || shape_src.cols == 8'd0) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_EMPTY;
                    state_next   = STATE_DONE;
                end else if (!is_data_capacity_ok(elem_count_src) ||
                             !is_data_capacity_ok(elem_count_scalar)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_FORMAT;
                    state_next   = STATE_DONE;
                end else if (!(shape_scalar.rows == 8'd1 && shape_scalar.cols == 8'd1)) begin
                    set_status   = 1'b1;
                    status_value = MATRIX_OP_STATUS_ERR_DIM;
                    state_next   = STATE_DONE;
                end else begin
                    validation_pass = 1'b1;
                    state_next      = STATE_READ_SCLR_DATA_ADDR;
                end
            end

            STATE_READ_SCLR_DATA_ADDR: state_next = STATE_READ_SCLR_DATA_WAIT;
            STATE_READ_SCLR_DATA_WAIT: state_next = STATE_WAIT_WRITE_READY;

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
                    state_next = STATE_PREPARE_SRC_ADDR;
                end
            end

            STATE_PREPARE_SRC_ADDR: state_next = STATE_WAIT_SRC_DATA;
            STATE_WAIT_SRC_DATA:    state_next = STATE_WRITE_DATA;

            STATE_WRITE_DATA: begin
                if (writer_ready) begin
                    state_next = STATE_CHECK_NEXT;
                end
            end

            STATE_CHECK_NEXT: begin
                if (element_index >= total_elements) begin
                    state_next = STATE_WAIT_WRITE_DONE;
                end else begin
                    state_next = STATE_PREPARE_SRC_ADDR;
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