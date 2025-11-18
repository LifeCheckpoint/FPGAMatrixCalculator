// 矩阵输入页面脚本

// 获取DOM元素
const matrixIdSelect = document.getElementById('matrix-id');
const matrixNameInput = document.getElementById('matrix-name');
const autoNameBtn = document.getElementById('auto-name-btn');
const rowsInput = document.getElementById('matrix-rows');
const colsInput = document.getElementById('matrix-cols');
const matrixGrid = document.getElementById('matrix-grid');
const submitBtn = document.getElementById('submit-btn');

/**
 * 自动生成矩阵名称
 * 根据矩阵ID生成名称：Matrix_A, Matrix_B, ..., Matrix_G
 */
function generateAutoName() {
    const matrixId = parseInt(matrixIdSelect.value);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
    matrixNameInput.value = 'Matrix_' + letters[matrixId - 1];
}

/**
 * 验证和调整维度数值
 * 确保值在1-32范围内
 * @param {HTMLInputElement} input - 输入框元素
 * @returns {number} 调整后的值
 */
function validateDimension(input) {
    let value = parseInt(input.value);
    if (isNaN(value) || value < 1) {
        value = 1;
    } else if (value > 32) {
        value = 32;
    }
    input.value = value;
    return value;
}

/**
 * 生成矩阵输入网格
 * 根据行列数动态创建输入单元格
 */
function generateGrid() {
    const rows = validateDimension(rowsInput);
    const cols = validateDimension(colsInput);
    
    // 清空现有网格
    matrixGrid.innerHTML = '';
    
    // 设置网格布局
    matrixGrid.style.gridTemplateColumns = `repeat(${cols}, 60px)`;
    matrixGrid.style.gridTemplateRows = `repeat(${rows}, 40px)`;
    
    // 创建网格单元
    for (let i = 0; i < rows; i++) {
        for (let j = 0; j < cols; j++) {
            const cell = document.createElement('input');
            cell.type = 'text';
            cell.className = 'matrix-cell';
            cell.dataset.row = i;
            cell.dataset.col = j;
            cell.placeholder = '0';
            
            // 只允许输入整数（包括负数）
            cell.addEventListener('input', function(e) {
                // 移除非数字和负号的字符，允许负号在开头
                let value = this.value;
                
                // 如果第一个字符是负号，保留它
                let hasNegative = value.startsWith('-');
                
                // 移除所有非数字字符
                value = value.replace(/[^0-9]/g, '');
                
                // 如果原来有负号，加回去
                if (hasNegative) {
                    value = '-' + value;
                }
                
                this.value = value;
            });
            
            // 键盘导航
            cell.addEventListener('keydown', function(e) {
                const currentRow = parseInt(this.dataset.row);
                const currentCol = parseInt(this.dataset.col);
                
                if (e.key === 'Enter') {
                    e.preventDefault();
                    // 移动到下一行，同一列
                    const nextRow = currentRow + 1;
                    if (nextRow < rows) {
                        const nextCell = matrixGrid.querySelector(`[data-row="${nextRow}"][data-col="${currentCol}"]`);
                        if (nextCell) nextCell.focus();
                    }
                } else if (e.key === 'Tab' && !e.shiftKey) {
                    e.preventDefault();
                    // 移动到下一个单元格（从左到右，从上到下）
                    let nextRow = currentRow;
                    let nextCol = currentCol + 1;
                    
                    if (nextCol >= cols) {
                        nextCol = 0;
                        nextRow = currentRow + 1;
                    }
                    
                    if (nextRow < rows) {
                        const nextCell = matrixGrid.querySelector(`[data-row="${nextRow}"][data-col="${nextCol}"]`);
                        if (nextCell) nextCell.focus();
                    }
                } else if (e.key === 'Tab' && e.shiftKey) {
                    e.preventDefault();
                    // Shift+Tab：移动到上一个单元格
                    let prevRow = currentRow;
                    let prevCol = currentCol - 1;
                    
                    if (prevCol < 0) {
                        prevCol = cols - 1;
                        prevRow = currentRow - 1;
                    }
                    
                    if (prevRow >= 0) {
                        const prevCell = matrixGrid.querySelector(`[data-row="${prevRow}"][data-col="${prevCol}"]`);
                        if (prevCell) prevCell.focus();
                    }
                }
            });
            
            matrixGrid.appendChild(cell);
        }
    }
}

