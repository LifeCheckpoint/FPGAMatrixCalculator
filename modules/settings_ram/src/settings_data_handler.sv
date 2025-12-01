`timescale 1ns / 1ps

/**
 * settings_data_handler - Settings Data Handler
 * 
 * Reads 5-byte setting data from buffer RAM and validates:
 * - Byte 0: Command (1=max_row, 2=max_col, 3=data_min, 4=data_max)
 * - Byte 1-4: int32 data (little-endian)
 * 
 * Validation rules:
 * - Row/Column count cannot exceed 32
 * - Data max value cannot exceed 65535
 */
module settings_data_handler (
    input  logic        clk,
    input  logic        rst_n,

    // Control signals
    input  logic        start,          // One-cycle start signal
    output logic        busy,           // Busy status
    output logic        done,           // Done signal (one cycle)
    output logic        error,          // Error signal (持续 until reset)

    // RAM read interface
    output logic [2:0]  ram_rd_addr,    // RAM read address (0-4)
    input  logic [7:0]  ram_rd_data,    // RAM read data
    
    // Settings output interface (connected to settings_ram)
    output logic        settings_wr_en,     // Settings write enable
    output logic [31:0] settings_max_row,   // Max row count
    output logic [31:0] settings_max_col,   // Max column count
    output logic [31:0] settings_data_min,  // Data minimum value
    output logic [31:0] settings_data_max   // Data maximum value
);

    // State machine definition
    typedef enum logic [2:0] {
        IDLE,           // Idle state
        READ_CMD,       // Read command byte
        READ_BYTE0,     // Read data byte 0
        READ_BYTE1,     // Read data byte 1
        READ_BYTE2,     // Read data byte 2
        READ_BYTE3,     // Read data byte 3
        VALIDATE,       // Validate data
        WRITE_SETTINGS  // Write settings
    } state_t;

    state_t state, state_next;

    // Internal registers
    logic [7:0]  cmd_reg;           // Command byte
    logic [31:0] data_reg;          // Data register
    logic        error_reg;         // Error register
    logic        validation_error;  // Validation error flag

    // State transition logic
    always_comb begin
        state_next = state;
        
        case (state)
            IDLE: begin
                if (start && !error_reg) begin
                    state_next = READ_CMD;
                end
            end
            
            READ_CMD: begin
                state_next = READ_BYTE0;
            end
            
            READ_BYTE0: begin
                state_next = READ_BYTE1;
            end
            
            READ_BYTE1: begin
                state_next = READ_BYTE2;
            end
            
            READ_BYTE2: begin
                state_next = READ_BYTE3;
            end
            
            READ_BYTE3: begin
                state_next = VALIDATE;
            end
            
            VALIDATE: begin
                if (validation_error) begin
                    state_next = IDLE;  // Return to IDLE on error
                end else begin
                    state_next = WRITE_SETTINGS;
                end
            end
            
            WRITE_SETTINGS: begin
                state_next = IDLE;
            end
            
            default: state_next = IDLE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cmd_reg   <= 8'd0;
            data_reg  <= 32'd0;
            error_reg <= 1'b0;
        end else begin
            state <= state_next;
            
            // Read command byte
            if (state == READ_CMD) begin
                cmd_reg <= ram_rd_data;
            end
            
            // Read data bytes (little-endian)
            if (state == READ_BYTE0) begin
                data_reg[7:0] <= ram_rd_data;
            end
            if (state == READ_BYTE1) begin
                data_reg[15:8] <= ram_rd_data;
            end
            if (state == READ_BYTE2) begin
                data_reg[23:16] <= ram_rd_data;
            end
            if (state == READ_BYTE3) begin
                data_reg[31:24] <= ram_rd_data;
            end
            
            // Set error flag during validation
            if (state == VALIDATE && validation_error) begin
                error_reg <= 1'b1;
            end
        end
    end

    // Data validation logic
    always_comb begin
        validation_error = 1'b0;
        
        if (state == VALIDATE) begin
            case (cmd_reg)
                8'd1: begin  // Max row count
                    if (data_reg > 32'd32 || data_reg == 32'd0) begin
                        validation_error = 1'b1;
                    end
                end
                8'd2: begin  // Max column count
                    if (data_reg > 32'd32 || data_reg == 32'd0) begin
                        validation_error = 1'b1;
                    end
                end
                8'd3: begin  // Data minimum value
                    // No special restrictions
                    validation_error = 1'b0;
                end
                8'd4: begin  // Data maximum value
                    if (data_reg > 32'd65535) begin
                        validation_error = 1'b1;
                    end
                end
                default: begin  // Invalid command
                    validation_error = 1'b1;
                end
            endcase
        end
    end

    // RAM read address generation
    always_comb begin
        ram_rd_addr = 3'd0;
        
        case (state)
            READ_CMD:   ram_rd_addr = 3'd0;
            READ_BYTE0: ram_rd_addr = 3'd1;
            READ_BYTE1: ram_rd_addr = 3'd2;
            READ_BYTE2: ram_rd_addr = 3'd3;
            READ_BYTE3: ram_rd_addr = 3'd4;
            default:    ram_rd_addr = 3'd0;
        endcase
    end

    // Output signals
    assign busy = (state != IDLE);
    assign done = (state == WRITE_SETTINGS);
    assign error = error_reg;

    // Settings output logic
    always_comb begin
        settings_wr_en = 1'b0;
        settings_max_row = 32'd0;
        settings_max_col = 32'd0;
        settings_data_min = 32'd0;
        settings_data_max = 32'd0;
        
        if (state == WRITE_SETTINGS) begin
            settings_wr_en = 1'b1;
            
            case (cmd_reg)
                8'd1: settings_max_row  = data_reg;
                8'd2: settings_max_col  = data_reg;
                8'd3: settings_data_min = data_reg;
                8'd4: settings_data_max = data_reg;
                default: begin
                    // Should not reach here (filtered in validation)
                end
            endcase
        end
    end

endmodule