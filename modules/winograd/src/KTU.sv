`timescale 1ns / 1ps

module kernel_transform_unit (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [15:0] kernel_in [0:2][0:2], // 3x3 kernel input
    output logic [15:0] kernel_out [0:5][0:5], // 6x6 transformed kernel output
    output logic transform_done
);

localparam S_IDLE   = 2'b00;
localparam S_CALC_T = 2'b01;
localparam S_CALC_U = 2'b10;
localparam S_DONE   = 2'b11;

logic [1:0] state;
logic [15:0] T [0:5][0:2];

// S_IDLE -> S_CALC_T -> S_CALC_U -> S_DONE -> S_IDLE
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        transform_done <= 1'b0;
    end else begin
        case (state)
            S_IDLE: begin
                transform_done <= 1'b0;
                if (start) begin
                    state <= S_CALC_T;
                end
            end
            S_CALC_T: begin
                state <= S_CALC_U;
            end
            S_CALC_U: begin
                state <= S_DONE;
            end
            S_DONE: begin
                transform_done <= 1'b1;
                state <= S_IDLE;
            end
            default: begin
                state <= S_IDLE;
                transform_done <= 1'b0;
            end
        endcase
    end
end

// Data path
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 3; j++) begin
                T[i][j] <= 16'd0;
            end
        end
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                kernel_out[i][j] <= 16'd0;
            end
        end
    end else begin
        case(state)
            S_IDLE: begin
                if (start) begin
                    for (int i = 0; i < 6; i++) begin
                        for (int j = 0; j < 3; j++) begin
                            T[i][j] <= 16'd0;
                        end
                    end
                end
            end
            
            S_CALC_T: begin
                // First step, calculate T = G * g (6x3 matrix)

                // T[0][j] = 6 * kernel_in[0][j]
                T[0][0] <= (kernel_in[0][0] << 2) + (kernel_in[0][0] << 1);
                T[0][1] <= (kernel_in[0][1] << 2) + (kernel_in[0][1] << 1);
                T[0][2] <= (kernel_in[0][2] << 2) + (kernel_in[0][2] << 1);
                
                // T[1][j] = -((g0 + g3 + g6) << 2)
                T[1][0] <= -((kernel_in[0][0] + kernel_in[1][0] + kernel_in[2][0]) << 2);
                T[1][1] <= -((kernel_in[0][1] + kernel_in[1][1] + kernel_in[2][1]) << 2);
                T[1][2] <= -((kernel_in[0][2] + kernel_in[1][2] + kernel_in[2][2]) << 2);
                
                // T[2][j] = -((g0 - g3 + g6) << 2)
                T[2][0] <= -((kernel_in[0][0] - kernel_in[1][0] + kernel_in[2][0]) << 2);
                T[2][1] <= -((kernel_in[0][1] - kernel_in[1][1] + kernel_in[2][1]) << 2);
                T[2][2] <= -((kernel_in[0][2] - kernel_in[1][2] + kernel_in[2][2]) << 2);
                
                // T[3][j] = g0 + (g3 << 1) + (g6 << 2)
                T[3][0] <= kernel_in[0][0] + (kernel_in[1][0] << 1) + (kernel_in[2][0] << 2);
                T[3][1] <= kernel_in[0][1] + (kernel_in[1][1] << 1) + (kernel_in[2][1] << 2);
                T[3][2] <= kernel_in[0][2] + (kernel_in[1][2] << 1) + (kernel_in[2][2] << 2);
                
                // T[4][j] = g0 - (g3 << 1) + (g6 << 2)
                T[4][0] <= kernel_in[0][0] - (kernel_in[1][0] << 1) + (kernel_in[2][0] << 2);
                T[4][1] <= kernel_in[0][1] - (kernel_in[1][1] << 1) + (kernel_in[2][1] << 2);
                T[4][2] <= kernel_in[0][2] - (kernel_in[1][2] << 1) + (kernel_in[2][2] << 2);
                
                // T[5][j] = 24 * kernel_in[2][j]
                T[5][0] <= (kernel_in[2][0] << 4) + (kernel_in[2][0] << 3);
                T[5][1] <= (kernel_in[2][1] << 4) + (kernel_in[2][1] << 3);
                T[5][2] <= (kernel_in[2][2] << 4) + (kernel_in[2][2] << 3);
            end
            
            S_CALC_U: begin
                // Second step, calculate U' = T * G'^T (6x6 matrix)
                
                // Column 0
                kernel_out[0][0] <= (T[0][0] << 2) + (T[0][0] << 1);
                kernel_out[0][1] <= -((T[0][0] + T[0][1] + T[0][2]) << 2);
                kernel_out[0][2] <= -((T[0][0] - T[0][1] + T[0][2]) << 2);
                kernel_out[0][3] <= T[0][0] + (T[0][1] << 1) + (T[0][2] << 2);
                kernel_out[0][4] <= T[0][0] - (T[0][1] << 1) + (T[0][2] << 2);
                kernel_out[0][5] <= (T[0][2] << 4) + (T[0][2] << 3);
                
                // Column 1
                kernel_out[1][0] <= (T[1][0] << 2) + (T[1][0] << 1);
                kernel_out[1][1] <= -((T[1][0] + T[1][1] + T[1][2]) << 2);
                kernel_out[1][2] <= -((T[1][0] - T[1][1] + T[1][2]) << 2);
                kernel_out[1][3] <= T[1][0] + (T[1][1] << 1) + (T[1][2] << 2);
                kernel_out[1][4] <= T[1][0] - (T[1][1] << 1) + (T[1][2] << 2);
                kernel_out[1][5] <= (T[1][2] << 4) + (T[1][2] << 3);
                
                // Column 2
                kernel_out[2][0] <= (T[2][0] << 2) + (T[2][0] << 1);
                kernel_out[2][1] <= -((T[2][0] + T[2][1] + T[2][2]) << 2);
                kernel_out[2][2] <= -((T[2][0] - T[2][1] + T[2][2]) << 2);
                kernel_out[2][3] <= T[2][0] + (T[2][1] << 1) + (T[2][2] << 2);
                kernel_out[2][4] <= T[2][0] - (T[2][1] << 1) + (T[2][2] << 2);
                kernel_out[2][5] <= (T[2][2] << 4) + (T[2][2] << 3);
                
                // Column 3
                kernel_out[3][0] <= (T[3][0] << 2) + (T[3][0] << 1);
                kernel_out[3][1] <= -((T[3][0] + T[3][1] + T[3][2]) << 2);
                kernel_out[3][2] <= -((T[3][0] - T[3][1] + T[3][2]) << 2);
                kernel_out[3][3] <= T[3][0] + (T[3][1] << 1) + (T[3][2] << 2);
                kernel_out[3][4] <= T[3][0] - (T[3][1] << 1) + (T[3][2] << 2);
                kernel_out[3][5] <= (T[3][2] << 4) + (T[3][2] << 3);
                
                // Column 4
                kernel_out[4][0] <= (T[4][0] << 2) + (T[4][0] << 1);
                kernel_out[4][1] <= -((T[4][0] + T[4][1] + T[4][2]) << 2);
                kernel_out[4][2] <= -((T[4][0] - T[4][1] + T[4][2]) << 2);
                kernel_out[4][3] <= T[4][0] + (T[4][1] << 1) + (T[4][2] << 2);
                kernel_out[4][4] <= T[4][0] - (T[4][1] << 1) + (T[4][2] << 2);
                kernel_out[4][5] <= (T[4][2] << 4) + (T[4][2] << 3);
                
                // Column 5
                kernel_out[5][0] <= (T[5][0] << 2) + (T[5][0] << 1);
                kernel_out[5][1] <= -((T[5][0] + T[5][1] + T[5][2]) << 2);
                kernel_out[5][2] <= -((T[5][0] - T[5][1] + T[5][2]) << 2);
                kernel_out[5][3] <= T[5][0] + (T[5][1] << 1) + (T[5][2] << 2);
                kernel_out[5][4] <= T[5][0] - (T[5][1] << 1) + (T[5][2] << 2);
                kernel_out[5][5] <= (T[5][2] << 4) + (T[5][2] << 3);
            end
            
            S_DONE: begin end
        endcase
    end
end

endmodule