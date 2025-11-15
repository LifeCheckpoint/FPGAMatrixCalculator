`timescale 1ns / 1ps

module tile_transform_unit (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [31:0] tile_in [0:5][0:5], // 6x6 tile input
    output logic [31:0] tile_out [0:5][0:5], // 6x6 transformed tile output
    output logic transform_done
);

localparam S_IDLE   = 2'b00;
localparam S_CALC_T = 2'b01;
localparam S_CALC_V = 2'b10;
localparam S_DONE   = 2'b11;

logic [1:0] state;
logic [31:0] T [0:5][0:5];

// S_IDLE -> S_CALC_T -> S_CALC_V -> S_DONE -> S_IDLE
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
                state <= S_CALC_V;
            end
            S_CALC_V: begin
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
            for (int j = 0; j < 6; j++) begin
                T[i][j] <= 32'd0;
            end
        end
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                tile_out[i][j] <= 32'd0;
            end
        end
    end else begin
        case(state)
            S_IDLE: begin
                if (start) begin
                    for (int i = 0; i < 6; i++) begin
                        for (int j = 0; j < 6; j++) begin
                            T[i][j] <= 32'd0;
                        end
                    end
                end
            end
            
            S_CALC_T: begin
                // First step, calculate T = B^T * d (6x6 matrix)
                
                // Row 0: B^T[0] = [4, 0, -5, 0, 1, 0]
                T[0][0] <= (tile_in[0][0] << 2) - (tile_in[2][0] << 2) - tile_in[2][0] + tile_in[4][0];
                T[0][1] <= (tile_in[0][1] << 2) - (tile_in[2][1] << 2) - tile_in[2][1] + tile_in[4][1];
                T[0][2] <= (tile_in[0][2] << 2) - (tile_in[2][2] << 2) - tile_in[2][2] + tile_in[4][2];
                T[0][3] <= (tile_in[0][3] << 2) - (tile_in[2][3] << 2) - tile_in[2][3] + tile_in[4][3];
                T[0][4] <= (tile_in[0][4] << 2) - (tile_in[2][4] << 2) - tile_in[2][4] + tile_in[4][4];
                T[0][5] <= (tile_in[0][5] << 2) - (tile_in[2][5] << 2) - tile_in[2][5] + tile_in[4][5];
                
                // Row 1: B^T[1] = [0, -4, -4, 1, 1, 0]
                T[1][0] <= -(tile_in[1][0] << 2) - (tile_in[2][0] << 2) + tile_in[3][0] + tile_in[4][0];
                T[1][1] <= -(tile_in[1][1] << 2) - (tile_in[2][1] << 2) + tile_in[3][1] + tile_in[4][1];
                T[1][2] <= -(tile_in[1][2] << 2) - (tile_in[2][2] << 2) + tile_in[3][2] + tile_in[4][2];
                T[1][3] <= -(tile_in[1][3] << 2) - (tile_in[2][3] << 2) + tile_in[3][3] + tile_in[4][3];
                T[1][4] <= -(tile_in[1][4] << 2) - (tile_in[2][4] << 2) + tile_in[3][4] + tile_in[4][4];
                T[1][5] <= -(tile_in[1][5] << 2) - (tile_in[2][5] << 2) + tile_in[3][5] + tile_in[4][5];
                
                // Row 2: B^T[2] = [0, 4, -4, -1, 1, 0]
                T[2][0] <= (tile_in[1][0] << 2) - (tile_in[2][0] << 2) - tile_in[3][0] + tile_in[4][0];
                T[2][1] <= (tile_in[1][1] << 2) - (tile_in[2][1] << 2) - tile_in[3][1] + tile_in[4][1];
                T[2][2] <= (tile_in[1][2] << 2) - (tile_in[2][2] << 2) - tile_in[3][2] + tile_in[4][2];
                T[2][3] <= (tile_in[1][3] << 2) - (tile_in[2][3] << 2) - tile_in[3][3] + tile_in[4][3];
                T[2][4] <= (tile_in[1][4] << 2) - (tile_in[2][4] << 2) - tile_in[3][4] + tile_in[4][4];
                T[2][5] <= (tile_in[1][5] << 2) - (tile_in[2][5] << 2) - tile_in[3][5] + tile_in[4][5];
                
                // Row 3: B^T[3] = [0, -2, -1, 2, 1, 0]
                T[3][0] <= -(tile_in[1][0] << 1) - tile_in[2][0] + (tile_in[3][0] << 1) + tile_in[4][0];
                T[3][1] <= -(tile_in[1][1] << 1) - tile_in[2][1] + (tile_in[3][1] << 1) + tile_in[4][1];
                T[3][2] <= -(tile_in[1][2] << 1) - tile_in[2][2] + (tile_in[3][2] << 1) + tile_in[4][2];
                T[3][3] <= -(tile_in[1][3] << 1) - tile_in[2][3] + (tile_in[3][3] << 1) + tile_in[4][3];
                T[3][4] <= -(tile_in[1][4] << 1) - tile_in[2][4] + (tile_in[3][4] << 1) + tile_in[4][4];
                T[3][5] <= -(tile_in[1][5] << 1) - tile_in[2][5] + (tile_in[3][5] << 1) + tile_in[4][5];
                
                // Row 4: B^T[4] = [0, 2, -1, -2, 1, 0]
                T[4][0] <= (tile_in[1][0] << 1) - tile_in[2][0] - (tile_in[3][0] << 1) + tile_in[4][0];
                T[4][1] <= (tile_in[1][1] << 1) - tile_in[2][1] - (tile_in[3][1] << 1) + tile_in[4][1];
                T[4][2] <= (tile_in[1][2] << 1) - tile_in[2][2] - (tile_in[3][2] << 1) + tile_in[4][2];
                T[4][3] <= (tile_in[1][3] << 1) - tile_in[2][3] - (tile_in[3][3] << 1) + tile_in[4][3];
                T[4][4] <= (tile_in[1][4] << 1) - tile_in[2][4] - (tile_in[3][4] << 1) + tile_in[4][4];
                T[4][5] <= (tile_in[1][5] << 1) - tile_in[2][5] - (tile_in[3][5] << 1) + tile_in[4][5];
                
                // Row 5: B^T[5] = [0, 4, 0, -5, 0, 1]
                T[5][0] <= (tile_in[1][0] << 2) - (tile_in[3][0] << 2) - tile_in[3][0] + tile_in[5][0];
                T[5][1] <= (tile_in[1][1] << 2) - (tile_in[3][1] << 2) - tile_in[3][1] + tile_in[5][1];
                T[5][2] <= (tile_in[1][2] << 2) - (tile_in[3][2] << 2) - tile_in[3][2] + tile_in[5][2];
                T[5][3] <= (tile_in[1][3] << 2) - (tile_in[3][3] << 2) - tile_in[3][3] + tile_in[5][3];
                T[5][4] <= (tile_in[1][4] << 2) - (tile_in[3][4] << 2) - tile_in[3][4] + tile_in[5][4];
                T[5][5] <= (tile_in[1][5] << 2) - (tile_in[3][5] << 2) - tile_in[3][5] + tile_in[5][5];
            end
            
            S_CALC_V: begin
                // Second step, calculate V = T * B (6x6 matrix)
                // B matrix columns (for matrix multiplication T * B):
                // B[:,0] = [4, 0, -5, 0, 1, 0]
                // B[:,1] = [0, -4, -4, 1, 1, 0]
                // B[:,2] = [0, 4, -4, -1, 1, 0]
                // B[:,3] = [0, -2, -1, 2, 1, 0]
                // B[:,4] = [0, 2, -1, -2, 1, 0]
                // B[:,5] = [0, 4, 0, -5, 0, 1]
                
                // Row 0: V[0][j] = sum(k) T[0][k]*B[k][j]
                tile_out[0][0] <= (T[0][0] << 2) - (T[0][2] << 2) - T[0][2] + T[0][4];
                tile_out[0][1] <= -(T[0][1] << 2) - (T[0][2] << 2) + T[0][3] + T[0][4];
                tile_out[0][2] <= (T[0][1] << 2) - (T[0][2] << 2) - T[0][3] + T[0][4];
                tile_out[0][3] <= -(T[0][1] << 1) - T[0][2] + (T[0][3] << 1) + T[0][4];
                tile_out[0][4] <= (T[0][1] << 1) - T[0][2] - (T[0][3] << 1) + T[0][4];
                tile_out[0][5] <= (T[0][1] << 2) - (T[0][3] << 2) - T[0][3] + T[0][5];
                
                // Row 1
                tile_out[1][0] <= (T[1][0] << 2) - (T[1][2] << 2) - T[1][2] + T[1][4];
                tile_out[1][1] <= -(T[1][1] << 2) - (T[1][2] << 2) + T[1][3] + T[1][4];
                tile_out[1][2] <= (T[1][1] << 2) - (T[1][2] << 2) - T[1][3] + T[1][4];
                tile_out[1][3] <= -(T[1][1] << 1) - T[1][2] + (T[1][3] << 1) + T[1][4];
                tile_out[1][4] <= (T[1][1] << 1) - T[1][2] - (T[1][3] << 1) + T[1][4];
                tile_out[1][5] <= (T[1][1] << 2) - (T[1][3] << 2) - T[1][3] + T[1][5];
                
                // Row 2
                tile_out[2][0] <= (T[2][0] << 2) - (T[2][2] << 2) - T[2][2] + T[2][4];
                tile_out[2][1] <= -(T[2][1] << 2) - (T[2][2] << 2) + T[2][3] + T[2][4];
                tile_out[2][2] <= (T[2][1] << 2) - (T[2][2] << 2) - T[2][3] + T[2][4];
                tile_out[2][3] <= -(T[2][1] << 1) - T[2][2] + (T[2][3] << 1) + T[2][4];
                tile_out[2][4] <= (T[2][1] << 1) - T[2][2] - (T[2][3] << 1) + T[2][4];
                tile_out[2][5] <= (T[2][1] << 2) - (T[2][3] << 2) - T[2][3] + T[2][5];
                
                // Row 3
                tile_out[3][0] <= (T[3][0] << 2) - (T[3][2] << 2) - T[3][2] + T[3][4];
                tile_out[3][1] <= -(T[3][1] << 2) - (T[3][2] << 2) + T[3][3] + T[3][4];
                tile_out[3][2] <= (T[3][1] << 2) - (T[3][2] << 2) - T[3][3] + T[3][4];
                tile_out[3][3] <= -(T[3][1] << 1) - T[3][2] + (T[3][3] << 1) + T[3][4];
                tile_out[3][4] <= (T[3][1] << 1) - T[3][2] - (T[3][3] << 1) + T[3][4];
                tile_out[3][5] <= (T[3][1] << 2) - (T[3][3] << 2) - T[3][3] + T[3][5];
                
                // Row 4
                tile_out[4][0] <= (T[4][0] << 2) - (T[4][2] << 2) - T[4][2] + T[4][4];
                tile_out[4][1] <= -(T[4][1] << 2) - (T[4][2] << 2) + T[4][3] + T[4][4];
                tile_out[4][2] <= (T[4][1] << 2) - (T[4][2] << 2) - T[4][3] + T[4][4];
                tile_out[4][3] <= -(T[4][1] << 1) - T[4][2] + (T[4][3] << 1) + T[4][4];
                tile_out[4][4] <= (T[4][1] << 1) - T[4][2] - (T[4][3] << 1) + T[4][4];
                tile_out[4][5] <= (T[4][1] << 2) - (T[4][3] << 2) - T[4][3] + T[4][5];
                
                // Row 5
                tile_out[5][0] <= (T[5][0] << 2) - (T[5][2] << 2) - T[5][2] + T[5][4];
                tile_out[5][1] <= -(T[5][1] << 2) - (T[5][2] << 2) + T[5][3] + T[5][4];
                tile_out[5][2] <= (T[5][1] << 2) - (T[5][2] << 2) - T[5][3] + T[5][4];
                tile_out[5][3] <= -(T[5][1] << 1) - T[5][2] + (T[5][3] << 1) + T[5][4];
                tile_out[5][4] <= (T[5][1] << 1) - T[5][2] - (T[5][3] << 1) + T[5][4];
                tile_out[5][5] <= (T[5][1] << 2) - (T[5][3] << 2) - T[5][3] + T[5][5];
            end
            
            S_DONE: begin end
        endcase
    end
end

endmodule