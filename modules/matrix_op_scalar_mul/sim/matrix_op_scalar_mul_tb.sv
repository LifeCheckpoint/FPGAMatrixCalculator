`timescale 1ns/1ps

import matrix_op_defs_pkg::*;

module matrix_op_scalar_mul_tb;

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
    logic [2:0]               matrix_src_id;
    logic [2:0]               matrix_scalar_id;
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
    logic [7:0]              name_src     [0:7];
    logic [7:0]              name_scalar  [0:7];
    logic [7:0]              name_bad     [0:7];
    logic [DATA_WIDTH-1:0]   src_matrix   [0:3];
    logic [DATA_WIDTH-1:0]   scalar_one   [0:0];
    logic [DATA_WIDTH-1:0]   scalar_three [0:0];
    logic [DATA_WIDTH-1:0]   bad_scalar   [0:3];
    logic [DATA_WIDTH-1:0]   expected_result [0:3];

    // Memory model
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Writer stub
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

    // DUT
    matrix_op_scalar_mul dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_src_id(matrix_src_id),
        .matrix_scalar_id(matrix_scalar_id),
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
            for (int nb = 0; nb < 8; nb++) writer_name[nb] <= 8'h00;
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
                        for (int nb = 0; nb < 8; nb++) writer_name[nb] <= matrix_name[nb];
                        writer_expected_words <= actual_rows * actual_cols;
                        writer_state          <= WR_META_0;
                    end
                end
                WR_META_0: begin
                    mem[writer_base_addr + 0] <= {writer_rows, writer_cols, 16'h0};
                    writer_state <= WR_META_1;
                end
                WR_META_1: begin
                    mem[writer_base_addr + 1] <= {writer_name[0], writer_name[1], writer_name[2], writer_name[3]};
                    writer_state <= WR_META_2;
                end
                WR_META_2: begin
                    mem[writer_base_addr + 2] <= {writer_name[4], writer_name[5], writer_name[6], writer_name[7]};
                    writer_state <= (writer_expected_words == 0) ? WR_DONE : WR_STREAM;
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

    // Helpers
    function automatic int base_addr(input int id);
        return id * BLOCK_SIZE;
    endfunction

    task automatic clear_memory();
        for (int idx = 0; idx < MEM_DEPTH; idx++) mem[idx] = '0;
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
        $display("[LOG][SCL][%s] Matrix ID=%0d (%0dx%0d)", tag, id, rows, cols);
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
                $error("[FAIL][SCL][%s] mismatch @idx %0d expected=%0d actual=%0d", tag, i, expected[i], actual);
            end
        end
        log_matrix({tag, "_out"}, 3'd0, rows, cols);
    endtask

    task automatic run_case_success(
        input string tag,
        input logic [2:0] id_src,
        input logic [2:0] id_scalar,
        input int rows,
        input int cols,
        input logic [DATA_WIDTH-1:0] expected []
    );
        $display("[CASE][SCL][%s] START src=%0d scalar=%0d -> %0dx%0d", tag, id_src, id_scalar, rows, cols);
        log_matrix({tag, "_src"}, id_src, rows, cols);
        log_matrix({tag, "_scalar"}, id_scalar, 1, 1);

        matrix_src_id    <= id_src;
        matrix_scalar_id <= id_scalar;
        start            <= 1'b1;
        @(posedge clk);
        start            <= 1'b0;

        wait (busy);
        wait (!busy);

        if (status != MATRIX_OP_STATUS_SUCCESS) begin
            $error("[FAIL][SCL][%s] expected SUCCESS but got %0d", tag, status);
        end else begin
            $display("[PASS][SCL][%s] status=SUCCESS", tag);
            compare_result(tag, rows, cols, expected);
        end
        repeat (4) @(posedge clk);
    endtask

    task automatic run_case_error(
        input string tag,
        input logic [2:0] id_src,
        input logic [2:0] id_scalar,
        input matrix_op_status_e expected_status
    );
        $display("[CASE][SCL][%s] START expect status %0d (src=%0d scalar=%0d)", tag, expected_status, id_src, id_scalar);
        matrix_src_id    <= id_src;
        matrix_scalar_id <= id_scalar;
        start            <= 1'b1;
        @(posedge clk);
        start            <= 1'b0;

        wait (busy);
        wait (!busy);

        if (status != expected_status) begin
            $error("[FAIL][SCL][%s] expected %0d but got %0d", tag, expected_status, status);
        end else begin
            $display("[PASS][SCL][%s] observed expected status %0d", tag, status);
        end
        repeat (4) @(posedge clk);
    endtask

    // Test stimulus
    initial begin
        clear_memory();
        start            = 1'b0;
        matrix_src_id    = 3'd0;
        matrix_scalar_id = 3'd0;

        repeat (6) @(posedge clk);
        rst_n = 1;
        repeat (6) @(posedge clk);

        name_src    = '{8'h53,8'h52,8'h43,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_scalar = '{8'h53,8'h43,8'h4c,8'h00,8'h00,8'h00,8'h00,8'h00};
        name_bad    = '{8'h42,8'h41,8'h44,8'h00,8'h00,8'h00,8'h00,8'h00};

        src_matrix    = '{32'd1,32'd2,32'd3,32'd4};
        scalar_one    = '{32'd1};
        scalar_three  = '{32'd3};
        bad_scalar    = '{32'd5,32'd6,32'd7,32'd8}; // not 1x1

        expected_result = '{32'd3,32'd6,32'd9,32'd12};

        load_matrix(3'd1, 2, 2, name_src, src_matrix);
        load_matrix(3'd2, 1, 1, name_scalar, scalar_one);
        load_matrix(3'd3, 1, 1, name_scalar, scalar_three);
        load_matrix(3'd4, 2, 2, name_bad, bad_scalar);

        run_case_success("scalar_mul_by_3", 3'd1, 3'd3, 2, 2, expected_result);
        run_case_success("scalar_mul_by_1", 3'd1, 3'd2, 2, 2, src_matrix);

        run_case_error("invalid_scalar_dim", 3'd1, 3'd4, MATRIX_OP_STATUS_ERR_DIM);
        run_case_error("invalid_id", 3'd0, 3'd2, MATRIX_OP_STATUS_ERR_ID);

        $display("[INFO][SCL] All testcases finished.");
        $finish;
    end

endmodule