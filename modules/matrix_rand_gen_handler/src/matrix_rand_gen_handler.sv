`timescale 1ns / 1ps

// Matrix Random Generation Handler
// Reads generation parameters (m, n, count) from buffer RAM
// Generates random matrices and writes to matrix storage manager
module matrix_rand_gen_handler (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control signals
    input  logic        start,              // One-cycle pulse to start processing
    output logic        error,              // Error flag
    output logic        busy,               // Processing in progress
    output logic        done,               // Processing complete
    
    // Settings interface
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
    
    // Matrix storage manager read interface (for checking empty slots)
    output logic [13:0] storage_rd_addr,
    input  logic [31:0] storage_rd_data
);

    // State machine
    typedef enum logic [4:0] {
        IDLE,
        READ_M,                 // Read rows (m)
        WAIT_M,
        READ_N,                 // Read cols (n)
        WAIT_N,
        READ_COUNT,             // Read count
        WAIT_COUNT,
        VALIDATE_PARAMS,        // Check if m, n, count are valid
        FIND_EMPTY_SLOT,        // Find empty matrix slot (ID 1-7)
        WAIT_EMPTY_CHECK,       // Wait for storage BRAM read
        INITIATE_WRITE,         // Start matrix write to storage manager
        WAIT_WRITER_READY,      // Wait for writer to be ready
        GENERATE_STREAM,        // Generate and stream random data
        CALC_MODULO,            // Calculate modulo (multi-cycle)
        WRITE_DATA,             // Write data to storage manager
        WAIT_WRITE_DONE,        // Wait for write completion
        CHECK_MORE,             // Check if more matrices need to be generated
        DONE_STATE,
        ERROR_STATE
    } state_t;
    
    state_t state, next_state;
    
    // Internal registers
    logic [7:0]  m_reg;             // Rows
    logic [7:0]  n_reg;             // Cols
    logic [31:0] count_reg;         // Number of matrices to generate
    logic [31:0] generated_count;   // Number of matrices already generated
    logic [15:0] total_elements;    // m * n
    logic [15:0] element_count;     // Elements written for current matrix
    logic [2:0]  check_id;          // For finding empty slot
    logic [2:0]  found_id;          // ID of the found empty slot
    
    // Division/Modulo registers
    logic [31:0] dividend_reg;
    logic [31:0] divisor_reg;
    logic [31:0] remainder_reg;
    logic [4:0]  calc_counter;

    // Random Number Generator signals
    logic        rng_start;
    logic [31:0] rng_seed;
    logic [31:0] rng_out [0:0];     // We only need 1 output per cycle
    logic [31:0] rand_val;
    logic [31:0] range;
    logic [31:0] mapped_val;
    
    // Cycle counter for seeding
    logic [31:0] cycle_counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_counter <= 0;
        else cycle_counter <= cycle_counter + 1;
    end

    // Local reset for RNG to allow re-seeding after parameter read
    logic rng_rst_n;
    assign rng_rst_n = rst_n && (state != VALIDATE_PARAMS);

    // Instantiate XorShift32
    xorshift32 #(
        .NUM_OUTPUTS(1)
    ) rng_inst (
        .clk(clk),
        .rst_n(rng_rst_n),
        .start(rng_start),
        .seed(rng_seed),
        .random_out(rng_out)
    );
    
    // RNG Control
    // Run RNG when we are generating data or just to mix state
    // Only pulse start when we are about to start a calculation in GENERATE_STREAM
    assign rng_start = (state == GENERATE_STREAM) && writer_ready && (element_count < total_elements);
    // Seed initialization: mix inputs and time, ensure non-zero with constant
    assign rng_seed = cycle_counter ^ {24'b0, m_reg} ^ {16'b0, n_reg, 8'b0} ^ {count_reg} ^ 32'hA5A5A5A5;
    
    assign rand_val = rng_out[0];
    
    // Map random value to range [min, max]
    // range = max - min + 1
    // val = (rand % range) + min
    // Note: Using absolute values for range calculation to be safe, though min/max are signed
    assign range = settings_data_max - settings_data_min + 32'd1;
    
    // Mapped value comes from remainder_reg after calculation
    assign mapped_val = settings_data_min + remainder_reg;

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
                if (start) next_state = READ_M;
            end
            
            READ_M:     next_state = WAIT_M;
            WAIT_M:     next_state = READ_N;
            
            READ_N:     next_state = WAIT_N;
            WAIT_N:     next_state = READ_COUNT;
            
            READ_COUNT: next_state = WAIT_COUNT;
            WAIT_COUNT: next_state = VALIDATE_PARAMS;
            
            VALIDATE_PARAMS: begin
                // Check dimensions and count
                if (m_reg > settings_max_row[7:0] || m_reg == 0 ||
                    n_reg > settings_max_col[7:0] || n_reg == 0 ||
                    count_reg > 2 || count_reg == 0) begin
                    next_state = ERROR_STATE;
                end else begin
                    next_state = FIND_EMPTY_SLOT;
                end
            end
            
            FIND_EMPTY_SLOT: next_state = WAIT_EMPTY_CHECK;
            
            WAIT_EMPTY_CHECK: begin
                // Check if slot is empty (rows == 0 && cols == 0)
                // storage_rd_data[31:16] contains {rows, cols}
                if (storage_rd_data[31:16] == 16'd0) begin
                    next_state = INITIATE_WRITE;
                end else if (check_id < 3'd7) begin
                    next_state = FIND_EMPTY_SLOT;
                end else begin
                    next_state = ERROR_STATE; // No empty slots
                end
            end
            
            INITIATE_WRITE: begin
                if (write_ready) next_state = WAIT_WRITER_READY;
            end
            
            WAIT_WRITER_READY: begin
                if (writer_ready && !write_ready) next_state = GENERATE_STREAM;
            end
            
            GENERATE_STREAM: begin
                if (writer_ready) begin
                    if (element_count < total_elements) begin
                        next_state = CALC_MODULO;
                    end else begin
                        next_state = WAIT_WRITE_DONE;
                    end
                end
            end

            CALC_MODULO: begin
                if (calc_counter == 0) next_state = WRITE_DATA;
            end

            WRITE_DATA: begin
                if (writer_ready) next_state = GENERATE_STREAM;
            end
            
            WAIT_WRITE_DONE: begin
                if (write_done) next_state = CHECK_MORE;
            end
            
            CHECK_MORE: begin
                if (generated_count + 1 < count_reg) begin
                    next_state = FIND_EMPTY_SLOT;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                // Auto-reset to IDLE to release done signal
                next_state = IDLE;
            end
            
            ERROR_STATE: begin
                // Auto-reset to IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_reg           <= 8'd0;
            n_reg           <= 8'd0;
            count_reg       <= 32'd0;
            generated_count <= 32'd0;
            total_elements  <= 16'd0;
            element_count   <= 16'd0;
            check_id        <= 3'd1;
            found_id        <= 3'd0;
            buf_rd_addr     <= 11'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        generated_count <= 32'd0;
                        check_id        <= 3'd1;
                        buf_rd_addr     <= 11'd0; // Address 0 for m
                    end
                end

                ERROR_STATE: begin
                    if (start) begin
                        generated_count <= 32'd0;
                        check_id        <= 3'd1;
                        buf_rd_addr     <= 11'd0; // Address 0 for m
                    end
                end
                
                READ_M: begin
                    buf_rd_addr <= 11'd1; // Prepare address 1 for n
                end
                
                WAIT_M: begin
                    m_reg <= buf_rd_data[7:0];
                end
                
                READ_N: begin
                    buf_rd_addr <= 11'd2; // Prepare address 2 for count
                end
                
                WAIT_N: begin
                    n_reg <= buf_rd_data[7:0];
                    total_elements <= buf_rd_data[7:0] * m_reg;
                end
                
                READ_COUNT: begin
                    // No more reads needed
                end
                
                WAIT_COUNT: begin
                    count_reg <= buf_rd_data;
                end
                
                FIND_EMPTY_SLOT: begin
                    // Address logic handled in comb block
                end
                
                WAIT_EMPTY_CHECK: begin
                    if (storage_rd_data[31:16] == 16'd0) begin
                        found_id <= check_id;
                        // Prepare for next search if needed, start from next ID
                        check_id <= check_id + 3'd1; 
                    end else if (check_id < 3'd7) begin
                        check_id <= check_id + 3'd1;
                    end
                end
                
                INITIATE_WRITE: begin
                    element_count <= 16'd0;
                end
                
                GENERATE_STREAM: begin
                    if (writer_ready && element_count < total_elements) begin
                        // Start calculation
                        dividend_reg <= rand_val;
                        divisor_reg <= range;
                        remainder_reg <= 32'd0;
                        calc_counter <= 5'd31;
                    end
                end

                CALC_MODULO: begin
                    // Restoring division step
                    // Shift remainder left, bring in MSB of dividend
                    logic [31:0] next_rem;
                    next_rem = {remainder_reg[30:0], dividend_reg[calc_counter]};
                    
                    if (next_rem >= divisor_reg) begin
                        remainder_reg <= next_rem - divisor_reg;
                    end else begin
                        remainder_reg <= next_rem;
                    end
                    
                    if (calc_counter > 0) calc_counter <= calc_counter - 1;
                end

                WRITE_DATA: begin
                    if (writer_ready) begin
                        element_count <= element_count + 16'd1;
                    end
                end
                
                CHECK_MORE: begin
                    generated_count <= generated_count + 1;
                    // check_id is already updated in WAIT_EMPTY_CHECK or we can reset it?
                    // Better to continue searching from where we left off or reset to 1?
                    // If we continue, we might miss slots if we freed some (unlikely here).
                    // But since we just filled one, we should search forward.
                    // However, if we wrap around or if the user wants to fill holes...
                    // Let's keep searching forward. If check_id > 7, we might fail.
                    // To be safe, let's reset check_id to 1 for the next matrix search
                    // to ensure we find the *first* available slot.
                    check_id <= 3'd1; 
                end
            endcase
        end
    end
    
    // Output assignments
    assign busy = (state != IDLE) && (state != DONE_STATE) && (state != ERROR_STATE);
    assign done = (state == DONE_STATE);
    assign error = (state == ERROR_STATE);
    
    // Matrix Storage Manager Interface
    assign write_request = (state == INITIATE_WRITE) && write_ready;
    assign matrix_id = found_id;
    assign actual_rows = m_reg;
    assign actual_cols = n_reg;
    
    // Name is all zeros for random matrices
    always_comb begin
        for (int i = 0; i < 8; i++) matrix_name[i] = 8'd0;
    end
    
    assign data_in = mapped_val;
    assign data_valid = (state == WRITE_DATA) && writer_ready;
    
    // Storage Read Address for Empty Slot Check
    // 0 * 1152 = 0
    // 1 * 1152 = 1152
    // ...
    always_comb begin
        case (check_id)
            3'd0: storage_rd_addr = 14'd0;
            3'd1: storage_rd_addr = 14'd1152;
            3'd2: storage_rd_addr = 14'd2304;
            3'd3: storage_rd_addr = 14'd3456;
            3'd4: storage_rd_addr = 14'd4608;
            3'd5: storage_rd_addr = 14'd5760;
            3'd6: storage_rd_addr = 14'd6912;
            3'd7: storage_rd_addr = 14'd8064;
            default: storage_rd_addr = 14'd0;
        endcase
    end

endmodule
