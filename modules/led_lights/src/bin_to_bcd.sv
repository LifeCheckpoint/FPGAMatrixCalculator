`timescale 1ns / 1ps

module bin_to_bcd (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] bin_in,
    output reg  [3:0]  bcd_out [0:3]
);

    // Sequential Double Dabble (Shift-Add-3) Algorithm
    // Latency: ~17 cycles
    // Throughput: Updates every 17 cycles
    
    reg [4:0]  state_ctr;
    reg [31:0] shift_reg;
    reg [15:0] bin_in_latched;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_ctr <= 0;
            shift_reg <= 0;
            bin_in_latched <= 0;
            bcd_out[0] <= 4'd0;
            bcd_out[1] <= 4'd15;
            bcd_out[2] <= 4'd15;
            bcd_out[3] <= 4'd15;
        end else begin
            if (state_ctr == 0) begin
                // Latch input and initialize
                bin_in_latched <= bin_in;
                shift_reg <= {16'b0, bin_in};
                state_ctr <= 1;
            end else if (state_ctr <= 16) begin
                // Double Dabble Algorithm Steps
                // 1. Check if any BCD digit is >= 5 and add 3
                logic [31:0] temp_reg;
                temp_reg = shift_reg;
                
                if (temp_reg[19:16] >= 5) temp_reg[19:16] = temp_reg[19:16] + 3;
                if (temp_reg[23:20] >= 5) temp_reg[23:20] = temp_reg[23:20] + 3;
                if (temp_reg[27:24] >= 5) temp_reg[27:24] = temp_reg[27:24] + 3;
                if (temp_reg[31:28] >= 5) temp_reg[31:28] = temp_reg[31:28] + 3;
                
                // 2. Shift left by 1
                shift_reg <= temp_reg << 1;
                state_ctr <= state_ctr + 1;
            end else begin
                // Update Output with Leading Zero Suppression
                if (shift_reg[31:28] != 0) begin
                    bcd_out[3] <= shift_reg[31:28];
                    bcd_out[2] <= shift_reg[27:24];
                    bcd_out[1] <= shift_reg[23:20];
                    bcd_out[0] <= shift_reg[19:16];
                end else if (shift_reg[27:24] != 0) begin
                    bcd_out[3] <= 4'd15; // Blank
                    bcd_out[2] <= shift_reg[27:24];
                    bcd_out[1] <= shift_reg[23:20];
                    bcd_out[0] <= shift_reg[19:16];
                end else if (shift_reg[23:20] != 0) begin
                    bcd_out[3] <= 4'd15;
                    bcd_out[2] <= 4'd15;
                    bcd_out[1] <= shift_reg[23:20];
                    bcd_out[0] <= shift_reg[19:16];
                end else begin
                    bcd_out[3] <= 4'd15;
                    bcd_out[2] <= 4'd15;
                    bcd_out[1] <= 4'd15;
                    bcd_out[0] <= shift_reg[19:16]; // Always show last digit
                end
                
                // Restart
                state_ctr <= 0;
            end
        end
    end

endmodule
