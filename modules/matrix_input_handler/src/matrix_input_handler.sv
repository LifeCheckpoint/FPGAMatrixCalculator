`timescale 1ns / 1ps

// Matrix input handler: reads matrix data from buffer RAM (num_storage_ram)
// and writes to matrix storage manager
// Data format in buffer RAM (all 32-bit signed integers):
//   Named matrix:    -1, id, name[0-7], rows, cols, data[0..rows*cols-1]
//   Anonymous matrix: rows, cols, data[0..rows*cols-1]
module matrix_input_handler (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        start,              // One-cycle pulse to start processing
    output logic        error,              // Error flag, stays high until reset
    output logic        busy,               // Processing in progress
    output logic        done,               // Processing complete
    
    // Settings interface (from settings_ram)
    input  logic [31:0] settings_max_row,
    input  logic [31:0] settings_max_col,
    input  logic [31:0] settings_data_min,
    input  logic [31:0] settings_data_max,
    
    // Buffer RAM read interface (from num_storage_ram)
    output logic [10:0] buf_rd_addr,
    input  logic [31:0] buf_rd_data,
    
    // Matrix storage manager write interface
    output logic        write_request,
    input  logic        write_ready,
    output logic [2:0]  matrix_id,
    output logic [7:0]  actual_rows,
    output logic [7:0]  actual_cols,
    output logic [7:0]  matrix_name [0:7],
    output logic [31:0] data_in,
    output logic        data_valid,
    input  logic        write_done,
    input  logic        writer_ready,
    
    // Matrix storage manager clear interface
    output logic        clear_request,
    input  logic        clear_done,
    output logic [2:0]  clear_matrix_id,
    
    // Matrix storage manager read interface (for checking empty slots)
    output logic [13:0] storage_rd_addr,
    input  logic [31:0] storage_rd_data
);

    // State machine
    typedef enum logic [4:0] {
        IDLE,
        READ_FIRST,             // Read first word to determine named/anonymous
        WAIT_FIRST,             // Wait for BRAM read latency
        READ_ID,                // For named: read matrix ID
        WAIT_ID,
        READ_NAME_0,            // Read name words 0-7 (each word has 4 ASCII bytes)
        WAIT_NAME_0,
        READ_NAME_1,
        WAIT_NAME_1,
        READ_ROWS,              // Read rows count
        WAIT_ROWS,
        READ_COLS,              // Read cols count
        WAIT_COLS,
        FIND_EMPTY_SLOT,        // For anonymous: find empty matrix slot (ID 1-7)
        WAIT_EMPTY_CHECK,       // Wait for storage BRAM read
        INITIATE_WRITE,         // Start matrix write to storage manager
        WAIT_WRITER_READY,      // Wait for writer to be ready for data
        READ_DATA,              // Read matrix data from buffer
        WAIT_DATA,              // Wait for buffer read
        STREAM_DATA,            // Send data to writer
        WAIT_WRITE_DONE,        // Wait for write completion
        INITIATE_CLEAR,         // Start clear operation due to error
        WAIT_CLEAR_DONE,        // Wait for clear completion
        DONE_STATE,
        ERROR_STATE
    } state_t;
    
    state_t state, next_state;
    
    // Internal registers
    logic        is_named_matrix;
    logic [2:0]  matrix_id_reg;
    logic [7:0]  rows_reg;
    logic [7:0]  cols_reg;
    logic [7:0]  name_reg [0:7];
    logic [15:0] total_elements;
    logic [15:0] element_count;
    logic [10:0] buf_read_ptr;     // Pointer for buffer RAM reading
    logic [2:0]  check_id;          // For finding empty slot
    logic [31:0] data_word;         // Buffered data word
    
    // State transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_FIRST;
                end
            end
            
            READ_FIRST:     next_state = WAIT_FIRST;
            WAIT_FIRST: begin
                // After 1 cycle, check if first word is -1
                if ($signed(buf_rd_data) == -32'd1) begin
                    next_state = READ_ID;
                end else begin
                    // First word is rows for anonymous matrix
                    next_state = READ_COLS;
                end
            end
            
            READ_ID:        next_state = WAIT_ID;
            WAIT_ID: begin
                if (buf_rd_data >= 32'd1 && buf_rd_data <= 32'd7) begin
                    next_state = READ_NAME_0;
                end else begin
                    next_state = ERROR_STATE;  // Invalid matrix ID
                end
            end
            
            READ_NAME_0:    next_state = WAIT_NAME_0;
            WAIT_NAME_0:    next_state = READ_NAME_1;
            READ_NAME_1:    next_state = WAIT_NAME_1;
            WAIT_NAME_1:    next_state = READ_ROWS;
            
            READ_ROWS:      next_state = WAIT_ROWS;
            WAIT_ROWS:      next_state = READ_COLS;
            
            READ_COLS:      next_state = WAIT_COLS;
            WAIT_COLS: begin
                // Check dimension validity
                // Use buf_rd_data[7:0] for cols because cols_reg is being updated in this cycle
                if (rows_reg > settings_max_row[7:0] || rows_reg == 8'd0 ||
                    buf_rd_data[7:0] > settings_max_col[7:0] || buf_rd_data[7:0] == 8'd0) begin
                    // Dimension exceeds settings, go to clear if named matrix started writing
                    if (is_named_matrix) begin
                        next_state = INITIATE_CLEAR;
                    end else begin
                        next_state = ERROR_STATE;  // Anonymous not yet allocated
                    end
                end else if (is_named_matrix) begin
                    next_state = INITIATE_WRITE;
                end else begin
                    next_state = FIND_EMPTY_SLOT;
                end
            end
            
            FIND_EMPTY_SLOT: next_state = WAIT_EMPTY_CHECK;
            
            WAIT_EMPTY_CHECK: begin
                // Wait 1 cycle for storage BRAM read
                // Check if found empty slot or need to check next
                if (storage_rd_data[31:16] == 16'd0) begin
                    // Found empty slot
                    next_state = INITIATE_WRITE;
                end else if (check_id < 3'd7) begin
                    next_state = FIND_EMPTY_SLOT;
                end else begin
                    next_state = ERROR_STATE;  // No empty slot
                end
            end
            
            INITIATE_WRITE: begin
                if (write_ready) begin
                    next_state = WAIT_WRITER_READY;
                end
            end
            
            WAIT_WRITER_READY: begin
                if (writer_ready && !write_ready) begin
                    next_state = READ_DATA;
                end
            end
            
            READ_DATA:      next_state = WAIT_DATA;
            WAIT_DATA:      next_state = STREAM_DATA;
            
            STREAM_DATA: begin
                if (writer_ready) begin
                    // Check data range validity
                    if ($signed(data_word) < $signed(settings_data_min) ||
                        $signed(data_word) > $signed(settings_data_max)) begin
                        // Data out of range, need to clear the matrix
                        next_state = INITIATE_CLEAR;
                    end else if (element_count + 16'd1 >= total_elements) begin
                        // All elements valid and written
                        next_state = WAIT_WRITE_DONE;
                    end else begin
                        // Continue reading next data
                        next_state = READ_DATA;
                    end
                end
            end
            
            WAIT_WRITE_DONE: begin
                if (write_done) begin
                    next_state = DONE_STATE;
                end
            end
            
            INITIATE_CLEAR: begin
                // Request clear operation
                next_state = WAIT_CLEAR_DONE;
            end
            
            WAIT_CLEAR_DONE: begin
                if (clear_done) begin
                    next_state = ERROR_STATE;
                end
            end
            
            DONE_STATE: begin
                // Auto-reset to IDLE to release done signal (and buf_clear)
                next_state = IDLE;
            end
            
            ERROR_STATE: begin
                // Auto-reset to IDLE to release error signal (and allow buf_clear)
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_named_matrix   <= 1'b0;
            matrix_id_reg     <= 3'd0;
            rows_reg          <= 8'd0;
            cols_reg          <= 8'd0;
            for (int i = 0; i < 8; i++) name_reg[i] <= 8'd0;
            total_elements    <= 16'd0;
            element_count     <= 16'd0;
            buf_read_ptr      <= 11'd0;
            check_id          <= 3'd1;
            data_word         <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        is_named_matrix  <= 1'b0;
                        matrix_id_reg    <= 3'd0;
                        rows_reg         <= 8'd0;
                        cols_reg         <= 8'd0;
                        for (int i = 0; i < 8; i++) name_reg[i] <= 8'd0;
                        element_count    <= 16'd0;
                        buf_read_ptr     <= 11'd0;
                        check_id         <= 3'd1;
                    end
                end

                ERROR_STATE: begin
                    if (start) begin
                        is_named_matrix  <= 1'b0;
                        matrix_id_reg    <= 3'd0;
                        rows_reg         <= 8'd0;
                        cols_reg         <= 8'd0;
                        for (int i = 0; i < 8; i++) name_reg[i] <= 8'd0;
                        element_count    <= 16'd0;
                        buf_read_ptr     <= 11'd0;
                        check_id         <= 3'd1;
                    end
                end
                
                READ_FIRST: begin
                    buf_read_ptr <= 11'd1;  // Prepare to read next
                end
                
                WAIT_FIRST: begin
                    if ($signed(buf_rd_data) == -32'd1) begin
                        is_named_matrix <= 1'b1;
                        buf_read_ptr <= 11'd1;  // Next: ID
                    end else begin
                        is_named_matrix <= 1'b0;
                        rows_reg <= buf_rd_data[7:0];
                        buf_read_ptr <= 11'd1;  // Next: cols
                    end
                end
                
                READ_ID: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_ID: begin
                    matrix_id_reg <= buf_rd_data[2:0];
                end
                
                READ_NAME_0: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_NAME_0: begin
                    // Each 32-bit word contains 4 bytes of name
                    name_reg[0] <= buf_rd_data[31:24];
                    name_reg[1] <= buf_rd_data[23:16];
                    name_reg[2] <= buf_rd_data[15:8];
                    name_reg[3] <= buf_rd_data[7:0];
                end
                
                READ_NAME_1: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_NAME_1: begin
                    name_reg[4] <= buf_rd_data[31:24];
                    name_reg[5] <= buf_rd_data[23:16];
                    name_reg[6] <= buf_rd_data[15:8];
                    name_reg[7] <= buf_rd_data[7:0];
                end
                
                READ_ROWS: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_ROWS: begin
                    rows_reg <= buf_rd_data[7:0];
                end
                
                READ_COLS: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_COLS: begin
                    cols_reg <= buf_rd_data[7:0];
                    total_elements <= buf_rd_data[7:0] * rows_reg;
                end
                
                FIND_EMPTY_SLOT: begin
                    // Storage address calculation: check_id * 1152
                    // Simplified: use upper bits for ID
                end
                
                WAIT_EMPTY_CHECK: begin
                    if (storage_rd_data[31:16] == 16'd0) begin
                        // Found empty slot
                        matrix_id_reg <= check_id;
                    end else if (check_id < 3'd7) begin
                        check_id <= check_id + 3'd1;
                    end
                end
                
                READ_DATA: begin
                    buf_read_ptr <= buf_read_ptr + 11'd1;
                end
                
                WAIT_DATA: begin
                    data_word <= buf_rd_data;
                end
                
                STREAM_DATA: begin
                    if (writer_ready) begin
                        element_count <= element_count + 16'd1;
                    end
                end
            endcase
        end
    end
    
    // Output assignments
    assign busy = (state != IDLE) && (state != DONE_STATE) && (state != ERROR_STATE);
    assign done = (state == DONE_STATE);
    assign error = (state == ERROR_STATE);
    
    assign matrix_id = matrix_id_reg;
    assign actual_rows = rows_reg;
    assign actual_cols = cols_reg;
    assign matrix_name = name_reg;
    
    // Write request signal
    assign write_request = (state == INITIATE_WRITE) && write_ready;
    
    // Clear request signal - initiate clear when entering INITIATE_CLEAR state
    assign clear_request = (state == INITIATE_CLEAR);
    assign clear_matrix_id = matrix_id_reg;
    
    // Data valid when in STREAM_DATA state and writer is ready
    // But not if data is out of range (will transition to INITIATE_CLEAR)
    assign data_valid = (state == STREAM_DATA) && writer_ready &&
                        !($signed(data_word) < $signed(settings_data_min) ||
                          $signed(data_word) > $signed(settings_data_max));
    assign data_in = data_word;
    
    // Buffer RAM read address
    assign buf_rd_addr = buf_read_ptr;
    
    // Storage RAM read address for checking empty slots
    // Use exact address calculation matching matrix_address_getter
    // Each matrix block starts at: matrix_id * BLOCK_SIZE (BLOCK_SIZE = 1152)
    always_comb begin
        case (check_id)
            3'd0: storage_rd_addr = 14'd0;      // 0 * 1152 = 0
            3'd1: storage_rd_addr = 14'd1152;   // 1 * 1152 = 1152
            3'd2: storage_rd_addr = 14'd2304;   // 2 * 1152 = 2304
            3'd3: storage_rd_addr = 14'd3456;   // 3 * 1152 = 3456
            3'd4: storage_rd_addr = 14'd4608;   // 4 * 1152 = 4608
            3'd5: storage_rd_addr = 14'd5760;   // 5 * 1152 = 5760
            3'd6: storage_rd_addr = 14'd6912;   // 6 * 1152 = 6912
            3'd7: storage_rd_addr = 14'd8064;   // 7 * 1152 = 8064
            default: storage_rd_addr = 14'd0;
        endcase
    end
    
endmodule