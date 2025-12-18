`timescale 1ns / 1ps

module tile_controller_sim;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] kernel_in  [0:2][0:2];
    logic [31:0] tile_in    [0:5][0:5];
    logic [31:0] result_out [0:3][0:3];
    logic        done;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    tile_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .kernel_in(kernel_in),
        .tile_in(tile_in),
        .result_out(result_out),
        .done(done)
    );

    // Test stimulus
    initial begin
        // Initialize all inputs to avoid X
        rst_n = 0;
        start = 0;
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 32'd0;
            end
        end
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                tile_in[i][j] = 32'd0;
            end
        end
        
        // Reset
        #30 rst_n = 1;
        #50;

        // Test case 1: Identity-like kernel
        $display("\n=== Test 1: Identity-like kernel ===");
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = (i == 1 && j == 1) ? 32'd1 : 32'd0;
            end
        end
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                tile_in[i][j] = i * 6 + j + 1;
            end
        end
        display_inputs();
        run_test();

        // Test case 2: All-ones kernel
        $display("\n=== Test 2: All-ones kernel ===");
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 32'd1;
            end
        end
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                tile_in[i][j] = 32'd1;
            end
        end
        display_inputs();
        run_test();

        // Test case 3: Custom values
        $display("\n=== Test 3: Custom kernel and tile ===");
        kernel_in[0][0] = 32'd1; kernel_in[0][1] = 32'd2; kernel_in[0][2] = 32'd3;
        kernel_in[1][0] = 32'd4; kernel_in[1][1] = 32'd5; kernel_in[1][2] = 32'd6;
        kernel_in[2][0] = 32'd7; kernel_in[2][1] = 32'd8; kernel_in[2][2] = 32'd9;
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                tile_in[i][j] = (i + j) % 10 + 1;
            end
        end
        display_inputs();
        run_test();

        #100 $finish;
    end

    // Run test task
    task run_test;
        begin
            @(posedge clk);
            #1;
            start = 1;
            @(posedge clk);
            #1;
            start = 0;
            
            // Wait for done to go high (computation complete)
            @(posedge done);
            @(posedge clk);
            #1;
            
            display_result();
            
            @(posedge clk);
            #1;
        end
    endtask

    // Display inputs
    task display_inputs;
        $display("Kernel 3x3:");
        for (int i = 0; i < 3; i++) begin
            $write("  ");
            for (int j = 0; j < 3; j++) begin
                $write("%4d ", kernel_in[i][j]);
            end
            $write("\n");
        end
        
        $display("Tile 6x6:");
        for (int i = 0; i < 6; i++) begin
            $write("  ");
            for (int j = 0; j < 6; j++) begin
                $write("%4d ", tile_in[i][j]);
            end
            $write("\n");
        end
    endtask

    // Display result
    task display_result;
        $display("Result 4x4:");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++) begin
                $write("%4d ", result_out[i][j]);
            end
            $write("\n");
        end
    endtask

    // Watchdog timer
    initial begin
        #100000; // 100us timeout
        $display("\nError: Simulation timed out! tile_controller did not complete in time.");
        $finish;
    end

endmodule