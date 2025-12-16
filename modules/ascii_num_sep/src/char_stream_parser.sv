`timescale 1ns / 1ps

// Character Stream Parser - Parses character stream and identifies number boundaries
module char_stream_parser #(
    parameter MAX_PAYLOAD = 1200
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control input
    input  logic        start,              // from validator.done && !invalid
    input  logic        clear,              // Clear/Reset signal
    input  logic [15:0] total_length,
    
    // Character buffer read interface
    input  logic [7:0]  char_buffer [0:MAX_PAYLOAD-1],
    
    // Control to ascii_to_int32
    output logic        num_start,          // start new number
    output logic [7:0]  num_char,
    output logic        num_valid,          // valid digit/minus
    output logic        num_end,            // number complete
    
    // Feedback from ascii_to_int32
    input  logic        result_valid,       // conversion done
    
    // Status
    output logic [10:0] num_count,          // total numbers parsed
    output logic        parse_done
);

    typedef enum logic [3:0] {
        IDLE,
        FETCH_SKIP,
        CHECK_SKIP,
        FETCH_NUM,
        CHECK_NUM,
        END_NUMBER,
        WAIT_CONVERT,
        DONE
    } state_t;
    
    state_t state;
    
    // Internal registers
    logic [15:0] read_ptr;
    logic [10:0] number_count;
    logic [7:0]  current_char;
    
    // Helper function: is space
    function automatic logic is_space(input logic [7:0] c);
        return (c == 8'h20);
    endfunction
    
    // Main State Machine and Data Path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_ptr <= 16'd0;
            current_char <= 8'd0;
            number_count <= 11'd0;
            
            // Outputs
            num_start <= 1'b0;
            num_char <= 8'd0;
            num_valid <= 1'b0;
            num_end <= 1'b0;
        end else begin
            if (clear) begin
                state <= IDLE;
                read_ptr <= 16'd0;
                current_char <= 8'd0;
                number_count <= 11'd0;
                $display("[%0t] Parser Cleared", $time);
                
                // Reset outputs
                num_start <= 1'b0;
                num_valid <= 1'b0;
                num_end <= 1'b0;
            end else begin
                // Default pulse signals
                num_start <= 1'b0;
                num_valid <= 1'b0;
                num_end <= 1'b0;
                
                case (state)
                    IDLE: begin
                        read_ptr <= 16'd0;
                        number_count <= 11'd0;
                        if (start) begin
                            state <= FETCH_SKIP;
                        end
                    end
                    
                    FETCH_SKIP: begin
                        // Fetch character to check for space
                        if (read_ptr >= total_length) begin
                            state <= DONE;
                        end else begin
                            current_char <= char_buffer[read_ptr];
                            state <= CHECK_SKIP;
                        end
                    end
                    
                    CHECK_SKIP: begin
                        // Check if the fetched character is a space
                        if (is_space(current_char)) begin
                            // It's a space, skip it
                            read_ptr <= read_ptr + 16'd1;
                            state <= FETCH_SKIP;
                        end else begin
                            // It's not a space, so it's the start of a number
                            num_start <= 1'b1;
                            num_char <= current_char;
                            num_valid <= 1'b1;
                            
                            // Move to next char
                            read_ptr <= read_ptr + 16'd1;
                            state <= FETCH_NUM;
                        end
                    end
                    
                    FETCH_NUM: begin
                        // Fetch next character of the number
                        if (read_ptr >= total_length) begin
                            // End of stream ends the number
                            state <= END_NUMBER;
                        end else begin
                            current_char <= char_buffer[read_ptr];
                            state <= CHECK_NUM;
                        end
                    end
                    
                    CHECK_NUM: begin
                        // Check if the fetched character is a space (end of number)
                        if (is_space(current_char)) begin
                            // Space found, number ends. 
                            // Do NOT increment read_ptr here. The space is preserved 
                            // and will be handled (skipped) after conversion.
                            state <= END_NUMBER;
                        end else begin
                            // Valid number character
                            num_char <= current_char;
                            num_valid <= 1'b1;
                            
                            // Move to next char
                            read_ptr <= read_ptr + 16'd1;
                            state <= FETCH_NUM;
                        end
                    end
                    
                    END_NUMBER: begin
                        num_end <= 1'b1;
                        state <= WAIT_CONVERT;
                    end
                    
                    WAIT_CONVERT: begin
                        if (result_valid) begin
                            number_count <= number_count + 11'd1;
                            // Conversion done. Go back to skipping spaces.
                            // Note: If we ended on a space, read_ptr still points to it.
                            // FETCH_SKIP will read it, CHECK_SKIP will see it's a space and skip it.
                            state <= FETCH_SKIP;
                        end
                    end
                    
                    DONE: begin
                        // Stay in DONE until clear/reset
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
    
    // Output assignments
    assign num_count = number_count;
    assign parse_done = (state == DONE);

endmodule
