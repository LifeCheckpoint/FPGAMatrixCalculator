`timescale 1ns / 1ps

module seg7_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       valid,
    input  wire [3:0] bcd_data_0,
    input  wire [3:0] bcd_data_1,
    input  wire [3:0] bcd_data_2,
    input  wire [3:0] bcd_data_3,
    output reg  [7:0] seg,
    output reg  [3:0] an
);

    reg [15:0] refresh_counter;
    reg [1:0] digit_select;
    reg [3:0] current_digit;

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

    always @(*) begin
        if (valid) begin
            case (digit_select)
                2'b00: begin
                    an = 4'b1110;
                    current_digit = bcd_data_0;
                end
                2'b01: begin
                    an = 4'b1101;
                    current_digit = bcd_data_1;
                end
                2'b10: begin
                    an = 4'b1011;
                    current_digit = bcd_data_2;
                end
                2'b11: begin
                    an = 4'b0111;
                    current_digit = bcd_data_3;
                end
            endcase
        end else begin
            an = 4'b1111;
            current_digit = 4'd15;
        end
    end

    always @(*) begin
        case (current_digit)
            4'd0:  seg = 8'b11000000;
            4'd1:  seg = 8'b11111001;
            4'd2:  seg = 8'b10100100;
            4'd3:  seg = 8'b10110000;
            4'd4:  seg = 8'b10011001;
            4'd5:  seg = 8'b10010010;
            4'd6:  seg = 8'b10000010;
            4'd7:  seg = 8'b11111000;
            4'd8:  seg = 8'b10000000;
            4'd9:  seg = 8'b10010000;
            4'd10: seg = 8'b10001110;
            default: seg = 8'b11111111;
        endcase
    end

endmodule