`timescale 1ns / 1ps

module matrix_bram_sim;

    parameter ROWS = 5;
    parameter COLS = 5;
    parameter ADDR_WIDTH = $clog2(ROWS*COLS);
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;

    matrix_bram #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        addr = 0;
        din = 0;

        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD);

        for (int i = 0; i < ROWS*COLS; i++) begin
            @(posedge clk);
            wr_en = 1;
            addr = i;
            din = $random;
        end

        @(posedge clk);
        wr_en = 0;
        #(CLK_PERIOD);

        for (int i = 0; i < ROWS*COLS; i++) begin
            @(posedge clk);
            addr = i;
            @(posedge clk);
            $display("addr=%0d, dout=0x%h", i, dout);
        end

        @(posedge clk);
        wr_en = 1;
        addr = 0;
        din = 32'hDEADBEEF;
        @(posedge clk);
        wr_en = 0;
        addr = 0;
        @(posedge clk);
        @(posedge clk);
        $display("Overwrite test: addr=0, dout=0x%h (expected 0xDEADBEEF)", dout);

        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        $display("Reset test: dout=0x%h (expected 0x00000000)", dout);
        @(posedge clk);
        rst_n = 1;

        #(CLK_PERIOD*5);
        $finish;
    end

endmodule