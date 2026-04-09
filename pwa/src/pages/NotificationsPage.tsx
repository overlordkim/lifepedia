import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, Check } from 'lucide-react'
import { loadNotifications, markAsRead, markAllRead } from '../services/notifications'
import { NOTIFICATION_ICONS, type AppNotification } from '../types'

export default function NotificationsPage() {
  const navigate = useNavigate()
  const [notifications, setNotifications] = useState<AppNotification[]>([])

  useEffect(() => {
    setNotifications(loadNotifications())
  }, [])

  function handleRead(id: string) {
    setNotifications(markAsRead(id))
  }

  function handleReadAll() {
    setNotifications(markAllRead())
  }

  function handleClick(n: AppNotification) {
    handleRead(n.id)
    if (n.related_entry_id) {
      navigate(`/entry/${n.related_entry_id}`)
    } else if (n.from_user_id) {
      navigate(`/user/${n.from_user_id}`, { state: { name: n.from_user_name } })
    }
  }

  const hasUnread = notifications.some(n => !n.is_read)

  return (
    <div className="flex flex-col h-screen bg-white">
      <div className="flex items-center gap-3 px-4 h-11 shrink-0 border-b border-wiki-divider">
        <button onClick={() => navigate(-1)}><ArrowLeft size={20} strokeWidth={1.5} /></button>
        <span className="font-semibold flex-1">通知</span>
        {hasUnread && (
          <button onClick={handleReadAll} className="flex items-center gap-1 text-wiki-small text-wiki-blue">
            <Check size={14} /> 全部已读
          </button>
        )}
      </div>

      <div className="flex-1 overflow-y-auto">
        {notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-wiki-tertiary gap-2">
            <p className="text-lg">暂无通知</p>
          </div>
        ) : (
          notifications.map(n => (
            <div
              key={n.id}
              onClick={() => handleClick(n)}
              className={`flex gap-3 px-4 py-3.5 border-b border-wiki-divider cursor-pointer hover:bg-wiki-bg-secondary ${
                !n.is_read ? 'bg-wiki-blue/[0.03]' : ''
              }`}
            >
              <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                !n.is_read ? 'bg-wiki-blue/10 text-wiki-blue' : 'bg-wiki-bg-secondary text-wiki-tertiary'
              }`}>
                <NotificationIcon type={n.type} />
              </div>
              <div className="flex-1 min-w-0">
                <p className={`text-sm ${!n.is_read ? 'font-semibold' : ''}`}>{n.title}</p>
                <p className="text-wiki-small text-wiki-secondary mt-0.5 line-clamp-2">{n.body}</p>
                <p className="text-[11px] text-wiki-tertiary mt-1">{timeAgo(n.created_at)}</p>
              </div>
              {!n.is_read && <div className="w-2 h-2 bg-wiki-blue rounded-full mt-2 shrink-0" />}
            </div>
          ))
        )}
      </div>
    </div>
  )
}

function NotificationIcon({ type }: { type: string }) {
  const iconMap: Record<string, string> = {
    comment: '💬', like: '❤️', follow: '👤', coEdit: '👥',
    aiUpdate: '✨', collabInvite: '✉️', collabRequest: '🤚',
  }
  return <span className="text-sm">{iconMap[type] || '🔔'}</span>
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return '刚刚'
  if (min < 60) return `${min} 分钟前`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr} 小时前`
  const day = Math.floor(hr / 24)
  if (day < 30) return `${day} 天前`
  return new Date(dateStr).toLocaleDateString('zh-CN')
}
