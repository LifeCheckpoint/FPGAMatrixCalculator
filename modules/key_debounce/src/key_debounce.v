module key_debounce #(
    parameter CNT_MAX = 20'd2000000 // 25MHz, 80ms
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_out
);

    reg [19:0] cnt;
    reg key_d0, key_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            key_out <= 1'b1; // high level when not pressed
            {key_d1, key_d0} <= 2'b11;
        end else begin
            {key_d1, key_d0} <= {key_d0, key_in};

            if (key_d1 == key_out) begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1'b1;
                if (cnt == CNT_MAX) begin
                    key_out <= key_d1;
                    cnt <= 0;
                end
            end
        end
    end

endmodule
