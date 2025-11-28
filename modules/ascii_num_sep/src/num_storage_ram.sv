`timescale 1ns / 1ps

// Number Storage RAM - Dual-port RAM for storing converted integers
module num_storage_ram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 2048,
    parameter ADDR_WIDTH = 11
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write port
    input  logic                    wr_en,
    input  logic [ADDR_WIDTH-1:0]   wr_addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    
    // Read port
    input  logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Write operation
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
    // Read operation
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_data <= '0;
        end else begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule