`timescale 1ns / 1ps

module op_mode_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  switches,
    output logic [2:0]  op_mode, // op_mode_t
    output logic [2:0]  calc_type // calc_type_t
);

    import matrix_op_selector_pkg::*;

    // Stability Logic
    // Wait for switches to be stable for a certain time before updating output.
    // This prevents flickering when switching between modes that require changing multiple switches.
    
    parameter STABILITY_THRESHOLD = 2500000; // 100ms at 25MHz
    
    logic [7:0] switches_prev;
    logic [7:0] switches_stable;
    logic [31:0] stability_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            switches_prev <= 8'd0;
            switches_stable <= 8'd0;
            stability_cnt <= 0;
        end else begin
            if (switches != switches_prev) begin
                // Input changed, reset counter
                switches_prev <= switches;
                stability_cnt <= 0;
            end else begin
                // Input stable
                if (stability_cnt < STABILITY_THRESHOLD) begin
                    stability_cnt <= stability_cnt + 1;
                end else begin
                    // Stable for enough time, update output
                    switches_stable <= switches;
                end
            end
        end
    end

    // Mapping:
    // SW[2:0]
    // 000: Transpose (Single)
    // 001: Add (Double)
    // 010: Mul (Double)
    // 011: Scalar Mul (Scalar)
    
    always_comb begin
        case (switches_stable[2:0])
            3'b000: begin
                op_mode = OP_SINGLE;
                calc_type = CALC_TRANSPOSE;
            end
            3'b001: begin
                op_mode = OP_DOUBLE;
                calc_type = CALC_ADD;
            end
            3'b010: begin
                op_mode = OP_DOUBLE;
                calc_type = CALC_MUL;
            end
            3'b011: begin
                op_mode = OP_SCALAR;
                calc_type = CALC_SCALAR_MUL;
            end
            3'b100: begin
                op_mode = OP_SINGLE;
                calc_type = CALC_CONV;
            end
            default: begin
                op_mode = OP_SINGLE;
                calc_type = CALC_TRANSPOSE;
            end
        endcase
    end

endmodule
