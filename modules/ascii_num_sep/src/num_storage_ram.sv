`timescale 1ns / 1ps

// Number Storage RAM - Dual-port RAM for storing converted integers
module num_storage_ram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 2048,
    parameter ADDR_WIDTH = 11
) (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Clear signal - clears all RAM contents
    input  logic                    clear,
    
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
    
    // Clear state machine
    logic clearing;
    logic [ADDR_WIDTH-1:0] clear_addr;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clearing <= 1'b0;
            clear_addr <= '0;
        end else begin
            if (clear && !clearing) begin
                // Start clearing
                clearing <= 1'b1;
                clear_addr <= '0;
            end else if (clearing) begin
                if (clear_addr < DEPTH - 1) begin
                    clear_addr <= clear_addr + 1'b1;
                end else begin
                    // Clearing complete
                    clearing <= 1'b0;
                end
            end
        end
    end
    
    // Write operation - clear has higher priority
    always_ff @(posedge clk) begin
        if (clearing) begin
            mem[clear_addr] <= '0;
        end else if (wr_en) begin
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