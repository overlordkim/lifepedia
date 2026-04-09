import type { AppNotification } from '../types'

const STORAGE_KEY = 'app_notifications_v2'

export function loadNotifications(): AppNotification[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch { return [] }
}

function save(notifications: AppNotification[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(notifications))
}

export function addNotification(n: AppNotification): AppNotification[] {
  const list = [n, ...loadNotifications()]
  save(list)
  return list
}

export function markAsRead(id: string): AppNotification[] {
  const list = loadNotifications().map(n => n.id === id ? { ...n, is_read: true } : n)
  save(list)
  return list
}

export function markAllRead(): AppNotification[] {
  const list = loadNotifications().map(n => ({ ...n, is_read: true }))
  save(list)
  return list
}

export function clearNotifications(): AppNotification[] {
  save([])
  return []
}

export function unreadCount(): number {
  return loadNotifications().filter(n => !n.is_read).length
}
