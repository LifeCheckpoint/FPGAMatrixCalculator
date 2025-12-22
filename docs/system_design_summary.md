# FPGA 矩阵计算器系统设计总文档 (详尽版)

## 1. 系统概述
本项目是一个基于 FPGA 的高性能矩阵计算器，支持矩阵的输入、随机生成、存储、展示以及多种数学运算（加法、乘法、转置、标量乘法、卷积）。系统采用模块化设计，通过 UART 串口与上位机交互，并利用板载拨码开关、按键、LED 和数码管进行本地控制与状态反馈。

---

## 2. 顶层架构与全局控制流
系统的顶层模块为 [`top_module.sv`](modules/main_module/src/top_module.sv)，它作为整个系统的“神经中枢”，负责全局资源的调度与仲裁。

### 2.1 模式切换逻辑
系统通过拨码开关 `sw[7:3]` 决定当前激活的子系统。
*   **`switches2op.sv`**: 这是一个组合逻辑模块，根据拨码开关的优先级（Input > Gen > Show > Calc > Settings）输出 `op_mode_raw`。
*   **`op_mode_controller.sv`**: 
    *   **控制流**: 包含一个稳定性计数器（`STABILITY_THRESHOLD`），只有当拨码开关状态保持稳定 100ms 后，才会更新输出模式。
    *   **功能**: 将 `sw[2:0]` 映射为具体的运算类型（如 `CALC_ADD`, `CALC_MUL` 等）。

### 2.2 资源仲裁机制
*   **UART TX 仲裁**: 采用优先级选择逻辑。
    1.  **最高优先级**: 手动清空响应（发送 "AC"）。
    2.  **次高优先级**: 调试信息 Dump。
    3.  **计算模式**: `compute_subsystem` 的交互提示与结果。
    4.  **展示模式**: `matrix_reader_all` 的矩阵数据。
    5.  **最低优先级**: 输入/生成模式下的 UART 回显（Echo）。
*   **BRAM 访问仲裁**: 在 [`matrix_storage_manager.sv`](modules/matrix_bram_manager/src/matrix_storage_manager.sv) 中实现。
    *   **写操作**: `matrix_clearer` (清空) 优先级高于 `matrix_writer` (写入)。
    *   **读操作**: 当无写请求时，根据当前模式切换读地址源（`compute_subsystem`, `matrix_reader_all` 或 `input_subsystem`）。

---

## 3. 输入子系统 (`input_subsystem`)
负责处理所有进入系统的数据流，位于 [`modules/main_module/src/input_subsystem.sv`](modules/main_module/src/input_subsystem.sv)。

### 3.1 数据解析流水线 (`ascii_num_sep_top.sv`)
该模块将 UART 接收到的 ASCII 字符流转换为 32 位整数，其内部控制流如下：
1.  **`ascii_validator.sv`**: 状态机从 `IDLE` 开始，接收 `pkt_payload_valid`，将字符存入 `char_buffer`，直到检测到 `pkt_payload_last`（换行符），进入 `DONE` 状态。
2.  **`char_stream_parser.sv`**: 遍历 `char_buffer`，识别数字字符并提取边界，通过 `num_start` 和 `num_end` 信号驱动转换器。
3.  **`ascii_to_int32.sv`**: 采用累加逻辑（`result = result * 10 + digit`），支持负数处理。
4.  **`data_write_controller.sv`**: 接收转换后的 `result_valid`，生成 RAM 写入地址，并在解析完成后发出 `all_done`。

### 3.2 任务处理器控制流
*   **`matrix_input_handler.sv`**: 
    *   **状态机**: `IDLE` -> `WAIT_DIMS` (等待行列数) -> `WAIT_DATA` (等待元素) -> `WRITE_BACK` (写入 BRAM)。
    *   **逻辑**: 自动补 0 或截断多余输入，确保矩阵形状符合预期。
*   **`matrix_rand_gen_handler.sv`**: 
    *   **状态机**: `IDLE` -> `GEN_DATA` (利用内部伪随机数发生器生成数据) -> `WRITE_BACK`。
*   **看门狗监控**: [`input_subsystem.sv`](modules/main_module/src/input_subsystem.sv) 包含一个 25MHz 下的 1 秒定时器。如果子系统处于 `busy` 状态超过 1 秒，将触发 `force_reset_pulse` 强制复位子模块并清除缓冲区。

---

## 4. 计算子系统 (`compute_subsystem`)
负责执行核心数学运算，位于 [`modules/main_module/src/compute_subsystem.sv`](modules/main_module/src/compute_subsystem.sv)。

### 4.1 运算选择器 (`matrix_op_selector.sv`)
这是系统中最复杂的交互状态机，包含 20 多个状态：
*   **参数获取**: `GET_DIMS` 状态下通过 UART 提示用户输入目标维度。
*   **矩阵扫描**: 调用 `matrix_scanner.sv` 遍历 BRAM 中的 8 个槽位，比对 Metadata 中的行列数，生成 `valid_mask`。
*   **用户交互**: 在 `SELECT_A` 和 `SELECT_B` 状态下，展示匹配的矩阵列表，并等待用户通过 UART 输入 ID。
*   **倒计时逻辑**: 如果用户输入非法或维度不匹配，进入 `ERROR_WAIT` 状态，数码管显示倒计时，超时则返回 `IDLE`。

