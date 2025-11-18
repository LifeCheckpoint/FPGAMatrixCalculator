/**
 * 矩阵运算页面脚本
 * 处理运算选择和执行逻辑
 */

// 当前选中的运算类型
let currentOperation = null;

// DOM 元素
let operationButtons = [];
let inputArea, resultArea;
let inputSections = {};
let submitBtn;

// 结果显示元素
let matrixResult, convResult, ansDisplay, convOutputGrid;

/**
 * 初始化 KaTeX 公式渲染
 */
function initializeFormulas() {
    const formulas = {
        'formula-transpose': 'A^{\\mathrm{T}}',
        'formula-add': 'A+B',
        'formula-scalar': '\\lambda A',
        'formula-multiply': 'A \\times B',
        'formula-conv': '\\text{Image}*\\text{ker}'
    };

    for (const [id, formula] of Object.entries(formulas)) {
        const element = document.getElementById(id);
        if (element) {
            try {
                katex.render(formula, element, {
                    displayMode: false,
                    throwOnError: false
                });
            } catch (error) {
                console.error(`渲染公式 ${id} 失败:`, error);
            }
        }
    }
}

/**
 * 初始化图像网格 (10×12)
 */
function initializeImageGrid() {
    const imageGrid = document.getElementById('image-grid');
    if (!imageGrid) return;

    // 从Verilog ROM模块提取的10×12图像数据
    const imageData = [
        [3, 7, 2, 9, 0, 5, 1, 8, 4, 6, 3, 2],
        [8, 1, 6, 4, 7, 3, 9, 0, 5, 2, 8, 1],
        [4, 9, 0, 2, 6, 8, 3, 5, 7, 1, 4, 9],
        [7, 3, 8, 5, 1, 4, 9, 2, 0, 6, 7, 3],
        [2, 6, 4, 0, 8, 7, 5, 3, 1, 9, 2, 4],
        [9, 0, 7, 3, 5, 2, 8, 6, 4, 1, 9, 0],
        [5, 8, 1, 6, 4, 9, 2, 7, 3, 0, 5, 8],
        [1, 4, 9, 2, 7, 0, 6, 8, 5, 3, 1, 4],
        [6, 2, 5, 8, 3, 1, 7, 4, 9, 0, 6, 2],
        [0, 7, 3, 9, 5, 6, 4, 1, 8, 2, 0, 7] 
    ];

    imageGrid.innerHTML = '';
    
    for (let i = 0; i < 10; i++) {
        for (let j = 0; j < 12; j++) {
            const cell = document.createElement('div');
            cell.className = 'image-cell';
            const value = imageData[i][j];
            cell.textContent = value;
            cell.setAttribute('data-value', value);
            imageGrid.appendChild(cell);
        }
    }
}

/**
 * 初始化卷积核网格 (3×3)
 */
function initializeKernelGrid() {
    const kernelGrid = document.getElementById('kernel-grid');
    if (!kernelGrid) return;

    kernelGrid.innerHTML = '';
    
    for (let i = 0; i < 9; i++) {
        const input = document.createElement('input');
        input.type = 'number';
        input.className = 'kernel-cell';
        input.placeholder = '0';
        input.value = '0';
        
        // 添加整数验证
        input.addEventListener('input', (e) => {
            const value = e.target.value;
            // 只允许整数和负号
            if (value && !/^-?\d*$/.test(value)) {
                e.target.value = value.replace(/[^\d-]/g, '');
            }
        });

        input.addEventListener('blur', (e) => {
            // 确保不是只有负号
            if (e.target.value === '-' || e.target.value === '') {
                e.target.value = '0';
            }
        });
        
        kernelGrid.appendChild(input);
    }
}

/**
 * 处理运算按钮点击
 */
