`timescale 1ns / 1ps

module winograd_conv_10x12_sim;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] image_in   [0:9][0:11];
    logic [31:0] kernel_in  [0:2][0:2];
    logic [31:0] result_out [0:7][0:9];
    logic        done;

    winograd_conv_10x12 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .image_in(image_in),
        .kernel_in(kernel_in),
        .result_out(result_out),
        .done(done)
    );
    
    // Debug monitor
    always @(posedge clk) begin
        if (dut.state == dut.ST_LOAD) begin
            $display("Time=%0t: LOAD state - round_idx=%0d, tile_i=%0d, tile_j=%0d",
                     $time, dut.round_idx, dut.tile_i, dut.tile_j);
        end
        if (dut.state == dut.ST_WRITE) begin
            $display("Time=%0t: WRITE state - round_idx=%0d, tile_i=%0d, tile_j=%0d, writing to result_tiles[%0d][%0d]",
                     $time, dut.round_idx, dut.tile_i, dut.tile_j, dut.tile_i, dut.tile_j);
        end
        if (dut.tc_inst.state == dut.tc_inst.S_IDLE && dut.tc_start) begin
            $display("Time=%0t: tile_controller START - Sampling tile_in", $time);
        end
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        start = 0;
        
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                image_in[i][j] = 32'(i * 12 + j + 1);
            end
        end
        
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 32'(i * 3 + j + 1);
            end
        end

        #20 rst_n = 1;
        #20 start = 1;
        #10 start = 0;

        $display("Input Image (10x12):");
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                $write("%d ", image_in[i][j]);
            end
            $write("\n");
        end
        
        $display("\nInput Kernel (3x3):");
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                $write("%d ", kernel_in[i][j]);
            end
            $write("\n");
        end

        wait(done);
        
        $display("\nDEBUG: Checking internal result_tiles:");
        for (int ti = 0; ti < 3; ti++) begin
            for (int tj = 0; tj < 3; tj++) begin
                $display("Tile[%0d][%0d]:", ti, tj);
                for (int i = 0; i < 4; i++) begin
                    $write("  ");
                    for (int j = 0; j < 4; j++) begin
                        $write("%d ", dut.result_tiles[ti][tj][i][j]);
                    end
                    $write("\n");
                end
            end
        end
        
        $display("\nDEBUG: Transform output (before division):");
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 10; j++) begin
                $write("%d ", dut.transform_out[i][j]);
            end
            $write("\n");
        end

        $display("\nOutput Result (8x10):");
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 10; j++) begin
                $write("%d ", result_out[i][j]);
            end
            $write("\n");
        end

        $display("\nSimulation completed");
        #1000 $finish;
    end

endmodule