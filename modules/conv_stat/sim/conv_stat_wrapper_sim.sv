`timescale 1ns / 1ps

module conv_stat_wrapper_sim;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] kernel_in  [0:2][0:2];
    logic [31:0] result_out [0:7][0:9];
    logic        done;
    logic [31:0] cycle_count;

    conv_stat_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .kernel_in(kernel_in),
        .result_out(result_out),
        .done(done),
        .cycle_count(cycle_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        rst_n = 0;
        start = 0;
        
        // Initialize kernel (3x3 identity-like kernel)
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 32'(i * 3 + j + 1);
            end
        end

        // Reset
        #20 rst_n = 1;
        
        $display("=================================================");
        $display("Convolution Statistics Wrapper Simulation");
        $display("=================================================");
        
        $display("\nInput Kernel (3x3):");
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                $write("%d ", kernel_in[i][j]);
            end
            $write("\n");
        end
        
        $display("\nInput Image is loaded from ROM (10x12)");
        $display("Starting convolution...\n");

        // Start convolution
        #20 start = 1;
        #10 start = 0;

        // Wait for completion
        wait(done);
        $display("Time=%0t: [TEST] Done signal detected, waiting for cycle count to latch...", $time);
        
        // CRITICAL: Wait for the cycle counter to latch the final count
        // The latch happens when done && counting is detected
        // Need to wait for the latch to complete
        @(posedge clk);
        @(posedge clk);  // Extra cycle to ensure latch completes
        
        $display("\n=================================================");
        $display("First Convolution Completed!");
        $display("=================================================");
        $display("Time=%0t: [TEST] Reading cycle_count=%0d, cycle_counter=%0d, counting=%0b",
            $time, cycle_count, dut.cycle_counter, dut.counting);
        $display("Total Cycle Count: %0d", cycle_count);
        
        $display("\nOutput Result (8x10):");
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 10; j++) begin
                $write("%10d ", result_out[i][j]);
            end
            $write("\n");
        end

        // Wait for done to go low
        $display("Time=%0t: [TEST] Waiting for done to go low...", $time);
        #20 start = 0;
        wait(!done);
        $display("Time=%0t: [TEST] Done signal went low, module back to IDLE", $time);
        
        $display("\n=================================================");
        $display("Starting Second Convolution with New Kernel");
        $display("=================================================");
        
        // Change kernel (use different values)
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                kernel_in[i][j] = 32'((2 - i) * 3 + (2 - j) + 1);
            end
        end
        
        $display("Time=%0t: [TEST] Kernel updated in testbench", $time);
        $display("Time=%0t: [TEST] New kernel_in values: [%0d,%0d,%0d; %0d,%0d,%0d; %0d,%0d,%0d]",
            $time,
            kernel_in[0][0], kernel_in[0][1], kernel_in[0][2],
            kernel_in[1][0], kernel_in[1][1], kernel_in[1][2],
            kernel_in[2][0], kernel_in[2][1], kernel_in[2][2]);
        
        $display("\nNew Kernel (3x3):");
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                $write("%10d ", kernel_in[i][j]);
            end
            $write("\n");
        end
        
        $display("\nInput Image is loaded from ROM (10x12) - same as before");
        $display("Starting second convolution...\n");
        
        // Start second convolution
        #20 start = 1;
        #10 start = 0;
        
        // Wait for second completion
        wait(done);
        $display("Time=%0t: [TEST] Second done signal detected, waiting for cycle count to latch...", $time);
        
        // CRITICAL: Wait for the cycle counter to latch the final count
        @(posedge clk);
        @(posedge clk);  // Extra cycle to ensure latch completes
        
        $display("\n=================================================");
        $display("Second Convolution Completed!");
        $display("=================================================");
        $display("Time=%0t: [TEST] Reading cycle_count=%0d, cycle_counter=%0d, counting=%0b",
            $time, cycle_count, dut.cycle_counter, dut.counting);
        $display("Total Cycle Count: %0d", cycle_count);
        
        $display("\nOutput Result (8x10):");
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 10; j++) begin
                $write("%10d ", result_out[i][j]);
            end
            $write("\n");
        end

        $display("\n=================================================");
        $display("Simulation completed successfully");
        $display("=================================================");
        
        #100 $finish;
    end
    
    // Comprehensive debug monitoring
    always @(posedge clk) begin
        // State transitions
        if (dut.state != $past(dut.state)) begin
            case (dut.state)
                dut.ST_IDLE: $display("Time=%0t: [STATE] State changed to ST_IDLE", $time);
                dut.ST_LOAD_IMAGE: $display("Time=%0t: [STATE] State changed to ST_LOAD_IMAGE", $time);
                dut.ST_CONV: $display("Time=%0t: [STATE] State changed to ST_CONV", $time);
                dut.ST_DONE: $display("Time=%0t: [STATE] State changed to ST_DONE", $time);
            endcase
        end
        
        // Image loading
        if (dut.state == dut.ST_LOAD_IMAGE) begin
            if (dut.read_counter == 7'd1) begin
                $display("Time=%0t: [LOAD] Loading image from ROM...", $time);
            end
            if (dut.read_counter == 7'd121) begin
                $display("Time=%0t: [LOAD] Image loading complete (120 pixels)", $time);
            end
        end
        
        // Convolution start
        if (dut.state == dut.ST_CONV && dut.conv_start) begin
            $display("Time=%0t: [CONV] Starting Winograd convolution...", $time);
            $display("Time=%0t: [CONV] Kernel values: [%0d,%0d,%0d; %0d,%0d,%0d; %0d,%0d,%0d]",
                $time,
                dut.conv_kernel_in[0][0], dut.conv_kernel_in[0][1], dut.conv_kernel_in[0][2],
                dut.conv_kernel_in[1][0], dut.conv_kernel_in[1][1], dut.conv_kernel_in[1][2],
                dut.conv_kernel_in[2][0], dut.conv_kernel_in[2][1], dut.conv_kernel_in[2][2]);
        end
        
        // Convolution done
        if (dut.conv_done && !$past(dut.conv_done)) begin
            $display("Time=%0t: [CONV] Winograd module signaled done", $time);
        end
        
        // Done signal
        if (done && !$past(done)) begin
            $display("Time=%0t: [DONE] Convolution done signal asserted", $time);
        end
        if (!done && $past(done)) begin
            $display("Time=%0t: [DONE] Convolution done signal deasserted", $time);
        end
        
        // Cycle counter monitoring
        if (dut.counting && !$past(dut.counting)) begin
            $display("Time=%0t: [COUNTER] Cycle counting started, cycle_count cleared to %0d",
                $time, dut.cycle_count);
        end
        
        if (dut.counting) begin
            if (dut.cycle_counter % 100 == 0) begin
                $display("Time=%0t: [COUNTER] Counting... cycle_counter=%0d, counting=%0b, done=%0b",
                    $time, dut.cycle_counter, dut.counting, done);
            end
        end
        
        if (!dut.counting && $past(dut.counting)) begin
            $display("Time=%0t: [COUNTER] Cycle counting stopped", $time);
            $display("Time=%0t: [COUNTER] Final values: cycle_counter=%0d, cycle_count=%0d",
                $time, dut.cycle_counter, dut.cycle_count);
        end
        
        // Start signal monitoring
        if (start && !$past(start)) begin
            $display("Time=%0t: [INPUT] Start signal asserted", $time);
        end
        if (!start && $past(start)) begin
            $display("Time=%0t: [INPUT] Start signal deasserted", $time);
        end
    end

endmodule