`timescale 1ns / 1ps

// Data Write Controller - Manages RAM write operations and address generation
module data_write_controller (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Data input from ascii_to_int32
    input  logic signed [31:0]      data_in,
    input  logic                    data_valid,
    
    // Expected count from parser
    input  logic [10:0]             total_count,
    input  logic                    parse_done,
    
    // RAM write interface
    output logic                    ram_wr_en,
    output logic [10:0]             ram_wr_addr,
    output logic [31:0]             ram_wr_data,
    
    // Status
    output logic [10:0]             write_count,
    output logic                    all_done
);

    // Internal registers
    logic [10:0] wr_addr_reg;
    logic [10:0] wr_count_reg;
    
    // Write enable generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_wr_en <= 1'b0;
        end else begin
            ram_wr_en <= data_valid;
        end
    end
    
    // Address and count management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_addr_reg <= 11'd0;
            wr_count_reg <= 11'd0;
        end else begin
            if (data_valid) begin
                wr_addr_reg <= wr_addr_reg + 11'd1;
                wr_count_reg <= wr_count_reg + 11'd1;
            end else if (all_done) begin
                // Reset for next operation
                wr_addr_reg <= 11'd0;
                wr_count_reg <= 11'd0;
            end
        end
    end
    
    // Data passthrough
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_wr_data <= 32'd0;
        end else begin
            if (data_valid) begin
                ram_wr_data <= data_in;
            end
        end
    end
    
    // Output assignments
    assign ram_wr_addr = wr_addr_reg;
    assign write_count = wr_count_reg;
    assign all_done = parse_done && (wr_count_reg == total_count);

endmodule