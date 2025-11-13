`timescale 1ns / 1ps

module matrix_pointwise_mult_6x6_time_sim (
    input logic clk,
    output logic placeholder
);
    logic rst_n = 1'b0;
    logic start = 1'b0;

    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_a [6][6];
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_b [6][6];
    (* DONT_TOUCH = "TRUE" *) logic [31:0] dut_c [6][6];
    (* DONT_TOUCH = "TRUE" *) logic dut_done;

    matrix_pointwise_mult_6x6 u_matrix_mult (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(dut_a),
        .b(dut_b),
        .c(dut_c),
        .done(dut_done)
    );

    (* DONT_TOUCH = "TRUE" *) logic [7:0] reset_counter;
    always_ff @(posedge clk) begin
        if (reset_counter != 8'hFF) begin
            reset_counter <= reset_counter + 1;
            rst_n <= 1'b0;
        end else begin
            rst_n <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    dut_a[i][j] <= 16'd0;
                    dut_b[i][j] <= 16'd0;
                end
            end
            start <= 1'b0;
        end else begin
            dut_a[0][0] <= dut_a[0][0] + 1;
            dut_b[0][0] <= dut_b[0][0] + 2;
            start <= ~start;
        end
    end

endmodule