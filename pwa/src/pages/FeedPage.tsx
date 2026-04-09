import { useState, useEffect, useMemo, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, X, Bell, ChevronDown } from 'lucide-react'
import { fetchPublishedEntries } from '../services/entries'
import { unreadCount } from '../services/notifications'
import type { SupabaseEntry, EntryCategory } from '../types'
import CategoryFilterBar from '../components/feed/CategoryFilterBar'
import FeedCard from '../components/feed/FeedCard'
import Avatar from '../components/shared/Avatar'
import { useAuth } from '../contexts/AuthContext'
import { followUser, unfollowUser, loadFollowing } from '../services/follows'
import { avatarURL } from '../lib/supabase'

type SearchMode = 'all' | 'entries' | 'users'
const SEARCH_MODES: { key: SearchMode; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: 'entries', label: '词条' },
  { key: 'users', label: '用户' },
]

export default function FeedPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [entries, setEntries] = useState<SupabaseEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedCat, setSelectedCat] = useState<EntryCategory | null>(null)
  const [showSearch, setShowSearch] = useState(false)
  const [searchText, setSearchText] = useState('')
  const [searchMode, setSearchMode] = useState<SearchMode>('all')
  const [showModeMenu, setShowModeMenu] = useState(false)
  const [followingIds, setFollowingIds] = useState<Set<string>>(new Set())
  const [shuffleSeed] = useState(() => Math.random())

  useEffect(() => {
    fetchPublishedEntries().then(setEntries).catch(console.error).finally(() => setLoading(false))
    if (user) loadFollowing(user.id).then(ids => setFollowingIds(new Set(ids))).catch(() => {})
  }, [user])

  const filteredEntries = useMemo(() => {
    let list = entries
    if (selectedCat) list = list.filter(e => e.category === selectedCat)
    if (searchText.trim()) {
      const q = searchText.toLowerCase()
      list = list.filter(e =>
        e.title.toLowerCase().includes(q) ||
        (e.introduction || '').toLowerCase().includes(q) ||
        e.author_name.toLowerCase().includes(q)
      )
      list.sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime())
    } else {
      list = [...list].sort((a, b) => {
        const ha = Math.abs(hashCode(a.id + shuffleSeed))
        const hb = Math.abs(hashCode(b.id + shuffleSeed))
        return ha - hb
      })
    }
    return list
  }, [entries, selectedCat, searchText, shuffleSeed])

  const matchedUsers = useMemo(() => {
    if (!searchText.trim()) return []
    const q = searchText.toLowerCase()
    const seen = new Set<string>()
    const result: { name: string; id: string; count: number }[] = []
    for (const e of entries) {
      if (seen.has(e.author_id) || e.author_id === user?.id) continue
      if (e.author_name.toLowerCase().includes(q)) {
        seen.add(e.author_id)
        result.push({
          name: e.author_name,
          id: e.author_id,
          count: entries.filter(x => x.author_id === e.author_id).length,
        })
      }
    }
    return result
  }, [entries, searchText, user])

  const toggleFollow = useCallback(async (userId: string) => {
    if (!user) return
    const isFollowing = followingIds.has(userId)
    setFollowingIds(prev => {
      const next = new Set(prev)
      isFollowing ? next.delete(userId) : next.add(userId)
      return next
    })
    try {
      isFollowing ? await unfollowUser(user.id, userId) : await followUser(user.id, userId)
    } catch {
      setFollowingIds(prev => {
        const next = new Set(prev)
        isFollowing ? next.add(userId) : next.delete(userId)
        return next
      })
    }
  }, [user, followingIds])

  const badges = unreadCount()

  return (
    <div className="flex flex-col h-full bg-white">
      {/* 顶栏 */}
      <div className="flex items-center px-4 h-11 shrink-0">
        <h1 className="font-serif italic font-bold text-[28px] text-wiki-text">Lifepedia</h1>
        <div className="flex-1" />
        <div className="flex items-center gap-4">
          <button onClick={() => { setShowSearch(!showSearch); if (showSearch) setSearchText('') }}>
            {showSearch ? <X size={20} strokeWidth={1.5} /> : <Search size={20} strokeWidth={1.5} />}
          </button>
          <button onClick={() => navigate('/notifications')} className="relative">
            <Bell size={20} strokeWidth={1.5} />
            {badges > 0 && <span className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-red-500 rounded-full" />}
          </button>
        </div>
      </div>

      {/* 搜索栏 */}
      {showSearch && (
        <div className="flex items-center gap-2 px-4 pb-1">
          <div className="relative">
            <button
              onClick={() => setShowModeMenu(!showModeMenu)}
              className="flex items-center gap-0.5 px-2 py-1.5 bg-[#E8E8E8] rounded-md text-[13px] font-medium"
            >
              {SEARCH_MODES.find(m => m.key === searchMode)?.label}
              <ChevronDown size={9} className={`text-wiki-tertiary transition-transform ${showModeMenu ? 'rotate-180' : ''}`} />
            </button>
            {showModeMenu && (
              <div className="absolute top-full left-0 mt-1 w-24 bg-white rounded-lg shadow-lg z-50 overflow-hidden">
                {SEARCH_MODES.map(m => (
                  <button
                    key={m.key}
                    onClick={() => { setSearchMode(m.key); setShowModeMenu(false) }}
                    className="w-full text-left px-3 py-2 text-[13px] hover:bg-wiki-bg-secondary flex items-center justify-between"
                  >
                    <span className={searchMode === m.key ? 'text-wiki-blue' : ''}>{m.label}</span>
                    {searchMode === m.key && <span className="text-wiki-blue text-[10px] font-bold">✓</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="flex-1 flex items-center gap-2 px-2.5 py-2 bg-[#F0F0F0] rounded-lg">
            <Search size={14} className="text-wiki-tertiary shrink-0" />
            <input
              type="text"
              value={searchText}
              onChange={e => setSearchText(e.target.value)}
              placeholder={searchMode === 'users' ? '搜索用户名……' : searchMode === 'entries' ? '搜索词条标题、作者……' : '搜索词条、用户……'}
              className="flex-1 bg-transparent text-sm"
              autoFocus
            />
          </div>
        </div>
      )}

      <CategoryFilterBar selected={selectedCat} onSelect={setSelectedCat} />

      {/* 内容 */}
      <div className="flex-1 overflow-y-auto bg-[#F4F4F4] pb-20">
        <div className="px-2.5 pt-1.5 space-y-3">
          {/* 匹配用户 */}
          {searchMode !== 'entries' && matchedUsers.length > 0 && (
            <div className="space-y-2">
              {searchMode === 'all' && <p className="text-[13px] font-semibold text-wiki-secondary px-1.5">用户</p>}
              {matchedUsers.map(u => (
                <div
                  key={u.id}
                  onClick={() => navigate(`/user/${u.id}`, { state: { name: u.name } })}
                  className="flex items-center gap-3 px-3 py-2 bg-white rounded-lg cursor-pointer"
                >
                  <Avatar userId={u.id} name={u.name} size={40} />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{u.name}</p>
                    <p className="text-wiki-small text-wiki-tertiary">{u.count} 篇词条</p>
                  </div>
                  <button
                    onClick={e => { e.stopPropagation(); toggleFollow(u.id) }}
                    className={`text-wiki-small font-medium px-3 py-1 rounded-md ${
                      followingIds.has(u.id)
                        ? 'text-wiki-secondary bg-wiki-bg-secondary'
                        : 'text-white bg-wiki-blue'
                    }`}
                  >
                    {followingIds.has(u.id) ? '已关注' : '关注'}
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* 词条列表 */}
          {searchMode !== 'users' && (
            <>
              {searchMode === 'all' && filteredEntries.length > 0 && matchedUsers.length > 0 && (
                <p className="text-[13px] font-semibold text-wiki-secondary px-1.5">词条</p>
              )}
              {loading ? (
                <div className="flex justify-center py-16">
                  <span className="w-8 h-8 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" />
                </div>
              ) : filteredEntries.length === 0 ? (
                <p className="text-center text-wiki-tertiary py-16">暂无词条</p>
              ) : (
                filteredEntries.map(entry => (
                  <FeedCard key={entry.id} entry={entry} onClick={() => navigate(`/entry/${entry.id}`)} />
                ))
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function hashCode(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  return h
}
