# UART 通用通信模块与协议设计方案

## 1. 系统架构概览

为了实现 PC 与 FPGA 的灵活交互，我们将系统划分为三层：

```mermaid
graph TD
    PC[电脑 (Python/上位机)] <--> UART_Cable[串口线]
    subgraph FPGA
        UART_PHY[UART 收发器 (uart_rx/tx)]
        Packet_Handler[协议解析与组包 (Packet Handler)]
        Dispatcher[指令分发器 (Command Dispatcher)]
        
        subgraph Adapters [专精适配模块]
            Writer_Adapter[矩阵写入适配器]
            Reader_Adapter[矩阵读取适配器]
            Compute_Ctrl[计算控制适配器]
        end
        
        Storage[矩阵存储管理器 (BRAM Manager)]
        Calc_Cores[计算核心 (Add/Mul/T...)]
    end
    
    UART_PHY <--> Packet_Handler
    Packet_Handler <--> Dispatcher
    Dispatcher --> Writer_Adapter --> Storage
    Dispatcher --> Reader_Adapter <--> Storage
    Dispatcher --> Compute_Ctrl --> Calc_Cores
```

## 2. 通信协议设计 (Communication Protocol)

采用 **定长帧头 + 变长载荷** 的帧结构。所有多字节数据采用 **Little-Endian (小端序)** 传输（与 x86 PC 保持一致，方便上位机处理）。

### 2.1 帧结构 (Frame Structure)

| 字节偏移 | 字段名 | 长度 (Byte) | 描述 |
| :--- | :--- | :--- | :--- |
| 0 | **HEAD_0** | 1 | 固定帧头 `0xAA` |
| 1 | **HEAD_1** | 1 | 固定帧头 `0x55` |
| 2 | **CMD** | 1 | 命令字 (见 2.2) |
| 3 | **LEN_L** | 1 | 载荷长度低 8 位 |
| 4 | **LEN_H** | 1 | 载荷长度高 8 位 |
| 5...N | **PAYLOAD** | LEN | 数据载荷 (参数或矩阵数据) |
| N+1 | **CHECKSUM** | 1 | 校验和 (CMD + LEN + PAYLOAD 的累加和取反) |

### 2.2 命令字定义 (Command Definitions)

#### PC -> FPGA (请求)

| CMD ID | 助记符 | 载荷 (Payload) 格式 | 功能描述 |
| :--- | :--- | :--- | :--- |
| `0x01` | `CMD_WRITE_MATRIX` | `[ID(1)][Rows(1)][Cols(1)][Name(8)][Data(N*4)]` | 向 FPGA 写入一个矩阵 |
| `0x02` | `CMD_READ_MATRIX` | `[ID(1)]` | 请求从 FPGA 读取一个矩阵 |
| `0x10` | `CMD_CALC_ADD` | `[SrcA_ID(1)][SrcB_ID(1)]` | 执行矩阵加法 (A + B -> Res) |
| `0x11` | `CMD_CALC_MUL` | `[SrcA_ID(1)][SrcB_ID(1)]` | 执行矩阵乘法 (A * B -> Res) |
| `0x12` | `CMD_CALC_SCALAR` | `[Src_ID(1)][Scalar_Val(4)]` | 执行标量乘法 (A * k -> Res) |
| `0x13` | `CMD_CALC_TRANS` | `[Src_ID(1)]` | 执行矩阵转置 (A' -> Res) |
| `0xF0` | `CMD_PING` | 无 | 测试连接 |

#### FPGA -> PC (响应)

| CMD ID | 助记符 | 载荷 (Payload) 格式 | 功能描述 |
| :--- | :--- | :--- | :--- |
| `0x80` | `RSP_OK` | 无 | 操作成功完成 |
| `0x81` | `RSP_ERROR` | `[ErrCode(1)]` | 操作失败 (1:校验错, 2:忙, 3:ID无效...) |
| `0x82` | `RSP_MATRIX_DATA` | `[ID(1)][Rows(1)][Cols(1)][Data(N*4)]` | 返回矩阵数据 (响应 CMD_READ_MATRIX) |
| `0x8F` | `RSP_PONG` | 无 | 响应 Ping |

## 3. 模块详细设计

### 3.1 UART Packet Handler (协议处理层)

- **功能**:
  - **RX**: 状态机检测 `0xAA 0x55` 帧头，读取长度，接收载荷到 FIFO，校验 Checksum。校验通过后触发 `packet_valid` 信号。
  - **TX**: 接收来自上层的发送请求，自动添加帧头、计算校验和并发送。
- **接口**:
  - `rx_payload_fifo`: 输出接收到的有效载荷。
  - `tx_payload_fifo`: 输入需要发送的载荷。

### 3.2 Command Dispatcher (业务逻辑层)

- **功能**: 解析 `CMD` 字段，控制状态机跳转。
- **状态机**:
  - `IDLE`: 等待新指令。
  - `WRITING_MATRIX`: 将 RX FIFO 中的数据流导向 **Matrix Writer Adapter**。
  - `READING_MATRIX`: 启动 **Matrix Reader Adapter**，将读取的数据填入 TX FIFO。
  - `COMPUTING`: 触发计算模块，等待 `busy` 信号变低，然后发送 `RSP_OK`。

### 3.3 Matrix Writer Adapter (写入适配器)

- **目的**: 桥接 UART (8-bit 流) 和 `matrix_storage_manager` (32-bit 接口)。
- **逻辑**:
    1. 从 Payload 前几个字节提取 `ID`, `Rows`, `Cols`, `Name`。
    2. 设置 `matrix_storage_manager` 的元数据端口。
    3. 拉高 `write_request`。
    4. 每接收 4 个字节 (UART)，拼接成 1 个 32-bit 字，在 `writer_ready` 有效时传给 `data_in`。

### 3.4 Matrix Reader Adapter (读取适配器)

- **目的**: 桥接 BRAM 读取接口和 UART 发送。
- **逻辑**:
    1. 根据请求的 ID，先读取元数据 (Rows, Cols)。
    2. 计算总数据量，组装 `RSP_MATRIX_DATA` 的帧头。
    3. 遍历 BRAM 地址，读取 32-bit 数据，拆分成 4 个字节写入 UART TX FIFO。

## 4. 开发路线图

1. **Step 1: 基础回环测试**
    - 实现 `Packet Handler`。
    - 实现 `CMD_PING` -> `RSP_PONG`。
    - 验证通信链路稳定性。

2. **Step 2: 矩阵写入功能**
    - 实现 `Matrix Writer Adapter`。
    - 支持 `CMD_WRITE_MATRIX`。
    - 通过 LED 或仿真验证数据是否正确写入 BRAM。

3. **Step 3: 矩阵读取功能**
    - 实现 `Matrix Reader Adapter`。
    - 支持 `CMD_READ_MATRIX`。
    - PC 写入后立即读取，验证数据一致性。

4. **Step 4: 计算控制**
    - 集成 `matrix_op_*` 模块。
    - 实现 `CMD_CALC_*` 指令。
    - 完成全系统联调。