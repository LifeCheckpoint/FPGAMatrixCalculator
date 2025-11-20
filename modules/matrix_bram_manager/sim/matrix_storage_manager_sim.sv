`timescale 1ns/1ps

module matrix_storage_manager_sim;

    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 14;
    localparam BLOCK_SIZE = 1152;

    logic clk = 0;
    logic rst_n;
    logic write_request;
    logic write_ready;
    logic [2:0] matrix_id;
    logic [7:0] actual_rows;
    logic [7:0] actual_cols;
    logic [7:0] matrix_name [0:7];
    logic [DATA_WIDTH-1:0] data_in;
    logic data_valid;
    logic write_done;
    logic writer_ready;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [DATA_WIDTH-1:0] data_out;

    logic [DATA_WIDTH-1:0] payload [0:3];
    logic [DATA_WIDTH-1:0] expected_words [0:6];

    matrix_storage_manager #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_request(write_request),
        .write_ready(write_ready),
        .matrix_id(matrix_id),
        .actual_rows(actual_rows),
        .actual_cols(actual_cols),
        .matrix_name(matrix_name),
        .data_in(data_in),
        .data_valid(data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        .read_addr(read_addr),
        .data_out(data_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin : stimulus
        int idx;
        rst_n = 0;
        write_request = 0;
        data_valid = 0;
        data_in = '0;
        matrix_id = 3'd0;
        actual_rows = 8'd2;
        actual_cols = 8'd2;
        read_addr = '0;

        matrix_name[0] = "M";
        matrix_name[1] = "A";
        matrix_name[2] = "T";
        matrix_name[3] = "R";
        matrix_name[4] = "I";
        matrix_name[5] = "X";
        matrix_name[6] = "0";
        matrix_name[7] = "1";

        payload[0] = 32'h3f800000; // 1.0
        payload[1] = 32'h40000000; // 2.0
        payload[2] = 32'h40400000; // 3.0
        payload[3] = 32'h40800000; // 4.0

        update_expected_words();

        repeat (4) @(posedge clk);
        rst_n = 1;

        wait (write_ready == 1'b1);
        @(posedge clk);
        write_request <= 1'b1;
        @(posedge clk);
        write_request <= 1'b0;

        wait (writer_ready && !write_ready);
        idx = 0;
        while (idx < 4) begin
            @(posedge clk);
            if (writer_ready && !write_ready) begin
                data_in <= payload[idx];
                data_valid <= 1'b1;
                $display("[INFO] %0t : driving data[%0d] = 0x%08h", $time, idx, payload[idx]);
                idx++;
            end else begin
                data_valid <= 1'b0;
                data_in <= '0;
            end
        end
        @(posedge clk);
        data_valid <= 1'b0;
        data_in <= '0;

        wait (write_done);
        $display("[INFO] %0t : write_done observed", $time);

        for (int addr = 0; addr < 7; addr++) begin
            string label;
            case (addr)
                0: label = "rows_cols_word";
                1: label = "name_high_word";
                2: label = "name_low_word";
                default: label = $sformatf("data_word[%0d]", addr - 3);
            endcase
            expect_read(addr[ADDR_WIDTH-1:0], expected_words[addr], label);
        end

        $display("[INFO] Simulation completed successfully");
        repeat (4) @(posedge clk);
        $finish;
    end

    task automatic update_expected_words;
        expected_words[0] = {actual_rows, actual_cols, 16'h0000};
        expected_words[1] = {matrix_name[0], matrix_name[1], matrix_name[2], matrix_name[3]};
        expected_words[2] = {matrix_name[4], matrix_name[5], matrix_name[6], matrix_name[7]};
        for (int i = 0; i < 4; i++) begin
            expected_words[3 + i] = payload[i];
        end
    endtask

    task automatic expect_read(
        input  [ADDR_WIDTH-1:0] addr,
        input  [DATA_WIDTH-1:0] expected,
        input  string           label
    );
        read_addr <= addr;
        @(posedge clk);
        @(posedge clk); // BRAM read latency
        if (data_out !== expected) begin
            $display("[FAIL] %s @0x%0h : expected 0x%08h, actual 0x%08h", label, addr, expected, data_out);
        end else begin
            $display("[PASS] %s @0x%0h : expected 0x%08h, actual 0x%08h", label, addr, expected, data_out);
        end
    endtask

endmodule