`timescale 1ns / 1ps

module counting_down (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] time_in,
    input  wire        start,
    output reg         stop,
    output wire [7:0]  seg,
    output wire [3:0]  an
);

    localparam IDLE     = 2'b00;
    localparam COUNTING = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0]  state, next_state;
    reg [15:0] counter;
    wire       sec_tick;
    wire [3:0] bcd_data [0:3];
    reg        led_valid;

    clock_divider #(.DIV_VALUE(25_000_000)) u_clk_div (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (state == COUNTING),
        .tick   (sec_tick)
    );

    bin_to_bcd u_bin2bcd (
        .clk     (clk),
        .rst_n   (rst_n),
        .bin_in  (counter),
        .bcd_out (bcd_data)
    );

    seg7_display u_seg7_display (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid      (led_valid),
        .bcd_data_0 (bcd_data[0]),
        .bcd_data_1 (bcd_data[1]),
        .bcd_data_2 (bcd_data[2]),
        .bcd_data_3 (bcd_data[3]),
        .seg        (seg),
        .an         (an)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (start) next_state = COUNTING;
            COUNTING: if (counter == 16'd0) next_state = DONE;
            DONE:     next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 16'd0;
            stop      <= 1'b0;
            led_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    stop      <= 1'b0;
                    led_valid <= 1'b0;
                    if (start)
                        counter <= time_in;
                    else
                        counter <= 16'd0;
                end
                
                COUNTING: begin
                    stop      <= 1'b0;
                    led_valid <= 1'b1;
                    if (sec_tick && counter > 16'd0)
                        counter <= counter - 16'd1;
                end
                
                DONE: begin
                    stop      <= 1'b1;
                    led_valid <= 1'b0;
                    counter   <= 16'd0;
                end
            endcase
        end
    end

endmodule