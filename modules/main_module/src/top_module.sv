`timescale 1ns / 1ps

import matrix_op_selector_pkg::*;

module top_module (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        uart_rx,
    output logic        uart_tx,
    input  logic [7:0]  sw,
    input  logic [7:0]  sw_dip, // Scalar Input DIP Switches
    input  logic        btn, // Confirm button
    input  logic        btn_clear, // Manual Clear Button (S1)
    input  logic        btn_dump, // Debug Dump Button (S3)
    output logic [7:0]  led,
    output logic [7:0]  seg,
    output logic [3:0]  an,
    output logic [7:0]  led_ext // Debug LEDs (K1, H6, H5, J5, K6, L1, M1, K3)
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------

    // Clock Generation (100MHz -> 25MHz)
    logic clk_25m;
    logic [1:0] clk_div_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div_cnt <= 2'b00;
        else
            clk_div_cnt <= clk_div_cnt + 1'b1;
    end
    
    assign clk_25m = clk_div_cnt[1];

    // Debounced Button
    logic btn_debounced;
    logic btn_clear_debounced;
    logic btn_dump_debounced;
    logic [7:0] sw_debounced;
    
    // UART Signals
    logic [7:0] rx_data;
    logic       rx_done;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy;
    
    // Mode Control
    logic [2:0] op_mode_raw; // From switches2op
    logic [2:0] calc_op_mode; // From op_mode_controller
    logic [2:0] calc_type_raw; // From op_mode_controller
    
    // Mode Flags
    logic mode_is_input;
    logic mode_is_gen;
    logic mode_is_show;
    logic mode_is_calc;
    logic mode_is_settings;
    
    // Settings
    logic [31:0] settings_max_row;
    logic [31:0] settings_max_col;
    logic [31:0] settings_data_min;
    logic [31:0] settings_data_max;
    logic [31:0] settings_countdown;
    
    // Input Subsystem Signals
    logic input_busy, input_done, input_error;
    logic input_wr_req;
    logic [2:0] input_mat_id;
    logic [7:0] input_rows, input_cols;
    logic [7:0] input_name [0:7];
    logic [31:0] input_data_out;
    logic input_data_valid;
    logic [13:0] input_rd_addr;
    
    // Compute Subsystem Signals
    logic compute_busy, compute_done, compute_error;
    logic [7:0] compute_seg;
    logic [3:0] compute_an;
    logic [7:0] compute_tx_data;
    logic compute_tx_valid;
    logic [13:0] compute_rd_addr;
    logic compute_wr_req;
    logic [2:0] compute_mat_id;
    logic [7:0] compute_rows, compute_cols;
    logic [7:0] compute_name [0:7];
    logic [31:0] compute_data_out;
    logic compute_data_valid;
    
    // Matrix Reader Signals
    logic reader_busy, reader_done;
    logic [13:0] reader_rd_addr;
    logic [7:0] reader_ascii_data;
    logic reader_ascii_valid;
    
    // Storage Manager Signals
    logic [13:0] storage_rd_addr;
    logic [31:0] storage_rd_data;
    logic storage_wr_req;
    logic storage_wr_ready;
    logic [2:0] storage_mat_id;
    logic [7:0] storage_rows, storage_cols;
    logic [7:0] storage_name [0:7];
    logic [31:0] storage_data_in;
    logic storage_data_valid;
    logic storage_wr_done;
    logic storage_writer_ready;
    
    //-------------------------------------------------------------------------
    // Button Debounce
    //-------------------------------------------------------------------------
    
    key_debounce #(
        .CNT_MAX(20'd500000) // 20ms at 25MHz
    ) u_debounce (
        .clk(clk_25m),
        .rst_n(rst_n),
        .key_in(btn), // Assuming active low button? No, usually active low on board but module expects key_in.
                      // key_debounce logic: key_out <= 1'b1 when not pressed (reset).
                      // If key_in is active low (0 when pressed), then key_out will be 0 when pressed.
                      // Let's assume active low button input.
        .key_out(btn_debounced)
    );

    key_debounce #(
        .CNT_MAX(20'd500000) // 20ms at 25MHz
    ) u_debounce_clear (
        .clk(clk_25m),
        .rst_n(rst_n),
        .key_in(btn_clear),
        .key_out(btn_clear_debounced)
    );

    key_debounce #(
        .CNT_MAX(20'd500000) // 20ms at 25MHz
    ) u_debounce_dump (
        .clk(clk_25m),
        .rst_n(rst_n),
        .key_in(btn_dump),
        .key_out(btn_dump_debounced)
    );

    switches_debounce #(
        .WIDTH(8),
        .CNT_MAX(20'd500000) // 20ms at 25MHz
    ) u_sw_debounce (
        .clk(clk_25m),
        .rst_n(rst_n),
        .sw_in(sw),
        .sw_out(sw_debounced)
    );
    
    // We need a pulse for 'start' or 'confirm'.
    // If btn_debounced is level, we need edge detection.
    // Assuming btn_debounced is 0 when pressed.
    logic btn_pressed_pulse;
    logic btn_d1;
    
    logic btn_clear_pulse;
    logic btn_clear_d1;
    
    logic btn_dump_pulse;
    logic btn_dump_d1;
    
    always_ff @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            btn_d1 <= 1'b1;
            btn_pressed_pulse <= 1'b0;
            btn_clear_d1 <= 1'b1;
            btn_clear_pulse <= 1'b0;
            btn_dump_d1 <= 1'b1;
            btn_dump_pulse <= 1'b0;
        end else begin
            btn_d1 <= btn_debounced;
            btn_pressed_pulse <= (btn_d1 && !btn_debounced);
            
            btn_clear_d1 <= btn_clear_debounced;
            btn_clear_pulse <= (btn_clear_d1 && !btn_clear_debounced);
            
            btn_dump_d1 <= btn_dump_debounced;
            btn_dump_pulse <= (btn_dump_d1 && !btn_dump_debounced);
        end
    end

    //-------------------------------------------------------------------------
    // UART Interface
    //-------------------------------------------------------------------------
    
    uart_rx #(
        .CLK_FREQ(25_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk(clk_25m),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );
    
    uart_tx #(
        .CLK_FREQ(25_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk(clk_25m),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );

    //-------------------------------------------------------------------------
    // Mode Control
    //-------------------------------------------------------------------------
    
    switches2op u_sw2op (
        .sw_mat_input(sw_debounced[7]),
        .sw_gen(sw_debounced[6]),
        .sw_show(sw_debounced[5]),
        .sw_calculate(sw_debounced[4]),
        .sw_settings(sw_debounced[3]),
        .op(op_mode_raw)
    );
    
    op_mode_controller u_op_ctrl (
        .clk(clk_25m),
        .rst_n(rst_n),
        .switches(sw_debounced), // Uses sw[2:0]
        .op_mode(calc_op_mode),
        .calc_type(calc_type_raw)
    );
    
    assign mode_is_input    = (op_mode_raw == 3'd1);
    assign mode_is_gen      = (op_mode_raw == 3'd2);
    assign mode_is_show     = (op_mode_raw == 3'd3);
    assign mode_is_calc     = (op_mode_raw == 3'd4);
    assign mode_is_settings = (op_mode_raw == 3'd5);

    //-------------------------------------------------------------------------
    // Input Subsystem
    //-------------------------------------------------------------------------
    
    // Gated UART Valid Signal for Input Subsystem
    logic input_rx_valid;
    assign input_rx_valid = rx_done && (mode_is_input || mode_is_gen || mode_is_settings);

    // Debug Dump Signals
    logic [7:0] debug_dump_tx_data;
    logic       debug_dump_tx_valid;
    logic       debug_dump_busy;

    input_subsystem #(
        .BLOCK_SIZE(1152),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(14)
    ) u_input_sub (
        .clk(clk_25m),
        .rst_n(rst_n),
        .mode_is_input(mode_is_input),
        .mode_is_gen(mode_is_gen),
        .mode_is_settings(mode_is_settings),
        .start(btn_pressed_pulse), // Start generation or confirm settings
        .manual_clear(btn_clear_pulse), // Manual clear signal
        .manual_dump(btn_dump_pulse), // Manual dump signal
        .dump_tx_data(debug_dump_tx_data),
        .dump_tx_valid(debug_dump_tx_valid),
        .dump_tx_ready(!tx_busy),
        .dump_busy(debug_dump_busy),
        .busy(input_busy),
        .done(input_done),
        .error(input_error),
        .uart_rx_data(rx_data),
        .uart_rx_valid(input_rx_valid),
        .settings_max_row(settings_max_row),
        .settings_max_col(settings_max_col),
        .settings_data_min(settings_data_min),
        .settings_data_max(settings_data_max),
        .settings_countdown(settings_countdown),
        .write_request(input_wr_req),
        .write_ready(storage_wr_ready),
        .matrix_id(input_mat_id),
        .actual_rows(input_rows),
        .actual_cols(input_cols),
        .matrix_name(input_name),
        .data_in(input_data_out),
        .data_valid(input_data_valid),
        .write_done(storage_wr_done),
        .writer_ready(storage_writer_ready),
        .storage_rd_addr(input_rd_addr),
        .storage_rd_data(storage_rd_data)
    );

    //-------------------------------------------------------------------------
    // Compute Subsystem
    //-------------------------------------------------------------------------
    
    // Gated UART Valid Signal for Compute Subsystem
    logic compute_rx_valid;
    assign compute_rx_valid = rx_done && mode_is_calc;

    compute_subsystem #(
        .BLOCK_SIZE(1152),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(14)
    ) u_compute_sub (
        .clk(clk_25m),
        .rst_n(rst_n),
        .start(btn_pressed_pulse && mode_is_calc),
        .confirm_btn(btn_pressed_pulse),
        .scalar_in({24'd0, sw_dip}), // From DIP switches
        .random_scalar(1'b0), // Not implemented yet
        .op_mode_in(op_mode_t'(calc_op_mode)),
        .calc_type_in(calc_type_t'(calc_type_raw)),
        .settings_countdown(settings_countdown),
        .busy(compute_busy),
        .done(compute_done),
        .error(compute_error),
        .seg(compute_seg),
        .an(compute_an),
        .uart_rx_data(rx_data),
        .uart_rx_valid(compute_rx_valid),
        .uart_tx_data(compute_tx_data),
        .uart_tx_valid(compute_tx_valid),
        .uart_tx_ready(!tx_busy),
        .bram_rd_addr(compute_rd_addr),
        .bram_rd_data(storage_rd_data),
        .write_request(compute_wr_req),
        .write_ready(storage_wr_ready),
        .write_matrix_id(compute_mat_id),
        .write_rows(compute_rows),
        .write_cols(compute_cols),
        .write_name(compute_name),
        .write_data(compute_data_out),
        .write_data_valid(compute_data_valid),
        .write_done(storage_wr_done),
        .writer_ready(storage_writer_ready),
        .debug_leds(led_ext)
    );

    //-------------------------------------------------------------------------
    // Matrix Reader (Show Mode)
    //-------------------------------------------------------------------------
    
    matrix_reader_all #(
        .BLOCK_SIZE(1152),
        .ADDR_WIDTH(14)
    ) u_reader_all (
        .clk(clk_25m),
        .rst_n(rst_n),
        .start(mode_is_show && btn_pressed_pulse), // Start showing on button press? Or auto?
                                                   // Requirement: "Matrix Display" mode.
                                                   // Let's assume button press triggers display refresh.
        .busy(reader_busy),
        .done(reader_done),
        .bram_addr(reader_rd_addr),
        .bram_data(storage_rd_data),
        .ascii_data(reader_ascii_data),
        .ascii_valid(reader_ascii_valid),
        .ascii_ready(!tx_busy)
    );

    //-------------------------------------------------------------------------
    // Storage Manager
    //-------------------------------------------------------------------------
    
    // Write Mux
    always_comb begin
        if (mode_is_calc) begin
            storage_wr_req = compute_wr_req;
            storage_mat_id = compute_mat_id;
            storage_rows = compute_rows;
            storage_cols = compute_cols;
            storage_name = compute_name;
            storage_data_in = compute_data_out;
            storage_data_valid = compute_data_valid;
        end else begin
            // Input/Gen modes
            storage_wr_req = input_wr_req;
            storage_mat_id = input_mat_id;
            storage_rows = input_rows;
            storage_cols = input_cols;
            storage_name = input_name;
            storage_data_in = input_data_out;
            storage_data_valid = input_data_valid;
        end
    end
    
    // Read Address Mux
    always_comb begin
        if (mode_is_calc) begin
            storage_rd_addr = compute_rd_addr;
        end else if (mode_is_show) begin
            storage_rd_addr = reader_rd_addr;
        end else begin
            storage_rd_addr = input_rd_addr;
        end
    end
    
    matrix_storage_manager #(
        .BLOCK_SIZE(1152),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(14),
        .DEPTH(8192 + 1024)
    ) u_storage_mgr (
        .clk(clk_25m),
        .rst_n(rst_n),
        .write_request(storage_wr_req),
        .write_ready(storage_wr_ready),
        .matrix_id(storage_mat_id),
        .actual_rows(storage_rows),
        .actual_cols(storage_cols),
        .matrix_name(storage_name),
        .data_in(storage_data_in),
        .data_valid(storage_data_valid),
        .write_done(storage_wr_done),
        .writer_ready(storage_writer_ready),
        .clear_request(1'b0), // Not used for now
        .clear_done(),
        .clear_matrix_id(3'd0),
        .read_addr(storage_rd_addr),
        .data_out(storage_rd_data)
    );

    //-------------------------------------------------------------------------
    // UART TX Arbitration
    //-------------------------------------------------------------------------
    
    // Manual Clear Response Logic ("AC")
    logic [2:0] clear_resp_state; // 0: Idle, 1: Send 'A', 2: Wait, 3: Send 'C', 4: Wait
    logic       clear_resp_valid;
    logic [7:0] clear_resp_data;
    logic [3:0] clear_wait_cnt;
    
    always_ff @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            clear_resp_state <= 0;
            clear_resp_valid <= 0;
            clear_resp_data <= 0;
            clear_wait_cnt <= 0;
        end else begin
            clear_resp_valid <= 0; // Default
            
            case (clear_resp_state)
                0: begin
                    if (btn_clear_pulse) begin
                        clear_resp_data <= "A";
                        clear_resp_valid <= 1;
                        clear_resp_state <= 1;
                    end
                end
                1: begin
                    // Wait for tx_busy to assert (if it hasn't already) or just wait a bit
                    clear_resp_state <= 2;
                    clear_wait_cnt <= 4'd10;
                end
                2: begin
                    if (clear_wait_cnt > 0) begin
                        clear_wait_cnt <= clear_wait_cnt - 1;
                    end else if (!tx_busy) begin
                        clear_resp_data <= "C";
                        clear_resp_valid <= 1;
                        clear_resp_state <= 3;
                    end
                end
                3: begin
                    clear_resp_state <= 4;
                    clear_wait_cnt <= 4'd10;
                end
                4: begin
                    if (clear_wait_cnt > 0) begin
                        clear_wait_cnt <= clear_wait_cnt - 1;
                    end else if (!tx_busy) begin
                        clear_resp_state <= 0;
                    end
                end
            endcase
        end
    end

    always_comb begin
        tx_start = 0;
        tx_data = 0;
        
        // Priority: Manual Clear Response > Debug Dump > Calc > Show > Echo
        if (clear_resp_valid) begin
            tx_start = 1;
            tx_data = clear_resp_data;
        end else if (debug_dump_tx_valid) begin
            tx_start = 1;
            tx_data = debug_dump_tx_data;
        end else if (mode_is_calc) begin
            tx_start = compute_tx_valid;
            tx_data = compute_tx_data;
        end else if (mode_is_show) begin
            tx_start = reader_ascii_valid;
            tx_data = reader_ascii_data;
        end else begin
            // Echo for Input/Gen/Settings
            tx_start = rx_done;
            tx_data = rx_data;
        end
    end

    //-------------------------------------------------------------------------
    // LED & SEG Arbitration
    //-------------------------------------------------------------------------
    
    // Default Display (0000)
    logic [7:0] default_seg;
    logic [3:0] default_an;
    
    seg7_display u_default_display (
        .clk(clk_25m),
        .rst_n(rst_n),
        .valid(1'b1),
        .bcd_data_0(4'd0),
        .bcd_data_1(4'd0),
        .bcd_data_2(4'd0),
        .bcd_data_3(4'd0),
        .seg(default_seg),
        .an(default_an)
    );

    // LED
    // LED[0]: Error
    // LED[1]: Done
    // LED[2]: Busy
    // LED[7:3]: Mode Debug
    
    logic sys_error, sys_done, sys_busy;
    
    always_comb begin
        if (mode_is_calc) begin
            sys_error = compute_error;
            sys_done = compute_done;
            sys_busy = compute_busy;
        end else if (mode_is_show) begin
            sys_error = 0;
            sys_done = reader_done;
            sys_busy = reader_busy;
        end else begin
            sys_error = input_error;
            sys_done = input_done;
            sys_busy = input_busy;
        end
    end
    
    // LED Pulse Extender for Done Signal
    logic [24:0] done_led_cnt;
    logic        done_led_extended;
    
    always_ff @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            done_led_cnt <= 0;
            done_led_extended <= 0;
        end else begin
            if (sys_done) begin
                done_led_cnt <= 25'd12_500_000; // Load counter (0.5s at 25MHz)
                done_led_extended <= 1'b1;
            end else if (done_led_cnt > 0) begin
                done_led_cnt <= done_led_cnt - 1;
                done_led_extended <= 1'b1;
            end else begin
                done_led_extended <= 1'b0;
            end
        end
    end

    assign led[0] = sys_error;
    assign led[1] = done_led_extended;
    assign led[2] = sys_busy;
    assign led[7:3] = op_mode_raw; // Debug: Show current mode
    
    // SEG
    always_comb begin
        if (mode_is_calc) begin
            seg = compute_seg;
            an = compute_an;
        end else begin
            // Default show 0000
            seg = default_seg;
            an = default_an;
        end
    end

endmodule
