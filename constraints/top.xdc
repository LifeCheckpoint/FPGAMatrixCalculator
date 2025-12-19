set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {seg[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports btn]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# Clock (P17 is 100MHz on EGO1)
# Timing constraint is in constraints/timing.xdc
set_property PACKAGE_PIN P17 [get_ports clk]

# Reset (S6 - P15)
set_property PACKAGE_PIN P15 [get_ports rst_n]

# Confirm Button (Mapped to S4 - U4, as S5 is PROG)
set_property PACKAGE_PIN U4 [get_ports btn]

# Manual Clear Button (S1 - R17)
set_property PACKAGE_PIN R17 [get_ports btn_clear]
set_property IOSTANDARD LVCMOS33 [get_ports btn_clear]

# Debug Dump Button (S3 - V1)
set_property PACKAGE_PIN V1 [get_ports btn_dump]
set_property IOSTANDARD LVCMOS33 [get_ports btn_dump]

# UART
set_property PACKAGE_PIN T4 [get_ports uart_tx]
set_property PACKAGE_PIN N5 [get_ports uart_rx]

# LEDs (LED7-LED0)
set_property PACKAGE_PIN F6 [get_ports {led[7]}]
set_property PACKAGE_PIN G4 [get_ports {led[6]}]
set_property PACKAGE_PIN G3 [get_ports {led[5]}]
set_property PACKAGE_PIN J4 [get_ports {led[4]}]
set_property PACKAGE_PIN H4 [get_ports {led[3]}]
set_property PACKAGE_PIN J3 [get_ports {led[2]}]
set_property PACKAGE_PIN J2 [get_ports {led[1]}]
set_property PACKAGE_PIN K2 [get_ports {led[0]}]

# Extended LEDs (LED15-LED8) for Debug
set_property PACKAGE_PIN K1 [get_ports {led_ext[7]}]
set_property PACKAGE_PIN H6 [get_ports {led_ext[6]}]
set_property PACKAGE_PIN H5 [get_ports {led_ext[5]}]
set_property PACKAGE_PIN J5 [get_ports {led_ext[4]}]
set_property PACKAGE_PIN K6 [get_ports {led_ext[3]}]
set_property PACKAGE_PIN L1 [get_ports {led_ext[2]}]
set_property PACKAGE_PIN M1 [get_ports {led_ext[1]}]
set_property PACKAGE_PIN K3 [get_ports {led_ext[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_ext[0]}]

# Switches (SW7-SW0)
set_property PACKAGE_PIN P5 [get_ports {sw[7]}]
set_property PACKAGE_PIN P4 [get_ports {sw[6]}]
set_property PACKAGE_PIN P3 [get_ports {sw[5]}]
set_property PACKAGE_PIN P2 [get_ports {sw[4]}]
set_property PACKAGE_PIN R2 [get_ports {sw[3]}]
set_property PACKAGE_PIN M4 [get_ports {sw[2]}]
set_property PACKAGE_PIN N4 [get_ports {sw[1]}]
set_property PACKAGE_PIN R1 [get_ports {sw[0]}]

# 7-Segment Display
# Segments (a, b, c, d, e, f, g, dp), High means light
set_property PACKAGE_PIN B4 [get_ports {seg[7]}]
set_property PACKAGE_PIN A4 [get_ports {seg[6]}]
set_property PACKAGE_PIN A3 [get_ports {seg[5]}]
set_property PACKAGE_PIN B1 [get_ports {seg[4]}]
set_property PACKAGE_PIN A1 [get_ports {seg[3]}]
set_property PACKAGE_PIN B3 [get_ports {seg[2]}]
set_property PACKAGE_PIN B2 [get_ports {seg[1]}]
set_property PACKAGE_PIN D5 [get_ports {seg[0]}]

# Anodes (an3-an0) -> (H1, C1, C2, G2)
set_property PACKAGE_PIN H1 [get_ports {an[3]}]
set_property PACKAGE_PIN C1 [get_ports {an[2]}]
set_property PACKAGE_PIN C2 [get_ports {an[1]}]
set_property PACKAGE_PIN G2 [get_ports {an[0]}]

# DIP Switches (SW_DIP7-SW_DIP0)
set_property PACKAGE_PIN U3 [get_ports {sw_dip[7]}]
set_property PACKAGE_PIN U2 [get_ports {sw_dip[6]}]
set_property PACKAGE_PIN V2 [get_ports {sw_dip[5]}]
set_property PACKAGE_PIN V5 [get_ports {sw_dip[4]}]
set_property PACKAGE_PIN V4 [get_ports {sw_dip[3]}]
set_property PACKAGE_PIN R3 [get_ports {sw_dip[2]}]
set_property PACKAGE_PIN T3 [get_ports {sw_dip[1]}]
set_property PACKAGE_PIN T5 [get_ports {sw_dip[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_dip[0]}]
