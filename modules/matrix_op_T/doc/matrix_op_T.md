# 矩阵转置模块 (matrix_op_T)

## 1. 功能概述

本模块执行矩阵的转置运算 ($C = A^T$)。结果矩阵将自动写入到系统预留的结果缓冲区（Matrix ID = 0）。

## 2. 接口定义

| 信号名称 | 方向 | 位宽 | 描述 |
| :--- | :--- | :--- | :--- |
| `clk` | input | 1 | 系统时钟 |
| `rst_n` | input | 1 | 异步复位，低电平有效 |
| `start` | input | 1 | 启动脉冲，高电平有效 |
| `matrix_src_id` | input | 3 | 源矩阵 A 的 ID (1-7) |
| `busy` | output | 1 | 模块忙指示，高电平表示正在运算 |
| `status` | output | 4 | 操作状态/错误码 (见下文) |
| `read_addr` | output | 14 | BRAM 读取地址 |
| `data_out` | input | 32 | BRAM 读取数据 |
| `write_request` | output | 1 | 请求写入权限 |
| `write_ready` | input | 1 | 外部仲裁器允许写入 |
| `matrix_id` | output | 3 | 写入目标 ID (固定为 0) |
| `actual_rows` | output | 8 | 结果矩阵行数 (等于 A 的列数) |
| `actual_cols` | output | 8 | 结果矩阵列数 (等于 A 的行数) |
| `matrix_name` | output | 8x8 | 结果矩阵名称 ("TRANSPOS") |
| `data_in` | output | 32 | 写入数据 |
| `data_valid` | output | 1 | 写入数据有效指示 |
| `writer_ready` | input | 1 | 写入器准备好接收数据 |
| `write_done` | input | 1 | 写入完成信号 |

## 3. 操作流程

1. **空闲状态**: 等待 `start` 信号。
2. **参数检查**: 检查输入 ID 是否有效 (1-7)。
3. **元数据读取**: 读取源矩阵的维度信息。
4. **维度校验**: 检查源矩阵是否为空。
5. **写入请求**: 向仲裁器请求写入权限。
6. **计算与写入**: 按照转置后的顺序（即按列优先）读取源矩阵元素，并流式写入结果缓冲区。
7. **完成**: 等待写入完成信号，更新 `status` 为 `SUCCESS`。

## 4. 状态码 (status)

- `0 (IDLE)`: 空闲
- `1 (BUSY)`: 忙碌
- `2 (SUCCESS)`: 操作成功
- `4 (ERR_ID)`: 输入 ID 无效 (必须在 1-7 之间)
- `5 (ERR_EMPTY)`: 输入矩阵为空或维度为 0
- `7 (ERR_FORMAT)`: 数据量超出容量限制

## 5. 注意事项

- 结果矩阵名称固定为 "TRANSPOS"。
- 转置操作通过改变读取地址的顺序来实现，不涉及复杂的算术运算。
- 若发生错误，`busy` 信号拉低，`status` 保持错误码直到下一次 `start`。
