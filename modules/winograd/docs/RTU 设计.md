# Winograd 逆变换单元 (`reverse_transform_unit.sv`)

规格如下：

1. 适用 $F(4\times4,3\times3)$ 的 Winograd 卷积算法
2. 输入输出均固定为 $4\times4$
3. 基于 KTU 与 TTU 的整数优化，输出结果会相对于最开始的结果放大 $6^2\times4^2=576$ 倍
4. 所有的运算都是 32 位宽，值域超出会截断
5. 流水线设计，共有 3 个状态，即 3 个时钟周期完成一次数据块预处理，transform_done 为高时表示当前数据块预处理完成，可以读取输出数据

## 行为级仿真

`reverse_transform_unit_sim.sv`，测试五种数据块输入，测试均通过

## 时序级仿真

计算通路与 TTU 类似，无需测试
