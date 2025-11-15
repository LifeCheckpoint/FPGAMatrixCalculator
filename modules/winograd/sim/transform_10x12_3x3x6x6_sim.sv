`timescale 1ns / 1ps

module transform_10x12_3x3x6x6_sim;

logic [31:0] image    [0:9][0:11];
logic [31:0] tile_out [0:2][0:2][0:5][0:5];

transform_10x12_3x3x6x6 dut (.*);

initial begin
    $display("=== Test 1: Sequential numbers ===");
    
    for (int i = 0; i < 10; i++)
        for (int j = 0; j < 12; j++)
            image[i][j] = i*12 + j + 1;
    
    #10;
    
    $display("Input image:");
    for (int i = 0; i < 10; i++) begin
        for (int j = 0; j < 12; j++)
            $write("%4d ", image[i][j]);
        $display("");
    end
    
    #10;
    
    $display("\nOutput tiles:");
    for (int ti = 0; ti < 3; ti++) begin
        for (int tj = 0; tj < 3; tj++) begin
            $display("Tile[%0d][%0d]:", ti, tj);
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++)
                    $write("%4d ", tile_out[ti][tj][i][j]);
                $display("");
            end
            $display("");
        end
    end
    
    #20;
    
    $display("=== Test 2: Check padding (all 50) ===");
    for (int i = 0; i < 10; i++)
        for (int j = 0; j < 12; j++)
            image[i][j] = 50;
    
    #10;
    
    $display("Edge tiles should show zeros in padding areas:");
    $display("Tile[0][2]:");
    for (int i = 0; i < 6; i++) begin
        for (int j = 0; j < 6; j++)
            $write("%4d ", tile_out[0][2][i][j]);
        $display("");
    end
    
    $display("\nTile[2][2]:");
    for (int i = 0; i < 6; i++) begin
        for (int j = 0; j < 6; j++)
            $write("%4d ", tile_out[2][2][i][j]);
        $display("");
    end
    
    #20;
    $finish;
end

endmodule