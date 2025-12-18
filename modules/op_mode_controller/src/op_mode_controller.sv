`timescale 1ns / 1ps

module op_mode_controller (
    input  logic [7:0] switches,
    output logic [2:0] op_mode, // op_mode_t
    output logic [2:0] calc_type // calc_type_t
);

    import matrix_op_selector_pkg::*;

    // Mapping:
    // SW[2:0]
    // 000: Transpose (Single)
    // 001: Add (Double)
    // 010: Mul (Double)
    // 011: Scalar Mul (Scalar)
    
    always_comb begin
        case (switches[2:0])
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
