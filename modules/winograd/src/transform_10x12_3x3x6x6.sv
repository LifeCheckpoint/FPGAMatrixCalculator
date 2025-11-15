`timescale 1ns / 1ps

module transform_10x12_3x3x6x6 (
    input  logic [15:0] image    [0:9][0:11],
    output logic [15:0] tile_out [0:2][0:2][0:5][0:5]
);

always_comb begin
    tile_out[0][0] = '{
        image[0][0], image[0][1], image[0][2], image[0][3], image[0][4], image[0][5],
        image[1][0], image[1][1], image[1][2], image[1][3], image[1][4], image[1][5],
        image[2][0], image[2][1], image[2][2], image[2][3], image[2][4], image[2][5],
        image[3][0], image[3][1], image[3][2], image[3][3], image[3][4], image[3][5],
        image[4][0], image[4][1], image[4][2], image[4][3], image[4][4], image[4][5],
        image[5][0], image[5][1], image[5][2], image[5][3], image[5][4], image[5][5]
    };
    tile_out[0][1] = '{
        image[0][4], image[0][5], image[0][6], image[0][7], image[0][8], image[0][9],
        image[1][4], image[1][5], image[1][6], image[1][7], image[1][8], image[1][9],
        image[2][4], image[2][5], image[2][6], image[2][7], image[2][8], image[2][9],
        image[3][4], image[3][5], image[3][6], image[3][7], image[3][8], image[3][9],
        image[4][4], image[4][5], image[4][6], image[4][7], image[4][8], image[4][9],
        image[5][4], image[5][5], image[5][6], image[5][7], image[5][8], image[5][9]
    };
    tile_out[0][2] = '{
        image[0][8],  image[0][9],  image[0][10], image[0][11], 16'b0, 16'b0,
        image[1][8],  image[1][9],  image[1][10], image[1][11], 16'b0, 16'b0,
        image[2][8],  image[2][9],  image[2][10], image[2][11], 16'b0, 16'b0,
        image[3][8],  image[3][9],  image[3][10], image[3][11], 16'b0, 16'b0,
        image[4][8],  image[4][9],  image[4][10], image[4][11], 16'b0, 16'b0,
        image[5][8],  image[5][9],  image[5][10], image[5][11], 16'b0, 16'b0
    };
    tile_out[1][0] = '{
        image[4][0], image[4][1], image[4][2], image[4][3], image[4][4], image[4][5],
        image[5][0], image[5][1], image[5][2], image[5][3], image[5][4], image[5][5],
        image[6][0], image[6][1], image[6][2], image[6][3], image[6][4], image[6][5],
        image[7][0], image[7][1], image[7][2], image[7][3], image[7][4], image[7][5],
        image[8][0], image[8][1], image[8][2], image[8][3], image[8][4], image[8][5],
        image[9][0], image[9][1], image[9][2], image[9][3], image[9][4], image[9][5]
    };
    tile_out[1][1] = '{
        image[4][4], image[4][5], image[4][6], image[4][7], image[4][8], image[4][9],
        image[5][4], image[5][5], image[5][6], image[5][7], image[5][8], image[5][9],
        image[6][4], image[6][5], image[6][6], image[6][7], image[6][8], image[6][9],
        image[7][4], image[7][5], image[7][6], image[7][7], image[7][8], image[7][9],
        image[8][4], image[8][5], image[8][6], image[8][7], image[8][8], image[8][9],
        image[9][4], image[9][5], image[9][6], image[9][7], image[9][8], image[9][9]
    };
    tile_out[1][2] = '{
        image[4][8],  image[4][9],  image[4][10], image[4][11], 16'b0, 16'b0,
        image[5][8],  image[5][9],  image[5][10], image[5][11], 16'b0, 16'b0,
        image[6][8],  image[6][9],  image[6][10], image[6][11], 16'b0, 16'b0,
        image[7][8],  image[7][9],  image[7][10], image[7][11], 16'b0, 16'b0,
        image[8][8],  image[8][9],  image[8][10], image[8][11], 16'b0, 16'b0,
        image[9][8],  image[9][9],  image[9][10], image[9][11], 16'b0, 16'b0
    };
    tile_out[2][0] = '{
        image[8][0], image[8][1], image[8][2], image[8][3], image[8][4], image[8][5],
        image[9][0], image[9][1], image[9][2], image[9][3], image[9][4], image[9][5],
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0
    };
    tile_out[2][1] = '{
        image[8][4], image[8][5], image[8][6], image[8][7], image[8][8], image[8][9],
        image[9][4], image[9][5], image[9][6], image[9][7], image[9][8], image[9][9],
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0,
        16'b0,       16'b0,       16'b0,       16'b0,       16'b0,       16'b0
    };
    tile_out[2][2] = '{
        image[8][8],  image[8][9],  image[8][10], image[8][11], 16'b0, 16'b0,
        image[9][8],  image[9][9],  image[9][10], image[9][11], 16'b0, 16'b0,
        16'b0,        16'b0,        16'b0,        16'b0,        16'b0, 16'b0,
        16'b0,        16'b0,        16'b0,        16'b0,        16'b0, 16'b0,
        16'b0,        16'b0,        16'b0,        16'b0,        16'b0, 16'b0,
        16'b0,        16'b0,        16'b0,        16'b0,        16'b0, 16'b0
    };
end    

endmodule