### 4.2 运算执行器 (`matrix_op_executor.sv`)
*   **控制流**: 
    1.  **`STATE_IDLE`**: 等待选择器发出 `start`。
    2.  **`STATE_PREPARE_SCALAR`**: 如果是标量乘法，先启动一个微型状态机将 `scalar_in` 写入 BRAM 的临时槽位（ID 7）。
    3.  **`STATE_EXECUTE_START`**: 根据 `op_type` 发出对应算子的 `start` 脉冲。
    4.  **`STATE_EXECUTE_WAIT`**: 轮询算子的 `status` 信号，直到其脱离 `BUSY` 状态。
*   **算子实现细节**:
    *   **`matrix_op_add.sv`**: 简单的双指针读取（A 和 B 的数据地址），求和后通过 `matrix_writer` 写入结果。
    *   **`matrix_op_mul.sv`**: 采用三层嵌套循环（`row_idx`, `col_idx`, `k_idx`）。在 `STATE_MAC` 状态下进行乘累加运算，每完成一个内层循环（`k_idx` 达到上限），将结果送入写入队列。

---

## 5. 存储管理系统 (`matrix_storage_manager`)
统一管理矩阵存储，位于 [`modules/matrix_bram_manager/src/matrix_storage_manager.sv`](modules/matrix_bram_manager/src/matrix_storage_manager.sv)。

### 5.1 存储协议
每个矩阵占用一个固定大小的 Block（默认 1152 个字）。
*   **Word 0**: `[31:24]` 行数, `[23:16]` 列数, `[15:0]` 预留。
*   **Word 1-2**: 存储 8 字节的 ASCII 名称。
*   **Word 3+**: 按行优先顺序存储矩阵元素。

### 5.2 写入控制流 (`matrix_writer.sv`)
1.  **`WRITE_META_ROWS_COLS`**: 写入行列信息。
2.  **`WRITE_META_NAME`**: 分两步写入 8 字节名称。
3.  **`WRITE_DATA`**: 这是一个流式写入状态。它会拉高 `writer_ready`，等待上游模块提供 `data_valid` 和 `data_in`。每接收到一个有效数据，地址自动累加，直到达到 `total_elements`。

---

## 6. 高性能卷积实现 (Winograd)
针对卷积运算，系统集成了基于 Winograd 算法的加速器，位于 [`modules/winograd/src/winograd_conv_10x12.sv`](modules/winograd/src/winograd_conv_10x12.sv)。

### 6.1 算法控制流
1.  **`ST_LOAD`**: 将 10x12 的图像和 3x3 的卷积核载入内部寄存器。
2.  **分块处理**: 10x12 图像被划分为 9 个重叠的 6x6 分块（Tile）。
3.  **变换流水线**:
    *   **KTU**: 对卷积核进行 $GgG^T$ 变换。
    *   **TTU**: 对每个 Tile 进行 $B^TdB$ 变换。
    *   **点乘**: 在 6x6 域进行逐元素乘法。
    *   **RTU**: 对结果进行 $A^TMA$ 逆变换，得到 4x4 的输出块。
4.  **`ST_DIVIDE`**: Winograd 变换过程中会引入缩放因子，最后通过 `division_576_8x10.sv` 进行统一移位/除法校准。

---

## 7. 展示子系统 (`matrix_reader_all`)
位于 [`modules/matrix_reader_all/src/matrix_reader_all.sv`](modules/matrix_reader_all/src/matrix_reader_all.sv)。
*   **控制流**: 
    1.  从 ID 0 开始，读取 BRAM 的 Word 0。
    2.  如果行列数均大于 0，则认为该槽位有效，启动 `matrix_reader.sv`。
    3.  `matrix_reader` 内部通过 `int32_to_ascii.sv` 将每个元素转换为字符串，并处理空格和换行。
    4.  完成一个矩阵后，发送两个换行符作为分隔，然后进入下一个 ID。

---

## 8. 信号握手协议总结
系统中广泛采用了以下握手信号：
*   **`start`**: 启动脉冲，通常由按键或上游状态机触发。
*   **`busy`**: 电平信号，表示模块正在处理中，此时应忽略新的 `start`。
*   **`write_request` / `write_ready`**: 写入请求握手。上游发出请求，存储管理器在准备好接收元数据时拉高 `ready`。
*   **`data_valid` / `writer_ready`**: 数据流握手。存储管理器在准备好接收下一个元素时拉高 `writer_ready`，上游在数据稳定时拉高 `data_valid`。
*   **`done`**: 完成脉冲，标志着整个任务（包括数据落盘）结束。

---

## 9. 硬件接口与约束 (EGO1 开发板)
系统针对 EGO1 开发板（Xilinx Artix-7）进行了优化：
*   **时钟**: 物理输入 100MHz (P17)，内部逻辑运行在 25MHz。
*   **复位**: 低电平有效复位 (`rst_n`)，连接至 S6 按键。
*   **UART**: 波特率 115200，引脚 N5 (RX) 和 T4 (TX)。
*   **时序约束**: 在 [`constraints/timing.xdc`](constraints/timing.xdc) 中定义了 25MHz 的主时钟约束，确保在复杂的矩阵乘法和 Winograd 变换逻辑中满足建立时间要求。

---

## 10. 仿真与验证
项目包含完善的仿真环境，位于各模块的 `sim/` 目录下：
*   **单元测试**: 如 `matrix_op_add_tb.sv` 验证基础算子的正确性。
*   **子系统测试**: `input_subsystem_tb.sv` 模拟 UART 连续输入多个矩阵的场景。
*   **综合测试**: `top_module_tb.sv` 模拟从拨码开关切换到 UART 交互的完整业务流程。
*   **性能验证**: 通过 `winograd_conv_10x12_sim.sv` 统计卷积运算的实际时钟周期，并与理论值进行对比。
