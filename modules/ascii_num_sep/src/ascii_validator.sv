`timescale 1ns / 1ps

// ASCII Validator - Validates and buffers payload characters
module ascii_validator #(
    parameter MAX_PAYLOAD = 1200
) (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from uart_packet_handler
    input  logic [7:0]  payload_data,
    input  logic        payload_valid,
    input  logic        payload_last,
    output logic        payload_ready,

    // Clear signal
    input  logic        clear,
    
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

    function automatic logic is_terminator(input logic [7:0] char_in);
        return (char_in == 8'h0A || char_in == 8'h0D);
    endfunction
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            if (clear) begin
                state <= IDLE;
            end else begin
                state <= state_next;
            end
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
                // Stay in DONE until reset or clear
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
            if (clear) begin
                write_ptr <= 16'd0;
                invalid_found <= 1'b0;
                buffer_length <= 16'd0;
                $display("[%0t] Validator Cleared", $time);
            end else begin
                case (state)
                    IDLE: begin
                        // Process first byte if it arrives in IDLE state
                        if (payload_valid) begin
                            $display("[%0t] Validator IDLE: Data=%h, Last=%b", $time, payload_data, payload_last);
                            // Write to buffer if not terminator
                            if (!is_terminator(payload_data)) begin
                                char_buffer[16'd0] <= payload_data;
                                write_ptr <= 16'd1;
                            end else begin
                                write_ptr <= 16'd0;
                            end
                            
                            // Validate character
                            if (!is_valid_char(payload_data) && !is_terminator(payload_data)) begin
                                invalid_found <= 1'b1;
                            end else begin
                                invalid_found <= 1'b0;
                            end
                            
                            // Update length if this is also the last byte
                            if (payload_last) begin
                                if (!is_terminator(payload_data)) begin
                                    buffer_length <= 16'd1;
                                end else begin
                                    buffer_length <= 16'd0;
                                end
                                // $display("[%0t] Validator IDLE Done: Length=%d (Last=%b)", $time, buffer_length, payload_last);
                            end else begin
                                buffer_length <= 16'd0;
                            end
                        end else begin
                        write_ptr <= 16'd0;
                        invalid_found <= 1'b0;
                        buffer_length <= 16'd0;
                    end
                end
                
                VALIDATE: begin
                    if (payload_valid) begin
                        $display("[%0t] Validator VALIDATE: Data=%h, Last=%b, Ptr=%d", $time, payload_data, payload_last, write_ptr);
                        // Write to buffer if not terminator
                        if (!is_terminator(payload_data)) begin
                            char_buffer[write_ptr] <= payload_data;
                            write_ptr <= write_ptr + 16'd1;
                        end
                        
                        // Validate character
                        if (!is_valid_char(payload_data) && !is_terminator(payload_data)) begin
                            invalid_found <= 1'b1;
                        end
                        
                        // Update length on last
                        if (payload_last) begin
                            if (!is_terminator(payload_data)) begin
                                buffer_length <= write_ptr + 16'd1;
                            end else begin
                                buffer_length <= write_ptr;
                            end
                            // $display("[%0t] Validator VALIDATE Done: Length=%d (Last=%b, Ptr=%d)", $time, buffer_length, payload_last, write_ptr);
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
    end
    
    // Output assignments
    assign payload_ready = (state == IDLE || state == VALIDATE);
    assign done = (state == DONE);
    assign invalid = invalid_found;

endmodule