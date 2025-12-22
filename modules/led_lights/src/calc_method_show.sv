`timescale 1ns / 1ps

module calc_method_show (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] method_sel, // 0:T, 1:A, 2:B, 3:C, 4:J
    output reg  [7:0] seg,
    output reg  [3:0] an
);

    reg [15:0] refresh_counter;
    reg [1:0]  digit_select;
    reg [7:0]  char_seg;

    // Refresh counter for scanning
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 0;
            digit_select <= 0;
        end else begin
            refresh_counter <= refresh_counter + 1;
            if (refresh_counter == 16'd25000) begin
                refresh_counter <= 0;
                digit_select <= digit_select + 1;
            end
        end
    end

    // Anode control - Scan all 4 digits
    always @(*) begin
        case (digit_select)
            2'b00: an = 4'b0001;
            2'b01: an = 4'b0010;
            2'b10: an = 4'b0100;
            2'b11: an = 4'b1000;
        endcase
    end

    // Decode character
    // seg = {a, b, c, d, e, f, g, dp}
    always @(*) begin
        case (method_sel)
            3'd0: char_seg =    8'b11100000; // T (a, b, c)
            3'd1: char_seg =    8'b11101110; // A (a, b, c, e, f, g)
            3'd2: char_seg =    8'b10011100; // C (a, d, e, f)
            3'd3: char_seg =    8'b11111110; // B (a, b, c, d, e, f, g)
            3'd4: char_seg =    8'b01110000; // J (b, c, d)
            default: char_seg = 8'b00000000; // Blank
        endcase
    end

    // Output segment
    always @(*) begin
        seg = char_seg;
    end

endmodule
