`timescale 1ns / 1ps

module bin_to_bcd (
    input  wire [15:0] bin_in,
    output reg  [3:0]  bcd_out [0:3]
);

    integer i;
    reg [15:0] temp;
    reg [3:0] raw_bcd [0:3];
    reg found_nonzero;

    always @(*) begin
        temp = bin_in;
        raw_bcd[3] = temp % 10;
        temp = temp / 10;
        raw_bcd[2] = temp % 10;
        temp = temp / 10;
        raw_bcd[1] = temp % 10;
        temp = temp / 10;
        raw_bcd[0] = temp % 10;
        
        found_nonzero = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (found_nonzero || raw_bcd[i] != 0 || i == 3) begin
                bcd_out[i] = raw_bcd[i];
                found_nonzero = 1;
            end else begin
                bcd_out[i] = 4'd15;
            end
        end
    end

endmodule