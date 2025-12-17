`timescale 1ns / 1ps

module switches2op (
    input  logic       sw_mat_input,
    input  logic       sw_gen,
    input  logic       sw_show,
    input  logic       sw_calculate,
    input  logic       sw_settings,
    output logic [2:0] op
);

always_comb begin
    case ({sw_mat_input, sw_gen, sw_show, sw_calculate, sw_settings})
        5'b00001: op = 3'd5; // Settings
        5'b00010: op = 3'd4; // Calculate
        5'b00100: op = 3'd3; // Show
        5'b01000: op = 3'd2; // Generate
        5'b10000: op = 3'd1; // Matrix Input
        default: op = 3'd0; // Invalid
    endcase
end

endmodule