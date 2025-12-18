`timescale 1ns / 1ps

module kernel_transform_unit (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [31:0] kernel_in [0:2][0:2], // 3x3 kernel input
    output logic [31:0] kernel_out [0:5][0:5], // 6x6 transformed kernel output
    output logic transform_done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_PASS1, // Calculate T = G * g (columns)
        S_PASS2, // Calculate U = T * G^T (rows)
        S_DONE
    } state_t;

    state_t state;
    logic [2:0] idx; // Counter
    logic [31:0] T [0:5][0:2]; // Intermediate matrix (6x3)

    // 1D Transform signals
    logic [31:0] trans_in [0:2];
    logic [31:0] trans_out [0:5];

    // Instantiate 1D Transform helper
    Winograd_Kernel_Transform_1D transform_1d (
        .g(trans_in),
        .t(trans_out)
    );

    // State Machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            transform_done <= 1'b0;
            idx <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    transform_done <= 1'b0;
                    idx <= 3'd0;
                    if (start) begin
                        state <= S_PASS1;
                    end
                end

                S_PASS1: begin
                    // Process 3 columns
                    if (idx == 3'd2) begin
                        idx <= 3'd0;
                        state <= S_PASS2;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end

                S_PASS2: begin
                    // Process 6 rows
                    if (idx == 3'd5) begin
                        idx <= 3'd0;
                        state <= S_DONE;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end

                S_DONE: begin
                    transform_done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Data Path Muxing
    always_comb begin
        // Default assignment
        for (int i = 0; i < 3; i++) begin
            trans_in[i] = 32'd0;
        end

        case (state)
            S_PASS1: begin
                // Process columns of kernel_in (3x3)
                // Input: Column 'idx' of kernel_in
                for (int i = 0; i < 3; i++) begin
                    trans_in[i] = kernel_in[i][idx];
                end
            end

            S_PASS2: begin
                // Process rows of T (6x3)
                // Input: Row 'idx' of T
                for (int i = 0; i < 3; i++) begin
                    trans_in[i] = T[idx][i];
                end
            end
            
            default: ;
        endcase
    end

    // Result Storage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 3; j++) begin
                    T[i][j] <= 32'd0;
                end
            end
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    kernel_out[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                S_IDLE: begin
                    // Optional clear
                end

                S_PASS1: begin
                    // Store result into Column 'idx' of T
                    // trans_out is size 6
                    for (int i = 0; i < 6; i++) begin
                        T[i][idx] <= trans_out[i];
                    end
                end

                S_PASS2: begin
                    // Store result into Row 'idx' of kernel_out
                    // trans_out is size 6
                    for (int i = 0; i < 6; i++) begin
                        kernel_out[idx][i] <= trans_out[i];
                    end
                end
            endcase
        end
    end

endmodule
