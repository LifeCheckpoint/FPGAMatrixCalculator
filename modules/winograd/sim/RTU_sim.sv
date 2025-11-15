`timescale 1ns / 1ps

module reverse_transform_unit_sim;

logic clk;
logic rst_n;
logic start;
logic [31:0] matrix_in [0:5][0:5];
logic [31:0] matrix_out [0:3][0:3];
logic transform_done;

reverse_transform_unit uut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .matrix_in(matrix_in),
    .matrix_out(matrix_out),
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
            matrix_in[i][j] = 0;
    
    // Reset
    #20 rst_n = 1;
    
    // Test 1: Identity center
    $display("\n[TEST 1] Identity Center");
    matrix_in[0][0]=0; matrix_in[0][1]=0; matrix_in[0][2]=0; matrix_in[0][3]=0; matrix_in[0][4]=0; matrix_in[0][5]=0;
    matrix_in[1][0]=0; matrix_in[1][1]=0; matrix_in[1][2]=0; matrix_in[1][3]=0; matrix_in[1][4]=0; matrix_in[1][5]=0;
    matrix_in[2][0]=0; matrix_in[2][1]=0; matrix_in[2][2]=1; matrix_in[2][3]=0; matrix_in[2][4]=0; matrix_in[2][5]=0;
    matrix_in[3][0]=0; matrix_in[3][1]=0; matrix_in[3][2]=0; matrix_in[3][3]=0; matrix_in[3][4]=0; matrix_in[3][5]=0;
    matrix_in[4][0]=0; matrix_in[4][1]=0; matrix_in[4][2]=0; matrix_in[4][3]=0; matrix_in[4][4]=0; matrix_in[4][5]=0;
    matrix_in[5][0]=0; matrix_in[5][1]=0; matrix_in[5][2]=0; matrix_in[5][3]=0; matrix_in[5][4]=0; matrix_in[5][5]=0;
    print_matrix();
    wait_done();
    
    // Test 2: All ones
    $display("\n[TEST 2] All Ones");
    matrix_in[0][0]=1; matrix_in[0][1]=1; matrix_in[0][2]=1; matrix_in[0][3]=1; matrix_in[0][4]=1; matrix_in[0][5]=1;
    matrix_in[1][0]=1; matrix_in[1][1]=1; matrix_in[1][2]=1; matrix_in[1][3]=1; matrix_in[1][4]=1; matrix_in[1][5]=1;
    matrix_in[2][0]=1; matrix_in[2][1]=1; matrix_in[2][2]=1; matrix_in[2][3]=1; matrix_in[2][4]=1; matrix_in[2][5]=1;
    matrix_in[3][0]=1; matrix_in[3][1]=1; matrix_in[3][2]=1; matrix_in[3][3]=1; matrix_in[3][4]=1; matrix_in[3][5]=1;
    matrix_in[4][0]=1; matrix_in[4][1]=1; matrix_in[4][2]=1; matrix_in[4][3]=1; matrix_in[4][4]=1; matrix_in[4][5]=1;
    matrix_in[5][0]=1; matrix_in[5][1]=1; matrix_in[5][2]=1; matrix_in[5][3]=1; matrix_in[5][4]=1; matrix_in[5][5]=1;
    print_matrix();
    wait_done();
    
    // Test 3: Sequential 1-36
    $display("\n[TEST 3] Sequential 1-36");
    matrix_in[0][0]= 1; matrix_in[0][1]= 2; matrix_in[0][2]= 3; matrix_in[0][3]= 4; matrix_in[0][4]= 5; matrix_in[0][5]= 6;
    matrix_in[1][0]= 7; matrix_in[1][1]= 8; matrix_in[1][2]= 9; matrix_in[1][3]=10; matrix_in[1][4]=11; matrix_in[1][5]=12;
    matrix_in[2][0]=13; matrix_in[2][1]=14; matrix_in[2][2]=15; matrix_in[2][3]=16; matrix_in[2][4]=17; matrix_in[2][5]=18;
    matrix_in[3][0]=19; matrix_in[3][1]=20; matrix_in[3][2]=21; matrix_in[3][3]=22; matrix_in[3][4]=23; matrix_in[3][5]=24;
    matrix_in[4][0]=25; matrix_in[4][1]=26; matrix_in[4][2]=27; matrix_in[4][3]=28; matrix_in[4][4]=29; matrix_in[4][5]=30;
    matrix_in[5][0]=31; matrix_in[5][1]=32; matrix_in[5][2]=33; matrix_in[5][3]=34; matrix_in[5][4]=35; matrix_in[5][5]=36;
    print_matrix();
    wait_done();
    
    // Test 4: Diagonal pattern
    $display("\n[TEST 4] Diagonal Pattern");
    matrix_in[0][0]=10; matrix_in[0][1]= 0; matrix_in[0][2]= 0; matrix_in[0][3]= 0; matrix_in[0][4]= 0; matrix_in[0][5]= 0;
    matrix_in[1][0]= 0; matrix_in[1][1]=10; matrix_in[1][2]= 0; matrix_in[1][3]= 0; matrix_in[1][4]= 0; matrix_in[1][5]= 0;
    matrix_in[2][0]= 0; matrix_in[2][1]= 0; matrix_in[2][2]=10; matrix_in[2][3]= 0; matrix_in[2][4]= 0; matrix_in[2][5]= 0;
    matrix_in[3][0]= 0; matrix_in[3][1]= 0; matrix_in[3][2]= 0; matrix_in[3][3]=10; matrix_in[3][4]= 0; matrix_in[3][5]= 0;
    matrix_in[4][0]= 0; matrix_in[4][1]= 0; matrix_in[4][2]= 0; matrix_in[4][3]= 0; matrix_in[4][4]=10; matrix_in[4][5]= 0;
    matrix_in[5][0]= 0; matrix_in[5][1]= 0; matrix_in[5][2]= 0; matrix_in[5][3]= 0; matrix_in[5][4]= 0; matrix_in[5][5]=10;
    print_matrix();
    wait_done();
    
    // Test 5: Mixed positive and negative
    $display("\n[TEST 5] Mixed Positive and Negative");
    matrix_in[0][0]= 5; matrix_in[0][1]=-3; matrix_in[0][2]= 2; matrix_in[0][3]=-1; matrix_in[0][4]= 4; matrix_in[0][5]=-2;
    matrix_in[1][0]=-4; matrix_in[1][1]= 6; matrix_in[1][2]=-5; matrix_in[1][3]= 3; matrix_in[1][4]=-2; matrix_in[1][5]= 1;
    matrix_in[2][0]= 3; matrix_in[2][1]=-2; matrix_in[2][2]= 7; matrix_in[2][3]=-4; matrix_in[2][4]= 1; matrix_in[2][5]=-3;
    matrix_in[3][0]=-1; matrix_in[3][1]= 4; matrix_in[3][2]=-3; matrix_in[3][3]= 8; matrix_in[3][4]=-5; matrix_in[3][5]= 2;
    matrix_in[4][0]= 2; matrix_in[4][1]=-5; matrix_in[4][2]= 1; matrix_in[4][3]=-2; matrix_in[4][4]= 6; matrix_in[4][5]=-4;
    matrix_in[5][0]=-3; matrix_in[5][1]= 1; matrix_in[5][2]=-4; matrix_in[5][3]= 2; matrix_in[5][4]=-1; matrix_in[5][5]= 5;
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
                $write("%4d ", $signed(matrix_in[i][j]));
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
        $display("Output 4x4:");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++)
                $write("%6d ", $signed(matrix_out[i][j]));
            $display("");
        end
        
        wait(transform_done == 0);
        @(posedge clk);
        #1;
    end
endtask

initial #100000 $finish;

endmodule