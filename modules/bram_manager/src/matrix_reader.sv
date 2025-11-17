// Matrix Reader Module
// 负责从指定的BRAM矩阵块中读取矩阵数据（包含元数据）

module matrix_reader #(
    parameter MAX_MEMORY_MATRIXES = 8,      // 最大矩阵块数量
    parameter BLOCK_SIZE = 1152,             // 每个矩阵块大小（32bit字）
    parameter DATA_WIDTH = 32,               // 数据位宽
    parameter ADDR_WIDTH = 14                // 地址位宽 ($clog2(9216))
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    // 读取请求接口
    input  logic                     read_req,         // 读取请求
    input  logic [2:0]               matrix_id,        // 矩阵编号 (0~7)
    input  logic                     read_data_req,    // 请求读取下一个矩阵数据
    output logic                     read_done,        // 读取完成
    output logic                     reader_ready,     // 读取器就绪
    
    // 元数据输出
    output logic [7:0]               rows,             // 真实行数
    output logic [7:0]               cols,             // 真实列数
    output logic [63:0]              matrix_name,      // 矩阵名称（8个字符）
    output logic                     meta_valid,       // 元数据有效
    
    // 矩阵数据输出
    output logic [DATA_WIDTH-1:0]    data_out,         // 矩阵数据输出
    output logic                     data_valid,       // 数据有效信号
    
    // BRAM接口
    output logic [ADDR_WIDTH-1:0]    bram_addr,
    input  logic [DATA_WIDTH-1:0]    bram_dout
);

    // 状态机定义
    typedef enum logic [2:0] {
        IDLE,
        READ_META0,       // 发起读取元数据字0
        WAIT_META0,       // 等待元数据字0
        READ_META1,       // 发起读取元数据字1（名称低32位）
        WAIT_META1,       // 等待元数据字1
        READ_META2,       // 发起读取元数据字2（名称高32位）
        WAIT_META2,       // 等待元数据字2
        READ_DATA,        // 读取矩阵数据
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // 内部寄存器
    logic [2:0]              saved_matrix_id;
    logic [7:0]              saved_rows;
    logic [7:0]              saved_cols;
    logic [31:0]             name_low;
    logic [31:0]             name_high;
    logic [ADDR_WIDTH-1:0]   base_addr;        // 当前矩阵块基地址
    logic [ADDR_WIDTH-1:0]   read_addr;        // 当前读地址
    logic [10:0]             data_count;       // 已读取的数据个数
    logic [10:0]             total_elements;   // 总元素数量
    
    // 计算基地址
    always_comb begin
        base_addr = saved_matrix_id * BLOCK_SIZE;
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
                if (read_req) begin
                    next_state = READ_META0;
                end
            end
            
            READ_META0: begin
                next_state = WAIT_META0;
            end
            
            WAIT_META0: begin
                next_state = READ_META1;
            end
            
            READ_META1: begin
                next_state = WAIT_META1;
            end
            
            WAIT_META1: begin
                next_state = READ_META2;
            end
            
            READ_META2: begin
                next_state = WAIT_META2;
            end
            
            WAIT_META2: begin
                next_state = READ_DATA;
            end
            
            READ_DATA: begin
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
            name_low <= 32'd0;
            name_high <= 32'd0;
            read_addr <= '0;
            data_count <= 11'd0;
            bram_addr <= '0;
            rows <= 8'd0;
            cols <= 8'd0;
            matrix_name <= 64'd0;
            meta_valid <= 1'b0;
            data_out <= '0;
            data_valid <= 1'b0;
            read_done <= 1'b0;
            reader_ready <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    reader_ready <= 1'b1;
                    read_done <= 1'b0;
                    meta_valid <= 1'b0;
                    data_valid <= 1'b0;
                    data_count <= 11'd0;
                    
                    if (read_req) begin
                        saved_matrix_id <= matrix_id;
                        reader_ready <= 1'b0;
                    end
                end
                
                READ_META0: begin
                    bram_addr <= base_addr;  // 地址0：元数据0
                end
                
                WAIT_META0: begin
                    // BRAM输出延迟1个周期，此时读取元数据0
                    saved_rows <= bram_dout[31:24];
                    saved_cols <= bram_dout[23:16];
                    total_elements <= bram_dout[31:24] * bram_dout[23:16];
                end
                
                READ_META1: begin
                    bram_addr <= base_addr + 1;  // 地址1：名称低32位
                end
                
                WAIT_META1: begin
                    name_low <= bram_dout;
                end
                
                READ_META2: begin
                    bram_addr <= base_addr + 2;  // 地址2：名称高32位
                    read_addr <= base_addr + 3;  // 准备读取数据的起始地址
                end
                
                WAIT_META2: begin
                    name_high <= bram_dout;
                    // 输出元数据
                    rows <= saved_rows;
                    cols <= saved_cols;
                    matrix_name <= {bram_dout, name_low};
                    meta_valid <= 1'b1;
                end
                
                READ_DATA: begin
                    meta_valid <= 1'b0;
                    
                    if (read_data_req && (data_count < total_elements)) begin
                        // 发起读取请求
                        bram_addr <= read_addr;
                        read_addr <= read_addr + 1;
                        data_count <= data_count + 1;
                        data_valid <= 1'b0;  // 当前周期数据无效
                    end else if (data_count > 0 && data_count <= total_elements) begin
                        // 读取数据延迟1个周期，输出上一次请求的数据
                        data_out <= bram_dout;
                        data_valid <= 1'b1;
                    end else begin
                        data_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    data_valid <= 1'b0;
                    read_done <= 1'b1;
                end
                
                default: begin
                    data_valid <= 1'b0;
                    meta_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule