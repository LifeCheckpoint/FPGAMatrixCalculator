`timescale 1ns / 1ps

module winograd_conv_10x12_sim;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] image_in   [0:9][0:11];
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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        start = 0;
        
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 12; j++) begin
                image_in[i][j] = 32'(i * 12 + j + 1) % 20;
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

        #1000;

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