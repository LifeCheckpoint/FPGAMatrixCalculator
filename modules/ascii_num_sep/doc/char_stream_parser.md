# 字符流解析器模块

## 模块概述

`char_stream_parser` 是整个系统中最复杂的控制模块，负责解析验证后的字符流，识别数字边界（空格分隔），并协调`ascii_to_int32`模块进行转换。该模块实现了完整的数字边界检测和转换控制逻辑。

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
| start | 1 | 开始解析信号 |
| total_length | 16 | 字符缓冲区总长度 |
| char_buffer | 8 × MAX_PAYLOAD | 字符缓冲区（来自validator） |
| result_valid | 1 | 转换完成反馈（来自converter） |

### 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| num_start | 1 | 数字开始信号（脉冲） |
| num_char | 8 | 当前字符 |
| num_valid | 1 | 字符有效信号 |
| num_end | 1 | 数字结束信号（脉冲） |
| num_count | 11 | 已解析数字计数 |
| parse_done | 1 | 解析完成标志 |

## 功能说明

### 状态机

六态状态机控制解析流程：

```
IDLE → SKIP_SPACE → PARSE_NUMBER → END_NUMBER → WAIT_CONVERT → DONE
  ↑                     ↓                                  |
  |                     └──────────────────────────────────┘
  └────────────────────────────────────────────────────────┘
```

#### 状态说明

1. **IDLE**：空闲状态，等待start信号
2. **SKIP_SPACE**：跳过前导和连续空格
3. **PARSE_NUMBER**：解析当前数字的字符
4. **END_NUMBER**：数字结束，发送num_end信号
5. **WAIT_CONVERT**：等待转换器完成当前数字
6. **DONE**：所有解析完成

### 数字边界检测

#### 空格判定
```verilog
function is_space(char);
  return (char == 8'h20);
endfunction
```

#### 边界识别规则

1. **数字开始**：
   - 当前状态：SKIP_SPACE
   - 当前字符：非空格
   - 动作：转到PARSE_NUMBER，发送num_start

2. **数字结束**：
   - 情况1：遇到空格
   - 情况2：到达字符串末尾
   - 动作：转到END_NUMBER，发送num_end

3. **数字继续**：
   - 当前状态：PARSE_NUMBER
   - 当前字符：非空格
   - 动作：继续发送num_char和num_valid

### 字符发送控制

#### num_start信号
- 在进入PARSE_NUMBER状态时发送
- 单周期脉冲
- 通知converter开始新数字

#### num_valid信号
- 在PARSE_NUMBER状态持续有效
- 表示num_char包含有效数字字符

#### num_end信号
- 在END_NUMBER状态发送
- 单周期脉冲
- 通知converter完成当前数字

## 工作流程

### 示例：解析 "123 456"

```
步骤  状态         read_ptr  current_char  动作
----------------------------------------------------------
 1   IDLE           0         -           收到start
 2   SKIP_SPACE     0        '1'          非空格，进入数字
 3   PARSE_NUMBER   0        '1'          发送num_start, num_char='1'
 4   PARSE_NUMBER   1        '2'          发送num_char='2'
 5   PARSE_NUMBER   2        '3'          发送num_char='3'
 6   PARSE_NUMBER   3        ' '          检测到空格
 7   END_NUMBER     3        ' '          发送num_end
 8   WAIT_CONVERT   3        ' '          等待result_valid
 9   SKIP_SPACE     4        ' '          继续跳过空格
10   SKIP_SPACE     5        '4'          检测到非空格
11   PARSE_NUMBER   5        '4'          发送num_start, num_char='4'
12   PARSE_NUMBER   6        '5'          发送num_char='5'
13   PARSE_NUMBER   7        '6'          发送num_char='6'
14   PARSE_NUMBER   7        -            到达末尾
15   END_NUMBER     7        -            发送num_end
16   WAIT_CONVERT   7        -            等待result_valid
17   DONE           -        -            num_count=2, parse_done=1
```

## 时序说明

### 单个数字解析时序

```
时钟  state        num_start  num_char  num_valid  num_end  result_valid
--------------------------------------------------------------------------
 1   SKIP_SPACE      0          -          0          0          0
 2   PARSE_NUMBER    1         '1'         1          0          0
 3   PARSE_NUMBER    0         '2'         1          0          0
 4   PARSE_NUMBER    0         '3'         1          0          0
 5   END_NUMBER      0          -          0          1          0
 6   WAIT_CONVERT    0          -          0          0          0
 7   WAIT_CONVERT    0          -          0          0          1
 8   SKIP_SPACE      0          -          0          0          0
```

### 多数字连续解析

