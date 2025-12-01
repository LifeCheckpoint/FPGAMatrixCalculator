`timescale 1ns / 1ps

// ASCII Number Separator Top Module - Integrates all sub-modules
module ascii_num_sep_top #(
    parameter MAX_PAYLOAD = 2048,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 2048,
    parameter ADDR_WIDTH = 11
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Buffer RAM clear signal
    input  logic                    buf_clear,
    
    // UART packet payload interface
    input  logic [7:0]              pkt_payload_data,
    input  logic                    pkt_payload_valid,
    input  logic                    pkt_payload_last,
    output logic                    pkt_payload_ready,
    
    // RAM read interface for downstream modules
    input  logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data,
    
    // Status outputs
    output logic                    processing,
    output logic                    done,
    output logic                    invalid,
    output logic [10:0]             num_count
);

    // Internal signals between modules
    
    // Validator outputs
    logic [7:0]  char_buffer [0:MAX_PAYLOAD-1];
    logic [15:0] buffer_length;
    logic        validator_done;
    logic        validator_invalid;
    
    // Parser outputs
    logic        num_start;
    logic [7:0]  num_char;
    logic        num_valid;
    logic        num_end;
    logic [10:0] parser_num_count;
    logic        parse_done;
    
    // Converter outputs
    logic signed [31:0] converter_result;
    logic        converter_result_valid;
    
    // Write controller outputs
    logic                    ram_wr_en;
    logic [ADDR_WIDTH-1:0]   ram_wr_addr;
    logic [DATA_WIDTH-1:0]   ram_wr_data;
    logic [10:0]             write_count;
    logic                    all_done;
    
    // Parser control signal
    logic parser_start;
    assign parser_start = validator_done && !validator_invalid;
    
    // Status output assignments
    assign processing = validator_done && !all_done;
    assign done = all_done;
    assign invalid = validator_invalid;
    assign num_count = parser_num_count;
    
    // Module instantiations
    
    // 1. ASCII Validator - validates and buffers payload
    ascii_validator #(
        .MAX_PAYLOAD(MAX_PAYLOAD)
    ) u_validator (
        .clk            (clk),
        .rst_n          (rst_n),
        .payload_data   (pkt_payload_data),
        .payload_valid  (pkt_payload_valid),
        .payload_last   (pkt_payload_last),
        .payload_ready  (pkt_payload_ready),
        .char_buffer    (char_buffer),
        .buffer_length  (buffer_length),
        .done           (validator_done),
        .invalid        (validator_invalid)
    );
    
    // 2. Character Stream Parser - parses number boundaries
    char_stream_parser #(
        .MAX_PAYLOAD(MAX_PAYLOAD)
    ) u_parser (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (parser_start),
        .total_length   (buffer_length),
        .char_buffer    (char_buffer),
        .num_start      (num_start),
        .num_char       (num_char),
        .num_valid      (num_valid),
        .num_end        (num_end),
        .result_valid   (converter_result_valid),
        .num_count      (parser_num_count),
        .parse_done     (parse_done)
    );
    
    // 3. ASCII to INT32 Converter - converts digit stream to int32
    ascii_to_int32 u_converter (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (num_start),
        .char_in        (num_char),
        .char_valid     (num_valid),
        .num_end        (num_end),
        .result         (converter_result),
        .result_valid   (converter_result_valid)
    );
    
    // 4. Data Write Controller - manages RAM writes
    data_write_controller u_write_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_in        (converter_result),
        .data_valid     (converter_result_valid),
        .total_count    (parser_num_count),
        .parse_done     (parse_done),
        .ram_wr_en      (ram_wr_en),
        .ram_wr_addr    (ram_wr_addr),
        .ram_wr_data    (ram_wr_data),
        .write_count    (write_count),
        .all_done       (all_done)
    );
    
    // 5. Number Storage RAM - stores converted integers
    num_storage_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_ram (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear      (buf_clear),
        .wr_en      (ram_wr_en),
        .wr_addr    (ram_wr_addr),
        .wr_data    (ram_wr_data),
        .rd_addr    (rd_addr),
        .rd_data    (rd_data)
    );

endmodule