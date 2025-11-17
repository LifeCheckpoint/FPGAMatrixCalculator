// Matrix Storage Manager - Top Level Module
// Integrates BRAM, write module and read module, provides unified matrix storage management interface

module matrix_storage_manager #(
    parameter MAX_MEMORY_MATRIXES = 8,      // Maximum number of matrix blocks
    parameter BLOCK_SIZE = 1152,             // Size of each matrix block (32-bit words)
    parameter DATA_WIDTH = 32,               // Data width
    parameter DEPTH = 9216,                  // BRAM total depth (8 * 1152)
    parameter ADDR_WIDTH = 14                // Address width ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Write interface
    input  logic                     write_req,        // Write request
    input  logic [2:0]               write_matrix_id,  // Matrix ID to write (0~7)
    input  logic [7:0]               write_rows,       // Actual row count
    input  logic [7:0]               write_cols,       // Actual column count
    input  logic [63:0]              write_matrix_name,// Matrix name (8 characters)
    input  logic [DATA_WIDTH-1:0]    write_data_in,    // Matrix data input
    input  logic                     write_data_valid, // Write data valid signal
    output logic                     write_done,       // Write complete
    output logic                     writer_ready,     // Writer ready
    
    // Read interface
    input  logic                     read_req,         // Read request
    input  logic [2:0]               read_matrix_id,   // Matrix ID to read (0~7)
    input  logic                     read_data_req,    // Request to read next matrix data
    output logic                     read_done,        // Read complete
    output logic                     reader_ready,     // Reader ready
    
    // Read metadata output
    output logic [7:0]               read_rows,        // Actual row count
    output logic [7:0]               read_cols,        // Actual column count
    output logic [63:0]              read_matrix_name, // Matrix name (8 characters)
    output logic                     read_meta_valid,  // Metadata valid
    
    // Read data output
    output logic [DATA_WIDTH-1:0]    read_data_out,    // Matrix data output
    output logic                     read_data_valid   // Data valid signal
);

    // BRAM interface signals
    logic                     bram_wr_en;
    logic [ADDR_WIDTH-1:0]    bram_addr;
    logic [DATA_WIDTH-1:0]    bram_din;
    logic [DATA_WIDTH-1:0]    bram_dout;
    
    // Write module BRAM interface
    logic                     writer_bram_wr_en;
    logic [ADDR_WIDTH-1:0]    writer_bram_addr;
    logic [DATA_WIDTH-1:0]    writer_bram_din;
    
    // Read module BRAM interface
    logic [ADDR_WIDTH-1:0]    reader_bram_addr;
    
    // Arbitration logic: read and write cannot occur simultaneously, write has priority
    // When writer is active, read operations are disabled
    logic write_active;
    assign write_active = !writer_ready || write_req;
    
    always_comb begin
        if (write_active) begin
            // Write mode
            bram_wr_en = writer_bram_wr_en;
            bram_addr = writer_bram_addr;
            bram_din = writer_bram_din;
        end else begin
            // Read mode
            bram_wr_en = 1'b0;
            bram_addr = reader_bram_addr;
            bram_din = '0;
        end
    end
    
    // Instantiate BRAM module
    bram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_bram (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(bram_wr_en),
        .addr(bram_addr),
        .din(bram_din),
        .dout(bram_dout)
    );
    
    // Instantiate matrix writer module
    matrix_writer #(
        .MAX_MEMORY_MATRIXES(MAX_MEMORY_MATRIXES),
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_matrix_writer (
        .clk(clk),
        .rst_n(rst_n),
        
        .write_req(write_req),
        .matrix_id(write_matrix_id),
        .rows(write_rows),
        .cols(write_cols),
        .matrix_name(write_matrix_name),
        .data_in(write_data_in),
        .data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        
        .bram_wr_en(writer_bram_wr_en),
        .bram_addr(writer_bram_addr),
        .bram_din(writer_bram_din)
    );
    
    // Instantiate matrix reader module
    matrix_reader #(
        .MAX_MEMORY_MATRIXES(MAX_MEMORY_MATRIXES),
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_matrix_reader (
        .clk(clk),
        .rst_n(rst_n),
        
        .read_req(read_req && !write_active),  // Disable read when writing
        .matrix_id(read_matrix_id),
        .read_data_req(read_data_req && !write_active),
        .read_done(read_done),
        .reader_ready(reader_ready),
        
        .rows(read_rows),
        .cols(read_cols),
        .matrix_name(read_matrix_name),
        .meta_valid(read_meta_valid),
        
        .data_out(read_data_out),
        .data_valid(read_data_valid),
        
        .bram_addr(reader_bram_addr),
        .bram_dout(bram_dout)
    );

endmodule