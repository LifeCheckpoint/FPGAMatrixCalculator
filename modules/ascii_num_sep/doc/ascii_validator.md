# ASCII字符验证器模块

## 模块概述

`ascii_validator` 模块负责验证UART接收到的payload字符流，检查是否所有字符都是有效的（数字、空格、负号）。同时，该模块将接收到的字符缓存起来，供后续解析模块使用。

## 参数说明

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| MAX_PAYLOAD | 2048 | 最大payload长度 |

## 接口定义

### 输入信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| clk | 1 | 时钟信号 |
| rst_n | 1 | 异步低电平复位 |
| payload_data | 8 | payload字节数据 |
| payload_valid | 1 | payload数据有效信号 |
| payload_last | 1 | payload最后一个字节标志 |

### 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| payload_ready | 1 | 准备接收payload标志 |
| char_buffer | 8 × MAX_PAYLOAD | 字符缓冲区数组 |
| buffer_length | 16 | 缓冲区有效长度 |
| done | 1 | 验证完成标志 |
| invalid | 1 | 发现无效字符标志 |

## 功能说明

### 有效字符定义

模块仅接受以下三类字符：

| 字符类型 | ASCII码范围 | 说明 |
|----------|-------------|------|
| 数字 | 0x30-0x39 | '0' 到 '9' |
| 空格 | 0x20 | ' ' |
| 负号 | 0x2D | '-' |

任何其他字符都会被标记为无效。

### 状态机

三态状态机控制验证流程：

1. **IDLE**：空闲状态，等待payload输入
2. **VALIDATE**：验证状态，接收并检查每个字符
3. **DONE**：完成状态，保持结果稳定

```
IDLE → VALIDATE → DONE
 ↑                  |
 └──────────────────┘
    (reset)
```

### 验证逻辑

```verilog
有效字符判定：
  '0' <= char <= '9'  OR
  char == ' '         OR
  char == '-'
```

### 缓冲机制

- 所有接收到的字符都存入 `char_buffer`
- 按接收顺序存储，索引从0开始
- `buffer_length` 记录总字符数
- 缓冲区在DONE状态保持稳定，供后续模块读取

## 时序说明

### 接收时序

```
时钟  payload_valid  payload_data  payload_last  state      invalid
--------------------------------------------------------------------
 1        0             -              0          IDLE        0
 2        1           '1'(0x31)        0          VALIDATE    0
 3        1           '2'(0x32)        0          VALIDATE    0
 4        1           '3'(0x33)        0          VALIDATE    0
 5        1           ' '(0x20)        0          VALIDATE    0
 6        1           '4'(0x34)        1          VALIDATE    0
 7        0             -              0          DONE        0
```

### 发现无效字符

```
时钟  payload_valid  payload_data  payload_last  state      invalid
--------------------------------------------------------------------
 1        0             -              0          IDLE        0
 2        1           '1'(0x31)        0          VALIDATE    0
 3        1           'A'(0x41)        0          VALIDATE    1  ← 检测到无效
 4        1           '3'(0x33)        1          VALIDATE    1
 5        0             -              0          DONE        1
```

## 使用示例

### 验证有效字符串

```systemverilog
// 发送字符流 "123 -456"
for (int i = 0; i < str.len(); i++) begin
    @(posedge clk);
    payload_data <= str[i];
    payload_valid <= 1'b1;
    payload_last <= (i == str.len() - 1);
    @(posedge clk);
    payload_valid <= 1'b0;
    payload_last <= 1'b0;
end

// 等待完成
while (!done) @(posedge clk);

// 检查结果
if (!invalid) begin
    // 验证通过，可以读取char_buffer
    for (int i = 0; i < buffer_length; i++) begin
        $display("char_buffer[%0d] = '%c'", i, char_buffer[i]);
    end
end else begin
    // 发现无效字符，丢弃该包
    $display("Invalid characters detected!");
end
```

## 工作流程

1. **接收阶段**（VALIDATE状态）
   - 监听 `payload_valid` 信号
   - 每次收到字节时：
     - 将字节存入 `char_buffer[write_ptr]`
     - write_ptr自增
     - 检查字节是否有效
     - 如果无效，设置 `invalid` 标志
   
2. **完成阶段**（DONE状态）
   - 收到 `payload_last` 信号后进入
   - 设置 `buffer_length` 为实际接收字符数
   - 保持 `done` 和 `invalid` 信号稳定
   - 等待系统复位

## 错误处理

### 无效字符检测

一旦检测到任何无效字符：
- 立即设置 `invalid = 1`
- 继续接收剩余字符（缓存完整数据）
- 在DONE状态保持invalid标志
- 后续模块应丢弃该数据包

### 缓冲区溢出

- 如果payload长度超过MAX_PAYLOAD，行为未定义
- 建议在uart_packet_handler层限制payload大小

## 性能特性

- **延迟**：处理完成延迟 = payload长度 + 1个时钟周期
- **吞吐率**：每时钟周期处理1个字节
- **缓冲容量**：最多存储MAX_PAYLOAD个字符

## 资源占用

- **寄存器**：约 MAX_PAYLOAD × 8 位（字符缓冲）
- **逻辑资源**：
  - 状态机：约20 LUTs
  - 验证逻辑：约10 LUTs
  - 地址管理：约20 LUTs

对于MAX_PAYLOAD=2048：
- **总寄存器数**：约16,400个FF
- **总LUT数**：约50个

## 注意事项

1. **缓冲区保持**：在DONE状态，char_buffer保持稳定，直到系统复位
2. **无效标志持久性**：invalid标志一旦置位，在当前包处理周期内不会清除
3. **单次使用**：每次验证后必须复位才能处理下一个包
4. **字符顺序**：字符严格按接收顺序存储
5. **流控**：通过payload_ready进行流控，暂不支持暂停接收

## 典型应用场景

### 场景1：正常数据验证

输入："123 456 -789"
- 所有字符有效
- buffer_length = 12
- invalid = 0
- 后续模块可安全解析

### 场景2：包含无效字符

输入："123ABC456"
- 检测到'A', 'B', 'C'无效
- invalid = 1
- 后续模块跳过该包

### 场景3：空payload

输入：payload_last立即置位
- buffer_length = 1（含最后字节）
- 根据最后字节判断invalid

## 测试验证

测试文件：`modules/ascii_num_sep/sim/ascii_validator_tb.sv`

测试用例包括：
- 纯数字字符串
- 带空格的数字
- 带负号的数字
- 包含字母的无效输入
- 包含特殊符号的无效输入
- 小数点（无效）
- 空payload
- 复杂混合有效字符
- 多种无效字符组合