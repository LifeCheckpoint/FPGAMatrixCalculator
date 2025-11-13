`timescale 1ns / 1ps

module kernel_transform_unit_time_sim (
    input logic clk,
    output logic placeholder
);
    logic rst_n = 1'b0;

    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_kernel_in [0:2][0:2];
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_kernel_out [0:5][0:5];
    (* DONT_TOUCH = "TRUE" *) logic dut_transform_done;

    kernel_transform_unit u_kernel_transform (
        .clk(clk),
        .rst_n(rst_n),
        .kernel_in(dut_kernel_in),
        .kernel_out(dut_kernel_out),
        .transform_done(dut_transform_done)
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
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    dut_kernel_in[i][j] <= 16'd0;
                end
            end
        end else begin
            dut_kernel_in[0][0] <= dut_kernel_in[0][0] + 1;
        end
    end

endmodule
