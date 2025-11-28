`timescale 1ns / 1ps

// ASCII Validator - Validates and buffers payload characters
module ascii_validator #(
    parameter MAX_PAYLOAD = 2048
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from uart_packet_handler
    input  logic [7:0]  payload_data,
    input  logic        payload_valid,
    input  logic        payload_last,
    output logic        payload_ready,
    
    // Character buffer for downstream
    output logic [7:0]  char_buffer [0:MAX_PAYLOAD-1],
    output logic [15:0] buffer_length,
    
    // Output status
    output logic        done,
    output logic        invalid         // 1: found invalid char
);

    typedef enum logic [1:0] {
        IDLE,
        VALIDATE,
        DONE
    } state_t;
    
    state_t state, state_next;
    
    // Internal registers
    logic [15:0] write_ptr;
    logic invalid_found;
    
    // Character validation function
    function automatic logic is_valid_char(input logic [7:0] char_in);
        // Valid: '0'-'9' (0x30-0x39), space (0x20), minus (0x2D)
        return ((char_in >= 8'h30 && char_in <= 8'h39) ||  // digits
                (char_in == 8'h20) ||                       // space
                (char_in == 8'h2D));                        // minus
    endfunction
    
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
                if (payload_valid) begin
                    state_next = VALIDATE;
                end
            end
            
            VALIDATE: begin
                if (payload_valid && payload_last) begin
                    state_next = DONE;
                end
            end
            
            DONE: begin
                // Stay in DONE until reset
                state_next = DONE;
            end
            
            default: state_next = IDLE;
        endcase
    end
    
    // Buffer write and validation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 16'd0;
            invalid_found <= 1'b0;
            buffer_length <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    write_ptr <= 16'd0;
                    invalid_found <= 1'b0;
                    buffer_length <= 16'd0;
                end
                
                VALIDATE: begin
                    if (payload_valid) begin
                        // Write to buffer
                        char_buffer[write_ptr] <= payload_data;
                        write_ptr <= write_ptr + 16'd1;
                        
                        // Validate character
                        if (!is_valid_char(payload_data)) begin
                            invalid_found <= 1'b1;
                        end
                        
                        // Update length on last
                        if (payload_last) begin
                            buffer_length <= write_ptr + 16'd1;
                        end
                    end
                end
                
                DONE: begin
                    // Keep values stable
                end
                
                default: begin
                    write_ptr <= 16'd0;
                    invalid_found <= 1'b0;
                    buffer_length <= 16'd0;
                end
            endcase
        end
    end
    
    // Output assignments
    assign payload_ready = (state == IDLE || state == VALIDATE);
    assign done = (state == DONE);
    assign invalid = invalid_found;

endmodule