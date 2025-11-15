`timescale 1ns / 1ps

module transform_3x3x4x4_8x10 (
    input  logic [31:0] tile  [0:2][0:2][0:3][0:3],
    output logic [31:0] image [0:7][0:9]
);

// In this module, input will be stick and clip invalid areas, not div.

always_comb begin
    // Row 0
    image[0][0] = tile[0][0][0][0]; image[0][1] = tile[0][0][0][1]; image[0][2] = tile[0][0][0][2]; image[0][3] = tile[0][0][0][3];
    image[0][4] = tile[0][1][0][0]; image[0][5] = tile[0][1][0][1]; image[0][6] = tile[0][1][0][2]; image[0][7] = tile[0][1][0][3];
    image[0][8] = tile[0][2][0][0]; image[0][9] = tile[0][2][0][1];
    
    // Row 1
    image[1][0] = tile[0][0][1][0]; image[1][1] = tile[0][0][1][1]; image[1][2] = tile[0][0][1][2]; image[1][3] = tile[0][0][1][3];
    image[1][4] = tile[0][1][1][0]; image[1][5] = tile[0][1][1][1]; image[1][6] = tile[0][1][1][2]; image[1][7] = tile[0][1][1][3];
    image[1][8] = tile[0][2][1][0]; image[1][9] = tile[0][2][1][1];
    
    // Row 2
    image[2][0] = tile[0][0][2][0]; image[2][1] = tile[0][0][2][1]; image[2][2] = tile[0][0][2][2]; image[2][3] = tile[0][0][2][3];
    image[2][4] = tile[0][1][2][0]; image[2][5] = tile[0][1][2][1]; image[2][6] = tile[0][1][2][2]; image[2][7] = tile[0][1][2][3];
    image[2][8] = tile[0][2][2][0]; image[2][9] = tile[0][2][2][1];
    
    // Row 3
    image[3][0] = tile[0][0][3][0]; image[3][1] = tile[0][0][3][1]; image[3][2] = tile[0][0][3][2]; image[3][3] = tile[0][0][3][3];
    image[3][4] = tile[0][1][3][0]; image[3][5] = tile[0][1][3][1]; image[3][6] = tile[0][1][3][2]; image[3][7] = tile[0][1][3][3];
    image[3][8] = tile[0][2][3][0]; image[3][9] = tile[0][2][3][1];
    
    // Row 4
    image[4][0] = tile[1][0][0][0]; image[4][1] = tile[1][0][0][1]; image[4][2] = tile[1][0][0][2]; image[4][3] = tile[1][0][0][3];
    image[4][4] = tile[1][1][0][0]; image[4][5] = tile[1][1][0][1]; image[4][6] = tile[1][1][0][2]; image[4][7] = tile[1][1][0][3];
    image[4][8] = tile[1][2][0][0]; image[4][9] = tile[1][2][0][1];
    
    // Row 5
    image[5][0] = tile[1][0][1][0]; image[5][1] = tile[1][0][1][1]; image[5][2] = tile[1][0][1][2]; image[5][3] = tile[1][0][1][3];
    image[5][4] = tile[1][1][1][0]; image[5][5] = tile[1][1][1][1]; image[5][6] = tile[1][1][1][2]; image[5][7] = tile[1][1][1][3];
    image[5][8] = tile[1][2][1][0]; image[5][9] = tile[1][2][1][1];
    
    // Row 6
    image[6][0] = tile[1][0][2][0]; image[6][1] = tile[1][0][2][1]; image[6][2] = tile[1][0][2][2]; image[6][3] = tile[1][0][2][3];
    image[6][4] = tile[1][1][2][0]; image[6][5] = tile[1][1][2][1]; image[6][6] = tile[1][1][2][2]; image[6][7] = tile[1][1][2][3];
    image[6][8] = tile[1][2][2][0]; image[6][9] = tile[1][2][2][1];
    
    // Row 7
    image[7][0] = tile[1][0][3][0]; image[7][1] = tile[1][0][3][1]; image[7][2] = tile[1][0][3][2]; image[7][3] = tile[1][0][3][3];
    image[7][4] = tile[1][1][3][0]; image[7][5] = tile[1][1][3][1]; image[7][6] = tile[1][1][3][2]; image[7][7] = tile[1][1][3][3];
    image[7][8] = tile[1][2][3][0]; image[7][9] = tile[1][2][3][1];
end

endmodule
