# Settings Data Handler 模块使用说明

## 模块概述

`settings_data_handler` 是一个设置数据处理器模块，用于从缓冲RAM读取5字节的设置数据，进行验证，并写入到设置存储模块。该模块通过一个启动信号触发，仅执行一次读取-验证-写入流程。

## 数据格式

从RAM读取的5字节数据格式如下：

| 字节偏移 | 内容 | 说明 |
|---------|------|------|
| 0 | 命令字节 | 1=最大行数, 2=最大列数, 3=数据最小值, 4=数据最大值, 5=倒计时时间 |
| 1 | 数据[7:0] | int32数据的低字节（小端序） |
| 2 | 数据[15:8] | int32数据的第二字节 |
| 3 | 数据[23:16] | int32数据的第三字节 |
| 4 | 数据[31:24] | int32数据的高字节 |

## 端口说明

### 输入端口

| 端口名 | 位宽 | 说明 |
|--------|------|------|
| `clk` | 1 | 系统时钟 |
| `rst_n` | 1 | 异步复位信号（低电平有效） |
| `start` | 1 | 启动信号（一周期脉冲） |
| `ram_rd_data` | 8 | RAM读取的数据 |

### 输出端口

| 端口名 | 位宽 | 说明 |
|--------|------|------|
| `busy` | 1 | 忙状态标志 |
| `done` | 1 | 完成信号（一周期脉冲） |
| `error` | 1 | 错误标志（持续直到复位） |
| `ram_rd_addr` | 3 | RAM读地址（0-4） |
| `settings_wr_en` | 1 | 设置写使能 |
| `settings_max_row` | 32 | 最大行数输出 |
| `settings_max_col` | 32 | 最大列数输出 |
| `settings_data_min` | 32 | 数据最小值输出 |
| `settings_data_max` | 32 | 数据最大值输出 |
| `settings_countdown_time` | 32 | 倒计时时间输出 |

## 验证规则

模块会对读取的数据进行以下验证：

### 1. 命令有效性
- 命令字节必须为 1, 2, 3, 或 4
- 其他值视为无效命令

### 2. 行数/列数限制
- 最大行数（命令=1）：必须在 1-32 范围内
- 最大列数（命令=2）：必须在 1-32 范围内
- 值为 0 或超过 32 均视为无效

### 3. 数据范围限制
- 数据最小值（命令=3）：无特殊限制
- 数据最大值（命令=4）：不可超过 65535

### 4. 倒计时时间限制
- 倒计时时间（命令=5）：必须在 5-15 范围内

## 状态机流程

```
IDLE → READ_CMD → READ_BYTE0 → READ_BYTE1 → READ_BYTE2 → READ_BYTE3 → VALIDATE
                                                                            ↓
                                                                    [验证成功]
                                                                            ↓
IDLE ← WRITE_SETTINGS ←─────────────────────────────────────────────────────┘
  ↑
  └─── [验证失败，设置error]
```

## 使用示例

```systemverilog
// 实例化缓冲RAM
logic [7:0] buffer_ram [0:4];
logic [2:0] rd_addr;
logic [7:0] rd_data;

// 实例化设置数据处理器
settings_data_handler u_handler (
    .clk                (clk),
    .rst_n              (rst_n),
    .start              (trigger_settings_update),
    .busy               (handler_busy),
    .done               (handler_done),
    .error              (handler_error),
    .ram_rd_addr        (rd_addr),
    .ram_rd_data        (rd_data),
    .settings_wr_en     (settings_wr),
    .settings_max_row   (new_max_row),
    .settings_max_col   (new_max_col),
    .settings_data_min  (new_min),
    .settings_data_max  (new_max)
);

// RAM读取逻辑
assign rd_data = buffer_ram[rd_addr];

// 示例：设置最大行数为10
initial begin
    buffer_ram[0] = 8'd1;      // 命令：最大行数
    buffer_ram[1] = 8'd10;     // 数据：10 (小端序)
    buffer_ram[2] = 8'd0;
    buffer_ram[3] = 8'd0;
    buffer_ram[4] = 8'd0;
end

// 启动处理
always_ff @(posedge clk) begin
    if (need_update && !handler_busy) begin
        trigger_settings_update <= 1'b1;
    end else begin
        trigger_settings_update <= 1'b0;
    end
end
```

## 错误处理

### 错误标志行为
- `error` 信号在检测到错误时拉高
- **持续保持高电平直到系统复位**
- 一旦 `error` 为高，模块拒绝新的 `start` 请求
- 必须通过复位清除错误状态

### 错误场景
1. **无效命令**：命令字节不在 1-4 范围内
2. **行数越界**：行数为0或超过32
3. **列数越界**：列数为0或超过32
4. **数据值越界**：数据最大值超过65535
5. **倒计时越界**：倒计时时间不在 5-15 范围内

## 与其他模块集成

### 连接到 settings_ram

```systemverilog
settings_data_handler u_handler (
    // ... 其他端口
    .settings_wr_en     (handler_wr_en),
    .settings_max_row   (handler_max_row),
    .settings_max_col   (handler_max_col),
    .settings_data_min  (handler_min),
    .settings_data_max  (handler_max)
);

settings_ram u_settings_ram (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_en        (handler_wr_en),
    .set_max_row  (handler_max_row),
    .set_max_col  (handler_max_col),
    .data_min     (handler_min),
    .data_max     (handler_max),
    .rd_max_row   (current_max_row),
    .rd_max_col   (current_max_col),
    .rd_data_min  (current_min),
    .rd_data_max  (current_max)
);
```

## 注意事项

1. **启动信号**：`start` 必须是单周期脉冲，不要持续拉高
2. **错误恢复**：错误标志只能通过复位清除，需要在上层逻辑处理
3. **RAM延迟**：模块假设RAM为同步读取，地址输出后下一周期数据有效
4. **重复启动**：在 `busy` 为高时发送 `start` 信号将被忽略
5. **数据准备**：启动前确保RAM中已填充正确的5字节数据
