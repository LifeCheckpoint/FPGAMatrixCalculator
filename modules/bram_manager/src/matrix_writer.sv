// Matrix Writer Module
// 负责将矩阵数据（包含元数据）写入到指定的BRAM矩阵块中

module matrix_writer #(
    parameter MAX_MEMORY_MATRIXES = 8,      // 最大矩阵块数量
    parameter BLOCK_SIZE = 1152,             // 每个矩阵块大小（32bit字）
    parameter DATA_WIDTH = 32,               // 数据位宽
    parameter ADDR_WIDTH = 14                // 地址位宽 ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // 写入请求接口
    input  logic                     write_req,        // 写入请求
    input  logic [2:0]               matrix_id,        // 矩阵编号 (0~7)
    input  logic [7:0]               rows,             // 真实行数
    input  logic [7:0]               cols,             // 真实列数
    input  logic [63:0]              matrix_name,      // 矩阵名称（8个字符）
    input  logic [DATA_WIDTH-1:0]    data_in,          // 矩阵数据输入
    input  logic                     data_valid,       // 数据有效信号
    output logic                     write_done,       // 写入完成
    output logic                     writer_ready,     // 写入器就绪
    
    // BRAM接口
    output logic                     bram_wr_en,
    output logic [ADDR_WIDTH-1:0]    bram_addr,
    output logic [DATA_WIDTH-1:0]    bram_din
);

    // 状态机定义
    typedef enum logic [2:0] {
        IDLE,
        WRITE_META0,      // 写元数据字0（行数、列数）
        WRITE_META1,      // 写元数据字1（名称低32位）
        WRITE_META2,      // 写元数据字2（名称高32位）
        WRITE_DATA,       // 写矩阵数据
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // 内部寄存器
    logic [2:0]              saved_matrix_id;
    logic [7:0]              saved_rows;
    logic [7:0]              saved_cols;
    logic [63:0]             saved_name;
    logic [ADDR_WIDTH-1:0]   base_addr;        // 当前矩阵块基地址
    logic [ADDR_WIDTH-1:0]   write_addr;       // 当前写地址
    logic [10:0]             data_count;       // 已写入的数据个数
    logic [10:0]             total_elements;   // 总元素数量
    
    // 计算基地址
    always_comb begin
        base_addr = saved_matrix_id * BLOCK_SIZE;
    end
    
    // 计算总元素数量
    always_comb begin
        total_elements = saved_rows * saved_cols;
    end
    
    // 状态机：时序逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // 状态机：组合逻辑
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (write_req) begin
                    next_state = WRITE_META0;
                end
            end
            
            WRITE_META0: begin
                next_state = WRITE_META1;
            end
            
            WRITE_META1: begin
                next_state = WRITE_META2;
            end
            
            WRITE_META2: begin
                next_state = WRITE_DATA;
            end
            
            WRITE_DATA: begin
                if (data_count >= total_elements) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // 数据路径控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_matrix_id <= 3'd0;
            saved_rows <= 8'd0;
            saved_cols <= 8'd0;
            saved_name <= 64'd0;
            write_addr <= '0;
            data_count <= 11'd0;
            bram_wr_en <= 1'b0;
            bram_addr <= '0;
            bram_din <= '0;
            write_done <= 1'b0;
            writer_ready <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    writer_ready <= 1'b1;
                    write_done <= 1'b0;
                    bram_wr_en <= 1'b0;
                    data_count <= 11'd0;
                    
                    if (write_req) begin
                        saved_matrix_id <= matrix_id;
                        saved_rows <= rows;
                        saved_cols <= cols;
                        saved_name <= matrix_name;
                        writer_ready <= 1'b0;
                    end
                end
                
                WRITE_META0: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr;  // 地址0：元数据0
                    bram_din <= {saved_rows, saved_cols, 16'd0};  // [31:24]=行数, [23:16]=列数
                end
                
                WRITE_META1: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr + 1;  // 地址1：名称低32位
                    bram_din <= saved_name[31:0];
                end
                
                WRITE_META2: begin
                    bram_wr_en <= 1'b1;
                    bram_addr <= base_addr + 2;  // 地址2：名称高32位
                    bram_din <= saved_name[63:32];
                    write_addr <= base_addr + 3;  // 下一次写入数据的起始地址
                end
                
                WRITE_DATA: begin
                    if (data_valid && (data_count < total_elements)) begin
                        bram_wr_en <= 1'b1;
                        bram_addr <= write_addr;
                        bram_din <= data_in;
                        write_addr <= write_addr + 1;
                        data_count <= data_count + 1;
                    end else begin
                        bram_wr_en <= 1'b0;
                    end
                end
                
                DONE: begin
                    bram_wr_en <= 1'b0;
                    write_done <= 1'b1;
                end
                
                default: begin
                    bram_wr_en <= 1'b0;
                end
            endcase
        end
    end

endmodule