import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

// 新版 Service Worker 激活后强制刷新页面，确保用户始终拿到最新代码
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    window.location.reload()
  })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
