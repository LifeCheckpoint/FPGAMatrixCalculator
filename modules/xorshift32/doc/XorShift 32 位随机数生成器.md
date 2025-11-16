# XorShift32 随机数生成器

## 原理

Xorshift算法通过三次异或移位操作生成伪随机数：

```systemverilog
state ^= state << 13
state ^= state >> 17  
state ^= state << 5
```

模块采用级联设计，在单个时钟周期内通过组合逻辑串行计算 N 个随机数。

## 接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk | input | 1 | 时钟信号 |
| rst_n | input | 1 | 异步复位（低有效） |
| start | input | 1 | 启动信号 |
| seed | input | 32 | 初始种子值 |
| random_out | output | 32×N | 随机数输出数组 |

## 参数

- `NUM_OUTPUTS`: 每周期生成的随机数数量（默认 4）

## 使用示例

```systemverilog
xorshift32 #(
    .NUM_OUTPUTS(4)
) rng (
    .clk(clk),
    .rst_n(rst_n),
    .start(1'b1),
    .seed(32'd123456789),
    .random_out(random_values)
);
```

复位后，每个时钟周期生成4个连续的随机数