function handleOperationClick(operation) {
    // 移除所有按钮的激活状态
    operationButtons.forEach(btn => btn.classList.remove('active'));
    
    // 激活当前按钮
    const clickedBtn = document.querySelector(`[data-operation="${operation}"]`);
    if (clickedBtn) {
        clickedBtn.classList.add('active');
    }
    
    // 设置当前运算
    currentOperation = operation;
    
    // 隐藏所有输入区段
    Object.values(inputSections).forEach(section => {
        section.classList.add('hidden');
    });
    
    // 显示对应的输入区段
    const inputSection = inputSections[operation];
    if (inputSection) {
        inputSection.classList.remove('hidden');
    }
    
    // 显示输入区域
    inputArea.classList.remove('hidden');
    
    // 隐藏结果区域
    resultArea.classList.add('hidden');
    matrixResult.classList.add('hidden');
    convResult.classList.add('hidden');
}

/**
 * 验证标量输入
 */
function validateScalarInput() {
    const scalarInput = document.getElementById('scalar-value');
    if (!scalarInput) return true;
    
    let value = parseInt(scalarInput.value);
    
    if (isNaN(value)) {
        value = 1;
    }
    
    // 限制范围 -65536 ~ 65535
    if (value < -65536) {
        value = -65536;
    } else if (value > 65535) {
        value = 65535;
    }
    
    scalarInput.value = value;
    return true;
}

/**
 * 收集卷积核数据
 */
function collectKernelData() {
    const kernelCells = document.querySelectorAll('.kernel-cell');
    const kernel = [];
    
    for (let i = 0; i < 9; i += 3) {
        const row = [];
        for (let j = 0; j < 3; j++) {
            const value = parseInt(kernelCells[i + j].value) || 0;
            row.push(value);
        }
        kernel.push(row);
    }
    
    return kernel;
}

/**
 * 生成占位符矩阵结果
 */
function generatePlaceholderMatrix(rows, cols) {
    const matrix = [];
    for (let i = 0; i < rows; i++) {
        const row = [];
        for (let j = 0; j < cols; j++) {
            row.push(Math.floor(Math.random() * 20) - 10);
        }
        matrix.push(row);
    }
    return matrix;
}

/**
 * 将矩阵转换为 LaTeX 格式
 */
function matrixToLatex(matrix) {
    if (!matrix || matrix.length === 0) {
        return '';
    }
    
    let latex = '\\begin{bmatrix}\n';
    
    for (let i = 0; i < matrix.length; i++) {
        const row = matrix[i];
        latex += row.join(' & ');
        if (i < matrix.length - 1) {
            latex += ' \\\\\n';
        } else {
            latex += '\n';
        }
    }
    
    latex += '\\end{bmatrix}';
    
    return latex;
}

/**
 * 显示矩阵结果
 */
function displayMatrixResult(matrix) {
    const latex = matrixToLatex(matrix);
    
    try {
        katex.render(latex, ansDisplay, {
            displayMode: true,
            throwOnError: false
        });
    } catch (error) {
        console.error('KaTeX 渲染错误:', error);
        ansDisplay.textContent = '矩阵渲染失败';
    }
    
    resultArea.classList.remove('hidden');
    matrixResult.classList.remove('hidden');
    convResult.classList.add('hidden');
}

/**
 * 显示卷积结果
 */
function displayConvResult() {
    convOutputGrid.innerHTML = '';
    
    // 生成 8×10 的占位符结果
    for (let i = 0; i < 8; i++) {
        for (let j = 0; j < 10; j++) {
            const cell = document.createElement('div');
            cell.className = 'conv-output-cell';
            cell.textContent = Math.floor(Math.random() * 100);
            convOutputGrid.appendChild(cell);
        }
    }
    
    resultArea.classList.remove('hidden');
    convResult.classList.remove('hidden');
    matrixResult.classList.add('hidden');
}

/**
 * 发送运算请求到后端
 */
