# ASCII数字分离器 - 顶层模块使用指南

## 模块概述

`ascii_num_sep_top` 是ASCII数字分离器系统的顶层集成模块，整合了5个子模块，提供完整的"UART数据包→整数数组"转换功能。

## 系统架构

```
uart_packet_handler
        ↓ (payload stream)
  ┌─────────────────────────────────────┐
  │      ascii_num_sep_top              │
  │                                     │
  │  ┌─────────────────────────┐        │
  │  │   ascii_validator       │        │
  │  └──────────┬──────────────┘        │
  │             ↓ (char_buffer)         │
  │  ┌─────────────────────────┐        │
  │  │  char_stream_parser     │        │
  │  └──────────┬──────────────┘        │
  │             ↓ (control signals)     │
  │  ┌─────────────────────────┐        │
  │  │   ascii_to_int32        │        │
  │  └──────────┬──────────────┘        │
  │             ↓ (int32 results)       │
  │  ┌─────────────────────────┐        │
  │  │ data_write_controller   │        │
  │  └──────────┬──────────────┘        │
  │             ↓ (write commands)      │
  │  ┌─────────────────────────┐        │
  │  │   num_storage_ram       │        │
  │  └──────────┬──────────────┘        │
  │             │                       │
  └─────────────┼───────────────────────┘
                ↓ (read interface)
         后续处理模块
```

## 参数说明

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| MAX_PAYLOAD | 2048 | 最大payload长度 |
| DATA_WIDTH | 32 | 数据位宽 |
| DEPTH | 2048 | RAM深度 |
| ADDR_WIDTH | 11 | 地址位宽 |

## 接口定义

### 输入信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| clk | 1 | 时钟信号 |
| rst_n | 1 | 异步低电平复位 |
| pkt_payload_data | 8 | UART包payload数据 |
| pkt_payload_valid | 1 | payload有效信号 |
| pkt_payload_last | 1 | payload最后字节标志 |
| rd_addr | 11 | RAM读地址 |

### 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| pkt_payload_ready | 1 | 准备接收payload |
| rd_data | 32 | RAM读数据 |
| processing | 1 | 正在处理标志 |
| done | 1 | 处理完成标志 |
| invalid | 1 | 无效字符标志 |
| num_count | 11 | 解析的数字数量 |

## 功能说明

### 完整处理流程

```
阶段1：字符验证 (ascii_validator)
  - 接收UART payload字节流
  - 验证每个字符是否有效（数字/空格/负号）
  - 缓存所有字符
  - 输出：done=1, invalid=0/1

阶段2：字符解析 (char_stream_parser)
  - 读取字符缓冲区
  - 识别数字边界
  - 逐个数字控制转换过程
  - 输出：num_count, parse_done

阶段3：数字转换 (ascii_to_int32)
  - 接收单个数字的字符序列
  - 累积计算int32值
  - 处理负号
  - 输出：result, result_valid

阶段4：写入管理 (data_write_controller)
  - 接收转换结果
  - 生成RAM写地址
  - 管理写入流程
  - 输出：all_done

阶段5：数据存储 (num_storage_ram)
  - 存储转换后的整数
  - 提供读取接口
```

## 状态与时序

### 系统状态

```
状态          processing  done  invalid  说明
-------------------------------------------------------
空闲           0          0      0       等待payload
接收验证       0          0      0       validator工作中
验证完成       1          0      0       开始解析
解析转换       1          0      0       parser+converter工作
写入RAM        1          0      0       写入过程
全部完成       0          1      0       可读取结果

错误状态       0          1      1       发现无效字符
```

### 典型时序

输入字符串："123 456"

```
时间(us)  阶段           processing  done  num_count
--------------------------------------------------------
 0-1      接收验证         0          0      0
 1-2      解析开始         1          0      0
 2-4      解析"123"        1          0      0
 4-5      转换"123"        1          0      0
 5-6      写入123          1          0      1
 6-8      解析"456"        1          0      1
 8-9      转换"456"        1          0      1
 9-10     写入456          1          0      2
10+       完成             0          1      2
```

## 使用示例

### 完整使用流程

```systemverilog
// 1. 发送payload数据
string test_str = "123 -456 789";
for (int i = 0; i < test_str.len(); i++) begin
    @(posedge clk);
    pkt_payload_data <= test_str[i];
    pkt_payload_valid <= 1'b1;
    pkt_payload_last <= (i == test_str.len() - 1);
    @(posedge clk);
    pkt_payload_valid <= 1'b0;
    pkt_payload_last <= 1'b0;
end

// 2. 等待处理完成
@(posedge clk);
while (!done) @(posedge clk);

// 3. 检查是否有效
if (invalid) begin
    $display("Error: Invalid characters detected!");
end else begin
    $display("Parsed %0d numbers", num_count);
    
    // 4. 读取结果
    for (int i = 0; i < num_count; i++) begin
        @(posedge clk);
        rd_addr <= i;
        @(posedge clk);
        @(posedge clk);  // 等待读延迟
        $display("Number[%0d] = %0d", i, $signed(rd_data));
    end
end
```

### 与uart_packet_handler集成

```systemverilog
// UART包处理器实例
uart_packet_handler u_uart_pkt (
    .clk                (clk),
    .rst_n              (rst_n),
    // ... 其他端口 ...
    .pkt_payload_data   (pkt_payload_data),
    .pkt_payload_valid  (pkt_payload_valid),
    .pkt_payload_last   (pkt_payload_last),
    .pkt_payload_ready  (pkt_payload_ready)
);

// ASCII数字分离器
ascii_num_sep_top u_ascii_sep (
    .clk                (clk),
    .rst_n              (rst_n),
    .pkt_payload_data   (pkt_payload_data),
    .pkt_payload_valid  (pkt_payload_valid),
    .pkt_payload_last   (pkt_payload_last),
    .pkt_payload_ready  (pkt_payload_ready),
    .rd_addr            (my_rd_addr),
    .rd_data            (my_rd_data),
    .processing         (processing),
    .done               (done),
    .invalid            (invalid),
    .num_count          (num_count)
);
```

