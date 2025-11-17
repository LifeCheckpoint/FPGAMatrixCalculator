// Matrix Storage Manager - Top Level Module
// 整合BRAM、写入模块和读取模块，提供统一的矩阵存储管理接口

module matrix_storage_manager #(
    parameter MAX_MEMORY_MATRIXES = 8,      // 最大矩阵块数量
    parameter BLOCK_SIZE = 1152,             // 每个矩阵块大小（32bit字）
    parameter DATA_WIDTH = 32,               // 数据位宽
    parameter DEPTH = 9216,                  // BRAM总深度 (8 * 1152)
    parameter ADDR_WIDTH = 14                // 地址位宽 ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // 写入接口
    input  logic                     write_req,        // 写入请求
    input  logic [2:0]               write_matrix_id,  // 要写入的矩阵编号 (0~7)
    input  logic [7:0]               write_rows,       // 真实行数
    input  logic [7:0]               write_cols,       // 真实列数
    input  logic [63:0]              write_matrix_name,// 矩阵名称（8个字符）
    input  logic [DATA_WIDTH-1:0]    write_data_in,    // 矩阵数据输入
    input  logic                     write_data_valid, // 写数据有效信号
    output logic                     write_done,       // 写入完成
    output logic                     writer_ready,     // 写入器就绪
    
    // 读取接口
    input  logic                     read_req,         // 读取请求
    input  logic [2:0]               read_matrix_id,   // 要读取的矩阵编号 (0~7)
    input  logic                     read_data_req,    // 请求读取下一个矩阵数据
    output logic                     read_done,        // 读取完成
    output logic                     reader_ready,     // 读取器就绪
    
    // 读取元数据输出
    output logic [7:0]               read_rows,        // 真实行数
    output logic [7:0]               read_cols,        // 真实列数
    output logic [63:0]              read_matrix_name, // 矩阵名称（8个字符）
    output logic                     read_meta_valid,  // 元数据有效
    
    // 读取数据输出
    output logic [DATA_WIDTH-1:0]    read_data_out,    // 矩阵数据输出
    output logic                     read_data_valid   // 数据有效信号
);

    // BRAM接口信号
    logic                     bram_wr_en;
    logic [ADDR_WIDTH-1:0]    bram_addr;
    logic [DATA_WIDTH-1:0]    bram_din;
    logic [DATA_WIDTH-1:0]    bram_dout;
    
    // 写入模块的BRAM接口
    logic                     writer_bram_wr_en;
    logic [ADDR_WIDTH-1:0]    writer_bram_addr;
    logic [DATA_WIDTH-1:0]    writer_bram_din;
    
    // 读取模块的BRAM接口
    logic [ADDR_WIDTH-1:0]    reader_bram_addr;
    
    // 仲裁逻辑：读写不能同时进行，写优先
    // 当写入器活跃时，禁止读操作
    logic write_active;
    assign write_active = !writer_ready || write_req;
    
    always_comb begin
        if (write_active) begin
            // 写模式
            bram_wr_en = writer_bram_wr_en;
            bram_addr = writer_bram_addr;
            bram_din = writer_bram_din;
        end else begin
            // 读模式
            bram_wr_en = 1'b0;
            bram_addr = reader_bram_addr;
            bram_din = '0;
        end
    end
    
    // 实例化BRAM模块
    bram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_bram (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(bram_wr_en),
        .addr(bram_addr),
        .din(bram_din),
        .dout(bram_dout)
    );
    
    // 实例化矩阵写入模块
    matrix_writer #(
        .MAX_MEMORY_MATRIXES(MAX_MEMORY_MATRIXES),
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_matrix_writer (
        .clk(clk),
        .rst_n(rst_n),
        
        .write_req(write_req),
        .matrix_id(write_matrix_id),
        .rows(write_rows),
        .cols(write_cols),
        .matrix_name(write_matrix_name),
        .data_in(write_data_in),
        .data_valid(write_data_valid),
        .write_done(write_done),
        .writer_ready(writer_ready),
        
        .bram_wr_en(writer_bram_wr_en),
        .bram_addr(writer_bram_addr),
        .bram_din(writer_bram_din)
    );
    
    // 实例化矩阵读取模块
    matrix_reader #(
        .MAX_MEMORY_MATRIXES(MAX_MEMORY_MATRIXES),
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_matrix_reader (
        .clk(clk),
        .rst_n(rst_n),
        
        .read_req(read_req && !write_active),  // 写入时禁止读取
        .matrix_id(read_matrix_id),
        .read_data_req(read_data_req && !write_active),
        .read_done(read_done),
        .reader_ready(reader_ready),
        
        .rows(read_rows),
        .cols(read_cols),
        .matrix_name(read_matrix_name),
        .meta_valid(read_meta_valid),
        
        .data_out(read_data_out),
        .data_valid(read_data_valid),
        
        .bram_addr(reader_bram_addr),
        .bram_dout(bram_dout)
    );

endmodule