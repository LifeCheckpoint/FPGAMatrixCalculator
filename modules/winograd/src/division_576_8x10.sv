`timescale 1ns / 1ps

module division_576_8x10 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    output logic        done,
    input  logic [31:0] input_array  [7:0][9:0],
    output logic [31:0] output_array [7:0][9:0]
);

    logic [3:0] row_idx;
    logic [3:0] col_idx;
    logic       busy;
    
    // Output storage
    logic [31:0] result_store [7:0][9:0];
    
    assign output_array = result_store;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            row_idx <= 0;
            col_idx <= 0;
            for (int i=0; i<8; i++) begin
                for (int j=0; j<10; j++) begin
                    result_store[i][j] <= 32'd0;
                end
            end
        end else begin
            done <= 1'b0;
            
            if (start && !busy) begin
                busy <= 1'b1;
                row_idx <= 0;
                col_idx <= 0;
            end else if (busy) begin
                // Perform division: input / 576
                // Using standard division operator as requested.
                // Synthesizer should optimize this to multiplication by reciprocal.
                result_store[row_idx][col_idx] <= signed'(input_array[row_idx][col_idx]) / 576;
                
                // Increment
                if (col_idx == 9) begin
                    col_idx <= 0;
                    if (row_idx == 7) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        row_idx <= row_idx + 1;
                    end
                end else begin
                    col_idx <= col_idx + 1;
                end
            end
        end
    end

endmodule
