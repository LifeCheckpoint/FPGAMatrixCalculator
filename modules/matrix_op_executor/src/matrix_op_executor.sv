`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;
import matrix_op_defs_pkg::*;

module matrix_op_executor #(
    parameter int BLOCK_SIZE = MATRIX_BLOCK_SIZE,
    parameter int ADDR_WIDTH = MATRIX_ADDR_WIDTH,
    parameter int DATA_WIDTH = MATRIX_DATA_WIDTH,
    parameter int SCALAR_TEMP_ID = 7
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control Interface (from matrix_op_selector)
    input  logic                  start,
    input  calc_type_t            op_type,
    input  logic [2:0]            matrix_a,
    input  logic [2:0]            matrix_b,
    input  logic [31:0]           scalar_in,
    
    // Status Output
    output logic                  busy,
    output logic                  done,
    
    // BRAM Read Interface
    output logic [ADDR_WIDTH-1:0] bram_read_addr,
    input  logic [DATA_WIDTH-1:0] bram_data_out,
    
    // Storage Manager Write Interface
    output logic                  write_request,
    input  logic                  write_ready,
    output logic [2:0]            write_matrix_id,
    output logic [7:0]            write_rows,
    output logic [7:0]            write_cols,
    output logic [7:0]            write_name [0:7],
    output logic [DATA_WIDTH-1:0] write_data,
    output logic                  write_data_valid,
    input  logic                  writer_ready,
    input  logic                  write_done,
    output logic [31:0]           cycle_count
);

    // Internal States
    typedef enum logic [3:0] {
        STATE_IDLE,
        STATE_PREPARE_SCALAR_REQ,
        STATE_PREPARE_SCALAR_WAIT_ENABLE,
        STATE_PREPARE_SCALAR_WRITE,
        STATE_PREPARE_SCALAR_WAIT_DONE,
        STATE_EXECUTE_START,
        STATE_EXECUTE_WAIT,
        STATE_DONE
    } state_t;

    state_t state;

    // Latched Inputs
    calc_type_t latched_op;
    calc_type_t latched_op_mux; // Duplicate for MUX control to reduce fanout
    logic [2:0] latched_matrix_a;
    logic [2:0] latched_matrix_b;
    logic [31:0] latched_scalar;

    // Submodule Signals
    logic op_add_start, op_add_busy;
    logic op_mul_start, op_mul_busy;
    logic op_scalar_start, op_scalar_busy;
    logic op_t_start, op_t_busy;
    logic op_conv_start, op_conv_busy;
    logic [31:0] op_conv_cycle_count;

    matrix_op_status_e op_add_status;
    matrix_op_status_e op_mul_status;
    matrix_op_status_e op_scalar_status;
    matrix_op_status_e op_t_status;
    matrix_op_status_e op_conv_status;

    logic [ADDR_WIDTH-1:0] op_add_addr, op_mul_addr, op_scalar_addr, op_t_addr, op_conv_addr;
    
    logic op_add_req, op_mul_req, op_scalar_req, op_t_req, op_conv_req;
    logic [2:0] op_add_id, op_mul_id, op_scalar_id, op_t_id, op_conv_id;
    logic [7:0] op_add_rows, op_mul_rows, op_scalar_rows, op_t_rows, op_conv_rows;
    logic [7:0] op_add_cols, op_mul_cols, op_scalar_cols, op_t_cols, op_conv_cols;
    logic [7:0] op_add_name[8], op_mul_name[8], op_scalar_name[8], op_t_name[8], op_conv_name[8];
    logic [DATA_WIDTH-1:0] op_add_data, op_mul_data, op_scalar_data, op_t_data, op_conv_data;
    logic op_add_valid, op_mul_valid, op_scalar_valid, op_t_valid, op_conv_valid;

    // Scalar Writer Signals
    logic scalar_writer_req;
    logic scalar_writer_valid;
    logic [7:0] scalar_name [0:7];

    // Internal Status Signals (Combinatorial)
    logic current_busy;
    matrix_op_status_e current_status;

    assign scalar_name[0] = "S";
    assign scalar_name[1] = "C";
    assign scalar_name[2] = "A";
    assign scalar_name[3] = "L";
    assign scalar_name[4] = "A";
    assign scalar_name[5] = "R";
    assign scalar_name[6] = 0;
    assign scalar_name[7] = 0;

    //-------------------------------------------------------------------------
    // Submodule Instantiations
    //-------------------------------------------------------------------------

    matrix_op_add #(
        .BLOCK_SIZE(BLOCK_SIZE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_op_add (
        .clk(clk), .rst_n(rst_n),
        .start(op_add_start),
        .matrix_a_id(latched_matrix_a),
        .matrix_b_id(latched_matrix_b),
        .busy(op_add_busy),
        .status(op_add_status),
        .read_addr(op_add_addr),
        .data_out(bram_data_out),
        .write_request(op_add_req),
        .write_ready(write_ready), // Shared
        .matrix_id(op_add_id),
        .actual_rows(op_add_rows),
        .actual_cols(op_add_cols),
        .matrix_name(op_add_name),
        .data_in(op_add_data),
        .data_valid(op_add_valid),
        .writer_ready(writer_ready), // Shared
        .write_done(write_done)      // Shared
    );

    matrix_op_mul #(
        .BLOCK_SIZE(BLOCK_SIZE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_op_mul (
        .clk(clk), .rst_n(rst_n),
        .start(op_mul_start),
        .matrix_a_id(latched_matrix_a),
        .matrix_b_id(latched_matrix_b),
        .busy(op_mul_busy),
        .status(op_mul_status),
        .read_addr(op_mul_addr),
        .data_out(bram_data_out),
        .write_request(op_mul_req),
        .write_ready(write_ready),
        .matrix_id(op_mul_id),
        .actual_rows(op_mul_rows),
        .actual_cols(op_mul_cols),
        .matrix_name(op_mul_name),
        .data_in(op_mul_data),
        .data_valid(op_mul_valid),
        .writer_ready(writer_ready),
        .write_done(write_done)
    );

    matrix_op_scalar_mul #(
        .BLOCK_SIZE(BLOCK_SIZE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_op_scalar (
        .clk(clk), .rst_n(rst_n),
        .start(op_scalar_start),
        .matrix_src_id(latched_matrix_a),
        .matrix_scalar_id(3'(SCALAR_TEMP_ID)), // Use the temp matrix ID
        .busy(op_scalar_busy),
        .status(op_scalar_status),
        .read_addr(op_scalar_addr),
        .data_out(bram_data_out),
        .write_request(op_scalar_req),
        .write_ready(write_ready),
        .matrix_id(op_scalar_id),
        .actual_rows(op_scalar_rows),
        .actual_cols(op_scalar_cols),
        .matrix_name(op_scalar_name),
        .data_in(op_scalar_data),
        .data_valid(op_scalar_valid),
        .writer_ready(writer_ready),
        .write_done(write_done)
    );

    matrix_op_T #(
        .BLOCK_SIZE(BLOCK_SIZE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_op_t (
        .clk(clk), .rst_n(rst_n),
        .start(op_t_start),
        .matrix_src_id(latched_matrix_a),
        .busy(op_t_busy),
        .status(op_t_status),
        .read_addr(op_t_addr),
        .data_out(bram_data_out),
        .write_request(op_t_req),
        .write_ready(write_ready),
        .matrix_id(op_t_id),
        .actual_rows(op_t_rows),
        .actual_cols(op_t_cols),
        .matrix_name(op_t_name),
        .data_in(op_t_data),
        .data_valid(op_t_valid),
        .writer_ready(writer_ready),
        .write_done(write_done)
    );

    matrix_op_conv #(
        .BLOCK_SIZE(BLOCK_SIZE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_op_conv (
        .clk(clk), .rst_n(rst_n),
        .start(op_conv_start),
        .matrix_src_id(latched_matrix_a),
        .busy(op_conv_busy),
        .status(op_conv_status),
        .read_addr(op_conv_addr),
        .data_out(bram_data_out),
        .write_request(op_conv_req),
        .write_ready(write_ready),
        .matrix_id(op_conv_id),
        .actual_rows(op_conv_rows),
        .actual_cols(op_conv_cols),
        .matrix_name(op_conv_name),
        .data_in(op_conv_data),
        .data_valid(op_conv_valid),
        .writer_ready(writer_ready),
        .write_done(write_done),
        .cycle_count(op_conv_cycle_count)
    );

    //-------------------------------------------------------------------------
    // Main FSM
    //-------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            latched_op <= CALC_ADD;
            latched_matrix_a <= 0;
            latched_matrix_b <= 0;
            latched_scalar <= 0;
            op_add_start <= 0;
            op_mul_start <= 0;
            op_scalar_start <= 0;
            op_t_start <= 0;
            op_conv_start <= 0;
            scalar_writer_req <= 0;
            scalar_writer_valid <= 0;
            done <= 0;
        end else begin
            // Default pulses
            op_add_start <= 0;
            op_mul_start <= 0;
            op_scalar_start <= 0;
            op_t_start <= 0;
            op_conv_start <= 0;
            done <= 0;

            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        latched_op <= op_type;
                        latched_op_mux <= op_type;
                        latched_matrix_a <= matrix_a;
                        latched_matrix_b <= matrix_b;
                        latched_scalar <= scalar_in;
                        
                        if (op_type == CALC_SCALAR_MUL) begin
                            state <= STATE_PREPARE_SCALAR_REQ;
                        end else begin
                            state <= STATE_EXECUTE_START;
                        end
                    end
                end

                // --- Scalar Writer Sequence ---
                STATE_PREPARE_SCALAR_REQ: begin
                    if (write_ready) begin
                        scalar_writer_req <= 1;
                        state <= STATE_PREPARE_SCALAR_WAIT_ENABLE;
                    end
                end

                STATE_PREPARE_SCALAR_WAIT_ENABLE: begin
                    scalar_writer_req <= 0; // Pulse request? Or hold? 
                    // matrix_writer usually expects request held until ready? 
                    // Let's check matrix_writer. It says "write_request" is input.
                    // matrix_op_add holds it until writer_ready.
                    // Let's hold it.
                    scalar_writer_req <= 1;
                    
                    if (writer_ready) begin
                        scalar_writer_req <= 0; // Deassert once enabled
                        state <= STATE_PREPARE_SCALAR_WRITE;
                    end
                end

                STATE_PREPARE_SCALAR_WRITE: begin
                    if (writer_ready) begin
                        scalar_writer_valid <= 1;
                        state <= STATE_PREPARE_SCALAR_WAIT_DONE;
                    end
                end

                STATE_PREPARE_SCALAR_WAIT_DONE: begin
                    scalar_writer_valid <= 0;
                    if (write_done) begin
                        state <= STATE_EXECUTE_START;
                    end
                end

                // --- Execution Sequence ---
                STATE_EXECUTE_START: begin
                    case (latched_op)
                        CALC_ADD:        op_add_start <= 1;
                        CALC_MUL:        op_mul_start <= 1;
                        CALC_SCALAR_MUL: op_scalar_start <= 1;
                        CALC_TRANSPOSE:  op_t_start <= 1;
                        CALC_CONV:       op_conv_start <= 1;
                    endcase
                    state <= STATE_EXECUTE_WAIT;
                end

                STATE_EXECUTE_WAIT: begin
                    // Wait for completion based on status
                    if (current_status != MATRIX_OP_STATUS_IDLE && current_status != MATRIX_OP_STATUS_BUSY) begin
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    done <= 1;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    assign busy = (state != STATE_IDLE);

    //-------------------------------------------------------------------------
    // Status Multiplexing
    //-------------------------------------------------------------------------
    always_comb begin
        case (latched_op_mux)
            CALC_ADD: begin
                current_busy = op_add_busy;
                current_status = op_add_status;
            end
            CALC_MUL: begin
                current_busy = op_mul_busy;
                current_status = op_mul_status;
            end
            CALC_SCALAR_MUL: begin
                current_busy = op_scalar_busy;
                current_status = op_scalar_status;
            end
            CALC_TRANSPOSE: begin
                current_busy = op_t_busy;
                current_status = op_t_status;
            end
            CALC_CONV: begin
                current_busy = op_conv_busy;
                current_status = op_conv_status;
            end
            default: begin
                current_busy = 0;
                current_status = MATRIX_OP_STATUS_IDLE;
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // Output Multiplexing
    //-------------------------------------------------------------------------

    assign cycle_count = (latched_op_mux == CALC_CONV) ? op_conv_cycle_count : 32'd0;

    always_comb begin
        // Default assignments
        bram_read_addr = 0;
        write_request = 0;
        write_matrix_id = 0;
        write_rows = 0;
        write_cols = 0;
        write_data = 0;
        write_data_valid = 0;
        
        // Name muxing is tricky with arrays, handle separately
        
        if (state == STATE_PREPARE_SCALAR_REQ ||
            state == STATE_PREPARE_SCALAR_WAIT_ENABLE ||
            state == STATE_PREPARE_SCALAR_WRITE ||
            state == STATE_PREPARE_SCALAR_WAIT_DONE) begin
            
            // Scalar Writer Control
            write_request = scalar_writer_req;
            write_matrix_id = 3'(SCALAR_TEMP_ID);
            write_rows = 1;
            write_cols = 1;
            write_data = latched_scalar;
            write_data_valid = scalar_writer_valid;
            
        end else begin
            // Op Module Control
            case (latched_op_mux)
                CALC_ADD: begin
                    bram_read_addr = op_add_addr;
                    write_request = op_add_req;
                    write_matrix_id = op_add_id;
                    write_rows = op_add_rows;
                    write_cols = op_add_cols;
                    write_data = op_add_data;
                    write_data_valid = op_add_valid;
                end
                CALC_MUL: begin
                    bram_read_addr = op_mul_addr;
                    write_request = op_mul_req;
                    write_matrix_id = op_mul_id;
                    write_rows = op_mul_rows;
                    write_cols = op_mul_cols;
                    write_data = op_mul_data;
                    write_data_valid = op_mul_valid;
                end
                CALC_SCALAR_MUL: begin
                    bram_read_addr = op_scalar_addr;
                    write_request = op_scalar_req;
                    write_matrix_id = op_scalar_id;
                    write_rows = op_scalar_rows;
                    write_cols = op_scalar_cols;
                    write_data = op_scalar_data;
                    write_data_valid = op_scalar_valid;
                end
                CALC_TRANSPOSE: begin
                    bram_read_addr = op_t_addr;
                    write_request = op_t_req;
                    write_matrix_id = op_t_id;
                    write_rows = op_t_rows;
                    write_cols = op_t_cols;
                    write_data = op_t_data;
                    write_data_valid = op_t_valid;
                end
                CALC_CONV: begin
                    bram_read_addr = op_conv_addr;
                    write_request = op_conv_req;
                    write_matrix_id = op_conv_id;
                    write_rows = op_conv_rows;
                    write_cols = op_conv_cols;
                    write_data = op_conv_data;
                    write_data_valid = op_conv_valid;
                end
            endcase
        end
    end

    // Name Muxing
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_name_mux
            always_comb begin
                if (state == STATE_PREPARE_SCALAR_REQ ||
                    state == STATE_PREPARE_SCALAR_WAIT_ENABLE ||
                    state == STATE_PREPARE_SCALAR_WRITE ||
                    state == STATE_PREPARE_SCALAR_WAIT_DONE) begin
                    write_name[i] = scalar_name[i];
                end else begin
                    case (latched_op_mux)
                        CALC_ADD:        write_name[i] = op_add_name[i];
                        CALC_MUL:        write_name[i] = op_mul_name[i];
                        CALC_SCALAR_MUL: write_name[i] = op_scalar_name[i];
                        CALC_TRANSPOSE:  write_name[i] = op_t_name[i];
                        CALC_CONV:       write_name[i] = op_conv_name[i];
                        default:         write_name[i] = 0;
                    endcase
                end
            end
        end
    endgenerate

endmodule
