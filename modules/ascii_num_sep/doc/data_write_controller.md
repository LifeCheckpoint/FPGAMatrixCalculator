# 数据写入控制器模块

## 模块概述

`data_write_controller` 模块负责管理转换后的int32数据写入RAM的过程。它接收来自`ascii_to_int32`模块的转换结果，生成RAM写地址和写使能信号，并跟踪写入进度。

## 接口定义

### 输入信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| clk | 1 | 时钟信号 |
| rst_n | 1 | 异步低电平复位 |
| data_in | 32 (signed) | 来自转换器的int32数据 |
| data_valid | 1 | 数据有效信号 |
| total_count | 11 | 期望的总数字数量 |
| parse_done | 1 | 解析完成标志 |

### 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| ram_wr_en | 1 | RAM写使能 |
| ram_wr_addr | 11 | RAM写地址 |
| ram_wr_data | 32 | RAM写数据 |
| write_count | 11 | 已写入数据计数 |
| all_done | 1 | 全部写入完成标志 |

## 功能说明

### 地址管理

- **起始地址**：每次复位后从地址0开始
- **地址递增**：每次有效写入后地址自动加1
- **地址范围**：0到2047（11位地址）

### 写入控制

#### 写使能生成
```verilog
ram_wr_en = data_valid的延迟1周期版本
```

写使能信号跟随data_valid信号，确保数据稳定后写入。

#### 数据直通
```verilog
ram_wr_data = data_in的寄存器版本
```

数据经过一级寄存器后写入RAM，确保时序满足要求。

### 完成检测

```verilog
all_done = parse_done AND (write_count == total_count)
```

只有当解析完成且写入数量达到预期时，才置位all_done标志。

## 工作流程

### 正常写入流程

```
1. 初始状态
   - write_count = 0
   - wr_addr = 0
   - all_done = 0

2. 接收第一个数据
   - data_valid = 1
   - data_in = 123
   → ram_wr_en = 1
   → ram_wr_addr = 0
   → ram_wr_data = 123
   → write_count = 1

3. 接收第二个数据
   - data_valid = 1
   - data_in = 456
   → ram_wr_addr = 1
   → ram_wr_data = 456
   → write_count = 2

4. 解析完成
   - parse_done = 1
   - total_count = 2
   - write_count = 2
   → all_done = 1
```

## 时序说明

### 写入时序

```
时钟  data_valid  data_in  ram_wr_en  ram_wr_addr  ram_wr_data  write_count
-----------------------------------------------------------------------------
 1       0          -         0          0            -            0
 2       1         123        0          0            -            0
 3       0          -         1          0           123           0  ← write_count还未更新
 4       0          -         0          1           123           1  ← write_count才更新
 5       1         456        0          1           123           1
 6       0          -         1          1           456           1  ← write_count还未更新
 7       0          -         0          2           456           2  ← write_count才更新
```

**关键时序特性：**
- `ram_wr_en` 相对于 `data_valid` 延迟1周期
- `ram_wr_data` 相对于 `data_in` 延迟1周期
- `write_count` 相对于 `ram_wr_en` **再延迟1周期**才能读到新值
  - 原因：使用非阻塞赋值（`<=`），寄存器更新在下一周期生效
  - 在周期3，`ram_wr_en=1` 时开始更新，但 `write_count` 仍为旧值0
  - 在周期4，`write_count` 才显示为新值1

**测试时注意：**
检查 `write_count` 时，需要在最后一次写入后等待**2个时钟周期**：
```systemverilog
send_data(32'd123);      // 周期N: data_valid=1
@(posedge clk);           // 周期N+1: ram_wr_en=1, write_count=旧值
@(posedge clk);           // 周期N+2: write_count=新值 ← 在这里检查
verify_write_count(1);    // 现在write_count才是正确的
```

### 完成时序

```
时钟  parse_done  total_count  write_count  all_done
-----------------------------------------------------
 1       0           3             0            0
 2       0           3             1            0
 3       0           3             2            0
 4       1           3             2            0  ← parse_done先到
 5       0           3             3            1  ← write_count到达
```

## 使用示例

### 基本写入操作