function sendComputeRequest(payload) {
    const timeoutId = setTimeout(() => {
        alert('后端响应超时（2秒无响应）');
    }, 2000);
    
    fetch('http://127.0.0.1:11459/api/matrix/compute', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
    })
    .then(response => response.json())
    .then(data => {
        clearTimeout(timeoutId);
        if (data.success) {
            // 显示结果
            if (currentOperation === 'conv') {
                displayConvResult();
            } else {
                const result = generatePlaceholderMatrix(3, 3);
                displayMatrixResult(result);
            }
        } else {
            alert('运算失败: ' + (data.error || '未知错误'));
        }
    })
    .catch(error => {
        clearTimeout(timeoutId);
        alert('网络错误: ' + error.message);
    });
}

/**
 * 处理提交
 */
function handleSubmit() {
    if (!currentOperation) {
        alert('请先选择运算类型');
        return;
    }
    
    let payload = { operation: currentOperation };
    
    // 根据不同运算类型进行处理
    switch (currentOperation) {
        case 'transpose':
            const transposeMatrix = document.getElementById('transpose-matrix').value;
            if (!transposeMatrix) {
                alert('请选择要转置的矩阵');
                return;
            }
            payload.matrix_id = transposeMatrix;
            break;
            
        case 'add':
            const addMatrixA = document.getElementById('add-matrix-a').value;
            const addMatrixB = document.getElementById('add-matrix-b').value;
            if (!addMatrixA || !addMatrixB) {
                alert('请选择两个矩阵进行加法运算');
                return;
            }
            payload.matrix_a = addMatrixA;
            payload.matrix_b = addMatrixB;
            break;
            
        case 'scalar':
            validateScalarInput();
            const scalarValue = document.getElementById('scalar-value').value;
            const scalarMatrix = document.getElementById('scalar-matrix').value;
            if (!scalarMatrix) {
                alert('请选择要进行标量乘法的矩阵');
                return;
            }
            payload.scalar = parseInt(scalarValue);
            payload.matrix_id = scalarMatrix;
            break;
            
        case 'multiply':
            const multiplyMatrixA = document.getElementById('multiply-matrix-a').value;
            const multiplyMatrixB = document.getElementById('multiply-matrix-b').value;
            if (!multiplyMatrixA || !multiplyMatrixB) {
                alert('请选择两个矩阵进行乘法运算');
                return;
            }
            payload.matrix_a = multiplyMatrixA;
            payload.matrix_b = multiplyMatrixB;
            break;
            
        case 'conv':
            const kernelData = collectKernelData();
            payload.kernel = kernelData;
            break;
            
        default:
            alert('未知的运算类型');
            return;
    }
    
    sendComputeRequest(payload);
}

/**
 * 页面初始化
 */
document.addEventListener('DOMContentLoaded', () => {
    // 获取 DOM 元素
    operationButtons = document.querySelectorAll('.operation-btn');
    inputArea = document.getElementById('input-area');
    resultArea = document.getElementById('result-area');
    submitBtn = document.getElementById('submit-btn');
    
    // 获取输入区段
    inputSections = {
        transpose: document.getElementById('input-transpose'),
        add: document.getElementById('input-add'),
        scalar: document.getElementById('input-scalar'),
        multiply: document.getElementById('input-multiply'),
        conv: document.getElementById('input-conv')
    };
    
    // 获取结果显示元素
    matrixResult = document.getElementById('matrix-result');
    convResult = document.getElementById('conv-result');
    ansDisplay = document.getElementById('ans-display');
    convOutputGrid = document.getElementById('conv-output-grid');
    
    // 初始化 KaTeX 公式
    initializeFormulas();
    
    // 初始化卷积网格
    initializeImageGrid();
    initializeKernelGrid();
    
    // 绑定运算按钮事件
    operationButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const operation = btn.getAttribute('data-operation');
            handleOperationClick(operation);
        });
    });
    
    // 绑定提交按钮事件
    submitBtn.addEventListener('click', handleSubmit);
    
    // 标量输入框失焦时验证
    const scalarInput = document.getElementById('scalar-value');
    if (scalarInput) {
        scalarInput.addEventListener('blur', validateScalarInput);
    }
});