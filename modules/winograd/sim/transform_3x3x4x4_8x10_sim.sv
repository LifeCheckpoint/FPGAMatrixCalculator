`timescale 1ns / 1ps

module transform_3x3x4x4_8x10_sim;

logic [31:0] tile  [0:2][0:2][0:3][0:3];
logic [31:0] image [0:7][0:9];

transform_3x3x4x4_8x10 dut (.*);

initial begin
    $display("=== Test 1: Sequential numbers ===");
    
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            for (int k = 0; k < 4; k++)
                for (int l = 0; l < 4; l++)
                    tile[i][j][k][l] = (i*3+j)*16 + k*4 + l + 1;
    
    #10;
    
    $display("Input tiles:");
    for (int i = 0; i < 3; i++) begin
        for (int j = 0; j < 3; j++) begin
            $display("Tile[%0d][%0d]:", i, j);
            for (int k = 0; k < 4; k++) begin
                for (int l = 0; l < 4; l++)
                    $write("%4d ", tile[i][j][k][l]);
                $display("");
            end
            $display("");
        end
    end
    
    $display("Output image (8x10):");
    for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 10; j++)
            $write("%4d ", image[i][j]);
        $display("");
    end
    
    #20;
    
    $display("\n=== Test 2: All same value (100) ===");
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            for (int k = 0; k < 4; k++)
                for (int l = 0; l < 4; l++)
                    tile[i][j][k][l] = 100;
    
    #10;
    
    $display("Output image (8x10):");
    for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 10; j++)
            $write("%4d ", image[i][j]);
        $display("");
    end
    
    #20;
    $finish;
end

endmodule