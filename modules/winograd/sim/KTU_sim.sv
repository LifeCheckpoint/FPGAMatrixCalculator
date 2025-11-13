`timescale 1ns / 1ps

module kernel_transform_unit_sim;

logic clk;
logic rst_n;
logic [15:0] kernel_in [0:2][0:2];
logic [15:0] kernel_out [0:5][0:5];
logic transform_done;

kernel_transform_unit uut (
    .clk(clk),
    .rst_n(rst_n),
    .kernel_in(kernel_in),
    .kernel_out(kernel_out),
    .transform_done(transform_done)
);

// Clock generation: 10ns period
always #5 clk = ~clk;

// Test stimulus
initial begin
    // Initialize
    clk = 0;
    rst_n = 0;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
            kernel_in[i][j] = 0;
    
    // Reset
    #20 rst_n = 1;
    
    // Test 1: Identity center
    $display("\n[TEST 1] Identity Center");
    kernel_in[0][0]=0; kernel_in[0][1]=0; kernel_in[0][2]=0;
    kernel_in[1][0]=0; kernel_in[1][1]=1; kernel_in[1][2]=0;
    kernel_in[2][0]=0; kernel_in[2][1]=0; kernel_in[2][2]=0;
    print_matrix();
    wait_done();
    
    // Test 2: All ones
    $display("\n[TEST 2] All Ones");
    kernel_in[0][0]=1; kernel_in[0][1]=1; kernel_in[0][2]=1;
    kernel_in[1][0]=1; kernel_in[1][1]=1; kernel_in[1][2]=1;
    kernel_in[2][0]=1; kernel_in[2][1]=1; kernel_in[2][2]=1;
    print_matrix();
    wait_done();
    
    // Test 3: Edge detection
    $display("\n[TEST 3] Edge Detection");
    kernel_in[0][0]=-1; kernel_in[0][1]=-1; kernel_in[0][2]=-1;
    kernel_in[1][0]=-1; kernel_in[1][1]= 8; kernel_in[1][2]=-1;
    kernel_in[2][0]=-1; kernel_in[2][1]=-1; kernel_in[2][2]=-1;
    print_matrix();
    wait_done();
    
    // Test 4: Sequential
    $display("\n[TEST 4] Sequential 1-9");
    kernel_in[0][0]=1; kernel_in[0][1]=2; kernel_in[0][2]=3;
    kernel_in[1][0]=4; kernel_in[1][1]=5; kernel_in[1][2]=6;
    kernel_in[2][0]=7; kernel_in[2][1]=8; kernel_in[2][2]=9;
    print_matrix();
    wait_done();
    
    // Test 5: Sobel
    $display("\n[TEST 5] Sobel Horizontal");
    kernel_in[0][0]=-1; kernel_in[0][1]=0; kernel_in[0][2]=1;
    kernel_in[1][0]=-2; kernel_in[1][1]=0; kernel_in[1][2]=2;
    kernel_in[2][0]=-1; kernel_in[2][1]=0; kernel_in[2][2]=1;
    print_matrix();
    wait_done();
    
    #50;
    $display("\n=== All Tests Complete ===\n");
    $finish;
end

task print_matrix;
    begin
        $display("Input 3x3:");
        for (int i = 0; i < 3; i++) begin
            $write("  ");
            for (int j = 0; j < 3; j++)
                $write("%4d ", $signed(kernel_in[i][j]));
            $display("");
        end
    end
endtask

task wait_done;
    begin
        // wait a clock period to sample
        @(posedge clk);
        #1;
        
        // ready for S_CALC_T statu（transform_done=0）
        wait(transform_done == 0);
        
        // waiting for calc
        @(posedge transform_done);
        @(posedge clk);
        #1;
        $display("Output 6x6:");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%6d ", $signed(kernel_out[i][j]));
            $display("");
        end
        
        wait(transform_done == 0);
        @(posedge clk);
        #1;
    end
endtask

initial #100000 $finish;

endmodule