`timescale 1ns / 1ps

module tile_transform_unit (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [31:0] tile_in [0:5][0:5], // 6x6 tile input
    output logic [31:0] tile_out [0:5][0:5], // 6x6 transformed tile output
    output logic transform_done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_PASS1, // Calculate T = B^T * d (columns)
        S_PASS2, // Calculate V = T * B (rows)
        S_DONE
    } state_t;

    state_t state;
    logic [2:0] idx; // Counter 0-5
    logic [31:0] T [0:5][0:5]; // Intermediate matrix

    // 1D Transform signals
    logic [31:0] trans_in [0:5];
    logic [31:0] trans_out [0:5];

    // Instantiate 1D Transform helper
    Winograd_Pre_Transform_1D transform_1d (
        .d(trans_in),
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
                    if (idx == 3'd5) begin
                        idx <= 3'd0;
                        state <= S_PASS2;
                    end else begin
                        idx <= idx + 3'd1;
                    end
                end

                S_PASS2: begin
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
        for (int i = 0; i < 6; i++) begin
            trans_in[i] = 32'd0;
        end

        case (state)
            S_PASS1: begin
                // Process columns of tile_in
                // Input: Column 'idx' of tile_in
                for (int i = 0; i < 6; i++) begin
                    trans_in[i] = tile_in[i][idx];
                end
            end

            S_PASS2: begin
                // Process rows of T
                // Input: Row 'idx' of T
                for (int i = 0; i < 6; i++) begin
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
                for (int j = 0; j < 6; j++) begin
                    T[i][j] <= 32'd0;
                    tile_out[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Optional: Clear registers? Not strictly necessary if we overwrite.
                    end
                end

                S_PASS1: begin
                    // Store result into Column 'idx' of T
                    for (int i = 0; i < 6; i++) begin
                        T[i][idx] <= trans_out[i];
                    end
                end

                S_PASS2: begin
                    // Store result into Row 'idx' of tile_out
                    for (int i = 0; i < 6; i++) begin
                        tile_out[idx][i] <= trans_out[i];
                    end
                end
            endcase
        end
    end

endmodule
