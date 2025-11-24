`timescale 1ns / 1ps

// UART packetizer / depacketizer
// ---------------------------------------------
// RX path:
//   - Accepts raw byte stream from uart_rx
//   - Detects frame header (0xAA55), parses length, accumulates checksum
//   - Stores payload into on-chip buffer and exposes it as a streaming interface
// TX path:
//   - Accepts command metadata plus payload stream
//   - Inserts frame header, appends checksum, emits serialized bytes
//
// Frame layout:
//   +--------+--------+---------+---------+---------+---------------+----------+
//   | HEAD0  | HEAD1  |  CMD    | LEN_L   | LEN_H   |   PAYLOAD     | CHECKSUM |
//   +--------+--------+---------+---------+---------+---------------+----------+
//   HEAD0 = 8'hAA, HEAD1 = 8'h55
//   LEN = LEN_H << 8 | LEN_L (little-endian)
//   CHECKSUM = bitwise_not( CMD + LEN_L + LEN_H + sum(PAYLOAD bytes) )
module uart_packet_handler #(
    parameter int unsigned MAX_PAYLOAD_BYTES = 512
) (
    input  logic        clk,
    input  logic        rst_n,

    // ------------------------------------------------------------------------
    // PC -> FPGA byte stream (comes from uart_rx)
    // ------------------------------------------------------------------------
    input  logic [7:0]  rx_byte,
    input  logic        rx_byte_valid,
    output logic        rx_byte_ready,

    // Decoded packet metadata
    output logic        pkt_meta_valid,
    input  logic        pkt_meta_ready,
    output logic [7:0]  pkt_cmd,
    output logic [15:0] pkt_length,
    output logic [1:0]  pkt_error,        // 0: OK, 1: length overflow, 2: checksum error, 3: others

    // Payload streaming interface (active after metadata is accepted)
    output logic [7:0]  pkt_payload_data,
    output logic        pkt_payload_valid,
    output logic        pkt_payload_last,
    input  logic        pkt_payload_ready,

    // ------------------------------------------------------------------------
    // FPGA -> PC byte stream (drives uart_tx)
    // ------------------------------------------------------------------------
    input  logic        tx_meta_valid,
    output logic        tx_meta_ready,
    input  logic [7:0]  tx_cmd,
    input  logic [15:0] tx_length,

    input  logic [7:0]  tx_payload_data,
    input  logic        tx_payload_valid,
    input  logic        tx_payload_last,
    output logic        tx_payload_ready,

    output logic [7:0]  tx_byte,
    output logic        tx_byte_valid,
    input  logic        tx_byte_ready
);

    // =========================================================================
    // RX PATH: frame state machine
    // =========================================================================
    typedef enum logic [3:0] {
        RX_IDLE,
        RX_HEAD1,
        RX_CMD,
        RX_LEN_L,
        RX_LEN_H,
        RX_PAYLOAD,
        RX_CHECK,
        RX_HOLD_META,
        RX_STREAM_PAYLOAD,
        RX_ERROR_DROP
    } rx_state_e;

    rx_state_e           rx_state, rx_state_nxt;
    logic [7:0]          rx_cmd_reg;
    logic [15:0]         rx_len_reg;
    logic [15:0]         rx_payload_count;
    logic [7:0]          checksum_accum;
    logic [7:0]          checksum_expect;
    logic [7:0]          payload_mem [0:MAX_PAYLOAD_BYTES-1];
    logic [15:0]         payload_wr_ptr;
    logic [15:0]         payload_rd_ptr;
    logic [1:0]          pkt_error_reg;

    // State transition
    always_comb begin
        rx_state_nxt   = rx_state;
        rx_byte_ready  = 1'b1;

        case (rx_state)
            RX_IDLE: begin
                if (rx_byte_valid && rx_byte == 8'hAA) begin
                    rx_state_nxt = RX_HEAD1;
                end
            end
            RX_HEAD1: begin
                if (rx_byte_valid) begin
                    if (rx_byte == 8'h55) begin
                        rx_state_nxt = RX_CMD;
                    end else begin
                        rx_state_nxt = RX_IDLE;
                    end
                end
            end
            RX_CMD: begin
                if (rx_byte_valid) begin
                    rx_state_nxt = RX_LEN_L;
                end
            end
            RX_LEN_L: begin
                if (rx_byte_valid) begin
                    rx_state_nxt = RX_LEN_H;
                end
            end
            RX_LEN_H: begin
                if (rx_byte_valid) begin
                    if (rx_len_reg == 16'd0) begin
                        rx_state_nxt = RX_CHECK;
                    end else if (rx_len_reg > MAX_PAYLOAD_BYTES) begin
                        rx_state_nxt = RX_ERROR_DROP;
                    end else begin
                        rx_state_nxt = RX_PAYLOAD;
                    end
                end
            end
            RX_PAYLOAD: begin
                if (rx_byte_valid) begin
                    if (rx_payload_count + 16'd1 == rx_len_reg) begin
                        rx_state_nxt = RX_CHECK;
                    end
                end
            end
            RX_CHECK: begin
                if (rx_byte_valid) begin
                    if (rx_byte == checksum_expect && pkt_meta_ready) begin
                        rx_state_nxt = (rx_len_reg == 16'd0) ? RX_IDLE : RX_STREAM_PAYLOAD;
                    end else if (rx_byte == checksum_expect && !pkt_meta_ready) begin
                        rx_state_nxt = RX_HOLD_META;
                    end else begin
                        rx_state_nxt = RX_ERROR_DROP;
                    end
                end
            end
            RX_HOLD_META: begin
                if (pkt_meta_ready) begin
                    rx_state_nxt = (rx_len_reg == 16'd0) ? RX_IDLE : RX_STREAM_PAYLOAD;
                end
                rx_byte_ready = 1'b0;
            end
            RX_STREAM_PAYLOAD: begin
                rx_byte_ready = 1'b0;
                if (pkt_payload_valid && pkt_payload_ready && pkt_payload_last) begin
                    rx_state_nxt = RX_IDLE;
                end
            end
            RX_ERROR_DROP: begin
                if (rx_byte_valid && rx_byte == 8'hAA) begin
                    rx_state_nxt = RX_HEAD1;
                end else if (rx_byte_valid) begin
                    rx_state_nxt = RX_IDLE;
                end
            end
            default: rx_state_nxt = RX_IDLE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state          <= RX_IDLE;
            rx_cmd_reg        <= '0;
            rx_len_reg        <= '0;
            rx_payload_count  <= '0;
            payload_wr_ptr    <= '0;
            payload_rd_ptr    <= '0;
            checksum_accum    <= '0;
            checksum_expect   <= '0;
            pkt_error_reg     <= 2'd0;
        end else begin
            rx_state <= rx_state_nxt;

            if (rx_state == RX_IDLE && rx_byte_valid && rx_byte == 8'hAA) begin
                checksum_accum   <= 8'd0;
                payload_wr_ptr   <= '0;
                rx_payload_count <= '0;
                pkt_error_reg    <= 2'd0;
            end

            if (rx_state == RX_CMD && rx_byte_valid) begin
                rx_cmd_reg     <= rx_byte;
                checksum_accum <= checksum_accum + rx_byte;
            end

            if (rx_state == RX_LEN_L && rx_byte_valid) begin
                rx_len_reg[7:0] <= rx_byte;
                checksum_accum  <= checksum_accum + rx_byte;
            end

            if (rx_state == RX_LEN_H && rx_byte_valid) begin
                rx_len_reg[15:8] <= rx_byte;
                checksum_accum   <= checksum_accum + rx_byte;
                if ({rx_byte, rx_len_reg[7:0]} > MAX_PAYLOAD_BYTES) begin
                    pkt_error_reg <= 2'd1;
                end
            end

            if (rx_state == RX_PAYLOAD && rx_byte_valid) begin
                payload_mem[payload_wr_ptr] <= rx_byte;
                payload_wr_ptr              <= payload_wr_ptr + 16'd1;
                rx_payload_count            <= rx_payload_count + 16'd1;
                checksum_accum              <= checksum_accum + rx_byte;
            end

            if (rx_state == RX_CHECK && rx_byte_valid) begin
                checksum_expect <= ~checksum_accum;
                if (rx_byte != ~checksum_accum) begin
                    pkt_error_reg <= 2'd2;
                end
            end

            if (rx_state == RX_STREAM_PAYLOAD && pkt_payload_valid && pkt_payload_ready) begin
                payload_rd_ptr <= payload_rd_ptr + 16'd1;
            end else if (rx_state == RX_IDLE || rx_state == RX_HEAD1) begin
                payload_rd_ptr <= 16'd0;
            end
        end
    end

    assign pkt_cmd    = rx_cmd_reg;
    assign pkt_length = rx_len_reg;
    assign pkt_error  = pkt_error_reg;

    assign pkt_meta_valid = (rx_state == RX_CHECK && checksum_expect == ~checksum_accum &&
                              pkt_error_reg == 2'd0) ||
                             (rx_state == RX_HOLD_META);

    assign pkt_payload_valid = (rx_state == RX_STREAM_PAYLOAD);
    assign pkt_payload_data  = payload_mem[payload_rd_ptr];
    assign pkt_payload_last  = (payload_rd_ptr + 16'd1 == rx_len_reg);

    // =========================================================================
    // TX PATH: frame generator
    // =========================================================================
    typedef enum logic [3:0] {
        TX_IDLE,
        TX_HEAD0,
        TX_HEAD1,
        TX_CMD,
        TX_LEN_L,
        TX_LEN_H,
        TX_PAYLOAD,
        TX_CHECKSUM
    } tx_state_e;

    tx_state_e          tx_state, tx_state_nxt;
    logic [15:0]        tx_len_counter;
    logic [7:0]         tx_checksum_accum;

    always_comb begin
        tx_state_nxt     = tx_state;
        tx_byte_valid    = 1'b0;
        tx_byte          = 8'h00;
        tx_meta_ready    = 1'b0;
        tx_payload_ready = 1'b0;

        case (tx_state)
            TX_IDLE: begin
                tx_meta_ready = 1'b1;
                if (tx_meta_valid) begin
                    tx_state_nxt = TX_HEAD0;
                end
            end
            TX_HEAD0: begin
                tx_byte_valid = 1'b1;
                tx_byte       = 8'hAA;
                if (tx_byte_ready) begin
                    tx_state_nxt = TX_HEAD1;
                end
            end
            TX_HEAD1: begin
                tx_byte_valid = 1'b1;
                tx_byte       = 8'h55;
                if (tx_byte_ready) begin
                    tx_state_nxt = TX_CMD;
                end
            end
            TX_CMD: begin
                tx_byte_valid = 1'b1;
                tx_byte       = tx_cmd;
                if (tx_byte_ready) begin
                    tx_state_nxt = TX_LEN_L;
                end
            end
            TX_LEN_L: begin
                tx_byte_valid = 1'b1;
                tx_byte       = tx_length[7:0];
                if (tx_byte_ready) begin
                    tx_state_nxt = TX_LEN_H;
                end
            end
            TX_LEN_H: begin
                tx_byte_valid = 1'b1;
                tx_byte       = tx_length[15:8];
                if (tx_byte_ready) begin
                    tx_state_nxt = (tx_length == 16'd0) ? TX_CHECKSUM : TX_PAYLOAD;
                end
            end
            TX_PAYLOAD: begin
                tx_payload_ready = (tx_payload_valid && tx_byte_ready);
                tx_byte_valid    = tx_payload_valid;
                tx_byte          = tx_payload_data;
                if (tx_payload_valid && tx_byte_ready) begin
                    if (tx_len_counter + 16'd1 == tx_length) begin
                        tx_state_nxt = TX_CHECKSUM;
                    end
                end
            end
            TX_CHECKSUM: begin
                tx_byte_valid = 1'b1;
                tx_byte       = ~tx_checksum_accum;
                if (tx_byte_ready) begin
                    tx_state_nxt = TX_IDLE;
                end
            end
            default: tx_state_nxt = TX_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state          <= TX_IDLE;
            tx_len_counter    <= '0;
            tx_checksum_accum <= '0;
        end else begin
            tx_state <= tx_state_nxt;

            if (tx_state == TX_IDLE && tx_meta_valid && tx_meta_ready) begin
                tx_len_counter    <= 16'd0;
                tx_checksum_accum <= 8'd0;
            end

            if (tx_state == TX_CMD && tx_byte_ready) begin
                tx_checksum_accum <= tx_checksum_accum + tx_cmd;
            end

            if (tx_state == TX_LEN_L && tx_byte_ready) begin
                tx_checksum_accum <= tx_checksum_accum + tx_length[7:0];
            end

            if (tx_state == TX_LEN_H && tx_byte_ready) begin
                tx_checksum_accum <= tx_checksum_accum + tx_length[15:8];
            end

            if (tx_state == TX_PAYLOAD && tx_payload_valid && tx_byte_ready) begin
                tx_checksum_accum <= tx_checksum_accum + tx_payload_data;
                tx_len_counter    <= tx_len_counter + 16'd1;
            end
        end
    end

endmodule