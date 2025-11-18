module matrix_address_getter #(
    parameter BLOCK_SIZE = 1152,
    parameter ADDR_WIDTH = 14
) (
    input  logic [2:0]            matrix_id,
    output logic [ADDR_WIDTH-1:0] base_addr
);

    always_comb begin
        case (matrix_id)
            3'd0: base_addr = 0 * BLOCK_SIZE;
            3'd1: base_addr = 1 * BLOCK_SIZE;
            3'd2: base_addr = 2 * BLOCK_SIZE;
            3'd3: base_addr = 3 * BLOCK_SIZE;
            3'd4: base_addr = 4 * BLOCK_SIZE;
            3'd5: base_addr = 5 * BLOCK_SIZE;
            3'd6: base_addr = 6 * BLOCK_SIZE;
            3'd7: base_addr = 7 * BLOCK_SIZE;
            default: base_addr = '0;
        endcase
    end

endmodule