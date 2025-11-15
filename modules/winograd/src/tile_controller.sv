`timescale 1ns / 1ps

module tile_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [15:0] kernel_in  [0:2][0:2],  // 3x3 kernel input
    input  logic [15:0] tile_in    [0:5][0:5],  // 6x6 tile input
    output logic [15:0] result_out [0:3][0:3],  // 4x4 result output
    output logic        done
);

    localparam S_IDLE              = 3'b000;
    localparam S_TRANSFORM         = 3'b001;
    localparam S_POINTWISE_MULT    = 3'b010;
    localparam S_REVERSE_TRANSFORM = 3'b011;
    localparam S_DONE              = 3'b100;
    
    logic [2:0] state;
    
    // KTU signals
    logic ktu_start;
    logic [15:0] ktu_kernel_in [0:2][0:2];
    logic [15:0] ktu_kernel_out [0:5][0:5];
    logic ktu_done;
    
    // TTU signals
    logic ttu_start;
    logic [15:0] ttu_tile_in [0:5][0:5];
    logic [15:0] ttu_tile_out [0:5][0:5];
    logic ttu_done;
    
    // Pointwise multiplication signals
    logic mult_start;
    logic [15:0] mult_a [6][6];
    logic [15:0] mult_b [6][6];
    logic [31:0] mult_c [6][6];
    logic mult_done;
    
    // RTU signals
    logic rtu_start;
    logic [15:0] rtu_matrix_in [0:5][0:5];
    logic [15:0] rtu_matrix_out [0:3][0:3];
    logic rtu_done;
    
    // Internal registers
    logic [15:0] U [0:5][0:5];  // Transformed kernel
    logic [15:0] V [0:5][0:5];  // Transformed tile
    logic [15:0] M [0:5][0:5];  // Pointwise product result
    
    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        state <= S_TRANSFORM;
                    end
                end
                
                S_TRANSFORM: begin
                    if (ktu_done && ttu_done) begin
                        state <= S_POINTWISE_MULT;
                    end
                end
                
                S_POINTWISE_MULT: begin
                    if (mult_done) begin
                        state <= S_REVERSE_TRANSFORM;
                    end
                end
                
                S_REVERSE_TRANSFORM: begin
                    if (rtu_done) begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        done <= 1'b0;
                        state <= S_IDLE;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                
                default: begin
                    state <= S_IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Control logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ktu_start <= 1'b0;
            ttu_start <= 1'b0;
            rtu_start <= 1'b0;
            mult_start <= 1'b0;
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    ktu_kernel_in[i][j] <= 16'd0;
                end
            end
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    ttu_tile_in[i][j] <= 16'd0;
                    U[i][j] <= 16'd0;
                    V[i][j] <= 16'd0;
                    M[i][j] <= 16'd0;
                end
            end
        end else begin
            // Default: clear all start signals
            ktu_start <= 1'b0;
            ttu_start <= 1'b0;
            rtu_start <= 1'b0;
            mult_start <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (start) begin
                        ktu_kernel_in <= kernel_in;
                        ttu_tile_in <= tile_in;
                        for (int i = 0; i < 6; i++) begin
                            for (int j = 0; j < 6; j++) begin
                                U[i][j] <= 16'd0;
                                V[i][j] <= 16'd0;
                                M[i][j] <= 16'd0;
                            end
                        end
                    end
                end
                
                S_TRANSFORM: begin
                    if (!ktu_done) begin
                        ktu_start <= 1'b1;
                    end
                    if (!ttu_done) begin
                        ttu_start <= 1'b1;
                    end
                    
                    if (ktu_done) begin
                        U <= ktu_kernel_out;
                    end
                    if (ttu_done) begin
                        V <= ttu_tile_out;
                    end
                end
                
                S_POINTWISE_MULT: begin
                    // Trigger multiplier on entry
                    if (!mult_done) begin
                        mult_start <= 1'b1;
                    end
                    
                    if (mult_done) begin
                        // Convert 32-bit to 16-bit and latch
                        for (int i = 0; i < 6; i++) begin
                            for (int j = 0; j < 6; j++) begin
                                M[i][j] <= mult_c[i][j][15:0];
                            end
                        end
                    end
                end
                
                S_REVERSE_TRANSFORM: begin
                    // Trigger RTU on entry
                    if (!rtu_done) begin
                        rtu_start <= 1'b1;
                    end
                    
                    if (rtu_done) begin
                        // Latch final result
                        result_out <= rtu_matrix_out;
                    end
                end
                
                S_DONE: begin
                end
                
                default: begin
                end
            endcase
        end
    end
    
    // Module connections
    assign mult_a = U;
    assign mult_b = V;
    assign rtu_matrix_in = M;
    
    // Instantiate KTU
    kernel_transform_unit ktu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ktu_start),
        .kernel_in(ktu_kernel_in),
        .kernel_out(ktu_kernel_out),
        .transform_done(ktu_done)
    );
    
    // Instantiate TTU
    tile_transform_unit ttu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ttu_start),
        .tile_in(ttu_tile_in),
        .tile_out(ttu_tile_out),
        .transform_done(ttu_done)
    );
    
    // Instantiate pointwise multiplier
    matrix_pointwise_mult_6x6 mult_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(mult_start),
        .a(mult_a),
        .b(mult_b),
        .c(mult_c),
        .done(mult_done)
    );
    
    // Instantiate RTU
    reverse_transform_unit rtu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(rtu_start),
        .matrix_in(rtu_matrix_in),
        .matrix_out(rtu_matrix_out),
        .transform_done(rtu_done)
    );

endmodule