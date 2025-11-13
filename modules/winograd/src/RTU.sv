`timescale 1ns / 1ps

module reverse_transform_unit (
    input logic clk,
    input logic rst_n,
    input logic [15:0] matrix_in [0:5][0:5], // 6x6 matrix input
    output logic [15:0] matrix_out [0:3][0:3], // 4x4 transformed matrix output
    output logic transform_done
);

localparam S_CALC_T = 2'b00;
localparam S_CALC_Y = 2'b01;
localparam S_DONE   = 2'b10;

logic [1:0] state;
logic [15:0] T [0:3][0:5];

// S_CALC_T -> S_CALC_Y -> S_DONE
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_CALC_T;
        transform_done <= 1'b0;
    end else begin
        case (state)
            S_CALC_T: begin
                // Compute T = A^T * M
                state <= S_CALC_Y;
                transform_done <= 1'b0;
            end
            S_CALC_Y: begin
                // Compute Y = T * A
                state <= S_DONE;
            end
            S_DONE: begin
                transform_done <= 1'b1;
                state <= S_CALC_T;
            end
            default: begin
                state <= S_CALC_T;
                transform_done <= 1'b0;
            end
        endcase
    end
end

// Data path
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 6; j++) begin
                T[i][j] <= 16'd0;
            end
        end
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                matrix_out[i][j] <= 16'd0;
            end
        end
    end else begin
        case(state)
            S_CALC_T: begin
                // First step, calculate T = A^T * M (4x6 matrix)

                // T[0][j] = M[0][j] + M[1][j] + M[2][j] + M[3][j] + M[4][j]
                T[0][0] <= matrix_in[0][0] + matrix_in[1][0] + matrix_in[2][0] + matrix_in[3][0] + matrix_in[4][0];
                T[0][1] <= matrix_in[0][1] + matrix_in[1][1] + matrix_in[2][1] + matrix_in[3][1] + matrix_in[4][1];
                T[0][2] <= matrix_in[0][2] + matrix_in[1][2] + matrix_in[2][2] + matrix_in[3][2] + matrix_in[4][2];
                T[0][3] <= matrix_in[0][3] + matrix_in[1][3] + matrix_in[2][3] + matrix_in[3][3] + matrix_in[4][3];
                T[0][4] <= matrix_in[0][4] + matrix_in[1][4] + matrix_in[2][4] + matrix_in[3][4] + matrix_in[4][4];
                T[0][5] <= matrix_in[0][5] + matrix_in[1][5] + matrix_in[2][5] + matrix_in[3][5] + matrix_in[4][5];
                
                // T[1][j] = M[1][j] - M[2][j] + (M[3][j] << 1) - (M[4][j] << 1)
                T[1][0] <= matrix_in[1][0] - matrix_in[2][0] + (matrix_in[3][0] << 1) - (matrix_in[4][0] << 1);
                T[1][1] <= matrix_in[1][1] - matrix_in[2][1] + (matrix_in[3][1] << 1) - (matrix_in[4][1] << 1);
                T[1][2] <= matrix_in[1][2] - matrix_in[2][2] + (matrix_in[3][2] << 1) - (matrix_in[4][2] << 1);
                T[1][3] <= matrix_in[1][3] - matrix_in[2][3] + (matrix_in[3][3] << 1) - (matrix_in[4][3] << 1);
                T[1][4] <= matrix_in[1][4] - matrix_in[2][4] + (matrix_in[3][4] << 1) - (matrix_in[4][4] << 1);
                T[1][5] <= matrix_in[1][5] - matrix_in[2][5] + (matrix_in[3][5] << 1) - (matrix_in[4][5] << 1);
                
                // T[2][j] = M[1][j] + M[2][j] + (M[3][j] << 2) + (M[4][j] << 2)
                T[2][0] <= matrix_in[1][0] + matrix_in[2][0] + (matrix_in[3][0] << 2) + (matrix_in[4][0] << 2);
                T[2][1] <= matrix_in[1][1] + matrix_in[2][1] + (matrix_in[3][1] << 2) + (matrix_in[4][1] << 2);
                T[2][2] <= matrix_in[1][2] + matrix_in[2][2] + (matrix_in[3][2] << 2) + (matrix_in[4][2] << 2);
                T[2][3] <= matrix_in[1][3] + matrix_in[2][3] + (matrix_in[3][3] << 2) + (matrix_in[4][3] << 2);
                T[2][4] <= matrix_in[1][4] + matrix_in[2][4] + (matrix_in[3][4] << 2) + (matrix_in[4][4] << 2);
                T[2][5] <= matrix_in[1][5] + matrix_in[2][5] + (matrix_in[3][5] << 2) + (matrix_in[4][5] << 2);
                
                // T[3][j] = M[1][j] - M[2][j] + (M[3][j] << 3) - (M[4][j] << 3) + M[5][j]
                T[3][0] <= matrix_in[1][0] - matrix_in[2][0] + (matrix_in[3][0] << 3) - (matrix_in[4][0] << 3) + matrix_in[5][0];
                T[3][1] <= matrix_in[1][1] - matrix_in[2][1] + (matrix_in[3][1] << 3) - (matrix_in[4][1] << 3) + matrix_in[5][1];
                T[3][2] <= matrix_in[1][2] - matrix_in[2][2] + (matrix_in[3][2] << 3) - (matrix_in[4][2] << 3) + matrix_in[5][2];
                T[3][3] <= matrix_in[1][3] - matrix_in[2][3] + (matrix_in[3][3] << 3) - (matrix_in[4][3] << 3) + matrix_in[5][3];
                T[3][4] <= matrix_in[1][4] - matrix_in[2][4] + (matrix_in[3][4] << 3) - (matrix_in[4][4] << 3) + matrix_in[5][4];
                T[3][5] <= matrix_in[1][5] - matrix_in[2][5] + (matrix_in[3][5] << 3) - (matrix_in[4][5] << 3) + matrix_in[5][5];
            end
            
            S_CALC_Y: begin
                // Second step, calculate Y = T * A (4x4 matrix)
                
                // Row 0
                matrix_out[0][0] <= T[0][0] + T[0][1] + T[0][2] + T[0][3] + T[0][4];
                matrix_out[0][1] <= T[0][1] - T[0][2] + (T[0][3] << 1) - (T[0][4] << 1);
                matrix_out[0][2] <= T[0][1] + T[0][2] + (T[0][3] << 2) + (T[0][4] << 2);
                matrix_out[0][3] <= T[0][1] - T[0][2] + (T[0][3] << 3) - (T[0][4] << 3) + T[0][5];
                
                // Row 1
                matrix_out[1][0] <= T[1][0] + T[1][1] + T[1][2] + T[1][3] + T[1][4];
                matrix_out[1][1] <= T[1][1] - T[1][2] + (T[1][3] << 1) - (T[1][4] << 1);
                matrix_out[1][2] <= T[1][1] + T[1][2] + (T[1][3] << 2) + (T[1][4] << 2);
                matrix_out[1][3] <= T[1][1] - T[1][2] + (T[1][3] << 3) - (T[1][4] << 3) + T[1][5];
                
                // Row 2
                matrix_out[2][0] <= T[2][0] + T[2][1] + T[2][2] + T[2][3] + T[2][4];
                matrix_out[2][1] <= T[2][1] - T[2][2] + (T[2][3] << 1) - (T[2][4] << 1);
                matrix_out[2][2] <= T[2][1] + T[2][2] + (T[2][3] << 2) + (T[2][4] << 2);
                matrix_out[2][3] <= T[2][1] - T[2][2] + (T[2][3] << 3) - (T[2][4] << 3) + T[2][5];
                
                // Row 3
                matrix_out[3][0] <= T[3][0] + T[3][1] + T[3][2] + T[3][3] + T[3][4];
                matrix_out[3][1] <= T[3][1] - T[3][2] + (T[3][3] << 1) - (T[3][4] << 1);
                matrix_out[3][2] <= T[3][1] + T[3][2] + (T[3][3] << 2) + (T[3][4] << 2);
                matrix_out[3][3] <= T[3][1] - T[3][2] + (T[3][3] << 3) - (T[3][4] << 3) + T[3][5];
            end
            
            S_DONE: begin end
        endcase
    end
end

endmodule