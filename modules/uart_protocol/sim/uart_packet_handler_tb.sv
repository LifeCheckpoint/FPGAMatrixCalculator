`timescale 1ns / 1ps

module uart_packet_handler_tb;

    // ------------------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    localparam CLK_PERIOD = 10ns;

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    // ------------------------------------------------------------------------
    // DUT connections
    // ------------------------------------------------------------------------
    logic [7:0] rx_byte;
    logic       rx_byte_valid;
    logic       rx_byte_ready;

    logic       pkt_meta_valid;
    logic       pkt_meta_ready;
    logic [7:0] pkt_cmd;
    logic [15:0] pkt_length;
    logic [1:0] pkt_error;

    logic [7:0] pkt_payload_data;
    logic       pkt_payload_valid;
    logic       pkt_payload_last;
    logic       pkt_payload_ready;

    logic       tx_meta_valid;
    logic       tx_meta_ready;
    logic [7:0] tx_cmd;
    logic [15:0] tx_length;

    logic [7:0] tx_payload_data;
    logic       tx_payload_valid;
    logic       tx_payload_last;
    logic       tx_payload_ready;

    logic [7:0] tx_byte;
    logic       tx_byte_valid;
    logic       tx_byte_ready;

    uart_packet_handler #(
        .MAX_PAYLOAD_BYTES(64)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_byte(rx_byte),
        .rx_byte_valid(rx_byte_valid),
        .rx_byte_ready(rx_byte_ready),
        .pkt_meta_valid(pkt_meta_valid),
        .pkt_meta_ready(pkt_meta_ready),
        .pkt_cmd(pkt_cmd),
        .pkt_length(pkt_length),
        .pkt_error(pkt_error),
        .pkt_payload_data(pkt_payload_data),
        .pkt_payload_valid(pkt_payload_valid),
        .pkt_payload_last(pkt_payload_last),
        .pkt_payload_ready(pkt_payload_ready),
        .tx_meta_valid(tx_meta_valid),
        .tx_meta_ready(tx_meta_ready),
        .tx_cmd(tx_cmd),
        .tx_length(tx_length),
        .tx_payload_data(tx_payload_data),
        .tx_payload_valid(tx_payload_valid),
        .tx_payload_last(tx_payload_last),
        .tx_payload_ready(tx_payload_ready),
        .tx_byte(tx_byte),
        .tx_byte_valid(tx_byte_valid),
        .tx_byte_ready(tx_byte_ready)
    );

    // ------------------------------------------------------------------------
    // Helper tasks / functions
    // ------------------------------------------------------------------------
    typedef byte unsigned byte_t;

    function automatic byte_t calc_checksum(
        input byte_t cmd,
        input byte_t len_l,
        input byte_t len_h,
        input byte_t payload[]
    );
        int unsigned sum = cmd + len_l + len_h;
        foreach (payload[i]) begin
            sum += payload[i];
        end
        calc_checksum = ~byte_t'(sum[7:0]);
    endfunction

    task automatic push_rx_byte(input byte_t b);
        @(posedge clk);
        while (!rx_byte_ready) @(posedge clk);
        rx_byte       <= b;
        rx_byte_valid <= 1'b1;
        @(posedge clk);
        rx_byte_valid <= 1'b0;
    endtask

    task automatic send_frame(input byte_t cmd, input byte_t payload[]);
        byte_t len_l, len_h;
        byte_t checksum;
        int unsigned payload_size;

        payload_size = payload.size();
        len_l = payload_size[7:0];
        len_h = payload_size[15:8];
        checksum = calc_checksum(cmd, len_l, len_h, payload);

        push_rx_byte(8'hAA);
        push_rx_byte(8'h55);
        push_rx_byte(cmd);
        push_rx_byte(len_l);
        push_rx_byte(len_h);
        foreach (payload[i]) begin
            push_rx_byte(payload[i]);
        end
        push_rx_byte(checksum);
    endtask

    task automatic consume_payload(
        input int expected_len,
        ref byte_t buffer[$]
    );
        int idx = 0;
        int unsigned stall_counter = 0;
        buffer = {};
        pkt_payload_ready = 1'b1;
        while (idx < expected_len) begin
            @(posedge clk);
            if (pkt_payload_valid) begin
                buffer.push_back(pkt_payload_data);
                idx++;
                stall_counter = 0;
                $display("[%0t] Payload byte %0d/%0d: 0x%02x", $time, idx, expected_len, pkt_payload_data);
            end else begin
                stall_counter++;
                if (stall_counter > WAIT_TIMEOUT_CYCLES) begin
                    $display("DEBUG payload wait: idx=%0d expected=%0d rx_state=%0d", idx, expected_len, dut.rx_state);
                    $fatal("Timeout while waiting payload bytes");
                end
            end
        end
        pkt_payload_ready = 1'b0;
    endtask

    // ------------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------------
    byte_t payload_a[$];
    byte_t payload_b[$];
    byte_t rx_buffer[$];
    byte_t tx_capture[$];
    byte_t expected_checksum;
    int unsigned payload_len;
    localparam int unsigned WAIT_TIMEOUT_CYCLES = 4096;

    initial begin
        rx_byte        = '0;
        rx_byte_valid  = 0;
        pkt_meta_ready = 0;
        pkt_payload_ready = 0;
        tx_meta_valid  = 0;
        tx_payload_valid = 0;
        tx_payload_last  = 0;
        tx_byte_ready = 1'b1;

        wait(rst_n == 1);
        @(posedge clk);

        $display("=== Testcase 1: RX simple payload ===");
        payload_a = {};
        payload_a.push_back(8'h11);
        payload_a.push_back(8'h22);
        payload_a.push_back(8'h33);
        payload_a.push_back(8'h44);
        send_frame(8'hA1, payload_a);

        @(posedge clk);
        pkt_meta_ready = 1'b1;
        begin
            int unsigned meta_wait = 0;
            while (!pkt_meta_valid) begin
                @(posedge clk);
                meta_wait++;
                if (meta_wait > WAIT_TIMEOUT_CYCLES) begin
                    $display("DEBUG meta wait: rx_state=%0d checksum=0x%02x time=%0t", dut.rx_state, dut.checksum_accum, $time);
                    $fatal("Timeout waiting pkt_meta_valid");
                end
            end
        end
        assert(pkt_cmd == 8'hA1) else $fatal("CMD mismatch");
        assert(pkt_length == payload_a.size()) else $fatal("Length mismatch");
        assert(pkt_error == 0) else $fatal("Unexpected error");
        @(posedge clk);
        pkt_meta_ready = 1'b0;

        consume_payload(payload_a.size(), rx_buffer);
        assert(rx_buffer == payload_a) else $fatal("Payload mismatch");

        $display("=== Testcase 2: RX zero-length payload ===");
        payload_b = {};
        send_frame(8'hA2, payload_b);
        @(posedge clk);
        pkt_meta_ready = 1'b1;
        wait(pkt_meta_valid);
        assert(pkt_length == 0);
        @(posedge clk);
        pkt_meta_ready = 1'b0;

        $display("=== Testcase 3: RX checksum error ===");
        payload_b = {};
        payload_b.push_back(8'h55);
        payload_b.push_back(8'hAA);
        push_rx_byte(8'hAA);
        push_rx_byte(8'h55);
        push_rx_byte(8'h5A);
        push_rx_byte(8'h02);
        push_rx_byte(8'h00);
        push_rx_byte(8'h55);
        push_rx_byte(8'hAA);
        push_rx_byte(8'h00); // wrong checksum

        repeat(20) @(posedge clk);
        assert(pkt_meta_valid == 0) else $fatal("Should not produce metadata on checksum error");

        $display("=== Testcase 4: TX path ===");
        tx_capture = {};
        fork
            begin : capture_tx
                forever begin
                    @(posedge clk);
                    if (tx_byte_valid && tx_byte_ready) begin
                        tx_capture.push_back(tx_byte);
                        if (tx_capture.size() == 4 + payload_a.size() + 1) begin
                            disable capture_tx;
                        end
                    end
                end
            end
        join_none

        tx_cmd    = 8'hB1;
        payload_len = payload_a.size();
        tx_length = payload_len;
        tx_meta_valid = 1'b1;
        @(posedge clk);
        tx_meta_valid = 1'b0;

        foreach(payload_a[i]) begin
            tx_payload_data  = payload_a[i];
            tx_payload_valid = 1'b1;
            tx_payload_last  = (i == payload_a.size()-1);
            @(posedge clk);
            while (!tx_payload_ready) @(posedge clk);
        end
        tx_payload_valid = 1'b0;
        tx_payload_last  = 1'b0;

        wait(tx_capture.size() == 4 + payload_len + 1);

        assert(tx_capture[0] == 8'hAA);
        assert(tx_capture[1] == 8'h55);
        assert(tx_capture[2] == 8'hB1);
        assert(tx_capture[3] == payload_len[7:0]);
        assert(tx_capture[4] == payload_len[15:8]);
        for (int i = 0; i < payload_len; i++) begin
            assert(tx_capture[5+i] == payload_a[i]);
        end
        expected_checksum = calc_checksum(8'hB1, payload_len[7:0], payload_len[15:8], payload_a);
        assert(tx_capture[$-1] == expected_checksum);

        $display("All tests passed.");
        #100ns;
        $finish;
    end

endmodule