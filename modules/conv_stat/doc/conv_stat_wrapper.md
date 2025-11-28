# 卷积统计包装模块 (conv_stat_wrapper)

## 概述

`conv_stat_wrapper` 是一个包装模块，将 ROM 图像存储器和 Winograd 卷积模块组合在一起，并提供时钟周期统计功能。

## 功能特性

1. **固定图像输入**：图像数据固定来自 `input_image_rom` 模块，无需外部输入
2. **卷积核输入**：卷积核由用户通过输入端口提供
3. **卷积结果输出**：输出 8x10 的卷积结果
4. **周期统计**：统计从开始到完成整个卷积流程消耗的时钟周期数

## 接口定义

### 输入信号

| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `clk` | 1 | 时钟信号 |
| `rst_n` | 1 | 异步复位信号（低电平有效） |
| `start` | 1 | 启动信号 |
| `kernel_in` | \[31:0\]\[0:2\]\[0:2\] | 3x3 卷积核输入，每个元素 32 位 |

### 输出信号

| 信号名 | 位宽 | 描述 |
|--------|------|------|
| `result_out` | \[31:0\]\[0:7\]\[0:9\] | 8x10 卷积结果输出，每个元素 32 位 |
| `done` | 1 | 完成信号 |
| `cycle_count` | 32 | 卷积流程消耗的时钟周期数 |

## 工作原理

模块采用状态机控制，包含以下四个状态：

### 状态 1: ST_IDLE（空闲状态）

- 等待 `start` 信号拉高
- 当检测到 `start` 时，转入 ST_LOAD_IMAGE 状态
- 周期计数器清零准备开始新的计数

### 状态 2: ST_LOAD_IMAGE（图像加载状态）

1. **ROM 读取过程**：
   - 从 ROM 中读取 10x12 = 120 个像素
   - ROM 地址按行优先顺序递增（x 方向遍历，然后 y 递增）
   - 每个像素需要 1 个时钟周期读取
   - 由于 ROM 有 1 周期延迟，实际需要 121 个时钟周期完成加载

2. **数据转换**：
   - ROM 输出 4 位数据
   - 扩展为 32 位：`{28'd0, rom_data}`
   - 存储到内部 `image_buffer[10][12]`

3. **状态转换**：
   - 读取完成后，将 `image_buffer` 和 `kernel_in` 复制到卷积模块输入
   - 生成单周期 `conv_start` 脉冲
   - 转入 ST_CONV 状态

### 状态 3: ST_CONV（卷积计算状态）

1. **启动卷积**：
   - 进入状态时 `conv_start` 为高
   - 下一周期立即清零 `conv_start`（确保单周期脉冲）

2. **完成检测**：
   - 使用边沿检测机制：`if (conv_done && !conv_done_prev)`
   - 仅在 `conv_done` 上升沿时识别完成
   - 防止多次卷积时误检测残留的高电平信号

3. **状态转换**：
   - 检测到 `conv_done` 上升沿时
   - 锁存卷积结果到 `result_out`
   - 拉高 `done` 信号
   - 转入 ST_DONE 状态

### 状态 4: ST_DONE（完成状态）

1. **信号保持**：
   - `done` 信号保持高电平
   - `cycle_count` 保持最终计数值
   - `result_out` 保持卷积结果

2. **状态转换**：
   - 等待 `start` 信号变低
   - 当 `start` 为低时，返回 ST_IDLE 状态
   - 为下一次卷积做准备

### 周期计数逻辑

1. **计数开始**：
   - 在 ST_IDLE 状态检测到 `start` 上升沿时
   - `cycle_counter` 从 1 开始计数
   - `cycle_count` 清零
   - `counting` 标志置 1

2. **计数过程**：
   - 每个时钟周期 `cycle_counter` 递增
   - 包括 ROM 加载时间（约 121 周期）
   - 包括卷积计算时间（约 209 周期）
   - 总计约 333 个时钟周期

3. **计数锁存**：
   - 当 `done && counting` 条件满足时
   - 将 `cycle_counter` 的值锁存到 `cycle_count`
   - `counting` 标志清零
   - `cycle_count` 保持不变直到下一次 `start`

## 内部模块

1. **input_image_rom**：存储 10x12 的 4 位图像数据
2. **winograd_conv_10x12**：执行 Winograd 卷积计算

## 使用示例

```systemverilog
conv_stat_wrapper dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .kernel_in(kernel),
    .result_out(result),
    .done(done),
    .cycle_count(cycles)
);
```

## 注意事项

1. ROM 中的图像数据在模块内部自动读取，用户无需关心
2. 周期计数从 `start` 拉高后的第一个时钟周期开始
3. 周期计数在 `done` 信号拉高时保持，直到下一次 `start`
4. ROM 数据为 4 位，内部会扩展为 32 位送入卷积模块
