const { contextBridge } = require('electron')

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld('electronAPI', {
  // 可以在这里添加主进程和渲染进程之间的通信方法
})