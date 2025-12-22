`timescale 1ns / 1ps

module led_display_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    // Control
    input  wire [1:0] display_mode, // 0: seg7_display, 1: calc_method_show, 2: OFF
    // Inputs for seg7_display
    input  wire       seg7_valid,
    input  wire [3:0] bcd_data_0,
    input  wire [3:0] bcd_data_1,
    input  wire [3:0] bcd_data_2,
    input  wire [3:0] bcd_data_3,
    // Inputs for calc_method_show
    input  wire [2:0] method_sel,
    // Outputs
    output reg  [7:0] seg,
    output reg  [3:0] an
);

    // Internal signals
    wire [7:0] seg_seg7;
    wire [3:0] an_seg7;
    wire [7:0] seg_calc;
    wire [3:0] an_calc;

    // Instantiate seg7_display
    seg7_display u_seg7_display (
        .clk(clk),
        .rst_n(rst_n),
        .valid(seg7_valid),
        .bcd_data_0(bcd_data_0),
        .bcd_data_1(bcd_data_1),
        .bcd_data_2(bcd_data_2),
        .bcd_data_3(bcd_data_3),
        .seg(seg_seg7),
        .an(an_seg7)
    );

    // Instantiate calc_method_show
    calc_method_show u_calc_method_show (
        .clk(clk),
        .rst_n(rst_n),
        .method_sel(method_sel),
        .seg(seg_calc),
        .an(an_calc)
    );

    // Mux logic
    always @(*) begin
        case (display_mode)
            2'd0: begin // seg7_display
                seg = seg_seg7;
                an  = an_seg7;
            end
            2'd1: begin // calc_method_show
                seg = seg_calc;
                an  = an_calc;
            end
            default: begin // Off
                seg = 8'b00000000; // All segments OFF (active high)
                an  = 4'b0000;     // All digits OFF (active high)
            end
        endcase
    end

endmodule
