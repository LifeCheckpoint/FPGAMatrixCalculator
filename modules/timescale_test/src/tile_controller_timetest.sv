`timescale 1ns / 1ps

module tile_controller_time_sim (
    input logic clk,
    output logic placeholder
);
    logic rst_n = 1'b0;

    (* DONT_TOUCH = "TRUE" *) logic dut_start;
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_kernel_in [0:2][0:2];
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_tile_in [0:5][0:5];
    (* DONT_TOUCH = "TRUE" *) logic [15:0] dut_result_out [0:3][0:3];
    (* DONT_TOUCH = "TRUE" *) logic dut_done;

    tile_controller u_tile_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(dut_start),
        .kernel_in(dut_kernel_in),
        .tile_in(dut_tile_in),
        .result_out(dut_result_out),
        .done(dut_done)
    );

    // Reset counter: generate rst_n signal
    (* DONT_TOUCH = "TRUE" *) logic [7:0] reset_counter;
    always_ff @(posedge clk) begin
        if (reset_counter != 8'hFF) begin
            reset_counter <= reset_counter + 1;
            rst_n <= 1'b0;
        end else begin
            rst_n <= 1'b1;
        end
    end

    // Start signal generator
    (* DONT_TOUCH = "TRUE" *) logic [7:0] start_counter;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_counter <= 8'd0;
            dut_start <= 1'b0;
        end else begin
            start_counter <= start_counter + 1;
            // Generate start pulse every 128 cycles
            dut_start <= (start_counter == 8'd0);
        end
    end

    // Test data generator for kernel_in
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3; j++) begin
                    dut_kernel_in[i][j] <= 16'd0;
                end
            end
        end else begin
            // Simple pattern: increment corner elements
            dut_kernel_in[0][0] <= dut_kernel_in[0][0] + 1;
            dut_kernel_in[1][1] <= dut_kernel_in[1][1] + 2;
            dut_kernel_in[2][2] <= dut_kernel_in[2][2] + 3;
        end
    end

    // Test data generator for tile_in
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 6; i++) begin
                for (int j = 0; j < 6; j++) begin
                    dut_tile_in[i][j] <= 16'd0;
                end
            end
        end else begin
            // Simple pattern: increment some elements
            dut_tile_in[0][0] <= dut_tile_in[0][0] + 1;
            dut_tile_in[2][2] <= dut_tile_in[2][2] + 2;
            dut_tile_in[5][5] <= dut_tile_in[5][5] + 3;
        end
    end

endmodule