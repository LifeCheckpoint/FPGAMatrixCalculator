`timescale 1ns / 1ps

module matrix_info_reader #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control Interface
    input  logic                  start,
    output logic                  busy,
    output logic                  done,
    
    // BRAM Read Interface
    output logic [ADDR_WIDTH-1:0] bram_addr,
    input  logic [31:0]           bram_data,
    
    // ASCII Output Interface
    output logic [7:0]            ascii_data,
    output logic                  ascii_valid,
    input  logic                  ascii_ready
);

    // Internal Signals
    logic [31:0] pack_data;
    logic [1:0]  pack_type;
    logic        pack_valid;
    logic        pack_ready;
    
    // Storage
    logic [15:0] dims [0:7]; // {rows[7:0], cols[7:0]}
    logic [7:0]  valid_mask;
    logic [7:0]  processed_mask;
    logic [2:0]  scan_idx;
    logic [2:0]  stat_idx;
    logic [2:0]  compare_idx;
    logic [3:0]  match_count; // Max 8
    logic [3:0]  total_count;
    
    // State Machine
    typedef enum logic [4:0] {
        IDLE,
        SCAN_INIT,
        READ_META, WAIT_META,
        SCAN_NEXT,
        CALC_TOTAL,
        SEND_TOTAL,
        SEND_SPACE_1,
        STATS_INIT,
        CHECK_CURRENT,
        COUNT_MATCHES_INIT,
        COUNT_MATCHES_LOOP,
        SEND_R, SEND_X1, SEND_C, SEND_X2, SEND_COUNT,
        SEND_SEP,
        STATS_NEXT,
        DONE_STATE
    } state_t;
    
    state_t state;
    
    // ASCII Pack Instance
    ascii_num_pack u_ascii_pack (
        .clk        (clk),
        .rst_n      (rst_n),
        .input_data (pack_data),
        .input_type (pack_type),
        .input_valid(pack_valid),
        .input_ready(pack_ready),
        .ascii_data (ascii_data),
        .ascii_valid(ascii_valid),
        .ascii_ready(ascii_ready),
        .busy       ()
    );
    
    // State Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scan_idx <= 0;
            stat_idx <= 0;
            compare_idx <= 0;
            valid_mask <= 0;
            processed_mask <= 0;
            match_count <= 0;
            total_count <= 0;
            done <= 1'b0;
            // Initialize dims
            for (int i=0; i<8; i++) dims[i] <= 16'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SCAN_INIT;
                    end
                end
                
                SCAN_INIT: begin
                    scan_idx <= 0;
                    valid_mask <= 0;
                    state <= READ_META;
                end
                
                READ_META: state <= WAIT_META;
                
                WAIT_META: begin
                    // bram_data: {rows, cols, ...}
                    logic [7:0] r, c;
                    r = bram_data[31:24];
                    c = bram_data[23:16];
                    dims[scan_idx] <= {r, c};
                    
                    if (r > 0 && c > 0)
                        valid_mask[scan_idx] <= 1'b1;
                    else
                        valid_mask[scan_idx] <= 1'b0;
                        
                    state <= SCAN_NEXT;
                end
                
                SCAN_NEXT: begin
                    if (scan_idx == 7) begin
                        state <= CALC_TOTAL;
                    end else begin
                        scan_idx <= scan_idx + 1;
                        state <= READ_META;
                    end
                end
                
                CALC_TOTAL: begin
                    // Count total valid matrices
                    logic [3:0] cnt;
                    cnt = 0;
                    for (int i=0; i<8; i++) begin
                        if (valid_mask[i]) cnt++;
                    end
                    total_count <= cnt;
                    processed_mask <= 0;
                    state <= SEND_TOTAL;
                end
                
                SEND_TOTAL: if (pack_ready) state <= SEND_SPACE_1;
                SEND_SPACE_1: if (pack_ready) state <= STATS_INIT;
                
                STATS_INIT: begin
                    stat_idx <= 0;
                    state <= CHECK_CURRENT;
                end
                
                CHECK_CURRENT: begin
                    if (stat_idx > 7) begin // Loop finished (using 3 bits, so check overflow logic or use 4 bits)
                        // Wait, stat_idx is 3 bits. It wraps to 0.
                        // Need better loop control.
                        // Let's check logic below.
                        state <= DONE_STATE; 
                    end else if (!valid_mask[stat_idx] || processed_mask[stat_idx]) begin
                        // Skip invalid or processed
                        if (stat_idx == 7) state <= DONE_STATE;
                        else begin
                            stat_idx <= stat_idx + 1;
                            state <= CHECK_CURRENT;
                        end
                    end else begin
                        // Found a new valid matrix type
                        state <= COUNT_MATCHES_INIT;
                    end
                end
                
                COUNT_MATCHES_INIT: begin
                    match_count <= 0;
                    compare_idx <= stat_idx; // Start from current
                    state <= COUNT_MATCHES_LOOP;
                end
                
                COUNT_MATCHES_LOOP: begin
                    // Check if compare_idx matches stat_idx dimensions
                    if (valid_mask[compare_idx] && !processed_mask[compare_idx]) begin
                        if (dims[compare_idx] == dims[stat_idx]) begin
                            match_count <= match_count + 1;
                            processed_mask[compare_idx] <= 1'b1; // Mark as processed
                        end
                    end
                    
                    if (compare_idx == 7) begin
                        state <= SEND_R;
                    end else begin
                        compare_idx <= compare_idx + 1;
                        state <= COUNT_MATCHES_LOOP;
                    end
                end
                
                // Send R*C*Count
                SEND_R: if (pack_ready) state <= SEND_X1;
                SEND_X1: if (pack_ready) state <= SEND_C;
                SEND_C: if (pack_ready) state <= SEND_X2;
                SEND_X2: if (pack_ready) state <= SEND_COUNT;
                SEND_COUNT: if (pack_ready) state <= SEND_SEP;
                
                SEND_SEP: begin
                    if (pack_ready) begin
                        if (stat_idx == 7) state <= DONE_STATE;
                        else begin
                            stat_idx <= stat_idx + 1;
                            state <= CHECK_CURRENT;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Output Logic
    always_comb begin
        busy = (state != IDLE);
        bram_addr = 0;
        pack_valid = 1'b0;
        pack_data = 0;
        pack_type = 2'd0; // 0:Num, 1:Space, 2:NL, 3:Char
        
        case (state)
            READ_META: bram_addr = scan_idx * BLOCK_SIZE;
            
            SEND_TOTAL: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {28'd0, total_count};
            end
            
            SEND_SPACE_1, SEND_SEP: begin
                pack_valid = 1'b1;
                pack_type = 2'd1; // Space
            end
            
            SEND_R: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {24'd0, dims[stat_idx][15:8]}; // Rows
            end
            
            SEND_X1, SEND_X2: begin
                pack_valid = 1'b1;
                pack_type = 2'd3; // Char
                pack_data = {24'd0, 8'h2A}; // '*'
            end
            
            SEND_C: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {24'd0, dims[stat_idx][7:0]}; // Cols
            end
            
            SEND_COUNT: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {28'd0, match_count};
            end
            
            default: ;
        endcase
    end

endmodule
