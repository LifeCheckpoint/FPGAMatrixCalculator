`timescale 1ns / 1ps

module array_divide_by_576 (
    input  logic [15:0] input_array  [7:0][9:0],
    output logic [15:0] output_array [7:0][9:0]
);

    genvar i, j;
    generate
        for (i = 0; i < 8; i++) begin : gen_row
            for (j = 0; j < 10; j++) begin : gen_col
                assign output_array[i][j] = (input_array[i][j] >> 6) / 9;
            end
        end
    endgenerate

endmodule
