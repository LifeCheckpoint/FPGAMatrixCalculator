/**
 * 矩阵生成页面脚本
 * 处理随机矩阵生成的所有交互逻辑
 */

// 获取DOM元素
let rowsInput, colsInput, minValueInput, maxValueInput, generateBtn;

// 矩阵复选框数组
const matrixCheckboxes = [];

/**
 * 验证维度值
 * @param {number} value - 要验证的维度值
 * @returns {number} 调整后的维度值（1-32范围内）
 */
function validateDimension(value) {
    let num = parseInt(value);
    if (isNaN(num) || num < 1) {
        return 1;
    }
    if (num > 32) {
        return 32;
    }
    return num;
}

/**
 * 验证数值范围
 * @param {number} value - 要验证的数值
 * @returns {number} 调整后的数值（-65536~65535范围内）
 */
function validateRangeValue(value) {
    let num = parseInt(value);
    if (isNaN(num)) {
        return 0;
    }
    if (num < -65536) {
        return -65536;
    }
    if (num > 65535) {
        return 65535;
    }
    return num;
}

/**
 * 获取选中的矩阵ID列表
 * @returns {Array<number>} 选中的矩阵ID数组
 */
function getSelectedMatrices() {
    const selected = [];
    matrixCheckboxes.forEach(checkbox => {
        if (checkbox.checked) {
            selected.push(parseInt(checkbox.value));
        }
    });
    return selected;
}

/**
 * 生成随机整数
 * @param {number} min - 最小值
 * @param {number} max - 最大值
 * @returns {number} 随机整数
 */
function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * 生成随机矩阵
 * @param {number} rows - 行数
 * @param {number} cols - 列数
 * @param {number} min - 最小值
 * @param {number} max - 最大值
 * @returns {Array<Array<number>>} 随机矩阵
 */
function generateRandomMatrix(rows, cols, min, max) {
    const matrix = [];
    for (let i = 0; i < rows; i++) {
        const row = [];
        for (let j = 0; j < cols; j++) {
            row.push(randomInt(min, max));
        }
        matrix.push(row);
    }
    return matrix;
}

/**
 * 处理生成按钮点击事件
 */
function handleGenerate() {
    // 获取选中的矩阵
    const selectedMatrices = getSelectedMatrices();
    if (selectedMatrices.length === 0) {
        alert('请至少选择一个矩阵');
        return;
    }

    // 获取并验证维度
    const rows = validateDimension(rowsInput.value);
    const cols = validateDimension(colsInput.value);
    rowsInput.value = rows;
    colsInput.value = cols;

    // 获取并验证数值范围
    const minValue = validateRangeValue(minValueInput.value);
    const maxValue = validateRangeValue(maxValueInput.value);
    minValueInput.value = minValue;
    maxValueInput.value = maxValue;

    // 验证最小值不能大于最大值
    if (minValue > maxValue) {
        alert('最小值不能大于最大值');
        minValueInput.focus();
        return;
    }

    // 为每个选中的矩阵生成随机数据
    const results = [];
    selectedMatrices.forEach(matrixId => {
        const matrixData = generateRandomMatrix(rows, cols, minValue, maxValue);
        results.push({
            id: matrixId,
            name: `Matrix_${String.fromCharCode(64 + matrixId)}`, // A=1, B=2, ...
            rows: rows,
            cols: cols,
            data: matrixData
        });
    });

    console.log('生成的矩阵数据:', results);
    
    // 发送数据到后端
    const timeoutId = setTimeout(() => {
        alert('后端响应超时（2秒无响应）');
    }, 2000);
    
    fetch('http://127.0.0.1:11459/api/matrix/generate', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(results)
    })
    .then(response => response.json())
    .then(data => {
        clearTimeout(timeoutId);
        if (data.success) {
            const matrixNames = results.map(r => `矩阵${r.id}`).join('、');
            alert(`成功生成 ${matrixNames} (${rows}×${cols})\n数值范围: ${minValue} ~ ${maxValue}`);
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

/**
 * 页面初始化
 */
document.addEventListener('DOMContentLoaded', () => {
    // 获取所有输入元素
    rowsInput = document.getElementById('rows-input');
    colsInput = document.getElementById('cols-input');
    minValueInput = document.getElementById('min-value');
    maxValueInput = document.getElementById('max-value');
    generateBtn = document.getElementById('generate-btn');

    // 获取所有矩阵复选框
    for (let i = 1; i <= 7; i++) {
        const checkbox = document.getElementById(`matrix-${i}`);
        if (checkbox) {
            matrixCheckboxes.push(checkbox);
        }
    }

    // 维度输入框失焦时验证
    rowsInput.addEventListener('blur', () => {
        rowsInput.value = validateDimension(rowsInput.value);
    });

    colsInput.addEventListener('blur', () => {
        colsInput.value = validateDimension(colsInput.value);
    });

    // 数值范围输入框失焦时验证
    minValueInput.addEventListener('blur', () => {
        minValueInput.value = validateRangeValue(minValueInput.value);
    });

    maxValueInput.addEventListener('blur', () => {
        maxValueInput.value = validateRangeValue(maxValueInput.value);
    });

    // 生成按钮点击事件
    generateBtn.addEventListener('click', handleGenerate);
});