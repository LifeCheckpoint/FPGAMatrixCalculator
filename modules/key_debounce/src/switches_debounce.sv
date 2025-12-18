`timescale 1ns / 1ps

module switches_debounce #(
    parameter WIDTH = 8,
    parameter CNT_MAX = 20'd500000 // 20ms at 25MHz
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] sw_in,
    output wire [WIDTH-1:0] sw_out
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_debounce
            key_debounce #(
                .CNT_MAX(CNT_MAX)
            ) u_debounce (
                .clk(clk),
                .rst_n(rst_n),
                .key_in(sw_in[i]),
                .key_out(sw_out[i])
            );
        end
    endgenerate

endmodule
