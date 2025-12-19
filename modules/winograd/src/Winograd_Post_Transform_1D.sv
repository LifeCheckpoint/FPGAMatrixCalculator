`timescale 1ns / 1ps

module Winograd_Post_Transform_1D (
    input  logic signed [63:0] in_vec [0:5],
    output logic signed [63:0] out_vec [0:3]
);
    // Winograd post-processing transform equations (A^T * x)
    // A^T = 
    // 1  1  1  1  1  0
    // 0  1 -1  2 -2  0
    // 0  1  1  4  4  0
    // 0  1 -1  8 -8  1

    // out[0] = in[0] + in[1] + in[2] + in[3] + in[4]
    // out[1] = in[1] - in[2] + 2*in[3] - 2*in[4]
    // out[2] = in[1] + in[2] + 4*in[3] + 4*in[4]
    // out[3] = in[1] - in[2] + 8*in[3] - 8*in[4] + in[5]

    assign out_vec[0] = in_vec[0] + in_vec[1] + in_vec[2] + in_vec[3] + in_vec[4];
    assign out_vec[1] = in_vec[1] - in_vec[2] + (in_vec[3] <<< 1) - (in_vec[4] <<< 1);
    assign out_vec[2] = in_vec[1] + in_vec[2] + (in_vec[3] <<< 2) + (in_vec[4] <<< 2);
    assign out_vec[3] = in_vec[1] - in_vec[2] + (in_vec[3] <<< 3) - (in_vec[4] <<< 3) + in_vec[5];

endmodule
