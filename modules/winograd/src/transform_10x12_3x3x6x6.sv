`timescale 1ns / 1ps

module transform_10x12_3x3x6x6 (
    input  logic [31:0] image    [0:9][0:11],
    output logic [31:0] tile_out [0:2][0:2][0:5][0:5]
);

always_comb begin
    // tile_out[0][0] - Top-left tile
    tile_out[0][0][0][0] = image[0][0]; tile_out[0][0][0][1] = image[0][1]; tile_out[0][0][0][2] = image[0][2];
    tile_out[0][0][0][3] = image[0][3]; tile_out[0][0][0][4] = image[0][4]; tile_out[0][0][0][5] = image[0][5];
    tile_out[0][0][1][0] = image[1][0]; tile_out[0][0][1][1] = image[1][1]; tile_out[0][0][1][2] = image[1][2];
    tile_out[0][0][1][3] = image[1][3]; tile_out[0][0][1][4] = image[1][4]; tile_out[0][0][1][5] = image[1][5];
    tile_out[0][0][2][0] = image[2][0]; tile_out[0][0][2][1] = image[2][1]; tile_out[0][0][2][2] = image[2][2];
    tile_out[0][0][2][3] = image[2][3]; tile_out[0][0][2][4] = image[2][4]; tile_out[0][0][2][5] = image[2][5];
    tile_out[0][0][3][0] = image[3][0]; tile_out[0][0][3][1] = image[3][1]; tile_out[0][0][3][2] = image[3][2];
    tile_out[0][0][3][3] = image[3][3]; tile_out[0][0][3][4] = image[3][4]; tile_out[0][0][3][5] = image[3][5];
    tile_out[0][0][4][0] = image[4][0]; tile_out[0][0][4][1] = image[4][1]; tile_out[0][0][4][2] = image[4][2];
    tile_out[0][0][4][3] = image[4][3]; tile_out[0][0][4][4] = image[4][4]; tile_out[0][0][4][5] = image[4][5];
    tile_out[0][0][5][0] = image[5][0]; tile_out[0][0][5][1] = image[5][1]; tile_out[0][0][5][2] = image[5][2];
    tile_out[0][0][5][3] = image[5][3]; tile_out[0][0][5][4] = image[5][4]; tile_out[0][0][5][5] = image[5][5];
    
    // tile_out[0][1] - Top-middle tile
    tile_out[0][1][0][0] = image[0][4]; tile_out[0][1][0][1] = image[0][5]; tile_out[0][1][0][2] = image[0][6];
    tile_out[0][1][0][3] = image[0][7]; tile_out[0][1][0][4] = image[0][8]; tile_out[0][1][0][5] = image[0][9];
    tile_out[0][1][1][0] = image[1][4]; tile_out[0][1][1][1] = image[1][5]; tile_out[0][1][1][2] = image[1][6];
    tile_out[0][1][1][3] = image[1][7]; tile_out[0][1][1][4] = image[1][8]; tile_out[0][1][1][5] = image[1][9];
    tile_out[0][1][2][0] = image[2][4]; tile_out[0][1][2][1] = image[2][5]; tile_out[0][1][2][2] = image[2][6];
    tile_out[0][1][2][3] = image[2][7]; tile_out[0][1][2][4] = image[2][8]; tile_out[0][1][2][5] = image[2][9];
    tile_out[0][1][3][0] = image[3][4]; tile_out[0][1][3][1] = image[3][5]; tile_out[0][1][3][2] = image[3][6];
    tile_out[0][1][3][3] = image[3][7]; tile_out[0][1][3][4] = image[3][8]; tile_out[0][1][3][5] = image[3][9];
    tile_out[0][1][4][0] = image[4][4]; tile_out[0][1][4][1] = image[4][5]; tile_out[0][1][4][2] = image[4][6];
    tile_out[0][1][4][3] = image[4][7]; tile_out[0][1][4][4] = image[4][8]; tile_out[0][1][4][5] = image[4][9];
    tile_out[0][1][5][0] = image[5][4]; tile_out[0][1][5][1] = image[5][5]; tile_out[0][1][5][2] = image[5][6];
    tile_out[0][1][5][3] = image[5][7]; tile_out[0][1][5][4] = image[5][8]; tile_out[0][1][5][5] = image[5][9];
    
    // tile_out[0][2] - Top-right tile
    tile_out[0][2][0][0] = image[0][8];  tile_out[0][2][0][1] = image[0][9];  tile_out[0][2][0][2] = image[0][10];
    tile_out[0][2][0][3] = image[0][11]; tile_out[0][2][0][4] = 32'b0;        tile_out[0][2][0][5] = 32'b0;
    tile_out[0][2][1][0] = image[1][8];  tile_out[0][2][1][1] = image[1][9];  tile_out[0][2][1][2] = image[1][10];
    tile_out[0][2][1][3] = image[1][11]; tile_out[0][2][1][4] = 32'b0;        tile_out[0][2][1][5] = 32'b0;
    tile_out[0][2][2][0] = image[2][8];  tile_out[0][2][2][1] = image[2][9];  tile_out[0][2][2][2] = image[2][10];
    tile_out[0][2][2][3] = image[2][11]; tile_out[0][2][2][4] = 32'b0;        tile_out[0][2][2][5] = 32'b0;
    tile_out[0][2][3][0] = image[3][8];  tile_out[0][2][3][1] = image[3][9];  tile_out[0][2][3][2] = image[3][10];
    tile_out[0][2][3][3] = image[3][11]; tile_out[0][2][3][4] = 32'b0;        tile_out[0][2][3][5] = 32'b0;
    tile_out[0][2][4][0] = image[4][8];  tile_out[0][2][4][1] = image[4][9];  tile_out[0][2][4][2] = image[4][10];
    tile_out[0][2][4][3] = image[4][11]; tile_out[0][2][4][4] = 32'b0;        tile_out[0][2][4][5] = 32'b0;
    tile_out[0][2][5][0] = image[5][8];  tile_out[0][2][5][1] = image[5][9];  tile_out[0][2][5][2] = image[5][10];
    tile_out[0][2][5][3] = image[5][11]; tile_out[0][2][5][4] = 32'b0;        tile_out[0][2][5][5] = 32'b0;
    
    // tile_out[1][0] - Middle-left tile
    tile_out[1][0][0][0] = image[4][0]; tile_out[1][0][0][1] = image[4][1]; tile_out[1][0][0][2] = image[4][2];
    tile_out[1][0][0][3] = image[4][3]; tile_out[1][0][0][4] = image[4][4]; tile_out[1][0][0][5] = image[4][5];
    tile_out[1][0][1][0] = image[5][0]; tile_out[1][0][1][1] = image[5][1]; tile_out[1][0][1][2] = image[5][2];
    tile_out[1][0][1][3] = image[5][3]; tile_out[1][0][1][4] = image[5][4]; tile_out[1][0][1][5] = image[5][5];
    tile_out[1][0][2][0] = image[6][0]; tile_out[1][0][2][1] = image[6][1]; tile_out[1][0][2][2] = image[6][2];
    tile_out[1][0][2][3] = image[6][3]; tile_out[1][0][2][4] = image[6][4]; tile_out[1][0][2][5] = image[6][5];
    tile_out[1][0][3][0] = image[7][0]; tile_out[1][0][3][1] = image[7][1]; tile_out[1][0][3][2] = image[7][2];
    tile_out[1][0][3][3] = image[7][3]; tile_out[1][0][3][4] = image[7][4]; tile_out[1][0][3][5] = image[7][5];
    tile_out[1][0][4][0] = image[8][0]; tile_out[1][0][4][1] = image[8][1]; tile_out[1][0][4][2] = image[8][2];
    tile_out[1][0][4][3] = image[8][3]; tile_out[1][0][4][4] = image[8][4]; tile_out[1][0][4][5] = image[8][5];
    tile_out[1][0][5][0] = image[9][0]; tile_out[1][0][5][1] = image[9][1]; tile_out[1][0][5][2] = image[9][2];
    tile_out[1][0][5][3] = image[9][3]; tile_out[1][0][5][4] = image[9][4]; tile_out[1][0][5][5] = image[9][5];
    
    // tile_out[1][1] - Middle-middle tile
    tile_out[1][1][0][0] = image[4][4]; tile_out[1][1][0][1] = image[4][5]; tile_out[1][1][0][2] = image[4][6];
    tile_out[1][1][0][3] = image[4][7]; tile_out[1][1][0][4] = image[4][8]; tile_out[1][1][0][5] = image[4][9];
    tile_out[1][1][1][0] = image[5][4]; tile_out[1][1][1][1] = image[5][5]; tile_out[1][1][1][2] = image[5][6];
    tile_out[1][1][1][3] = image[5][7]; tile_out[1][1][1][4] = image[5][8]; tile_out[1][1][1][5] = image[5][9];
    tile_out[1][1][2][0] = image[6][4]; tile_out[1][1][2][1] = image[6][5]; tile_out[1][1][2][2] = image[6][6];
    tile_out[1][1][2][3] = image[6][7]; tile_out[1][1][2][4] = image[6][8]; tile_out[1][1][2][5] = image[6][9];
    tile_out[1][1][3][0] = image[7][4]; tile_out[1][1][3][1] = image[7][5]; tile_out[1][1][3][2] = image[7][6];
    tile_out[1][1][3][3] = image[7][7]; tile_out[1][1][3][4] = image[7][8]; tile_out[1][1][3][5] = image[7][9];
    tile_out[1][1][4][0] = image[8][4]; tile_out[1][1][4][1] = image[8][5]; tile_out[1][1][4][2] = image[8][6];
    tile_out[1][1][4][3] = image[8][7]; tile_out[1][1][4][4] = image[8][8]; tile_out[1][1][4][5] = image[8][9];
    tile_out[1][1][5][0] = image[9][4]; tile_out[1][1][5][1] = image[9][5]; tile_out[1][1][5][2] = image[9][6];
    tile_out[1][1][5][3] = image[9][7]; tile_out[1][1][5][4] = image[9][8]; tile_out[1][1][5][5] = image[9][9];
    
    // tile_out[1][2] - Middle-right tile
    tile_out[1][2][0][0] = image[4][8];  tile_out[1][2][0][1] = image[4][9];  tile_out[1][2][0][2] = image[4][10];
    tile_out[1][2][0][3] = image[4][11]; tile_out[1][2][0][4] = 32'b0;        tile_out[1][2][0][5] = 32'b0;
    tile_out[1][2][1][0] = image[5][8];  tile_out[1][2][1][1] = image[5][9];  tile_out[1][2][1][2] = image[5][10];
    tile_out[1][2][1][3] = image[5][11]; tile_out[1][2][1][4] = 32'b0;        tile_out[1][2][1][5] = 32'b0;
    tile_out[1][2][2][0] = image[6][8];  tile_out[1][2][2][1] = image[6][9];  tile_out[1][2][2][2] = image[6][10];
    tile_out[1][2][2][3] = image[6][11]; tile_out[1][2][2][4] = 32'b0;        tile_out[1][2][2][5] = 32'b0;
    tile_out[1][2][3][0] = image[7][8];  tile_out[1][2][3][1] = image[7][9];  tile_out[1][2][3][2] = image[7][10];
    tile_out[1][2][3][3] = image[7][11]; tile_out[1][2][3][4] = 32'b0;        tile_out[1][2][3][5] = 32'b0;
    tile_out[1][2][4][0] = image[8][8];  tile_out[1][2][4][1] = image[8][9];  tile_out[1][2][4][2] = image[8][10];
    tile_out[1][2][4][3] = image[8][11]; tile_out[1][2][4][4] = 32'b0;        tile_out[1][2][4][5] = 32'b0;
    tile_out[1][2][5][0] = image[9][8];  tile_out[1][2][5][1] = image[9][9];  tile_out[1][2][5][2] = image[9][10];
    tile_out[1][2][5][3] = image[9][11]; tile_out[1][2][5][4] = 32'b0;        tile_out[1][2][5][5] = 32'b0;
    
    // tile_out[2][0] - Bottom-left tile
    tile_out[2][0][0][0] = image[8][0]; tile_out[2][0][0][1] = image[8][1]; tile_out[2][0][0][2] = image[8][2];
    tile_out[2][0][0][3] = image[8][3]; tile_out[2][0][0][4] = image[8][4]; tile_out[2][0][0][5] = image[8][5];
    tile_out[2][0][1][0] = image[9][0]; tile_out[2][0][1][1] = image[9][1]; tile_out[2][0][1][2] = image[9][2];
    tile_out[2][0][1][3] = image[9][3]; tile_out[2][0][1][4] = image[9][4]; tile_out[2][0][1][5] = image[9][5];
    tile_out[2][0][2][0] = 32'b0;       tile_out[2][0][2][1] = 32'b0;       tile_out[2][0][2][2] = 32'b0;
    tile_out[2][0][2][3] = 32'b0;       tile_out[2][0][2][4] = 32'b0;       tile_out[2][0][2][5] = 32'b0;
    tile_out[2][0][3][0] = 32'b0;       tile_out[2][0][3][1] = 32'b0;       tile_out[2][0][3][2] = 32'b0;
    tile_out[2][0][3][3] = 32'b0;       tile_out[2][0][3][4] = 32'b0;       tile_out[2][0][3][5] = 32'b0;
    tile_out[2][0][4][0] = 32'b0;       tile_out[2][0][4][1] = 32'b0;       tile_out[2][0][4][2] = 32'b0;
    tile_out[2][0][4][3] = 32'b0;       tile_out[2][0][4][4] = 32'b0;       tile_out[2][0][4][5] = 32'b0;
    tile_out[2][0][5][0] = 32'b0;       tile_out[2][0][5][1] = 32'b0;       tile_out[2][0][5][2] = 32'b0;
    tile_out[2][0][5][3] = 32'b0;       tile_out[2][0][5][4] = 32'b0;       tile_out[2][0][5][5] = 32'b0;
    
    // tile_out[2][1] - Bottom-middle tile
    tile_out[2][1][0][0] = image[8][4]; tile_out[2][1][0][1] = image[8][5]; tile_out[2][1][0][2] = image[8][6];
    tile_out[2][1][0][3] = image[8][7]; tile_out[2][1][0][4] = image[8][8]; tile_out[2][1][0][5] = image[8][9];
    tile_out[2][1][1][0] = image[9][4]; tile_out[2][1][1][1] = image[9][5]; tile_out[2][1][1][2] = image[9][6];
    tile_out[2][1][1][3] = image[9][7]; tile_out[2][1][1][4] = image[9][8]; tile_out[2][1][1][5] = image[9][9];
    tile_out[2][1][2][0] = 32'b0;       tile_out[2][1][2][1] = 32'b0;       tile_out[2][1][2][2] = 32'b0;
    tile_out[2][1][2][3] = 32'b0;       tile_out[2][1][2][4] = 32'b0;       tile_out[2][1][2][5] = 32'b0;
    tile_out[2][1][3][0] = 32'b0;       tile_out[2][1][3][1] = 32'b0;       tile_out[2][1][3][2] = 32'b0;
    tile_out[2][1][3][3] = 32'b0;       tile_out[2][1][3][4] = 32'b0;       tile_out[2][1][3][5] = 32'b0;
    tile_out[2][1][4][0] = 32'b0;       tile_out[2][1][4][1] = 32'b0;       tile_out[2][1][4][2] = 32'b0;
    tile_out[2][1][4][3] = 32'b0;       tile_out[2][1][4][4] = 32'b0;       tile_out[2][1][4][5] = 32'b0;
    tile_out[2][1][5][0] = 32'b0;       tile_out[2][1][5][1] = 32'b0;       tile_out[2][1][5][2] = 32'b0;
    tile_out[2][1][5][3] = 32'b0;       tile_out[2][1][5][4] = 32'b0;       tile_out[2][1][5][5] = 32'b0;
    
    // tile_out[2][2] - Bottom-right tile
    tile_out[2][2][0][0] = image[8][8];  tile_out[2][2][0][1] = image[8][9];  tile_out[2][2][0][2] = image[8][10];
    tile_out[2][2][0][3] = image[8][11]; tile_out[2][2][0][4] = 32'b0;        tile_out[2][2][0][5] = 32'b0;
    tile_out[2][2][1][0] = image[9][8];  tile_out[2][2][1][1] = image[9][9];  tile_out[2][2][1][2] = image[9][10];
    tile_out[2][2][1][3] = image[9][11]; tile_out[2][2][1][4] = 32'b0;        tile_out[2][2][1][5] = 32'b0;
    tile_out[2][2][2][0] = 32'b0;        tile_out[2][2][2][1] = 32'b0;        tile_out[2][2][2][2] = 32'b0;
    tile_out[2][2][2][3] = 32'b0;        tile_out[2][2][2][4] = 32'b0;        tile_out[2][2][2][5] = 32'b0;
    tile_out[2][2][3][0] = 32'b0;        tile_out[2][2][3][1] = 32'b0;        tile_out[2][2][3][2] = 32'b0;
    tile_out[2][2][3][3] = 32'b0;        tile_out[2][2][3][4] = 32'b0;        tile_out[2][2][3][5] = 32'b0;
    tile_out[2][2][4][0] = 32'b0;        tile_out[2][2][4][1] = 32'b0;        tile_out[2][2][4][2] = 32'b0;
    tile_out[2][2][4][3] = 32'b0;        tile_out[2][2][4][4] = 32'b0;        tile_out[2][2][4][5] = 32'b0;
    tile_out[2][2][5][0] = 32'b0;        tile_out[2][2][5][1] = 32'b0;        tile_out[2][2][5][2] = 32'b0;
    tile_out[2][2][5][3] = 32'b0;        tile_out[2][2][5][4] = 32'b0;        tile_out[2][2][5][5] = 32'b0;
end

endmodule
