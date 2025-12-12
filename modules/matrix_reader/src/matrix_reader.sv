`timescale 1ns / 1ps

module matrix_reader #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    // Control Interface
    input  logic                  start,
    input  logic [2:0]            matrix_id,
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
    
    // Registers
    logic [2:0]  target_id;
    logic [7:0]  rows;
    logic [7:0]  cols;
    logic [31:0] name_part1;
    logic [31:0] name_part2;
    logic [7:0]  current_row;
    logic [7:0]  current_col;
    logic [31:0] current_val;
    logic [ADDR_WIDTH-1:0] current_addr;
    
    // State Machine
    typedef enum logic [4:0] {
        IDLE,
        READ_META_0, WAIT_META_0, // Rows/Cols
        READ_META_1, WAIT_META_1, // Name 1
        READ_META_2, WAIT_META_2, // Name 2
        SEND_ID,
        SEND_SPACE_1,
        SEND_NAME_0, SEND_NAME_1, SEND_NAME_2, SEND_NAME_3,
        SEND_NAME_4, SEND_NAME_5, SEND_NAME_6, SEND_NAME_7,
        SEND_NEWLINE_1,
        SEND_ROWS,
        SEND_SPACE_2,
        SEND_COLS,
        SEND_NEWLINE_2,
        READ_DATA, WAIT_DATA,
        SEND_DATA,
        SEND_SEP,
        CHECK_LOOP,
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
    
    // Helper to calculate base address
    logic [ADDR_WIDTH-1:0] base_addr;
    assign base_addr = target_id * BLOCK_SIZE;
    
    // State Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            target_id <= 3'd0;
            rows <= 8'd0;
            cols <= 8'd0;
            name_part1 <= 32'd0;
            name_part2 <= 32'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
            current_val <= 32'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0; // Default
            
            case (state)
                IDLE: begin
                    if (start) begin
                        target_id <= matrix_id;
                        state <= READ_META_0;
                    end
                end
                
                // Read Rows/Cols (Addr 0)
                READ_META_0: state <= WAIT_META_0;
                WAIT_META_0: begin
                    // Format: {rows[7:0], cols[7:0], 16'b0} or similar.
                    // Assuming rows at [31:24], cols at [23:16] based on typical packing
                    rows <= bram_data[31:24];
                    cols <= bram_data[23:16];
                    state <= READ_META_1;
                end
                
                // Read Name Part 1 (Addr 1)
                READ_META_1: state <= WAIT_META_1;
                WAIT_META_1: begin
                    name_part1 <= bram_data;
                    state <= READ_META_2;
                end
                
                // Read Name Part 2 (Addr 2)
                READ_META_2: state <= WAIT_META_2;
                WAIT_META_2: begin
                    name_part2 <= bram_data;
                    state <= SEND_ID;
                end
                
                // Send "ID Name\n"
                SEND_ID:        if (pack_ready) state <= SEND_SPACE_1;
                SEND_SPACE_1:   if (pack_ready) state <= SEND_NAME_0;
                
                SEND_NAME_0:    if (pack_ready) state <= SEND_NAME_1;
                SEND_NAME_1:    if (pack_ready) state <= SEND_NAME_2;
                SEND_NAME_2:    if (pack_ready) state <= SEND_NAME_3;
                SEND_NAME_3:    if (pack_ready) state <= SEND_NAME_4;
                SEND_NAME_4:    if (pack_ready) state <= SEND_NAME_5;
                SEND_NAME_5:    if (pack_ready) state <= SEND_NAME_6;
                SEND_NAME_6:    if (pack_ready) state <= SEND_NAME_7;
                SEND_NAME_7:    if (pack_ready) state <= SEND_NEWLINE_1;
                
                SEND_NEWLINE_1: if (pack_ready) state <= SEND_ROWS;
                
                // Send "Rows Cols\n"
                SEND_ROWS:      if (pack_ready) state <= SEND_SPACE_2;
                SEND_SPACE_2:   if (pack_ready) state <= SEND_COLS;
                SEND_COLS:      if (pack_ready) state <= SEND_NEWLINE_2;
                SEND_NEWLINE_2: begin
                    if (pack_ready) begin
                        current_row <= 8'd0;
                        current_col <= 8'd0;
                        current_addr <= base_addr + 3;
                        if (rows == 0 || cols == 0) begin
                            state <= DONE_STATE; // Empty matrix
                        end else begin
                            state <= READ_DATA;
                        end
                    end
                end
                
                // Read Data Loop
                READ_DATA: state <= WAIT_DATA;
                WAIT_DATA: begin
                    current_val <= bram_data;
                    state <= SEND_DATA;
                end
                
                SEND_DATA: if (pack_ready) state <= SEND_SEP;
                
                SEND_SEP: begin
                    if (pack_ready) begin
                        state <= CHECK_LOOP;
                    end
                end
                
                CHECK_LOOP: begin
                    // Increment logic
                    current_addr <= current_addr + 1;
                    if (current_col == cols - 1) begin
                        current_col <= 8'd0;
                        if (current_row == rows - 1) begin
                            state <= DONE_STATE;
                        end else begin
                            current_row <= current_row + 1;
                            state <= READ_DATA;
                        end
                    end else begin
                        current_col <= current_col + 1;
                        state <= READ_DATA;
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
            READ_META_0: bram_addr = base_addr + 0;
            READ_META_1: bram_addr = base_addr + 1;
            READ_META_2: bram_addr = base_addr + 2;
            READ_DATA:   bram_addr = current_addr;
            
            SEND_ID: begin
                pack_valid = 1'b1;
                pack_type = 2'd0; // Number
                pack_data = {29'd0, target_id};
            end
            
            SEND_SPACE_1, SEND_SPACE_2: begin
                pack_valid = 1'b1;
                pack_type = 2'd1; // Space
            end
            
            SEND_NEWLINE_1, SEND_NEWLINE_2: begin
                pack_valid = 1'b1;
                pack_type = 2'd2; // Newline
            end
            
            // Name Sending (Char by Char)
            // Assuming Big Endian: [31:24], [23:16], [15:8], [7:0]
            SEND_NAME_0: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part1[31:24]}; end
            SEND_NAME_1: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part1[23:16]}; end
            SEND_NAME_2: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part1[15:8]}; end
            SEND_NAME_3: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part1[7:0]}; end
            SEND_NAME_4: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part2[31:24]}; end
            SEND_NAME_5: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part2[23:16]}; end
            SEND_NAME_6: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part2[15:8]}; end
            SEND_NAME_7: begin pack_valid=1; pack_type=3; pack_data={24'd0, name_part2[7:0]}; end
            
            SEND_ROWS: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {24'd0, rows};
            end
            
            SEND_COLS: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = {24'd0, cols};
            end
            
            SEND_DATA: begin
                pack_valid = 1'b1;
                pack_type = 2'd0;
                pack_data = current_val;
            end
            
            SEND_SEP: begin
                pack_valid = 1'b1;
                if (current_col == cols - 1)
                    pack_type = 2'd2; // Newline at end of row
                else
                    pack_type = 2'd1; // Space between cols
            end
            
            default: ;
        endcase
    end

endmodule
