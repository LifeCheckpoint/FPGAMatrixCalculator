`timescale 1ns / 1ps

module matrix_pointwise_mult_6x6_sim;

logic clk;
logic rst_n;
logic start;
logic [15:0] a [6][6];
logic [15:0] b [6][6];
logic [31:0] c [6][6];
logic done;

matrix_pointwise_mult_6x6 uut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .a(a),
    .b(b),
    .c(c),
    .done(done)
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
        for (int j = 0; j < 6; j++) begin
            a[i][j] = 0;
            b[i][j] = 0;
        end
    
    // Reset
    #20 rst_n = 1;
    #10;
    
    // Test 1: Zero matrices
    $display("\n[TEST 1] Zero Matrices");
    init_zero();
    run_test();
    
    // Test 2: Identity multiplication
    $display("\n[TEST 2] Identity (diagonal=1) × Ones");
    init_identity_ones();
    run_test();
    
    // Test 3: Simple values
    $display("\n[TEST 3] Simple Values (2×3)");
    init_simple();
    run_test();
    
    // Test 4: All ones
    $display("\n[TEST 4] All Ones");
    init_all_ones();
    run_test();
    
    // Test 5: Sequential values
    $display("\n[TEST 5] Sequential (1-36) × (1-36)");
    init_sequential();
    run_test();
    
    #50;
    $display("\n=== All Tests Complete ===\n");
    $finish;
end

task init_zero;
    begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) begin
                a[i][j] = 0;
                b[i][j] = 0;
            end
    end
endtask

task init_identity_ones;
    begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) begin
                a[i][j] = (i == j) ? 1 : 0;
                b[i][j] = 1;
            end
    end
endtask

task init_simple;
    begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) begin
                a[i][j] = 2;
                b[i][j] = 3;
            end
    end
endtask

task init_all_ones;
    begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) begin
                a[i][j] = 1;
                b[i][j] = 1;
            end
    end
endtask

task init_sequential;
    begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) begin
                a[i][j] = i * 6 + j + 1;
                b[i][j] = i * 6 + j + 1;
            end
    end
endtask

task run_test;
    begin
        print_input();
        
        // Start operation
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for done
        wait(done == 1);
        @(posedge clk);
        #1;
        
        print_output();
        
        // Wait for done to clear
        wait(done == 0);
        @(posedge clk);
        #1;
    end
endtask

task print_input;
    begin
        $display("Matrix A (6x6):");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%5d ", a[i][j]);
            $display("");
        end
        $display("Matrix B (6x6):");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%5d ", b[i][j]);
            $display("");
        end
    end
endtask

task print_output;
    begin
        $display("Result C = A .* B (6x6):");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++)
                $write("%8d ", c[i][j]);
            $display("");
        end
    end
endtask

initial #100000 $finish;

endmodule