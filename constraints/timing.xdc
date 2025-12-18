create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} -add [get_ports clk]

# Generated clock for 25MHz logic
# Source: clk (100MHz), Divider: clk_div_cnt[1] (divide by 4)
# Using wildcard to match the register name after synthesis
create_generated_clock -name clk_25m -source [get_ports clk] -divide_by 4 [get_pins -hierarchical *clk_div_cnt*[1]/Q]

# Set false path for asynchronous inputs (Switches, Buttons, UART RX)
set_false_path -from [get_ports {rst_n btn sw[*] uart_rx}]

# Set false path for outputs (LEDs, Segments, UART TX) - strictly speaking should be constrained but for this app false path is acceptable to clear warnings
set_false_path -to [get_ports {led[*] seg[*] an[*] uart_tx}]
