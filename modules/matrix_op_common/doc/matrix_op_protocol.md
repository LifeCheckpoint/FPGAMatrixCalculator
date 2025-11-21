# 矩阵运算公共协议

## 1. 适用范围

本文档定义 `matrix_op_*` 系列（加法、乘法、标量乘、转置）与 `matrix_storage_manager` 之间的交互协议和状态码约定，统一矩阵读取 / 写回流程。

## 2. 总体约束

1. **矩阵编号**：  
   - `ID0` 固定作为结果写回位置。  
   - 运算输入仅允许来自 `ID1~ID7`。  
   - 一旦发现输入 ID 为 `0` 或大于 `7`，直接报错。

2. **数据格式**（引用 [matrix_writer.sv](modules/matrix_bram_manager/src/matrix_writer.sv:1) 约定）：
   - `base_addr = matrix_id * BLOCK_SIZE`。
   - `base_addr + 0`：`{rows[7:0], cols[7:0], 16'b0}`。
   - `base_addr + 1/2`：名称。
   - `base_addr + 3` 起为行优先矩阵元素。

3. **标志位**：统一使用 4 bit `matrix_op_status_e`（定义见 [matrix_op_defs_pkg.sv](modules/matrix_op_common/src/matrix_op_defs_pkg.sv:1)）：

   | 编码 | 说明 |
   | --- | --- |
   | `0` | 空闲（IDLE） |
   | `1` | 运算中（BUSY） |
   | `2` | 成功（SUCCESS） |
   | `3` | 维度非法（ERR_DIM） |
   | `4` | ID 非法（ERR_ID） |
   | `5` | 数据为空 / 元素个数 0（ERR_EMPTY） |
   | `6` | 写回失败（ERR_WRITER） |
   | `7` | 元数据格式错误（ERR_FORMAT） |
   | `8` | 内部异常（ERR_INTERNAL） |
   | `9~15` | 预留 |

4. **写回流程**：
   - 运算模块在 `write_ready=1` 时拉高 `write_request` 一个周期。
   - 结果固定写入 `matrix_id = 3'd0`，`matrix_name` 根据运算类型给出（如 `"ADDRES\0"`）。
   - 数据阶段仅在 `writer_ready=1` 时输出 `data_valid=1` 和 `data_in`。

5. **读流程**：
   - 运算模块独占 `read_addr` 总线期间不可被其他模块抢占。
   - 访问顺序：先读取元数据校验，再读取矩阵体数据。
   - 由于 BRAM 1 周期延迟，所有模块需实现“两阶段”采样（地址阶段 / 数据阶段）。

6. **标量乘法约束**：
   - 标量同样以矩阵形式存储，必须是 `1x1`。  
   - 结果仍写入 `ID0`，其名称为 `"SCLRES\0"`。

## 3. 各模块状态流

### 3.1 Matrix Add (`matrix_op_add`)

1. `start` 触发后设置 `status=BUSY`。
2. 依次读取 A/B 元数据，验证：
   - `rows_a == rows_b` 且 `cols_a == cols_b`。
   - 元素个数 `rows*cols` 在 `(0, BLOCK_SIZE-3]`。
3. 拉起写请求，发送结果元数据（与输入同维度）。
4. 采用 **A→B→计算** 两阶段遍历：
   - 先读指定元素的 A，再读 B，对齐数据后求和送 `data_in`。
5. 所有元素写完且 `write_done=1` 后置 `status=SUCCESS`。

异常路径：若任一条件不满足，直接置对应错误状态并停止写请求。

### 3.2 Matrix Multiply (`matrix_op_mul`)

1. 读取 A/B 元数据：
   - 条件：`cols_a == rows_b`。
   - 结果维度：`rows_a x cols_b`。
2. 在确认结果元素数合法后触发写流程。
3. State 机实现三层循环 `(i, j, k)`：  
   - 对每个 `(i, j)` 清零累加器。  
   - 连续读取 `A[i][k]` 与 `B[k][j]`，乘法结果累加。  
   - 内层循环结束后将结果写入。
4. 当 `write_done=1`，置 `status=SUCCESS`。

### 3.3 Matrix Scalar Multiply (`matrix_op_scalar_mul`)

1. `matrix_id_matrix` 指向被缩放矩阵，`matrix_id_scalar` 指向标量矩阵：
   - 标量矩阵必须 `1x1`。  
   - 结果维度等同矩阵本身。
2. 读取标量值后缓存，遍历矩阵元素：
   - 对每个元素 `value * scalar`，在 `writer_ready` 时送出。
3. 写完置 `status=SUCCESS`。

### 3.4 Matrix Transpose (`matrix_op_T`)

1. 读取输入矩阵元数据，结果维度 `cols x rows`。
2. 内层循环按输出顺序枚举 `(r_out, c_out)`，将其映射回源地址：
   - `src_index = c_out * rows_in + r_out`。
3. 逐个读取、写出。

## 4. 时序/周期参考

| 操作 | 周期估计（元素个数 N、共享单口 BRAM） |
| --- | --- |
| Add / Scalar | `~ 4N + 常数` |
| Transpose | `~ 3N + 常数` |
| Multiply | `~ (2 * cols_a + 1) * rows_a * cols_b + 常数` |
