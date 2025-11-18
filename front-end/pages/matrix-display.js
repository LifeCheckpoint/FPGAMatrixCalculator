/**
 * 矩阵展示页面脚本
 * 处理矩阵选择和显示逻辑
 */

// 获取DOM元素
let matrixSelect, displayArea, emptyState;
let matrixNameElement, matrixDimensionElement, matrixDisplayElement;

// 占位符数据 - 模拟不同的矩阵数据
const placeholderMatrices = {
    'ans': {
        name: 'ANS_Result',
        rows: 3,
        cols: 3,
        data: [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9]
        ]
    },
    '1': {
        name: 'Matrix_A',
        rows: 4,
        cols: 4,
        data: [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    },
    '2': {
        name: 'Matrix_B',
        rows: 3,
        cols: 4,
        data: [
            [2, 4, 6, 8],
            [1, 3, 5, 7],
            [9, 11, 13, 15]
        ]
    },
    '3': {
        name: 'Matrix_C',
        rows: 2,
        cols: 3,
        data: [
            [10, 20, 30],
            [40, 50, 60]
        ]
    },
    '4': {
        name: 'Matrix_D',
        rows: 5,
        cols: 2,
        data: [
            [1, 2],
            [3, 4],
            [5, 6],
            [7, 8],
            [9, 10]
        ]
    },
    '5': {
        name: 'Matrix_E',
        rows: 3,
        cols: 3,
        data: [
            [-5, 10, -15],
            [20, -25, 30],
            [-35, 40, -45]
        ]
    },
    '6': {
        name: 'Matrix_F',
        rows: 2,
        cols: 2,
        data: [
            [100, 200],
            [300, 400]
        ]
    },
    '7': {
        name: 'Matrix_G',
        rows: 6,
        cols: 3,
        data: [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
            [10, 11, 12],
            [13, 14, 15],
            [16, 17, 18]
        ]
    }
};

/**
 * 将矩阵数据转换为 LaTeX 格式
 * @param {Array<Array<number>>} matrix - 矩阵数据
 * @returns {string} LaTeX 格式的矩阵字符串
 */
function matrixToLatex(matrix) {
    if (!matrix || matrix.length === 0) {
        return '';
    }
    
    // 构建 LaTeX 矩阵字符串
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
 * 显示矩阵数据
 * @param {string} matrixId - 矩阵ID（ans 或 1-7）
 */
function displayMatrix(matrixId) {
    const matrixData = placeholderMatrices[matrixId];
    
    if (!matrixData) {
        // 如果没有数据，显示空状态
        showEmptyState();
        return;
    }
    
    // 更新矩阵信息
    matrixNameElement.textContent = matrixData.name;
    matrixDimensionElement.textContent = `${matrixData.rows} × ${matrixData.cols}`;
    
    // 生成 LaTeX 并渲染
    const latex = matrixToLatex(matrixData.data);
    
    try {
        katex.render(latex, matrixDisplayElement, {
            displayMode: true,
            throwOnError: false
        });
    } catch (error) {
        console.error('KaTeX 渲染错误:', error);
        matrixDisplayElement.textContent = '矩阵渲染失败';
    }
    
    // 显示显示区域，隐藏空状态
    displayArea.classList.remove('hidden');
    emptyState.classList.add('hidden');
}

/**
 * 显示空状态
 */
function showEmptyState() {
    displayArea.classList.add('hidden');
    emptyState.classList.remove('hidden');
}

/**
 * 处理选择框变化事件
 */
function handleSelectionChange() {
    const selectedValue = matrixSelect.value;
    
    if (selectedValue === '') {
        // 未选择，显示空状态
        showEmptyState();
    } else {
        // 显示选中的矩阵
        displayMatrix(selectedValue);
    }
}

/**
 * 页面初始化
 */
document.addEventListener('DOMContentLoaded', () => {
    // 获取所有DOM元素
    matrixSelect = document.getElementById('matrix-select');
    displayArea = document.getElementById('display-area');
    emptyState = document.getElementById('empty-state');
    matrixNameElement = document.getElementById('matrix-name');
    matrixDimensionElement = document.getElementById('matrix-dimension');
    matrixDisplayElement = document.getElementById('matrix-display');
    
    // 监听选择框变化
    matrixSelect.addEventListener('change', handleSelectionChange);
    
    // 初始显示空状态
    showEmptyState();
});