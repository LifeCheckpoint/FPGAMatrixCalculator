package matrix_op_selector_pkg;

    typedef enum logic [4:0] {
        IDLE,
        WAIT_INFO,
        GET_DIMS,
        WAIT_M,
        READ_M,
        WAIT_N,
        READ_N,
        SCAN_MATRICES,
        WAIT_SCANNER,
        DISPLAY_LIST,
        WAIT_READER_LIST,
        SELECT_A,
        WAIT_ID_A,
        READ_ID_A,
        DISPLAY_A,
        WAIT_READER_A,
        CHECK_MODE,
        SELECT_B,
        WAIT_ID_B,
        READ_ID_B,
        DISPLAY_B,
        WAIT_READER_B,
        SELECT_SCALAR,
        VALIDATE,
        ERROR_WAIT,
        DONE
    } state_t;

    typedef enum logic [2:0] {
        OP_SINGLE,
        OP_DOUBLE,
        OP_SCALAR
    } op_mode_t;

    typedef enum logic [2:0] {
        CALC_TRANSPOSE,
        CALC_ADD,
        CALC_MUL,
        CALC_SCALAR_MUL,
        CALC_CONV
    } calc_type_t;

endpackage
