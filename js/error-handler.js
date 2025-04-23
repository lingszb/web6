/**
 * 全局错误处理程序，用于捕获异步Promise错误
 */
window.addEventListener('unhandledrejection', function(event) {
    // 检查是否是消息通道关闭错误
    if (event.reason && event.reason.message && 
        event.reason.message.includes('message channel closed')) {
        
        console.warn('页面通信被中断，可能是由于页面跳转或刷新导致。这通常不是问题。');
        
        // 防止错误显示在控制台中
        event.preventDefault();
    }
});

/**
 * 安全发送异步请求的包装函数
 * @param {Function} asyncFunction - 返回Promise的异步函数
 * @param {Object} options - 配置选项
 * @returns {Promise} - 包装后的Promise
 */
function safeAsyncRequest(asyncFunction, options = {}) {
    const timeout = options.timeout || 5000; // 默认5秒超时
    
    // 创建一个可以取消的Promise
    let timeoutId;
    const timeoutPromise = new Promise((_, reject) => {
        timeoutId = setTimeout(() => {
            reject(new Error('请求超时'));
        }, timeout);
    });
    
    // 包装原始Promise，添加超时和错误处理
    return Promise.race([
        asyncFunction().catch(error => {
            // 检查是否是由于页面离开导致的错误
            if (error.message && error.message.includes('message channel closed')) {
                console.warn('页面通信被中断，这通常是由于页面跳转引起的，不是错误。');
                // 返回一个成功的结果，防止错误传播
                return { aborted: true };
            }
            throw error; // 重新抛出其他错误
        }),
        timeoutPromise
    ]).finally(() => {
        clearTimeout(timeoutId);
    });
}
