`timescale 1ns / 1ps

// ASCII to INT32 Converter - Converts ASCII digit stream to signed 32-bit integer
module ascii_to_int32 (
    input  logic                clk,
    input  logic                rst_n,
    
    // Control interface
    input  logic                start,          // begin new number
    input  logic [7:0]          char_in,
    input  logic                char_valid,
    input  logic                num_end,        // end of current number
    
    // Output
    output logic signed [31:0]  result,
    output logic                result_valid
);

    // Internal registers
    logic signed [31:0] accumulator;
    logic               is_negative;
    
    typedef enum logic [1:0] {
        IDLE,
        ACCUMULATE,
        OUTPUT
    } state_t;
    
    state_t state, state_next;
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end
    
    // Next state logic
    always_comb begin
        state_next = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    state_next = ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                if (num_end) begin
                    state_next = OUTPUT;
                end
            end
            
            OUTPUT: begin
                state_next = IDLE;
            end
            
            default: state_next = IDLE;
        endcase
    end
    
    // Accumulator logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 32'sd0;
            is_negative <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        accumulator <= 32'sd0;
                        is_negative <= 1'b0;
                    end
                end
                
                ACCUMULATE: begin
                    if (char_valid) begin
                        if (char_in == 8'h2D) begin  // minus sign '-'
                            is_negative <= 1'b1;
                        end else if (char_in >= 8'h30 && char_in <= 8'h39) begin  // digit '0'-'9'
                            // accumulator = accumulator * 10 + (char - '0')
                            accumulator <= accumulator * 10 + (char_in - 8'd48);
                        end
                    end
                end
                
                OUTPUT: begin
                    // Keep accumulator value for output
                end
                
                default: begin
                    accumulator <= 32'sd0;
                    is_negative <= 1'b0;
                end
            endcase
        end
    end
    
    // Output logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'sd0;
            result_valid <= 1'b0;
        end else begin
            if (state == OUTPUT) begin
                result <= is_negative ? -accumulator : accumulator;
                result_valid <= 1'b1;
            end else begin
                result_valid <= 1'b0;
            end
        end
    end

endmodule