/**
 * 收集矩阵数据
 * @returns {Array<Array<number>>|null} 矩阵数据的二维数组，如果有无效输入则返回null
 */
function collectMatrixData() {
    const rows = parseInt(rowsInput.value);
    const cols = parseInt(colsInput.value);
    const matrixData = [];
    
    for (let i = 0; i < rows; i++) {
        const row = [];
        for (let j = 0; j < cols; j++) {
            const cell = matrixGrid.querySelector(`[data-row="${i}"][data-col="${j}"]`);
            const cellValue = cell.value.trim();
            
            // 检查是否只输入了负号
            if (cellValue === '-') {
                alert(`矩阵单元格 (${i + 1}, ${j + 1}) 只包含负号，请输入完整的数字`);
                cell.focus();
                return null;
            }
            
            // 空值或无效值默认为0
            const value = cellValue === '' || isNaN(parseInt(cellValue)) ? 0 : parseInt(cellValue);
            row.push(value);
        }
        matrixData.push(row);
    }
    
    return matrixData;
}

/**
 * 提交矩阵数据
 */
function handleSubmit() {
    const matrixId = matrixIdSelect.value;
    const matrixName = matrixNameInput.value.trim();
    const rows = parseInt(rowsInput.value);
    const cols = parseInt(colsInput.value);
    
    // 验证名称
    if (!matrixName) {
        alert('请输入矩阵名称或点击自动生成');
        return;
    }
    
    // 验证名称只包含ASCII字符
    if (!/^[\x00-\x7F]*$/.test(matrixName)) {
        alert('矩阵名称只能包含ASCII字符');
        return;
    }
    
    // 收集矩阵数据
    const matrixData = collectMatrixData();
    
    // 如果收集数据失败（有无效输入），则返回
    if (matrixData === null) {
        return;
    }
    
    // 构建要发送的数据
    const payload = {
        id: parseInt(matrixId),
        name: matrixName,
        rows: rows,
        cols: cols,
        data: matrixData
    };
    
    console.log('提交矩阵数据:', payload);
    
    // 发送数据到后端
    const timeoutId = setTimeout(() => {
        alert('后端响应超时（2秒无响应）');
    }, 2000);
    
    fetch('http://127.0.0.1:11459/api/matrix/input', {
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
            alert('矩阵数据提交成功！');
            document.body.style.opacity = '0';
            setTimeout(() => {
                window.location.href = '../index.html';
            }, 300);
        } else {
            alert('提交失败: ' + (data.error || '未知错误'));
        }
    })
    .catch(error => {
        clearTimeout(timeoutId);
        alert('网络错误: ' + error.message);
    });
}

// 事件监听器
autoNameBtn.addEventListener('click', generateAutoName);
rowsInput.addEventListener('change', generateGrid);
rowsInput.addEventListener('blur', generateGrid);
colsInput.addEventListener('change', generateGrid);
colsInput.addEventListener('blur', generateGrid);
submitBtn.addEventListener('click', handleSubmit);

// 当矩阵ID变化时，自动更新名称（如果当前名称是自动生成的格式）
matrixIdSelect.addEventListener('change', function() {
    const currentName = matrixNameInput.value;
    // 检查当前名称是否是自动生成的格式
    if (/^Matrix_[A-G]$/.test(currentName)) {
        generateAutoName();
    }
});

// 页面加载完成后的初始化
if (document.readyState === 'loading') {
    // 正在加载，等待 DOMContentLoaded
    document.addEventListener('DOMContentLoaded', function() {
        generateGrid();
        generateAutoName();
    });
} else {
    // DOM 已就绪，直接初始化
    generateGrid();
    generateAutoName();
}