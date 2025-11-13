module matrix_pointwise_mult_6x6 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [15:0] a [6][6],
    input  logic [15:0] b [6][6],
    output logic [31:0] c [6][6],
    output logic        done
);

    parameter LATENCY = 3;
    
    logic [31:0] mult [6][6];
    logic [31:0] pipe [LATENCY-1:0][6][6];
    logic [LATENCY:0] valid;
    
    assign valid[0] = start;
    
    always_comb begin
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++)
                mult[i][j] = a[i][j] * b[i][j];
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe <= '{default: 0};
            valid[LATENCY:1] <= '0;
        end else begin
            pipe[0] <= mult;
            for (int k = 1; k < LATENCY; k++)
                pipe[k] <= pipe[k-1];
            
            for (int k = 1; k <= LATENCY; k++)
                valid[k] <= valid[k-1];
        end
    end
    
    assign c = pipe[LATENCY-1];
    assign done = valid[LATENCY];

endmodule
