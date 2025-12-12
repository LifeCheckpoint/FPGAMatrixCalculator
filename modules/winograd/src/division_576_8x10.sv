`timescale 1ns / 1ps

module division_576_8x10 (
    input  logic [31:0] input_array  [7:0][9:0],
    output logic [31:0] output_array [7:0][9:0]
);

    genvar i, j;
    generate
        for (i = 0; i < 8; i++) begin : gen_row
            for (j = 0; j < 10; j++) begin : gen_col
                // Optimization: Replace division with multiplication to save LUTs
                // Original: (input >> 6) / 9
                // New: (input >>> 6) * 1908874354 >>> 34
                // 1908874354 approx 2^34 / 9
                
                logic signed [31:0] s_input;
                logic signed [31:0] s_shifted;
                logic signed [63:0] mult_res;
                
                assign s_input = signed'(input_array[i][j]);
                assign s_shifted = s_input >>> 6; // Arithmetic shift for signed data
                
                // Use 64-bit signed multiplication
                assign mult_res = s_shifted * signed'(64'd1908874354);
                
                assign output_array[i][j] = mult_res >>> 34;
            end
        end
    endgenerate

endmodule
