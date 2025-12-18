`timescale 1ns / 1ps

module reverse_transform_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic signed [39:0] M [0:5][0:5],
    output logic signed [39:0] R [0:3][0:3],
    output logic        done,
    output logic        busy
);

    // State definition
    typedef enum logic [1:0] {
        S_IDLE,
        S_PASS1, // Columns: A^T * M -> Temp (4x6)
        S_PASS2, // Rows: Temp * A -> R (4x4)
        S_DONE
    } state_t;

    state_t state;
    logic [2:0] idx; // Counter for rows/cols (max 6)

    // Intermediate storage
    logic signed [39:0] temp [0:3][0:5]; // 4x6 matrix

    // Transform unit interface
    logic signed [39:0] trans_in [0:5];
    logic signed [39:0] trans_out [0:3];

    Winograd_Post_Transform_1D transform_inst (
        .in_vec(trans_in),
        .out_vec(trans_out)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            busy <= 0;
            idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_PASS1;
                        busy <= 1;
                        idx <= 0;
                    end else begin
                        busy <= 0;
                    end
                end

                S_PASS1: begin
                    // Process column 'idx' of M
                    // Store into column 'idx' of temp
                    // temp[0..3][idx] = transform(M[0..5][idx])
                    
                    // Write result to temp
                    temp[0][idx] <= trans_out[0];
                    temp[1][idx] <= trans_out[1];
                    temp[2][idx] <= trans_out[2];
                    temp[3][idx] <= trans_out[3];

                    if (idx == 5) begin
                        state <= S_PASS2;
                        idx <= 0;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                S_PASS2: begin
                    // Process row 'idx' of temp
                    // Store into row 'idx' of R
                    // R[idx][0..3] = transform(temp[idx][0..5])
                    
                    // Write result to R
                    R[idx][0] <= trans_out[0];
                    R[idx][1] <= trans_out[1];
                    R[idx][2] <= trans_out[2];
                    R[idx][3] <= trans_out[3];

                    if (idx == 3) begin
                        state <= S_DONE;
                        done <= 1;
                        busy <= 0;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                S_DONE: begin
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Mux for transform input
    always_comb begin
        if (state == S_PASS1) begin
            // Input is column 'idx' of M
            trans_in[0] = M[0][idx];
            trans_in[1] = M[1][idx];
            trans_in[2] = M[2][idx];
            trans_in[3] = M[3][idx];
            trans_in[4] = M[4][idx];
            trans_in[5] = M[5][idx];
        end else if (state == S_PASS2) begin
            // Input is row 'idx' of temp
            trans_in[0] = temp[idx][0];
            trans_in[1] = temp[idx][1];
            trans_in[2] = temp[idx][2];
            trans_in[3] = temp[idx][3];
            trans_in[4] = temp[idx][4];
            trans_in[5] = temp[idx][5];
        end else begin
            trans_in = '{default: '0};
        end
    end

endmodule
