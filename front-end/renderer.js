// 页面跳转逻辑
document.addEventListener('DOMContentLoaded', () => {
    // 获取所有的卡片元素
    const cards = document.querySelectorAll('.card');
    
    // 为每个卡片添加点击事件监听器
    cards.forEach(card => {
        card.addEventListener('click', () => {
            const pageName = card.getAttribute('data-page');
            if (pageName) {
                // 跳转到对应的页面
                window.location.href = `pages/${pageName}.html`;
            }
        });
        
        // 添加键盘访问支持
        card.setAttribute('tabindex', '0');
        card.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                const pageName = card.getAttribute('data-page');
                if (pageName) {
                    window.location.href = `pages/${pageName}.html`;
                }
            }
        });
    });
    
    // 添加悬停效果音效反馈（可选）
    cards.forEach(card => {
        card.addEventListener('mouseenter', () => {
            // 可以在这里添加音效或其他反馈
            card.style.cursor = 'pointer';
        });
    });
});