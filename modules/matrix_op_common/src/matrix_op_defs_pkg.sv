package matrix_op_defs_pkg;

    parameter int MATRIX_BLOCK_SIZE     = 1152;
    parameter int MATRIX_DATA_WIDTH     = 32;
    parameter int MATRIX_ADDR_WIDTH     = 14;
    parameter int MATRIX_ID_WIDTH       = 3;
    parameter int MATRIX_METADATA_WORDS = 3;
    parameter int MATRIX_DATA_CAPACITY  = MATRIX_BLOCK_SIZE - MATRIX_METADATA_WORDS;

    typedef struct packed {
        logic [7:0] rows;
        logic [7:0] cols;
    } matrix_shape_t;

    typedef enum logic [3:0] {
        MATRIX_OP_STATUS_IDLE         = 4'd0,
        MATRIX_OP_STATUS_BUSY         = 4'd1,
        MATRIX_OP_STATUS_SUCCESS      = 4'd2,
        MATRIX_OP_STATUS_ERR_DIM      = 4'd3,
        MATRIX_OP_STATUS_ERR_ID       = 4'd4,
        MATRIX_OP_STATUS_ERR_EMPTY    = 4'd5,
        MATRIX_OP_STATUS_ERR_WRITER   = 4'd6,
        MATRIX_OP_STATUS_ERR_FORMAT   = 4'd7,
        MATRIX_OP_STATUS_ERR_INTERNAL = 4'd8
    } matrix_op_status_e;

    localparam matrix_shape_t MATRIX_SHAPE_ZERO = '{rows:8'd0, cols:8'd0};

    function automatic matrix_shape_t decode_shape_word(input logic [MATRIX_DATA_WIDTH-1:0] word);
        matrix_shape_t shape;
        shape.rows = word[31:24];
        shape.cols = word[23:16];
        return shape;
    endfunction

    function automatic logic [15:0] shape_element_count(input matrix_shape_t shape);
        return shape.rows * shape.cols;
    endfunction

    function automatic logic [MATRIX_ADDR_WIDTH-1:0] linear_data_addr(
        input logic [MATRIX_ADDR_WIDTH-1:0] base_addr,
        input logic [15:0] linear_index
    );
        return base_addr + MATRIX_METADATA_WORDS + linear_index;
    endfunction

    function automatic logic [MATRIX_ADDR_WIDTH-1:0] indexed_data_addr(
        input logic [MATRIX_ADDR_WIDTH-1:0] base_addr,
        input matrix_shape_t shape,
        input logic [15:0] row_idx,
        input logic [15:0] col_idx
    );
        return base_addr + MATRIX_METADATA_WORDS + row_idx * shape.cols + col_idx;
    endfunction

    function automatic logic is_valid_matrix_id(input logic [MATRIX_ID_WIDTH-1:0] matrix_id);
        return (matrix_id <= 3'd7);
    endfunction

    function automatic logic is_valid_operand_id(input logic [MATRIX_ID_WIDTH-1:0] matrix_id);
        return (matrix_id >= 3'd1) && (matrix_id <= 3'd7);
    endfunction

    function automatic logic is_data_capacity_ok(input logic [15:0] elem_count);
        return (elem_count > 0) && (elem_count <= MATRIX_DATA_CAPACITY);
    endfunction

endpackage