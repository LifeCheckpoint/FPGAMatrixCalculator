`timescale 1ns/1ps

module xorshift32_sim;

    parameter NUM_OUTPUTS = 4;
    
    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] seed;
    logic [31:0] random_out [NUM_OUTPUTS-1:0];
    
    xorshift32 #(
        .NUM_OUTPUTS(NUM_OUTPUTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .seed(seed),
        .random_out(random_out)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        start = 0;
        seed = 32'd123456789;
        
        #20 rst_n = 1;
        #10 start = 1;
        
        $display("Time\tCycle\tOutputs");
        $display("----\t-----\t-------");
        
        repeat(10) begin
            @(posedge clk);
            #1;
            $write("%0t\t", $time);
            $write("%0d\t", ($time/10 - 3));
            for (int i = 0; i < NUM_OUTPUTS; i++) begin
                $write("%h ", random_out[i]);
            end
            $write("\n");
        end
        
        #20 $finish;
    end

endmodule