//=============================================================================
// Module: main_module
// Description: FPGA Matrix Calculator - Top Level Module
// Author: Auto-generated
// Date: 2025-11-11
//=============================================================================

module main_module (
    // Clock and Reset
    input  wire clk,          // 系统时钟
    input  wire rst_n,        // 异步复位（低有效）
    
    // GPIO Interface
    input  wire [7:0]  gpio_in,   // GPIO输入端口
    output wire [7:0]  gpio_out,  // GPIO输出端口
    
    // Status LEDs
    output wire led_ready,    // 就绪指示LED
    output wire led_busy,     // 忙碌指示LED
    output wire led_error     // 错误指示LED
);

//-----------------------------------------------------------------------------
// Internal Signals
//-----------------------------------------------------------------------------
reg [7:0]  gpio_out_reg;
reg        led_ready_reg;
reg        led_busy_reg;
reg        led_error_reg;

//-----------------------------------------------------------------------------
// Main Logic
//-----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset state
        gpio_out_reg  <= 8'b0;
        led_ready_reg <= 1'b1;
        led_busy_reg  <= 1'b0;
        led_error_reg <= 1'b0;
    end else begin
        // Normal operation - Echo input to output for now
        gpio_out_reg  <= gpio_in;
        led_ready_reg <= 1'b1;
        led_busy_reg  <= 1'b0;
        led_error_reg <= 1'b0;
    end
end

//-----------------------------------------------------------------------------
// Output assignments
//-----------------------------------------------------------------------------
assign gpio_out  = gpio_out_reg;
assign led_ready = led_ready_reg;
assign led_busy  = led_busy_reg;
assign led_error = led_error_reg;

endmodule

//=============================================================================
// End of File
//=============================================================================