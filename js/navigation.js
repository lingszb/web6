/**
 * 安全页面导航工具
 * 处理页面跳转时可能的异步操作中断问题
 */
document.addEventListener('DOMContentLoaded', function() {
    // 对所有连接添加点击事件处理
    const links = document.querySelectorAll('a');
    
    links.forEach(link => {
        // 忽略外部链接和空链接
        if (!link.href || link.target === '_blank' || link.href.startsWith('javascript:')) {
            return;
        }
        
        link.addEventListener('click', function(event) {
            const href = this.getAttribute('href');
            
            // 检查是否有未完成的异步操作
            if (window.pendingAsyncOperations && window.pendingAsyncOperations > 0) {
                // 有未完成的操作，显示确认对话框
                if (!confirm('页面上有未完成的操作，确定要离开吗？')) {
                    event.preventDefault();
                    return;
                }
            }
            
            // 设置延迟，给任何后台操作时间完成
            if (href && !href.startsWith('#') && !href.startsWith('javascript:')) {
                event.preventDefault();
                
                // 显示加载指示器（如果有）
                const loadingIndicator = document.getElementById('loadingIndicator');
                if (loadingIndicator) {
                    loadingIndicator.style.display = 'block';
                }
                
                // 短暂延迟后进行跳转，给异步操作时间完成
                setTimeout(() => {
                    window.location.href = href;
                }, 100);
            }
        });
    });
});

// 跟踪异步操作的工具
window.pendingAsyncOperations = 0;

/**
 * 增加待处理的异步操作计数
 */
function incrementPendingOperations() {
    window.pendingAsyncOperations++;
}

/**
 * 减少待处理的异步操作计数
 */
function decrementPendingOperations() {
    window.pendingAsyncOperations--;
    if (window.pendingAsyncOperations < 0) {
        window.pendingAsyncOperations = 0;
    }
}
