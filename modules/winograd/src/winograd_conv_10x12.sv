`timescale 1ns / 1ps

module winograd_conv_10x12 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] image_in   [0:9][0:11],
    input  logic [31:0] kernel_in  [0:2][0:2],
    output logic [31:0] result_out [0:7][0:9],
    output logic        done
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_PREP,
        ST_LOAD,
        ST_WAIT_CLEAR,
        ST_WAIT,
        ST_WRITE,
        ST_DIVIDE,
        ST_FINISH
    } state_t;

    localparam int NUM_ROUNDS = 9;

    state_t state;
    logic [3:0] round_idx;
    logic [1:0] tile_i, tile_j;
    
    logic        tc_start;
    logic [31:0] tc_kernel_in  [0:2][0:2];
    logic [31:0] tc_tile_in    [0:5][0:5];
    logic [31:0] tc_result_out [0:3][0:3];
    logic        tc_done;
    
    logic        div_start;
    logic        div_done;
    
    logic [31:0] kernel_reg [0:2][0:2];
    logic [31:0] image_reg [0:9][0:11];
    
    // 10x12 -> 3x3x6x6
    logic [31:0] tile_out [0:2][0:2][0:5][0:5];
    
    transform_10x12_3x3x6x6 input_transform_inst (
        .image(image_reg),
        .tile_out(tile_out)
    );
    
    // 3x3x4x4 results
    logic [31:0] result_tiles [0:2][0:2][0:3][0:3];
    
    // 3x3x4x4 -> 8x10
    logic [31:0] transform_out [0:7][0:9];
    
    transform_3x3x4x4_8x10 output_transform_inst (
        .tile(result_tiles),
        .image(transform_out)
    );
    
    // division ny 576 = 4^2 * 6^2
    division_576_8x10 division_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .done(div_done),
        .input_array(transform_out),
        .output_array(result_out)
    );
    
    always_comb begin
        tile_i = round_idx / 3;  // 0,1,2
        tile_j = round_idx % 3;  // 0,1,2
        tc_tile_in = tile_out[tile_i][tile_j];
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            round_idx <= '0;
            done <= 1'b0;
            tc_start <= 1'b0;
            div_start <= 1'b0;
            kernel_reg <= '{default: 32'd0};
            tc_kernel_in <= '{default: 32'd0};
            image_reg <= '{default: 32'd0};
            result_tiles <= '{default: 32'd0};
        end else begin
            // Default pulse reset
            div_start <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        kernel_reg <= kernel_in;
                        image_reg <= image_in;
                        result_tiles <= '{default: 32'd0};
                        round_idx <= 4'd0;
                        state <= ST_PREP;
                    end
                end

                ST_PREP: begin
                    done <= 1'b0;
                    state <= ST_LOAD;
                end

                ST_LOAD: begin
                    done <= 1'b0;
                    tc_kernel_in <= kernel_reg;
                    tc_start <= 1'b1;
                    state <= ST_WAIT_CLEAR;
                end

                ST_WAIT_CLEAR: begin
                    done <= 1'b0;
                    tc_start <= 1'b0;
                    // Wait for tc_done to clear before waiting for completion
                    if (!tc_done) begin
                        state <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    done <= 1'b0;
                    tc_start <= 1'b0;
                    if (tc_done) begin
                        state <= ST_WRITE;
                    end
                end

                ST_WRITE: begin
                    done <= 1'b0;
                    result_tiles[tile_i][tile_j] <= tc_result_out;

                    if (round_idx == NUM_ROUNDS - 1) begin
                        state <= ST_DIVIDE;
                    end else begin
                        round_idx <= round_idx + 4'd1;
                        state <= ST_PREP;
                    end
                end
                
                ST_DIVIDE: begin
                    div_start <= 1'b1;
                    if (div_done) begin
                        div_start <= 1'b0;
                        state <= ST_FINISH;
                    end
                end

                ST_FINISH: begin
                    done <= 1'b1;
                    if (start) begin
                        done <= 1'b0;
                        kernel_reg <= kernel_in;
                        image_reg <= image_in;
                        result_tiles <= '{default: 32'd0};
                        round_idx <= 4'd0;
                        state <= ST_PREP;
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    tile_controller tc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(tc_start),
        .kernel_in(tc_kernel_in),
        .tile_in(tc_tile_in),
        .result_out(tc_result_out),
        .done(tc_done)
    );

endmodule