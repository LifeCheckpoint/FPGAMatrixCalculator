`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_mul_tb;

    localparam int DATA_WIDTH = MATRIX_DATA_WIDTH;
    localparam int ADDR_WIDTH = MATRIX_ADDR_WIDTH;
    localparam int BLOCK_SIZE = MATRIX_BLOCK_SIZE;
    localparam int TOTAL_MATRIX_COUNT = 8;
    localparam int MEM_DEPTH = BLOCK_SIZE * TOTAL_MATRIX_COUNT;
    localparam time CLK_PERIOD = 10ns;

    logic clk = 0;
    logic rst_n = 0;

    // DUT interface
    logic                     start;
    logic [2:0]               matrix_a_id;
    logic [2:0]               matrix_b_id;
    logic                     busy;
    matrix_op_status_e        status;

    logic [ADDR_WIDTH-1:0]    read_addr;
    logic [DATA_WIDTH-1:0]    data_out;

    logic                     write_request;
    logic                     write_ready;
    logic [2:0]               matrix_id;
    logic [7:0]               actual_rows;
    logic [7:0]               actual_cols;
    logic [7:0]               matrix_name [0:7];
    logic [DATA_WIDTH-1:0]    data_in;
    logic                     data_valid;
    logic                     writer_ready;
    logic                     write_done;

    // Stimulus storage
    logic [7:0]              name_A          [0:7];
    logic [7:0]              name_B          [0:7];
    logic [7:0]              name_C          [0:7];
    logic [7:0]              name_D          [0:7];
    logic [7:0]              name_E          [0:7];
    logic [7:0]              name_F          [0:7];
    logic [DATA_WIDTH-1:0]   A23             [0:5];
    logic [DATA_WIDTH-1:0]   B32             [0:5];
    logic [DATA_WIDTH-1:0]   C22             [0:3];
    logic [DATA_WIDTH-1:0]   D22             [0:3];
    logic [DATA_WIDTH-1:0]   E34             [0:11];
    logic [DATA_WIDTH-1:0]   F42             [0:7];
    logic [DATA_WIDTH-1:0]   expected_basic  [0:3];
    logic [DATA_WIDTH-1:0]   expected_small  [0:3];
    logic [DATA_WIDTH-1:0]   expected_rect   [0:5];

    // Simple BRAM model
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Writer stub FSM
    typedef enum logic [2:0] {
        WR_IDLE,
        WR_META_0,
        WR_META_1,
        WR_META_2,
        WR_STREAM,
        WR_DONE
    } writer_state_e;

    writer_state_e writer_state;
    logic [ADDR_WIDTH-1:0] writer_base_addr;
    logic [15:0]           writer_expected_words;
    logic [15:0]           writer_word_idx;
    logic [7:0]            writer_rows;
    logic [7:0]            writer_cols;
    logic [7:0]            writer_name [0:7];

    // Clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // DUT instance
    matrix_op_mul dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_a_id(matrix_a_id),
        .matrix_b_id(matrix_b_id),
        .busy(busy),
        .status(status),
        .read_addr(read_addr),
        .data_out(data_out),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(matrix_id),
        .actual_rows(actual_rows),
        .actual_cols(actual_cols),
        .matrix_name(matrix_name),
        .data_in(data_in),
        .data_valid(data_valid),
        .writer_ready(writer_ready),
        .write_done(write_done)
    );

    // Zero-latency combinational read to match DUT expectation
    always_comb begin
        data_out = mem[read_addr];
    end

    // Writer stub behavior
    wire writer_accept_data = (writer_state == WR_STREAM);
    assign write_ready  = (writer_state == WR_IDLE);
    assign writer_ready = writer_accept_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            writer_state          <= WR_IDLE;
            writer_base_addr      <= '0;
            writer_expected_words <= '0;
            writer_word_idx       <= '0;
            writer_rows           <= '0;
            writer_cols           <= '0;
            for (int nb = 0; nb < 8; nb++) begin
                writer_name[nb] <= 8'h00;
            end
            write_done <= 1'b0;
        end else begin
            write_done <= 1'b0;

            unique case (writer_state)
                WR_IDLE: begin
                    writer_word_idx <= 16'd0;
                    if (write_request && write_ready) begin
                        writer_base_addr      <= matrix_id * BLOCK_SIZE;
                        writer_rows           <= actual_rows;
                        writer_cols           <= actual_cols;
                        for (int nb = 0; nb < 8; nb++) begin
                            writer_name[nb] <= matrix_name[nb];
                        end
                        writer_expected_words <= actual_rows * actual_cols;
                        writer_state          <= WR_META_0;
                    end
                end

                WR_META_0: begin
                    mem[writer_base_addr + 0] <= {writer_rows, writer_cols, 16'h0000};
                    writer_state <= WR_META_1;
                end

                WR_META_1: begin
                    mem[writer_base_addr + 1] <= {writer_name[0], writer_name[1], writer_name[2], writer_name[3]};
                    writer_state <= WR_META_2;
                end

                WR_META_2: begin
                    mem[writer_base_addr + 2] <= {writer_name[4], writer_name[5], writer_name[6], writer_name[7]};
                    if (writer_expected_words == 0) begin
                        writer_state <= WR_DONE;
                    end else begin
                        writer_state <= WR_STREAM;
                    end
                end

                WR_STREAM: begin
                    if (data_valid) begin
                        mem[writer_base_addr + MATRIX_METADATA_WORDS + writer_word_idx] <= data_in;
                        writer_word_idx <= writer_word_idx + 16'd1;
                        if (writer_word_idx + 16'd1 >= writer_expected_words) begin
                            writer_state <= WR_DONE;
                        end
                    end
                end

                WR_DONE: begin
                    write_done   <= 1'b1;
                    writer_state <= WR_IDLE;
                end

                default: writer_state <= WR_IDLE;
            endcase
        end
    end

    // Utilities
    function automatic int base_addr(input int id);
        return id * BLOCK_SIZE;
    endfunction

    task automatic clear_memory();
        for (int idx = 0; idx < MEM_DEPTH; idx++) begin
            mem[idx] = '0;
        end
    endtask

    task automatic load_matrix(
        input logic [2:0] id,
        input int rows,
        input int cols,
        input logic [7:0] name_bytes [0:7],
        input logic [DATA_WIDTH-1:0] values []
    );
        int base = base_addr(id);
        mem[base + 0] = {rows[7:0], cols[7:0], 16'h0};
        mem[base + 1] = {name_bytes[0], name_bytes[1], name_bytes[2], name_bytes[3]};
        mem[base + 2] = {name_bytes[4], name_bytes[5], name_bytes[6], name_bytes[7]};
        for (int i = 0; i < rows*cols; i++) begin
            mem[base + MATRIX_METADATA_WORDS + i] = values[i];
        end
    endtask

    task automatic log_matrix(
        input string tag,
        input logic [2:0] id,
        input int rows,
        input int cols
    );
        int base = base_addr(id);
        $display("[LOG][MUL][%s] Matrix ID=%0d (%0dx%0d)", tag, id, rows, cols);
        for (int r = 0; r < rows; r++) begin
            string line = "";
            for (int c = 0; c < cols; c++) begin
                line = {line, $sformatf("%0d ", mem[base + MATRIX_METADATA_WORDS + r*cols + c])};
            end
            $display("    Row %0d -> %s", r, line);
        end
    endtask

    task automatic compare_result(
        input string tag,
        input int rows,
        input int cols,
        input logic [DATA_WIDTH-1:0] expected []
    );
        int base = base_addr(3'd0);
        for (int i = 0; i < rows*cols; i++) begin
            logic [DATA_WIDTH-1:0] actual = mem[base + MATRIX_METADATA_WORDS + i];
            if (actual !== expected[i]) begin
                $error("[FAIL][MUL][%s] mismatch @idx %0d expected=%0d actual=%0d", tag, i, expected[i], actual);
            end
        end
        log_matrix({tag, "_out"}, 3'd0, rows, cols);
    endtask

    task automatic run_case_success(
        input string tag,
        input logic [2:0] id_a,
        input logic [2:0] id_b,
        input int rows,
        input int cols,
        input int rows_a,
        input int cols_a,
        input int rows_b,
        input int cols_b,
        input logic [DATA_WIDTH-1:0] expected []
    );
        $display("[CASE][MUL][%s] START A=%0d (%0dx%0d) B=%0d (%0dx%0d) -> %0dx%0d",
                 tag, id_a, rows_a, cols_a, id_b, rows_b, cols_b, rows, cols);
        log_matrix({tag, "_A"}, id_a, rows_a, cols_a);
        log_matrix({tag, "_B"}, id_b, rows_b, cols_b);

        matrix_a_id <= id_a;
        matrix_b_id <= id_b;
        start       <= 1'b1;
        @(posedge clk);
        start       <= 1'b0;

        wait (busy);
        wait (!busy);

        if (status != MATRIX_OP_STATUS_SUCCESS) begin
            $error("[FAIL][MUL][%s] expected SUCCESS but got %0d", tag, status);
        end else begin
            $display("[PASS][MUL][%s] status=SUCCESS", tag);
            compare_result(tag, rows, cols, expected);
        end
        repeat (5) @(posedge clk);
    endtask

    task automatic run_case_error(
        input string tag,
        input logic [2:0] id_a,
        input logic [2:0] id_b,
        input matrix_op_status_e expected_status
    );
        $display("[CASE][MUL][%s] START expect status %0d (A=%0d, B=%0d)", tag, expected_status, id_a, id_b);
        matrix_a_id <= id_a;
        matrix_b_id <= id_b;
        start       <= 1'b1;
        @(posedge clk);
        start       <= 1'b0;

        wait (busy);
        wait (!busy);

        if (status != expected_status) begin
            $error("[FAIL][MUL][%s] expected %0d but got %0d", tag, expected_status, status);
        end else begin
            $display("[PASS][MUL][%s] observed expected status %0d", tag, status);
        end
        repeat (5) @(posedge clk);
    endtask

    // Test stimulus
    initial begin
        clear_memory();
        start       = 1'b0;
        matrix_a_id = 3'd0;
        matrix_b_id = 3'd0;

        repeat (6) @(posedge clk);
        rst_n = 1;
        repeat (6) @(posedge clk);

        // Prepare matrices
        name_A = '{8'h41,8'h5f,8'h41,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_B = '{8'h42,8'h5f,8'h42,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_C = '{8'h43,8'h5f,8'h43,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_D = '{8'h44,8'h5f,8'h44,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_E = '{8'h45,8'h5f,8'h52,8'h30,8'h00,8'h00,8'h00,8'h00}; // "E_R0"
        name_F = '{8'h46,8'h5f,8'h52,8'h31,8'h00,8'h00,8'h00,8'h00}; // "F_R1"

        A23 = '{32'd1,32'd2,32'd3,32'd4,32'd5,32'd6};
        B32 = '{32'd7,32'd8,32'd9,32'd10,32'd11,32'd12};
        expected_basic = '{
            32'd58, 32'd64,
            32'd139,32'd154
        };

        C22 = '{32'd2,32'd0,32'shFFFF_FFFF,32'd3};
        D22 = '{32'd4,32'd1,32'd5,32'd2};
        expected_small = '{
            32'd8,  32'd2,
            32'd11, 32'd5
        };

        E34 = '{
            32'd1, 32'd2, 32'd3, 32'd4,
            32'd5, 32'd6, 32'd7, 32'd8,
            32'd9, 32'd10,32'd11,32'd12
        };
        F42 = '{
            32'd1, 32'd2,
            32'd0, 32'd1,
            32'd2, 32'd0,
            32'd1, 32'd1
        };
        expected_rect = '{
            32'd11, 32'd8,
            32'd27, 32'd24,
            32'd43, 32'd40
        };

        load_matrix(3'd1, 2, 3, name_A, A23);
        load_matrix(3'd2, 3, 2, name_B, B32);
        load_matrix(3'd3, 2, 2, name_C, C22);
        load_matrix(3'd4, 2, 2, name_D, D22);
        load_matrix(3'd5, 3, 4, name_E, E34);
        load_matrix(3'd6, 4, 2, name_F, F42);

        run_case_success("mul_basic_2x3x3x2", 3'd1, 3'd2, 2, 2, 2, 3, 3, 2, expected_basic);
        run_case_success("mul_1x1", 3'd3, 3'd4, 2, 2, 2, 2, 2, 2, expected_small);
        run_case_success("mul_rect_3x4x4x2", 3'd5, 3'd6, 3, 2, 3, 4, 4, 2, expected_rect);

        run_case_error("dim_mismatch_cols_rows", 3'd1, 3'd3, MATRIX_OP_STATUS_ERR_DIM);
        run_case_error("invalid_operand_id", 3'd0, 3'd2, MATRIX_OP_STATUS_ERR_ID);

        $display("[INFO][MUL] All testcases finished.");
        $finish;
    end

endmodule