module xorshift32 #(
    parameter NUM_OUTPUTS = 4
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] seed,
    output logic [31:0] random_out [NUM_OUTPUTS-1:0]
);

    logic [31:0] state;
    logic [31:0] next_states [NUM_OUTPUTS:0];
    
    function automatic logic [31:0] xorshift32(input logic [31:0] s);
        logic [31:0] tmp;
        tmp = s ^ ((s << 13) & 32'hFFFFFFFF);
        tmp = tmp ^ ((tmp >> 17) & 32'hFFFFFFFF);
        tmp = tmp ^ ((tmp << 5) & 32'hFFFFFFFF);
        return tmp & 32'hFFFFFFFF;
    endfunction
    
    always_comb begin
        next_states[0] = state;
        for (int i = 0; i < NUM_OUTPUTS; i++) begin
            next_states[i+1] = xorshift32(next_states[i]);
            random_out[i] = next_states[i+1];
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= seed;
        end else if (start) begin
            state <= next_states[NUM_OUTPUTS];
        end
    end

endmodule