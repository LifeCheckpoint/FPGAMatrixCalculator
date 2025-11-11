# FPGA Matrix Calculator

CS 207 Proj. **基于 FPGA 的矩阵计算器开发**

---

## 配置与运行

### VSCode (推荐)

1. 打开 `.vscode/settings.json`，根据 Vivado 安装路径修改 `vivado.installPath`，例如

    ```json
    {
        "vivado.installPath": "F:/Programs/VivadoSuite/2025.1/Vivado",
    }
    ```

2. 使用 `ctrl+shift+P` 打开命令，输入 `run task` 找到 `任务：运行任务`，进入后选择 `Run Vivado Tcl Script`，即可自动创建 Vivado 工程并打开 Vivado GUI

### 手动运行

```powershell
# Step 0: 设置工作目录变量
$workspaceFolder = "path/to/FPGAMatrixCalculator"  # 修改为工作空间根目录

# Step 1: 日志目录与切换
$logDir = Join-Path $workspaceFolder "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
Set-Location $logDir

# Step 2: 设置 Vivado 路径
# 如果 PATH 已包含 vivado，可跳过以下两行。否则取消注释并修改为实际路径。
$env:PATH = "$env:PATH;your/vivado/202x.x/bin"
$env:XILINX_VIVADO = "your/vivado/202x.x"

# Step 3: 运行 TCL 脚本
vivado -mode batch -source (Join-Path $workspaceFolder "scripts\create_project.tcl")
```

> 注意，每一次都会根据源代码生成新的 Vivado 项目

---

## 项目内容

Proj 要求见 [docs/ProjRequirements.md](https://github.com/LifeCheckpoint/FPGAMatrixCalculator/tree/main/docs/ProjRequirements.md)