## 性能指标

### 处理时间

假设时钟频率为100MHz（周期10ns）：

| 数据内容 | 字符数 | 数字数 | 处理时间 | 说明 |
|----------|--------|--------|----------|------|
| "123" | 3 | 1 | ~100ns | 单个3位数 |
| "123 456" | 7 | 2 | ~200ns | 两个数字 |
| "1 2 3..." (10个) | 19 | 10 | ~500ns | 10个单位数 |
| "100 200..." (10个) | 39 | 10 | ~800ns | 10个三位数 |

**估算公式**：
```
处理时间 ≈ (字符总数 × 10ns) + (数字个数 × 50ns)
```

### 吞吐率

- **字符处理速率**：100M字符/秒
- **数字转换速率**：约20M数字/秒
- **限制因素**：字符解析和状态转换

## 资源占用

### 总资源估算

| 资源类型 | 数量 | 说明 |
|----------|------|------|
| FF (寄存器) | ~16,600 | 主要在char_buffer |
| LUT | ~300 | 控制逻辑 |
| BRAM | 1块 | num_storage_ram |
| DSP | 1个 | 乘法运算 |

### 各模块占比

```
ascii_validator:     16,400 FF (缓冲区)
char_stream_parser:      40 FF, 100 LUT
ascii_to_int32:          40 FF,  50 LUT, 1 DSP
data_write_controller:   60 FF,  45 LUT
num_storage_ram:          -  ,   -      , 1 BRAM
顶层连线:                 -  ,  50 LUT
```

## 错误处理

### 无效字符检测

```systemverilog
if (done && invalid) begin
    // 处理错误
    case (error_policy)
        DISCARD: begin
            // 丢弃整个包
            $display("Packet discarded");
        end
        REPORT: begin
            // 报告错误但继续
            $display("Warning: Invalid chars");
        end
    endcase
end
```

### 超时处理

```systemverilog
// 超时计数器
logic [15:0] timeout_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_cnt <= 0;
    end else if (done) begin
        timeout_cnt <= 0;
    end else if (processing) begin
        timeout_cnt <= timeout_cnt + 1;
        if (timeout_cnt > TIMEOUT_LIMIT) begin
            // 超时处理
            $display("Processing timeout!");
        end
    end
end
```

## 调试与监控

### 关键监控点

```systemverilog
// 实时监控
always @(posedge clk) begin
    if (pkt_payload_valid && pkt_payload_last) begin
        $display("[%t] Payload received, length=%0d", 
                 $time, payload_length);
    end
    
    if (done) begin
        if (invalid) begin
            $display("[%t] ERROR: Invalid characters", $time);
        end else begin
            $display("[%t] SUCCESS: %0d numbers parsed", 
                     $time, num_count);
        end
    end
end
```

### 调试建议

1. **分阶段调试**
   - 先验证validator工作正常
   - 再检查parser边界检测
   - 最后验证转换准确性

2. **波形观察重点**
   - validator的done和invalid时刻
   - parser的num_start/num_end脉冲
   - converter的result_valid
   - RAM写使能和地址

3. **常见问题定位**
   - 数字丢失：检查parser状态转换
   - 转换错误：检查converter输入
   - 计数不符：检查num_count更新时机

## 应用场景

### 场景1：矩阵数据接收

```systemverilog
// 接收矩阵数据 "1 2 3 4 5 6 7 8 9"
// 用于3×3矩阵
while (!done) @(posedge clk);

if (!invalid && num_count == 9) begin
    // 读取并填充矩阵
    for (int row = 0; row < 3; row++) begin
        for (int col = 0; col < 3; col++) begin
            rd_addr <= row * 3 + col;
            @(posedge clk);
            @(posedge clk);
            matrix[row][col] = rd_data;
        end
    end
end
```

### 场景2：参数配置

```systemverilog
// 接收配置参数 "100 200 -50"
// 对应：阈值1 阈值2 偏移量
while (!done) @(posedge clk);

if (!invalid && num_count == 3) begin
    rd_addr <= 0; @(posedge clk); @(posedge clk);
    threshold1 = rd_data;
    
    rd_addr <= 1; @(posedge clk); @(posedge clk);
    threshold2 = rd_data;
    
    rd_addr <= 2; @(posedge clk); @(posedge clk);
    offset = rd_data;
end
```

## 注意事项

1. **复位要求**：每处理完一个包必须复位才能处理下一个
2. **payload格式**：必须是空格分隔的整数，不支持其他格式
3. **容量限制**：最多2048个整数
4. **时序约束**：确保100MHz时钟稳定
5. **读延迟**：RAM读操作有1周期延迟

## 测试验证

完整的测试套件包括：

### 单元测试
- `num_storage_ram_tb.sv` - RAM测试
- `ascii_to_int32_tb.sv` - 转换器测试
- `ascii_validator_tb.sv` - 验证器测试
- `data_write_controller_tb.sv` - 控制器测试
- `char_stream_parser_tb.sv` - 解析器测试

### 集成测试
- `ascii_num_sep_top_tb.sv` - 顶层集成测试

### 测试覆盖
- ✓ 正数
- ✓ 负数
- ✓ 混合正负数
- ✓ 单个数字
- ✓ 多个数字
- ✓ 前导/尾部空格
- ✓ 多重空格
- ✓ 边界值
- ✓ 无效字符
- ✓ 空输入