```systemverilog
// 设置期望计数
total_count <= 11'd3;

// 写入第一个数据
@(posedge clk);
data_in <= 32'd100;
data_valid <= 1'b1;
@(posedge clk);
data_valid <= 1'b0;

// 写入第二个数据
@(posedge clk);
data_in <= 32'd200;
data_valid <= 1'b1;
@(posedge clk);
data_valid <= 1'b0;

// 写入第三个数据
@(posedge clk);
data_in <= 32'd300;
data_valid <= 1'b1;
@(posedge clk);
data_valid <= 1'b0;

// 标记解析完成
parse_done <= 1'b1;

// 等待all_done
while (!all_done) @(posedge clk);
```

## 关键特性

### 1. 地址自动管理
- 无需外部提供地址
- 自动从0开始递增
- 保证连续存储

### 2. 计数同步
- write_count实时反映已写入数量
- 可用于进度监控

### 3. 完成检测
- 双重条件确认（解析完成 + 计数匹配）
- 防止过早或遗漏数据

### 4. 复位后自动归零
- all_done置位后，系统复位可重新开始

## 边缘情况处理

### 情况1：解析完成早于最后一次写入

```
parse_done先到 → 等待write_count增加 → all_done置位
```

### 情况2：写入完成早于解析完成

```
write_count到达total_count → 等待parse_done → all_done置位
```

### 情况3：写入数据有间隙

```
支持非连续写入，只要data_valid脉冲即可
```

## 性能特性

- **写入延迟**：data_valid到ram_wr_en为1个时钟周期
- **吞吐率**：理论上每周期可写入1个数据
- **最大容量**：支持最多2048个数据（11位地址）

## 资源占用

- **寄存器**：
  - 地址寄存器：11位
  - 计数器：11位
  - 数据寄存器：32位
  - 控制信号：约5位
  - **总计**：约60个FF

- **逻辑资源**：
  - 加法器（地址递增）：约15 LUTs
  - 比较器（完成检测）：约20 LUTs
  - 控制逻辑：约10 LUTs
  - **总计**：约45 LUTs

## 注意事项

1. **写入顺序**：严格按照data_valid顺序写入，地址连续递增
2. **计数准确性**：total_count必须准确反映实际数字数量
3. **同步要求**：parse_done应在所有数据写入完成前置位
4. **复位行为**：all_done置位后需要复位才能处理下一批数据
5. **无溢出保护**：如果write_count超过2047，地址会回绕
6. **⚠️ 时序延迟**：`write_count`的更新相对于`ram_wr_en`有1周期延迟
   - 读取`write_count`值时，需要在最后一次写入后等待2个时钟周期
   - 这是由于寄存器的非阻塞赋值特性导致的正常现象
   - 测试代码必须考虑这个延迟，否则会读到过时的计数值

## 与其他模块的接口

### 上游：ascii_to_int32
- 接收：data_in, data_valid
- data_valid为单周期脉冲

### 上游：char_stream_parser  
- 接收：total_count, parse_done
- total_count随解析过程更新

### 下游：num_storage_ram
- 输出：ram_wr_en, ram_wr_addr, ram_wr_data
- 符合RAM写接口时序要求

## 调试建议

### 监控点

1. **write_count**：观察写入进度
2. **ram_wr_addr**：验证地址连续性
3. **all_done**：确认完成时机

### 常见问题

**问题1**：all_done不置位
- 检查：write_count是否等于total_count
- 检查：parse_done是否已置位
- ⚠️ 检查：是否在write_count更新完成后才检查（需等待2个周期）

**问题2**：地址跳跃
- 检查：data_valid脉冲是否正确
- 检查：是否有意外的复位

**问题3**：数据错位
- 检查：写使能时序
- 检查：数据寄存器延迟

**问题4**：write_count读取值不正确（常见问题）
- **根因**：在ram_wr_en有效的同一周期读取write_count
- **现象**：读到的值总是比预期少1
- **解决**：在最后一次写入后等待2个时钟周期再读取
- **示例**：
  ```systemverilog
  // 错误做法 ❌
  send_data(123);
  @(posedge clk);
  $display("count=%d", write_count);  // 会少1！
  
  // 正确做法 ✓
  send_data(123);
  @(posedge clk);
  @(posedge clk);  // 多等1个周期
  $display("count=%d", write_count);  // 正确
  ```

## 测试验证

测试文件：`modules/ascii_num_sep/sim/data_write_controller_tb.sv`

测试用例包括：
- 单个写入
- 连续多个写入
- 负数写入
- 写入间隙
- 批量写入（10个）
- parse_done时序测试
- 大数值写入
- 地址序列验证