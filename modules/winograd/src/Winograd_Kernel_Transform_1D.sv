`timescale 1ns / 1ps

module Winograd_Kernel_Transform_1D (
    input  logic [31:0] g [0:2], // Input vector (size 3)
    output logic [31:0] t [0:5]  // Output vector (size 6)
);

    always_comb begin
        // G matrix multiplication (or G^T depending on pass)
        // Transform 3 -> 6
        
        // t[0] = 6 * g[0]
        t[0] = (g[0] << 2) + (g[0] << 1);
        
        // t[1] = -4 * (g[0] + g[1] + g[2])
        t[1] = -((g[0] + g[1] + g[2]) << 2);
        
        // t[2] = -4 * (g[0] - g[1] + g[2])
        t[2] = -((g[0] - g[1] + g[2]) << 2);
        
        // t[3] = g[0] + 2*g[1] + 4*g[2]
        t[3] = g[0] + (g[1] << 1) + (g[2] << 2);
        
        // t[4] = g[0] - 2*g[1] + 4*g[2]
        t[4] = g[0] - (g[1] << 1) + (g[2] << 2);
        
        // t[5] = 24 * g[2]
        t[5] = (g[2] << 4) + (g[2] << 3);
    end

endmodule