```
时钟  current_char  num_start  num_valid  num_end  num_count
--------------------------------------------------------------
 1      '1'           1          1          0         0
 2      '2'           0          1          0         0
 3      '3'           0          1          0         0
 4      ' '           0          0          1         0
 5      ' '           0          0          0         0  ← 等待转换
 6      ' '           0          0          0         1  ← 计数+1
 7      '4'           1          1          0         1
 8      '5'           0          1          0         1
 9      -             0          0          1         1
10      -             0          0          0         1
11      -             0          0          0         2  ← 计数+2
```

## 特殊情况处理

### 1. 前导空格

输入："  123"

```
SKIP_SPACE(跳过空格) → SKIP_SPACE(跳过空格) → PARSE_NUMBER('1')
```

解析正常，忽略前导空格。

### 2. 连续空格

输入："123  456"

```
PARSE_NUMBER → END_NUMBER → WAIT_CONVERT → 
SKIP_SPACE(跳过) → SKIP_SPACE(跳过) → PARSE_NUMBER
```

正确识别两个数字。

### 3. 尾部空格

输入："123  "

```
PARSE_NUMBER → END_NUMBER → WAIT_CONVERT → 
SKIP_SPACE → SKIP_SPACE → DONE（到达末尾）
```

正确结束，num_count=1。

### 4. 负数

输入："-123"

```
PARSE_NUMBER(char='-') → PARSE_NUMBER(char='1') → 
PARSE_NUMBER(char='2') → PARSE_NUMBER(char='3')
```

负号被当作数字的一部分传给converter。

## 使用示例

### 基本解析流程

```systemverilog
// 准备字符缓冲区
for (int i = 0; i < str.len(); i++) begin
    char_buffer[i] = str[i];
end
total_length = str.len();

// 启动解析
@(posedge clk);
start <= 1'b1;
@(posedge clk);
start <= 1'b0;

// 等待完成
while (!parse_done) @(posedge clk);

// 检查结果
$display("Parsed %0d numbers", num_count);
```

## 性能特性

### 处理速度

- **单数字处理**：N + 4个时钟周期
  - N：数字字符数
  - 4：状态转换开销（START + END + WAIT + 额外1）

- **多数字处理**：总字符数 + 数字个数 × 3

### 吞吐率

- 理想情况：约每3个周期处理1个数字（无空格）
- 实际：取决于字符串格式和空格数量

## 资源占用

- **状态机**：3位状态寄存器
- **指针**：16位读指针
- **计数器**：11位数字计数器
- **字符寄存器**：8位当前字符
- **控制逻辑**：约100 LUTs（状态转换 + 字符判断）

**总计**：
- 寄存器：约40个FF
- LUTs：约100个

## 与其他模块的协作

### 上游：ascii_validator
- 读取：char_buffer, buffer_length
- char_buffer保持稳定直到解析完成

### 下游：ascii_to_int32
- 输出：num_start, num_char, num_valid, num_end
- 输入：result_valid（反馈）
- 等待转换完成才继续下一个数字

### 下游：data_write_controller
- 输出：num_count, parse_done
- 用于写入完成判断

## 注意事项

1. **反馈同步**：必须等待result_valid才能继续解析下一个数字
2. **字符顺序**：严格按char_buffer顺序读取，不能跳跃
3. **空格处理**：正确跳过任意数量的连续空格
4. **边界检测**：准确识别字符串末尾
5. **计数准确性**：num_count必须与实际解析数字数一致

## 调试建议

### 监控信号

```systemverilog
always @(posedge clk) begin
    if (num_start) $display("Start num #%0d", num_count);
    if (num_valid) $display("  Char: '%c'", num_char);
    if (num_end) $display("End num");
    if (result_valid) $display("  Converted");
end
```

### 常见问题

**问题1**：数字被拆分
- 原因：空格判断错误
- 检查：is_space函数逻辑

**问题2**：连续空格导致额外数字
- 原因：SKIP_SPACE状态逻辑错误
- 检查：状态转换条件

**问题3**：最后一个数字丢失
- 原因：未正确处理字符串末尾
- 检查：PARSE_NUMBER到END_NUMBER的转换

## 优化建议

### 性能优化

1. **流水线**：可以在等待转换时预读下一个字符
2. **并行**：多个converter并行处理（需要更复杂的控制）

### 资源优化

1. **状态编码**：使用one-hot编码减少组合逻辑
2. **字符预判**：提前判断下一个字符是否为空格

## 测试验证

测试文件：`modules/ascii_num_sep/sim/char_stream_parser_tb.sv`

测试用例：
- 单个数字
- 多个数字（单空格分隔）
- 多空格分隔
- 前导空格
- 尾部空格
- 前后空格
- 负数
- 复杂空格组合
- 大量数字（10个）
- 单个数字符