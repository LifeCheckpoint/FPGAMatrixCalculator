`timescale 1ns / 1ps

module tile_transform_unit_sim;

logic clk;
logic rst_n;
logic start;
logic [31:0] tile_in [0:5][0:5];
logic [31:0] tile_out [0:5][0:5];
logic transform_done;

tile_transform_unit uut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .tile_in(tile_in),
    .tile_out(tile_out),
    .transform_done(transform_done)
);

// Clock generation: 10ns period
always #5 clk = ~clk;

// Test stimulus
initial begin
    // Initialize
    clk = 0;
    rst_n = 0;
    start = 0;
    for (int i = 0; i < 6; i++)
        for (int j = 0; j < 6; j++)
            tile_in[i][j] = 0;
    
    // Reset
    #20 rst_n = 1;
    
    // Test 1: Identity center
    $display("\n[TEST 1] Identity Center");
    tile_in[0][0]=0; tile_in[0][1]=0; tile_in[0][2]=0; tile_in[0][3]=0; tile_in[0][4]=0; tile_in[0][5]=0;
    tile_in[1][0]=0; tile_in[1][1]=0; tile_in[1][2]=0; tile_in[1][3]=0; tile_in[1][4]=0; tile_in[1][5]=0;
    tile_in[2][0]=0; tile_in[2][1]=0; tile_in[2][2]=1; tile_in[2][3]=0; tile_in[2][4]=0; tile_in[2][5]=0;
    tile_in[3][0]=0; tile_in[3][1]=0; tile_in[3][2]=0; tile_in[3][3]=0; tile_in[3][4]=0; tile_in[3][5]=0;
    tile_in[4][0]=0; tile_in[4][1]=0; tile_in[4][2]=0; tile_in[4][3]=0; tile_in[4][4]=0; tile_in[4][5]=0;
    tile_in[5][0]=0; tile_in[5][1]=0; tile_in[5][2]=0; tile_in[5][3]=0; tile_in[5][4]=0; tile_in[5][5]=0;
    print_matrix();
    wait_done();
    
    // Test 2: All ones
    $display("\n[TEST 2] All Ones");
    tile_in[0][0]=1; tile_in[0][1]=1; tile_in[0][2]=1; tile_in[0][3]=1; tile_in[0][4]=1; tile_in[0][5]=1;
    tile_in[1][0]=1; tile_in[1][1]=1; tile_in[1][2]=1; tile_in[1][3]=1; tile_in[1][4]=1; tile_in[1][5]=1;
    tile_in[2][0]=1; tile_in[2][1]=1; tile_in[2][2]=1; tile_in[2][3]=1; tile_in[2][4]=1; tile_in[2][5]=1;
    tile_in[3][0]=1; tile_in[3][1]=1; tile_in[3][2]=1; tile_in[3][3]=1; tile_in[3][4]=1; tile_in[3][5]=1;
    tile_in[4][0]=1; tile_in[4][1]=1; tile_in[4][2]=1; tile_in[4][3]=1; tile_in[4][4]=1; tile_in[4][5]=1;
    tile_in[5][0]=1; tile_in[5][1]=1; tile_in[5][2]=1; tile_in[5][3]=1; tile_in[5][4]=1; tile_in[5][5]=1;
    print_matrix();
    wait_done();
    
    // Test 3: Edge pattern
    $display("\n[TEST 3] Edge Pattern");
    tile_in[0][0]=1; tile_in[0][1]=1; tile_in[0][2]=1; tile_in[0][3]=1; tile_in[0][4]=1; tile_in[0][5]=1;
    tile_in[1][0]=1; tile_in[1][1]=0; tile_in[1][2]=0; tile_in[1][3]=0; tile_in[1][4]=0; tile_in[1][5]=1;
    tile_in[2][0]=1; tile_in[2][1]=0; tile_in[2][2]=0; tile_in[2][3]=0; tile_in[2][4]=0; tile_in[2][5]=1;
    tile_in[3][0]=1; tile_in[3][1]=0; tile_in[3][2]=0; tile_in[3][3]=0; tile_in[3][4]=0; tile_in[3][5]=1;
    tile_in[4][0]=1; tile_in[4][1]=0; tile_in[4][2]=0; tile_in[4][3]=0; tile_in[4][4]=0; tile_in[4][5]=1;
    tile_in[5][0]=1; tile_in[5][1]=1; tile_in[5][2]=1; tile_in[5][3]=1; tile_in[5][4]=1; tile_in[5][5]=1;
    print_matrix();
    wait_done();
    
    // Test 4: Sequential
    $display("\n[TEST 4] Sequential 1-36");
    tile_in[0][0]=1;  tile_in[0][1]=2;  tile_in[0][2]=3;  tile_in[0][3]=4;  tile_in[0][4]=5;  tile_in[0][5]=6;
    tile_in[1][0]=7;  tile_in[1][1]=8;  tile_in[1][2]=9;  tile_in[1][3]=10; tile_in[1][4]=11; tile_in[1][5]=12;
    tile_in[2][0]=13; tile_in[2][1]=14; tile_in[2][2]=15; tile_in[2][3]=16; tile_in[2][4]=17; tile_in[2][5]=18;
    tile_in[3][0]=19; tile_in[3][1]=20; tile_in[3][2]=21; tile_in[3][3]=22; tile_in[3][4]=23; tile_in[3][5]=24;
    tile_in[4][0]=25; tile_in[4][1]=26; tile_in[4][2]=27; tile_in[4][3]=28; tile_in[4][4]=29; tile_in[4][5]=30;
    tile_in[5][0]=31; tile_in[5][1]=32; tile_in[5][2]=33; tile_in[5][3]=34; tile_in[5][4]=35; tile_in[5][5]=36;
    print_matrix();
    wait_done();
    
    // Test 5: Diagonal
    $display("\n[TEST 5] Diagonal Pattern");
    tile_in[0][0]=1; tile_in[0][1]=0; tile_in[0][2]=0; tile_in[0][3]=0; tile_in[0][4]=0; tile_in[0][5]=0;
    tile_in[1][0]=0; tile_in[1][1]=2; tile_in[1][2]=0; tile_in[1][3]=0; tile_in[1][4]=0; tile_in[1][5]=0;
    tile_in[2][0]=0; tile_in[2][1]=0; tile_in[2][2]=3; tile_in[2][3]=0; tile_in[2][4]=0; tile_in[2][5]=0;
    tile_in[3][0]=0; tile_in[3][1]=0; tile_in[3][2]=0; tile_in[3][3]=4; tile_in[3][4]=0; tile_in[3][5]=0;
    tile_in[4][0]=0; tile_in[4][1]=0; tile_in[4][2]=0; tile_in[4][3]=0; tile_in[4][4]=5; tile_in[4][5]=0;
    tile_in[5][0]=0; tile_in[5][1]=0; tile_in[5][2]=0; tile_in[5][3]=0; tile_in[5][4]=0; tile_in[5][5]=6;
    print_matrix();
    wait_done();
    
    #50;
    $display("\n=== All Tests Complete ===\n");
    $finish;
end

task print_matrix;
    begin
        $display("Input 6x6:");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%4d ", $signed(tile_in[i][j]));
            $display("");
        end
    end
endtask

task wait_done;
    begin
        @(posedge clk);
        #1;
        
        // Trigger start
        start = 1;
        @(posedge clk);
        #1;
        start = 0;
        
        // Wait for completion
        @(posedge transform_done);
        @(posedge clk);
        #1;
        $display("Output 6x6:");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%6d ", $signed(tile_out[i][j]));
            $display("");
        end
        
        wait(transform_done == 0);
        @(posedge clk);
        #1;
    end
endtask

initial #100000 $finish;

endmodule