`timescale 1ns / 1ps

module tile_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] kernel_in  [0:2][0:2],  // 3x3 kernel input
    input  logic [31:0] tile_in    [0:5][0:5],  // 6x6 tile input
    output logic [31:0] result_out [0:3][0:3],  // 4x4 result output
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
    logic [31:0] ktu_kernel_in [0:2][0:2];
    logic [31:0] ktu_kernel_out [0:5][0:5];
    logic ktu_done;
    
    // TTU signals
    logic ttu_start;
    logic [31:0] ttu_tile_in [0:5][0:5];
    logic [31:0] ttu_tile_out [0:5][0:5];
    logic ttu_done;
    
    // Pointwise multiplication signals
    logic mult_start;
    logic signed [31:0] mult_U [0:5][0:5];
    logic signed [31:0] mult_V [0:5][0:5];
    logic signed [63:0] mult_M [0:5][0:5];
    logic mult_done;
    logic mult_busy;
    
    // RTU signals
    logic rtu_start;
    logic signed [63:0] rtu_M [0:5][0:5];
    logic signed [63:0] rtu_R [0:3][0:3];
    logic rtu_done;
    logic rtu_busy;
    
    // Internal registers
    logic [31:0] U [0:5][0:5];  // Transformed kernel
    logic [31:0] V [0:5][0:5];  // Transformed tile
    logic signed [63:0] M [0:5][0:5];  // Pointwise product result
    
    logic ktu_finished;
    logic ttu_finished;

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
                    if (ktu_finished && ttu_finished) begin
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
            ktu_finished <= 1'b0;
            ttu_finished <= 1'b0;
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    ktu_kernel_in[i][j] <= 32'd0;
                end
            end
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    ttu_tile_in[i][j] <= 32'd0;
                    U[i][j] <= 32'd0;
                    V[i][j] <= 32'd0;
                    M[i][j] <= 64'd0;
                end
            end
            result_out <= '{default: 32'd0};
        end else begin
            // Default: clear all start signals
            ktu_start <= 1'b0;
            ttu_start <= 1'b0;
            rtu_start <= 1'b0;
            mult_start <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    ktu_finished <= 1'b0;
                    ttu_finished <= 1'b0;
                    if (start) begin
                        ktu_kernel_in <= kernel_in;
                        ttu_tile_in <= tile_in;
                        for (int i = 0; i < 6; i++) begin
                            for (int j = 0; j < 6; j++) begin
                                U[i][j] <= 32'd0;
                                V[i][j] <= 32'd0;
                                M[i][j] <= 64'd0;
                            end
                        end
                    end
                end
                
                S_TRANSFORM: begin
                    if (!ktu_finished && !ktu_done) begin
                        ktu_start <= 1'b1;
                    end
                    if (!ttu_finished && !ttu_done) begin
                        ttu_start <= 1'b1;
                    end
                    
                    if (ktu_done) begin
                        U <= ktu_kernel_out;
                        ktu_finished <= 1'b1;
                    end
                    if (ttu_done) begin
                        V <= ttu_tile_out;
                        ttu_finished <= 1'b1;
                    end
                end
                
                S_POINTWISE_MULT: begin
                    // Trigger multiplier on entry
                    if (!mult_done && !mult_busy) begin
                        mult_start <= 1'b1;
                    end
                    
                    if (mult_done) begin
                        M <= mult_M;
                    end
                end
                
                S_REVERSE_TRANSFORM: begin
                    // Trigger RTU on entry
                    if (!rtu_done && !rtu_busy) begin
                        rtu_start <= 1'b1;
                    end
                    
                    if (rtu_done) begin
                        // Latch final result (truncate to 32 bits)
                        for (int i = 0; i < 4; i++) begin
                            for (int j = 0; j < 4; j++) begin
                                result_out[i][j] <= rtu_R[i][j][31:0];
                            end
                        end
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
    // No truncation needed for 32-bit inputs
    always_comb begin
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 6; j++) begin
                mult_U[i][j] = signed'(U[i][j]);
                mult_V[i][j] = signed'(V[i][j]);
            end
        end
    end
    
    assign rtu_M = M;
    
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
        .U(mult_U),
        .V(mult_V),
        .M(mult_M),
        .done(mult_done),
        .busy(mult_busy)
    );
    
    // Instantiate RTU
    reverse_transform_unit rtu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(rtu_start),
        .M(rtu_M),
        .R(rtu_R),
        .done(rtu_done),
        .busy(rtu_busy)
    );

endmodule
