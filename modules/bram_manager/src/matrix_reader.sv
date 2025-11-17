module matrix_reader #(
    parameter MAX_MEMORY_MATRIXES = 8,  // Max Num of Matrix Blocks
    parameter BLOCK_SIZE = 1152,        // Size of Each Matrix Block (32bit words)
    parameter DATA_WIDTH = 32,          // Data Width
    parameter ADDR_WIDTH = 14           // Address Width ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Read request interface
    input  logic                     read_req,         // Read request
    input  logic [2:0]               matrix_id,        // Matrix ID (0~7)
    input  logic                     read_data_req,    // Request to read next matrix data
    output logic                     read_done,        // Read complete
    output logic                     reader_ready,     // Reader ready
    
    // Metadata output
    output logic [7:0]               rows,             // Actual row count
    output logic [7:0]               cols,             // Actual column count
    output logic [63:0]              matrix_name,      // Matrix name (8 characters)
    output logic                     meta_valid,       // Metadata valid
    
    // Matrix data output
    output logic [DATA_WIDTH-1:0]    data_out,         // Matrix data output
    output logic                     data_valid,       // Data valid signal
    
    // BRAM interface
    output logic [ADDR_WIDTH-1:0]    bram_addr,
    input  logic [DATA_WIDTH-1:0]    bram_dout
);

    // State machine definition
    typedef enum logic [2:0] {
        IDLE,
        READ_META0,       // Initiate read metadata word 0
        WAIT_META0,       // Wait for metadata word 0
        READ_META1,       // Initiate read metadata word 1 (name low 32 bits)
        WAIT_META1,       // Wait for metadata word 1
        READ_META2,       // Initiate read metadata word 2 (name high 32 bits)
        WAIT_META2,       // Wait for metadata word 2
        READ_DATA,        // Read matrix data
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Internal registers
    logic [2:0]              saved_matrix_id;
    logic [7:0]              saved_rows;
    logic [7:0]              saved_cols;
    logic [31:0]             name_low;
    logic [31:0]             name_high;
    logic [ADDR_WIDTH-1:0]   base_addr;        // Current matrix block base address
    logic [ADDR_WIDTH-1:0]   read_addr;        // Current read address
    logic [10:0]             data_count;       // Number of data read
    logic [10:0]             total_elements;   // Total number of elements
    
    // Calculate base address
    always_comb begin
        base_addr = saved_matrix_id * BLOCK_SIZE;
    end
    
    // State machine: sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // State machine: combinational logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (read_req) begin
                    next_state = READ_META0;
                end
            end
            
            READ_META0: begin
                next_state = WAIT_META0;
            end
            
            WAIT_META0: begin
                next_state = READ_META1;
            end
            
            READ_META1: begin
                next_state = WAIT_META1;
            end
            
            WAIT_META1: begin
                next_state = READ_META2;
            end
            
            READ_META2: begin
                next_state = WAIT_META2;
            end
            
            WAIT_META2: begin
                next_state = READ_DATA;
            end
            
            READ_DATA: begin
                if (data_count >= total_elements) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Data path control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_matrix_id <= 3'd0;
            saved_rows <= 8'd0;
            saved_cols <= 8'd0;
            name_low <= 32'd0;
            name_high <= 32'd0;
            read_addr <= '0;
            data_count <= 11'd0;
            bram_addr <= '0;
            rows <= 8'd0;
            cols <= 8'd0;
            matrix_name <= 64'd0;
            meta_valid <= 1'b0;
            data_out <= '0;
            data_valid <= 1'b0;
            read_done <= 1'b0;
            reader_ready <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    reader_ready <= 1'b1;
                    read_done <= 1'b0;
                    meta_valid <= 1'b0;
                    data_valid <= 1'b0;
                    data_count <= 11'd0;
                    
                    if (read_req) begin
                        saved_matrix_id <= matrix_id;
                        reader_ready <= 1'b0;
                    end
                end
                
                READ_META0: begin
                    bram_addr <= base_addr;  // Address 0: metadata 0
                end
                
                WAIT_META0: begin
                    // BRAM output delay 1 cycle, read metadata 0 now
                    saved_rows <= bram_dout[31:24];
                    saved_cols <= bram_dout[23:16];
                    total_elements <= bram_dout[31:24] * bram_dout[23:16];
                end
                
                READ_META1: begin
                    bram_addr <= base_addr + 1;  // Address 1: name low 32 bits
                end
                
                WAIT_META1: begin
                    name_low <= bram_dout;
                end
                
                READ_META2: begin
                    bram_addr <= base_addr + 2;  // Address 2: name high 32 bits
                    read_addr <= base_addr + 3;  // Prepare start address for data reading
                end
                
                WAIT_META2: begin
                    name_high <= bram_dout;
                    // Output metadata
                    rows <= saved_rows;
                    cols <= saved_cols;
                    matrix_name <= {bram_dout, name_low};
                    meta_valid <= 1'b1;
                end
                
                READ_DATA: begin
                    meta_valid <= 1'b0;
                    
                    if (read_data_req && (data_count < total_elements)) begin
                        // Initiate read request
                        bram_addr <= read_addr;
                        read_addr <= read_addr + 1;
                        data_count <= data_count + 1;
                        data_valid <= 1'b0;  // Data invalid in current cycle
                    end else if (data_count > 0 && data_count <= total_elements) begin
                        // Read data delay 1 cycle, output data from previous request
                        data_out <= bram_dout;
                        data_valid <= 1'b1;
                    end else begin
                        data_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    data_valid <= 1'b0;
                    read_done <= 1'b1;
                end
                
                default: begin
                    data_valid <= 1'b0;
                    meta_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule