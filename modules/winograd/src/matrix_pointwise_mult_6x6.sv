`timescale 1ns / 1ps

module matrix_pointwise_mult_6x6 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic signed [19:0] U [0:5][0:5],
    input  logic signed [19:0] V [0:5][0:5],
    output logic signed [39:0] M [0:5][0:5],
    output logic        done,
    output logic        busy
);

    // State definition
    typedef enum logic [1:0] {
        S_IDLE,
        S_CALC,
        S_DONE
    } state_t;

    state_t state;
    logic [2:0] i, j; // Counters (0..5)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            busy <= 0;
            i <= 0;
            j <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_CALC;
                        busy <= 1;
                        i <= 0;
                        j <= 0;
                    end else begin
                        busy <= 0;
                    end
                end

                S_CALC: begin
                    // Perform multiplication for current element
                    M[i][j] <= signed'(U[i][j]) * signed'(V[i][j]);

                    // Increment counters
                    if (j == 5) begin
                        j <= 0;
                        if (i == 5) begin
                            state <= S_DONE;
                            done <= 1;
                            busy <= 0;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        j <= j + 1;
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

endmodule
