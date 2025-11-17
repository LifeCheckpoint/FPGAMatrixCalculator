`timescale 1ns / 1ps

// Matrix Storage Manager Testbench
// 测试矩阵存储管理系统的读写功能

module matrix_storage_manager_sim();

    // 参数定义
    parameter MAX_MEMORY_MATRIXES = 8;
    parameter BLOCK_SIZE = 1152;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 9216;
    parameter ADDR_WIDTH = 14;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // 时钟和复位
    logic clk;
    logic rst_n;
    
    // 写入接口
    logic                     write_req;
    logic [2:0]               write_matrix_id;
    logic [7:0]               write_rows;
    logic [7:0]               write_cols;
    logic [63:0]              write_matrix_name;
    logic [DATA_WIDTH-1:0]    write_data_in;
    logic                     write_data_valid;
    logic                     write_done;
    logic                     writer_ready;
    
    // 读取接口
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
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT实例化
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
    
    // 测试用矩阵数据
    logic [DATA_WIDTH-1:0] test_matrix_3x3 [0:8];
    logic [DATA_WIDTH-1:0] test_matrix_2x4 [0:7];
    
    // 初始化测试数据
    initial begin
        // 3x3矩阵数据
        for (int i = 0; i < 9; i++) begin
            test_matrix_3x3[i] = i + 1;  // 1, 2, 3, ..., 9
        end
        
        // 2x4矩阵数据
        for (int i = 0; i < 8; i++) begin
            test_matrix_2x4[i] = (i + 1) * 10;  // 10, 20, 30, ..., 80
        end
    end
    
    // 任务：写入矩阵
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
        
        $display("[%0t] 开始写入矩阵 ID=%0d, 行=%0d, 列=%0d, 名称=%s", 
                 $time, matrix_id, rows, cols, matrix_name);
        
        // 等待写入器就绪
        wait(writer_ready);
        @(posedge clk);
        
        // 发起写入请求
        write_req <= 1'b1;
        write_matrix_id <= matrix_id;
        write_rows <= rows;
        write_cols <= cols;
        write_matrix_name <= matrix_name;
        @(posedge clk);
        write_req <= 1'b0;
        
        // 等待几个周期让状态机处理元数据
        repeat(4) @(posedge clk);
        
        // 写入矩阵数据
        for (i = 0; i < total_elements; i++) begin
            write_data_in <= data_array[i];
            write_data_valid <= 1'b1;
            @(posedge clk);
        end
        write_data_valid <= 1'b0;
        
        // 等待写入完成
        wait(write_done);
        $display("[%0t] 矩阵写入完成 ID=%0d", $time, matrix_id);
        @(posedge clk);
    endtask
    
    // 任务：读取矩阵
    task read_matrix(
        input logic [2:0] matrix_id,
        output logic [7:0] actual_rows,
        output logic [7:0] actual_cols,
        output logic [63:0] actual_name
    );
        integer i;
        integer total_elements;
        logic [DATA_WIDTH-1:0] received_data[$];
        
        $display("[%0t] 开始读取矩阵 ID=%0d", $time, matrix_id);
        
        // 等待读取器就绪
        wait(reader_ready);
        @(posedge clk);
        
        // 发起读取请求
        read_req <= 1'b1;
        read_matrix_id <= matrix_id;
        @(posedge clk);
        read_req <= 1'b0;
        
        // 等待元数据有效
        wait(read_meta_valid);
        @(posedge clk);
        actual_rows = read_rows;
        actual_cols = read_cols;
        actual_name = read_matrix_name;
        total_elements = actual_rows * actual_cols;
        
        $display("[%0t] 收到元数据: 行=%0d, 列=%0d, 名称=%s", 
                 $time, actual_rows, actual_cols, actual_name);
        
        // 读取矩阵数据
        for (i = 0; i < total_elements; i++) begin
            read_data_req <= 1'b1;
            @(posedge clk);
            read_data_req <= 1'b0;
            @(posedge clk);  // 等待数据延迟
            
            if (read_data_valid) begin
                received_data.push_back(read_data_out);
                $display("[%0t] 读取数据[%0d] = %0d", $time, i, read_data_out);
            end
        end
        
        // 等待读取完成
        wait(read_done);
        $display("[%0t] 矩阵读取完成 ID=%0d, 共读取%0d个数据", 
                 $time, matrix_id, received_data.size());
        @(posedge clk);
    endtask
    
    // 主测试流程
    initial begin
        // 初始化信号
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
        $display("矩阵存储管理系统仿真测试开始");
        $display("========================================");
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // 测试1: 写入3x3矩阵到槽位0
        $display("\n[测试1] 写入3x3矩阵到槽位0");
        write_matrix(3'd0, 8'd3, 8'd3, "Matrix_A", test_matrix_3x3);
        repeat(5) @(posedge clk);
        
        // 测试2: 写入2x4矩阵到槽位1
        $display("\n[测试2] 写入2x4矩阵到槽位1");
        write_matrix(3'd1, 8'd2, 8'd4, "Matrix_B", test_matrix_2x4);
        repeat(5) @(posedge clk);
        
        // 测试3: 读取槽位0的矩阵
        $display("\n[测试3] 读取槽位0的矩阵");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd0, rows_out, cols_out, name_out);
            
            // 验证元数据
            if (rows_out == 8'd3 && cols_out == 8'd3 && name_out == "Matrix_A") begin
                $display("✓ 槽位0元数据验证通过");
            end else begin
                $display("✗ 槽位0元数据验证失败");
            end
        end
        repeat(5) @(posedge clk);
        
        // 测试4: 读取槽位1的矩阵
        $display("\n[测试4] 读取槽位1的矩阵");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd1, rows_out, cols_out, name_out);
            
            // 验证元数据
            if (rows_out == 8'd2 && cols_out == 8'd4 && name_out == "Matrix_B") begin
                $display("✓ 槽位1元数据验证通过");
            end else begin
                $display("✗ 槽位1元数据验证失败");
            end
        end
        repeat(5) @(posedge clk);
        
        // 测试5: 覆盖写入槽位0
        $display("\n[测试5] 覆盖写入槽位0");
        write_matrix(3'd0, 8'd2, 8'd4, "NewMat_A", test_matrix_2x4);
        repeat(5) @(posedge clk);
        
        // 测试6: 再次读取槽位0验证覆盖
        $display("\n[测试6] 验证槽位0被正确覆盖");
        begin
            logic [7:0] rows_out, cols_out;
            logic [63:0] name_out;
            read_matrix(3'd0, rows_out, cols_out, name_out);
            
            if (rows_out == 8'd2 && cols_out == 8'd4 && name_out == "NewMat_A") begin
                $display("✓ 槽位0覆盖写入验证通过");
            end else begin
                $display("✗ 槽位0覆盖写入验证失败");
            end
        end
        repeat(10) @(posedge clk);
        
        $display("\n========================================");
        $display("仿真测试完成");
        $display("========================================");
        $finish;
    end

endmodule