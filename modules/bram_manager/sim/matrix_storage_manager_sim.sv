`timescale 1ns / 1ps

module matrix_storage_manager_sim();

    parameter MAX_MEMORY_MATRIXES = 8;
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 9216;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    logic clk;
    logic rst_n;
    
    logic                     write_req;
    logic [2:0]               write_matrix_id;
    logic [7:0]               write_rows;
    logic [7:0]               write_cols;
    logic [63:0]              write_matrix_name;
    logic [DATA_WIDTH-1:0]    write_data_in;
    logic                     write_data_valid;
    logic                     write_done;
    logic                     writer_ready;
    
    logic                     read_req;
    logic [2:0]               read_matrix_id;
    logic                     read_data_req;
    logic                     read_done;
    logic                     reader_ready;
    logic [7:0]               read_rows;
    logic [7:0]               read_cols;
    logic [63:0]              read_matrix_name;
    logic                     read_meta_valid;
    logic [DATA_WIDTH-1:0]    read_data_out;
    logic                     read_data_valid;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    matrix_storage_manager #(
        .MAX_MEMORY_MATRIXES(MAX_MEMORY_MATRIXES),
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        
        .write_req(write_req),
        .write_matrix_id(write_matrix_id),
        .write_rows(write_rows),
        .write_cols(write_cols),
        .write_matrix_name(write_matrix_name),
        .write_data_in(write_data_in),
        .write_data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        
        .read_req(read_req),
        .read_matrix_id(read_matrix_id),
        .read_data_req(read_data_req),
        .read_done(read_done),
        .reader_ready(reader_ready),
        .read_rows(read_rows),
        .read_cols(read_cols),
        .read_matrix_name(read_matrix_name),
        .read_meta_valid(read_meta_valid),
        .read_data_out(read_data_out),
        .read_data_valid(read_data_valid)
    );
    
    logic [DATA_WIDTH-1:0] test_matrix_3x3 [0:8];
    logic [DATA_WIDTH-1:0] test_matrix_2x4 [0:7];
    
    initial begin
        // 3x3
        for (int i = 0; i < 9; i++) begin
            test_matrix_3x3[i] = i + 1;  // 1, 2, 3, ..., 9
        end
        
        // 2x4
        for (int i = 0; i < 8; i++) begin
            test_matrix_2x4[i] = (i + 1) * 10;  // 10, 20, 30, ..., 80
        end
    end
    
    // Task: Writing
    task write_matrix(
        input logic [2:0] matrix_id,
        input logic [7:0] rows,
        input logic [7:0] cols,
        input logic [63:0] matrix_name,
        input logic [DATA_WIDTH-1:0] data_array[]
    );
        integer i;
        integer total_elements;
        
        total_elements = rows * cols;
        
        $display("[%0t] Writing matrix ID=%0d, row=%0d, column=%0d, name=%s", 
                 $time, matrix_id, rows, cols, matrix_name);
        
        wait(writer_ready);
        @(posedge clk);
        
        write_req <= 1'b1;
        write_matrix_id <= matrix_id;
        write_rows <= rows;
        write_cols <= cols;
        write_matrix_name <= matrix_name;
        @(posedge clk);
        write_req <= 1'b0;
        
        repeat(4) @(posedge clk);
        
        for (i = 0; i < total_elements; i++) begin
            write_data_in <= data_array[i];
            write_data_valid <= 1'b1;
            @(posedge clk);
        end
        write_data_valid <= 1'b0;
        
        wait(write_done);
        $display("[%0t] Writing over. ID=%0d", $time, matrix_id);
        @(posedge clk);
    endtask
    
    // Task: Reading
    task read_matrix(
        input logic [2:0] matrix_id,
        output logic [7:0] actual_rows,
        output logic [7:0] actual_cols,
        output logic [63:0] actual_name
    );
        integer i;
        integer total_elements;
        logic [DATA_WIDTH-1:0] received_data[$];
        
        $display("[%0t] Reading Matrix ID=%0d", $time, matrix_id);
        
        wait(reader_ready);
        @(posedge clk);
        
        read_req <= 1'b1;
        read_matrix_id <= matrix_id;
        @(posedge clk);
        read_req <= 1'b0;
        
        wait(read_meta_valid);
        @(posedge clk);
        actual_rows = read_rows;
        actual_cols = read_cols;
        actual_name = read_matrix_name;
        total_elements = actual_rows * actual_cols;
        
        $display("[%0t] Receive metadata: row=%0d, column=%0d, name=%s", 
                 $time, actual_rows, actual_cols, actual_name);
        
        for (i = 0; i < total_elements; i++) begin
            read_data_req <= 1'b1;
            @(posedge clk);
            read_data_req <= 1'b0;
            @(posedge clk);
            
            if (read_data_valid) begin
                received_data.push_back(read_data_out);
                $display("[%0t] ReadData[%0d] = %0d", $time, i, read_data_out);
            end
        end
        
        wait(read_done);
        $display("[%0t] Reading complete ID=%0d, Total %0d datas received.", 
                 $time, matrix_id, received_data.size());
        @(posedge clk);
    endtask
    
    initial begin
        rst_n = 0;
        write_req = 0;
        write_matrix_id = 0;
        write_rows = 0;
        write_cols = 0;
        write_matrix_name = 0;
        write_data_in = 0;
        write_data_valid = 0;
        read_req = 0;
        read_matrix_id = 0;
        read_data_req = 0;
        
        // 复位
        $display("========================================");
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("\n[test 1] write 3x3 mat to slot 0");
        write_matrix(3'd0, 8'd3, 8'd3, "Matrix_A", test_matrix_3x3);
        repeat(5) @(posedge clk);
        
        $display("\n[test 2] write 2x4 mat to slot 1");
        write_matrix(3'd1, 8'd2, 8'd4, "Matrix_B", test_matrix_2x4);
        repeat(5) @(posedge clk);
        
        $display("\n[test 3] read back slot 0 mat");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd0, rows_out, cols_out, name_out);
            
            $display("\nValidating metadata for slot 0");
            $display("Expected rows: 3, Actual rows: %0d", rows_out);
            $display("Expected cols: 3, Actual cols: %0d", cols_out);
            $display("Expected name: Matrix_A, Actual name: %s", name_out);
        end
        repeat(5) @(posedge clk);
        
        $display("\n[test 4] read back slot 1 mat");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd1, rows_out, cols_out, name_out);

            $display("\nValidating metadata for slot 1");
            $display("Expected rows: 2, Actual rows: %0d", rows_out);
            $display("Expected cols: 4, Actual cols: %0d", cols_out);
            $display("Expected name: Matrix_B, Actual name: %s", name_out);
        end
        repeat(5) @(posedge clk);
        
        $display("\n[test 5] overwrite slot 0 with new 2x4 mat");
        write_matrix(3'd0, 8'd2, 8'd4, "NewMat_A", test_matrix_2x4);
        repeat(5) @(posedge clk);
        
        $display("\n[test 6] read back overwritten slot 0 mat");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd0, rows_out, cols_out, name_out);
            
            $display("\nValidating metadata for overwritten slot 0");
            $display("Expected rows: 2, Actual rows: %0d", rows_out);
            $display("Expected cols: 4, Actual cols: %0d", cols_out);
            $display("Expected name: NewMat_A, Actual name: %s", name_out);
        end
        repeat(10) @(posedge clk);
        
        $display("\n========================================");
        $finish;
    end

endmodule