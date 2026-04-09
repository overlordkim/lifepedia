import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { clientsClaim } from 'workbox-core'

declare let self: ServiceWorkerGlobalScope

// 每次部署时 SW 文件内容都会变化（含新的 precache manifest），
// install 立即激活，不等旧 SW 的标签关闭
self.addEventListener('install', () => self.skipWaiting())

// activate 时：清除所有旧缓存 → 让 main.tsx 的 controllerchange 触发页面刷新
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(names => Promise.all(names.map(n => caches.delete(n))))
      .then(() => clientsClaim())
  )
})

cleanupOutdatedCaches()
precacheAndRoute(self.__WB_MANIFEST)
