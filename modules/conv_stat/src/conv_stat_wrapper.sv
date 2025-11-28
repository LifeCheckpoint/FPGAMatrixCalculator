`timescale 1ns / 1ps

module conv_stat_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] kernel_in  [0:2][0:2],
    output logic [31:0] result_out [0:7][0:9],
    output logic        done,
    output logic [31:0] cycle_count
);

    // State machine definition
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_LOAD_IMAGE,
        ST_CONV,
        ST_DONE
    } state_t;

    state_t state;
    
    // ROM interface signals
    logic [3:0] rom_x;
    logic [3:0] rom_y;
    logic [3:0] rom_data;
    
    // Image buffer (10x12, 32-bit)
    logic [31:0] image_buffer [0:9][0:11];
    
    // ROM read counter
    logic [6:0] read_counter;  // 0-119
    logic [3:0] read_x;
    logic [3:0] read_y;
    
    // Winograd convolution module interface
    logic        conv_start;
    logic [31:0] conv_image_in   [0:9][0:11];
    logic [31:0] conv_kernel_in  [0:2][0:2];
    logic [31:0] conv_result_out [0:7][0:9];
    logic        conv_done;
    logic        conv_done_prev;  // To detect rising edge
    
    // Cycle counter
    logic [31:0] cycle_counter;
    logic        counting;
    
    // ROM address calculation
    assign read_x = read_counter / 12;
    assign read_y = read_counter % 12;
    assign rom_x = read_x;
    assign rom_y = read_y;
    
    // ROM instantiation
    input_image_rom rom_inst (
        .clk(clk),
        .x(rom_x),
        .y(rom_y),
        .data_out(rom_data)
    );
    
    // Winograd convolution module instantiation
    winograd_conv_10x12 conv_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(conv_start),
        .image_in(conv_image_in),
        .kernel_in(conv_kernel_in),
        .result_out(conv_result_out),
        .done(conv_done)
    );
    
    // Main state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            read_counter <= 7'd0;
            conv_start <= 1'b0;
            done <= 1'b0;
            conv_done_prev <= 1'b0;
            image_buffer <= '{default: 32'd0};
            conv_image_in <= '{default: 32'd0};
            conv_kernel_in <= '{default: 32'd0};
            result_out <= '{default: 32'd0};
        end else begin
            case (state)
                ST_IDLE: begin
                    done <= 1'b0;
                    conv_start <= 1'b0;
                    if (start) begin
                        read_counter <= 7'd0;
                        state <= ST_LOAD_IMAGE;
                    end
                end
                
                ST_LOAD_IMAGE: begin
                    if (read_counter <= 7'd120) begin
                        // Store data with ROM delay (data arrives next cycle)
                        if (read_counter >= 7'd1) begin
                            logic [3:0] prev_x, prev_y;
                            prev_x = (read_counter - 7'd1) / 7'd12;
                            prev_y = (read_counter - 7'd1) % 7'd12;
                            image_buffer[prev_x][prev_y] <= {28'd0, rom_data};
                        end
                        read_counter <= read_counter + 7'd1;
                    end else begin
                        // All data loaded, prepare convolution inputs
                        conv_image_in <= image_buffer;
                        conv_kernel_in <= kernel_in;
                        conv_start <= 1'b1;  // Generate single start pulse
                        state <= ST_CONV;
                    end
                end
                
                ST_CONV: begin
                    conv_start <= 1'b0;  // Clear start signal after one cycle
                    conv_done_prev <= conv_done;  // Track previous value
                    // Wait for rising edge of conv_done (transition from 0 to 1)
                    if (conv_done && !conv_done_prev) begin
                        result_out <= conv_result_out;
                        done <= 1'b1;
                        state <= ST_DONE;
                    end
                end
                
                ST_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= ST_IDLE;
                    end
                end
                
                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
    
    // Cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 32'd0;
            cycle_count <= 32'd0;
            counting <= 1'b0;
        end else begin
            if (state == ST_IDLE && start) begin
                // Start counting and clear previous count
                cycle_counter <= 32'd1;
                cycle_count <= 32'd0;
                counting <= 1'b1;
            end else if (counting && !done) begin
                // Continue counting
                cycle_counter <= cycle_counter + 32'd1;
            end else if (done && counting) begin
                // Done, latch the count and stop counting
                cycle_count <= cycle_counter;
                counting <= 1'b0;
            end
            // Keep cycle_count value when idle - don't clear it
        end
    end

endmodule