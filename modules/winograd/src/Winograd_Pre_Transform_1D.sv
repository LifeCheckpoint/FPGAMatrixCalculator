`timescale 1ns / 1ps

module Winograd_Pre_Transform_1D (
    input  logic [31:0] d [0:5], // Input vector (column of tile)
    output logic [31:0] t [0:5]  // Output vector (column of T)
);

    always_comb begin
        // B^T matrix multiplication
        // B^T is 6x6, d is 6x1
        
        // Row 0: B^T[0] = [4, 0, -5, 0, 1, 0]
        // t[0] = 4*d[0] - 5*d[2] + d[4]
        t[0] = (d[0] << 2) - (d[2] << 2) - d[2] + d[4];

        // Row 1: B^T[1] = [0, -4, -4, 1, 1, 0]
        // t[1] = -4*d[1] - 4*d[2] + d[3] + d[4]
        t[1] = -(d[1] << 2) - (d[2] << 2) + d[3] + d[4];

        // Row 2: B^T[2] = [0, 4, -4, -1, 1, 0]
        // t[2] = 4*d[1] - 4*d[2] - d[3] + d[4]
        t[2] = (d[1] << 2) - (d[2] << 2) - d[3] + d[4];

        // Row 3: B^T[3] = [0, -2, -1, 2, 1, 0]
        // t[3] = -2*d[1] - d[2] + 2*d[3] + d[4]
        t[3] = -(d[1] << 1) - d[2] + (d[3] << 1) + d[4];

        // Row 4: B^T[4] = [0, 2, -1, -2, 1, 0]
        // t[4] = 2*d[1] - d[2] - 2*d[3] + d[4]
        t[4] = (d[1] << 1) - d[2] - (d[3] << 1) + d[4];

        // Row 5: B^T[5] = [0, 4, 0, -5, 0, 1]
        // t[5] = 4*d[1] - 5*d[3] + d[5]
        t[5] = (d[1] << 2) - (d[3] << 2) - d[3] + d[5];
    end

endmodule
