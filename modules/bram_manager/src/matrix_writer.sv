// Matrix Writer Module
// Responsible for writing matrix data (including metadata) to specified BRAM matrix blocks

module matrix_writer #(
    parameter MAX_MEMORY_MATRIXES = 8,      // Maximum number of matrix blocks
    parameter BLOCK_SIZE = 1152,             // Size of each matrix block (32-bit words)
    parameter DATA_WIDTH = 32,               // Data width
    parameter ADDR_WIDTH = 14                // Address width ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // Write request interface
    input  logic                     write_req,        // Write request
    input  logic [2:0]               matrix_id,        // Matrix ID (0~7)
    input  logic [7:0]               rows,             // Actual row count
    input  logic [7:0]               cols,             // Actual column count
    input  logic [63:0]              matrix_name,      // Matrix name (8 characters)
    input  logic [DATA_WIDTH-1:0]    data_in,          // Matrix data input
    input  logic                     data_valid,       // Data valid signal
    output logic                     write_done,       // Write complete
    output logic                     writer_ready,     // Writer ready
    
    // BRAM interface
    output logic                     bram_wr_en,
    output logic [ADDR_WIDTH-1:0]    bram_addr,
    output logic [DATA_WIDTH-1:0]    bram_din
);

    // State machine definition
    typedef enum logic [2:0] {
        IDLE,
        WRITE_META0,      // Write metadata word 0 (rows, columns)
        WRITE_META1,      // Write metadata word 1 (name low 32 bits)
        WRITE_META2,      // Write metadata word 2 (name high 32 bits)
        WRITE_DATA,       // Write matrix data
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Internal registers
    logic [2:0]              saved_matrix_id;
    logic [7:0]              saved_rows;
    logic [7:0]              saved_cols;
    logic [63:0]             saved_name;
    logic [ADDR_WIDTH-1:0]   base_addr;        // Current matrix block base address
    logic [ADDR_WIDTH-1:0]   write_addr;       // Current write address
    logic [10:0]             data_count;       // Number of data written
    logic [10:0]             total_elements;   // Total number of elements
    
    // Calculate base address
    always_comb begin
        base_addr = saved_matrix_id * BLOCK_SIZE;
    end
    
    // Calculate total number of elements
    always_comb begin
        total_elements = saved_rows * saved_cols;
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
                if (write_req) begin
                    next_state = WRITE_META0;
                end
            end
            
            WRITE_META0: begin
                next_state = WRITE_META1;
            end
            
            WRITE_META1: begin
                next_state = WRITE_META2;
            end
            
            WRITE_META2: begin
                next_state = WRITE_DATA;
            end
            
            WRITE_DATA: begin
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
            saved_name <= 64'd0;
            write_addr <= '0;
            data_count <= 11'd0;
            bram_wr_en <= 1'b0;
            bram_addr <= '0;
            bram_din <= '0;
            write_done <= 1'b0;
            writer_ready <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    writer_ready <= 1'b1;
                    write_done <= 1'b0;
                    bram_wr_en <= 1'b0;
                    data_count <= 11'd0;
                    
                    if (write_req) begin
                        saved_matrix_id <= matrix_id;
                        saved_rows <= rows;
                        saved_cols <= cols;
                        saved_name <= matrix_name;
                        writer_ready <= 1'b0;
                    end
                end
                
                WRITE_META0: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr;  // Address 0: metadata 0
                    bram_din <= {saved_rows, saved_cols, 16'd0};  // [31:24]=rows, [23:16]=columns
                end
                
                WRITE_META1: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr + 1;  // Address 1: name low 32 bits
                    bram_din <= saved_name[31:0];
                end
                
                WRITE_META2: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr + 2;  // Address 2: name high 32 bits
                    bram_din <= saved_name[63:32];
                    write_addr <= base_addr + 3;  // Start address for next data write
                end
                
                WRITE_DATA: begin
                    if (data_valid && (data_count < total_elements)) begin
                        bram_wr_en <= 1'b1;
                        bram_addr <= write_addr;
                        bram_din <= data_in;
                        write_addr <= write_addr + 1;
                        data_count <= data_count + 1;
                    end else begin
                        bram_wr_en <= 1'b0;
                    end
                end
                
                DONE: begin
                    bram_wr_en <= 1'b0;
                    write_done <= 1'b1;
                end
                
                default: begin
                    bram_wr_en <= 1'b0;
                end
            endcase
        end
    end

endmodule