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

    typedef enum logic [2:0] {
        IDLE,
        SKIP_SPACE,
        PARSE_NUMBER,
        END_NUMBER,
        WAIT_CONVERT,
        DONE
    } state_t;
    
    state_t state, state_next;
    
    // Internal registers
    logic [15:0] read_ptr;
    logic [10:0] number_count;
    logic [7:0]  current_char;
    logic        in_number;
    
    // Helper function: is space
    function automatic logic is_space(input logic [7:0] c);
        return (c == 8'h20);
    endfunction
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            if (clear) begin
                state <= IDLE;
                $display("[%0t] Parser Cleared", $time);
            end else begin
                state <= state_next;
                if (state != state_next)
                    $display("[%0t] Parser State: %d -> %d (Ptr=%d, Len=%d)", $time, state, state_next, read_ptr, total_length);
            end
        end
    end
    
    // Next state logic
    always_comb begin
        state_next = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    state_next = SKIP_SPACE;
                    end
                end
                
                SKIP_SPACE: begin
                if (read_ptr >= total_length) begin
                    state_next = DONE;
                end else if (!is_space(char_buffer[read_ptr])) begin
                    state_next = PARSE_NUMBER;
                    end
                end
                
                PARSE_NUMBER: begin
                if (read_ptr >= total_length) begin
                    // End of stream, finish current number
                    state_next = END_NUMBER;
                end else if (is_space(char_buffer[read_ptr])) begin
                    // Space encountered, end current number
                    state_next = END_NUMBER;
                end
            end
            
            END_NUMBER: begin
                state_next = WAIT_CONVERT;
            end
            
            WAIT_CONVERT: begin
                if (result_valid) begin
                    if (read_ptr >= total_length) begin
                        state_next = DONE;
                    end else begin
                        state_next = SKIP_SPACE;
                    end
                end
            end
            
            DONE: begin
                state_next = DONE;
            end
            
            default: state_next = IDLE;
        endcase
    end
    
    // Read pointer and character management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 16'd0;
            current_char <= 8'd0;
            in_number <= 1'b0;
            number_count <= 11'd0;
        end else begin
            if (clear) begin
                read_ptr <= 16'd0;
                current_char <= 8'd0;
                in_number <= 1'b0;
                number_count <= 11'd0;
            end else begin
                case (state)
                    IDLE: begin
                    read_ptr <= 16'd0;
                    current_char <= 8'd0;
                    in_number <= 1'b0;
                    number_count <= 11'd0;
                end
                
                SKIP_SPACE: begin
                    current_char <= char_buffer[read_ptr];
                    if (is_space(char_buffer[read_ptr])) begin
                        read_ptr <= read_ptr + 16'd1;
                    end else begin
                        // Found start of number, advance to next char for PARSE_NUMBER state
                        read_ptr <= read_ptr + 16'd1;
                        if (read_ptr + 16'd1 < total_length) begin
                            current_char <= char_buffer[read_ptr + 16'd1];
                        end
                    end
                    in_number <= 1'b0;
                end
                
                PARSE_NUMBER: begin
                    if (state != state_next) begin
                        // Transitioning out, don't advance yet
                        in_number <= 1'b1;
                    end else begin
                        // Continue parsing
                        read_ptr <= read_ptr + 16'd1;
                        if (read_ptr + 16'd1 < total_length) begin
                            current_char <= char_buffer[read_ptr + 16'd1];
                        end
                        in_number <= 1'b1;
                        end
                    end
                    
                    END_NUMBER: begin
                        in_number <= 1'b0;
                    end
                    
                    WAIT_CONVERT: begin
                    if (result_valid) begin
                        number_count <= number_count + 11'd1;
                        if (read_ptr < total_length) begin
                            read_ptr <= read_ptr + 16'd1;
                            current_char <= char_buffer[read_ptr];
                        end
                        end
                    end
                    
                    DONE: begin
                        // Keep stable
                    end
                    
                    default: begin
                        read_ptr <= 16'd0;
                        current_char <= 8'd0;
                        in_number <= 1'b0;
                        number_count <= 11'd0;
                    end
                endcase
            end
        end
    end
    
    // Control signal generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_start <= 1'b0;
            num_char <= 8'd0;
            num_valid <= 1'b0;
            num_end <= 1'b0;
        end else begin
            // Default: clear one-cycle pulses
            num_start <= 1'b0;
            num_end <= 1'b0;
            
            case (state)
                SKIP_SPACE: begin
                    if (state_next == PARSE_NUMBER) begin
                        // Entering number, send start pulse
                        num_start <= 1'b1;
                        num_char <= char_buffer[read_ptr];
                        num_valid <= 1'b1;
                    end else begin
                        num_valid <= 1'b0;
                    end
                end
                
                PARSE_NUMBER: begin
                    if (state_next == PARSE_NUMBER) begin
                        // Continue sending chars
                        num_char <= current_char;
                        num_valid <= 1'b1;
                    end else begin
                        // Leaving number state
                        num_valid <= 1'b0;
                    end
                end
                
                END_NUMBER: begin
                    num_end <= 1'b1;
                    num_valid <= 1'b0;
                end
                
                default: begin
                    num_valid <= 1'b0;
                end
            endcase
        end
    end
    
    // Output assignments
    assign num_count = number_count;
    assign parse_done = (state == DONE);

endmodule