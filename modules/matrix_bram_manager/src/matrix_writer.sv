module matrix_writer #(
    parameter BLOCK_SIZE = 1152,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14
) (
    input  logic                  clk,
    input  logic                  rst_n,
    // Write request
    input  logic                  write_request,
    output logic                  write_ready,
    // Write netadata
    input  logic [2:0]            matrix_id,
    input  logic [7:0]            actual_rows,
    input  logic [7:0]            actual_cols,
    input  logic [7:0]            matrix_name [0:7],
    // input data
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  data_valid,
    output logic                  write_done,
    output logic                  writer_ready,
    // BRAM interface
    // This interface will provide signals for BRAM write operations
    output logic                  bram_wr_en,
    output logic [ADDR_WIDTH-1:0] bram_addr,
    output logic [DATA_WIDTH-1:0] bram_din
);

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        WRITE_META_ROWS_COLS,
        WRITE_META_NAME_HIGH32,
        WRITE_META_NAME_LOW32,
        WRITE_DATA,
        DONE
    } state_t;

    state_t current_state, next_state;

    // registers
    logic [ADDR_WIDTH-1:0] base_addr;       // base address
    logic [ADDR_WIDTH-1:0] write_addr;      // current write address
    logic [10:0]           data_count;      // number of data written
    logic [10:0]           total_elements;  // total number of elements

    matrix_address_getter #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mag (
        .matrix_id(matrix_id),
        .base_addr(base_addr)
    );

    always_comb begin
        total_elements = actual_rows * actual_cols;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (write_request) begin
                    next_state = WRITE_META_ROWS_COLS;
                end
            end

            WRITE_META_ROWS_COLS: begin
                next_state = WRITE_META_NAME_HIGH32;
            end

            WRITE_META_NAME_HIGH32: begin
                next_state = WRITE_META_NAME_LOW32;
            end

            WRITE_META_NAME_LOW32: begin
                next_state = WRITE_DATA;
            end

            WRITE_DATA: begin
                if (data_count == total_elements) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Data path control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr <= '0;
            data_count <= '0;
            write_done <= 1'b0;
            writer_ready <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    write_addr <= base_addr;
                    data_count <= '0;
                    write_done <= 1'b0;
                    writer_ready <= 1'b1;
                end

                WRITE_META_ROWS_COLS: begin
                    // Write rows and cols
                    bram_wr_en <= 1'b1;
                    bram_addr <= write_addr;
                    bram_din <= {actual_rows, actual_cols, 16'd0}; // upper 16 bits zeroed
                    write_addr <= write_addr + 1;
                    writer_ready <= 1'b0;
                end

                WRITE_META_NAME_HIGH32: begin
                    // Write high 32 bits of name
                    bram_wr_en <= 1'b1;
                    bram_addr <= write_addr;
                    bram_din <= {matrix_name[0], matrix_name[1], matrix_name[2], matrix_name[3]};
                    write_addr <= write_addr + 1;
                end

                WRITE_META_NAME_LOW32: begin
                    // Write low 32 bits of name
                    bram_wr_en <= 1'b1;
                    bram_addr <= write_addr;
                    bram_din <= {matrix_name[4], matrix_name[5], matrix_name[6], matrix_name[7]};
                    write_addr <= write_addr + 1;
                end

                WRITE_DATA: begin
                    if (data_valid) begin
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
                    write_done <= 1'b1;
                    writer_ready <= 1'b1;
                end

                default: begin
                    bram_wr_en <= 1'b0;
                end
            endcase
        end
    end

endmodule