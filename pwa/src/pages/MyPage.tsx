import { useState, useEffect, useMemo, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Settings, ChevronDown, ChevronRight, ChevronUp, FileText } from 'lucide-react'
import { fetchEntriesByAuthor, fetchEntriesByContributor, fetchPublishedEntries } from '../services/entries'
import { loadFollowing, loadFollowers, fetchUserProfiles, followUser, unfollowUser } from '../services/follows'
import { useAuth } from '../contexts/AuthContext'
import Avatar from '../components/shared/Avatar'
import FeedCard from '../components/feed/FeedCard'
import CategoryFilterBar from '../components/feed/CategoryFilterBar'
import type { SupabaseEntry, SimpleUser, EntryCategory } from '../types'
import { CATEGORY_META } from '../types'

type SubTab = 'authored' | 'coEditing' | 'favorited'

export default function MyPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [subTab, setSubTab] = useState<SubTab>('authored')
  const [selectedCategory, setSelectedCategory] = useState<EntryCategory | null>(null)
  const [entries, setEntries] = useState<SupabaseEntry[]>([])
  const [collabEntries, setCollabEntries] = useState<SupabaseEntry[]>([])
  const [favoritedEntries, setFavoritedEntries] = useState<SupabaseEntry[]>([])
  const [followingIds, setFollowingIds] = useState<string[]>([])
  const [followerIds, setFollowerIds] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [draftsExpanded, setDraftsExpanded] = useState(false)
  const [showFollowSheet, setShowFollowSheet] = useState<'following' | 'followers' | null>(null)
  const [followUsers, setFollowUsers] = useState<SimpleUser[]>([])
  const [myFollowingSet, setMyFollowingSet] = useState<Set<string>>(new Set())

  useEffect(() => {
    if (!user) return
    Promise.all([
      fetchEntriesByAuthor(user.id).then(setEntries),
      fetchEntriesByContributor(user.display_name).then(setCollabEntries),
      fetchPublishedEntries().then(all => setFavoritedEntries(all.filter(e => e.author_id !== user.id))),
      loadFollowing(user.id).then(ids => { setFollowingIds(ids); setMyFollowingSet(new Set(ids)) }),
      loadFollowers(user.id).then(setFollowerIds),
    ]).catch(console.error).finally(() => setLoading(false))
  }, [user])

  const drafts: SupabaseEntry[] = useMemo(() => {
    try { return JSON.parse(localStorage.getItem('drafts') || '[]') } catch { return [] }
  }, [])

  const publishedEntries = useMemo(() => {
    let list: SupabaseEntry[]
    if (subTab === 'authored') list = entries
    else if (subTab === 'coEditing') list = collabEntries
    else list = favoritedEntries
    if (selectedCategory) list = list.filter(e => e.category === selectedCategory)
    return list
  }, [entries, collabEntries, favoritedEntries, subTab, selectedCategory])

  async function handleShowFollows(type: 'following' | 'followers') {
    if (!user) return
    setShowFollowSheet(type)
    const ids = type === 'following' ? followingIds : followerIds
    const profiles = await fetchUserProfiles(ids)
    setFollowUsers(profiles)
  }

  const toggleFollowInSheet = useCallback(async (targetId: string) => {
    if (!user) return
    const following = myFollowingSet.has(targetId)
    setMyFollowingSet(prev => { const s = new Set(prev); following ? s.delete(targetId) : s.add(targetId); return s })
    try { following ? await unfollowUser(user.id, targetId) : await followUser(user.id, targetId) } catch {
      setMyFollowingSet(prev => { const s = new Set(prev); following ? s.add(targetId) : s.delete(targetId); return s })
    }
  }, [user, myFollowingSet])

  if (!user) return null

  return (
    <div className="flex flex-col h-full bg-white">
      {/* 顶栏 */}
      <div className="flex items-center px-4 h-11 shrink-0">
        <h1 className="font-serif italic font-bold text-[28px] text-wiki-text">Lifepedia</h1>
        <div className="flex-1" />
        <button onClick={() => navigate('/settings')}>
          <Settings size={20} strokeWidth={1.5} />
        </button>
      </div>

      <div className="overflow-y-auto flex-1 pb-24">
        {/* Instagram 风格个人信息 */}
        <div className="px-4 pt-4">
          <div className="flex items-center gap-5">
            <Avatar userId={user.id} name={user.display_name} size={80} />
            <div className="flex-1 flex justify-around">
              <StatItem value={entries.length} label="词条" />
              <StatItem value={followingIds.length} label="关注" onClick={() => handleShowFollows('following')} />
              <StatItem value={followerIds.length} label="被关注" onClick={() => handleShowFollows('followers')} />
            </div>
          </div>
          <div className="mt-3">
            <p className="text-[15px] font-semibold">{user.display_name}</p>
            <p className="text-sm text-wiki-secondary">{user.bio || '用百科的方式，记录我的人生'}</p>
          </div>
        </div>

        {/* 子 Tab */}
        <div className="flex mt-4">
          {([['authored', '编纂'], ['coEditing', '合编'], ['favorited', '收藏']] as const).map(([key, label]) => (
            <button
              key={key}
              onClick={() => { setSubTab(key); setSelectedCategory(null) }}
              className={`flex-1 py-3 text-sm text-center ${subTab === key ? 'font-semibold text-wiki-text border-b-2 border-wiki-blue' : 'text-wiki-tertiary'}`}
            >
              {label}
            </button>
          ))}
        </div>

        <CategoryFilterBar selected={selectedCategory} onSelect={setSelectedCategory} />

        {/* 草稿区（仅编纂 Tab） */}
        {subTab === 'authored' && drafts.length > 0 && (
          <div className="pt-2">
            <button
              onClick={() => setDraftsExpanded(!draftsExpanded)}
              className="w-full flex items-center gap-2 px-4 py-3"
            >
              <FileText size={14} className="text-wiki-blue" />
              <span className="text-[15px] font-semibold">草稿</span>
              <span className="text-wiki-small text-wiki-tertiary px-1.5 py-0.5 bg-wiki-bg-secondary rounded-full">{drafts.length}</span>
              <div className="flex-1" />
              {draftsExpanded ? <ChevronUp size={12} className="text-wiki-tertiary" /> : <ChevronDown size={12} className="text-wiki-tertiary" />}
            </button>

            {draftsExpanded && drafts.map((draft, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-2.5 active:bg-wiki-bg-secondary">
                <div className="w-11 h-11 bg-wiki-bg-secondary rounded-md flex items-center justify-center">
                  <span className="text-base text-wiki-tertiary">{CATEGORY_META[draft.category as EntryCategory]?.label?.charAt(0) || '?'}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm font-medium truncate ${draft.title ? 'text-wiki-text' : 'text-wiki-tertiary'}`}>{draft.title || '未命名词条'}</p>
                  <p className="text-[11px] text-wiki-tertiary">{CATEGORY_META[draft.category as EntryCategory]?.label || draft.category} · {timeAgo(draft.updated_at)}</p>
                </div>
                <ChevronRight size={12} className="text-wiki-tertiary" />
              </div>
            ))}
          </div>
        )}

        {/* 词条列表 */}
        <div className="px-2.5 pt-3 space-y-3 bg-[#F4F4F4]">
          {loading ? (
            <div className="flex justify-center py-16">
              <span className="w-8 h-8 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" />
            </div>
          ) : publishedEntries.length === 0 ? (
            <p className="text-center text-wiki-tertiary py-16">{subTab === 'favorited' ? '暂无收藏' : '暂无词条'}</p>
          ) : (
            publishedEntries.map(entry => (
              <FeedCard key={entry.id} entry={entry} onClick={() => navigate(`/entry/${entry.id}`)} />
            ))
          )}
        </div>
      </div>

      {/* 关注/被关注列表 */}
      {showFollowSheet && (
        <div className="fixed inset-0 z-50 bg-black/35 flex items-end justify-center" onClick={() => setShowFollowSheet(null)}>
          <div className="bg-white rounded-t-2xl w-full max-w-lg max-h-[70vh] overflow-hidden" onClick={e => e.stopPropagation()}>
            <p className="text-base font-semibold text-center pt-[18px] pb-[14px]">{showFollowSheet === 'following' ? '关注' : '被关注'}</p>
            <div className="h-px bg-wiki-divider" />

            {followUsers.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 text-wiki-tertiary gap-2.5">
                <span className="text-3xl">👥</span>
                <p className="text-sm">{showFollowSheet === 'following' ? '还没有关注任何人' : '还没有人关注你'}</p>
              </div>
            ) : (
              <div className="overflow-y-auto max-h-[60vh]">
                {followUsers.map(u => (
                  <div
                    key={u.id}
                    className="flex items-center gap-3 px-4 py-2.5 active:bg-wiki-bg-secondary"
                    onClick={() => { setShowFollowSheet(null); setTimeout(() => navigate(`/user/${u.id}`, { state: { name: u.display_name } }), 200) }}
                  >
                    <Avatar userId={u.id} name={u.display_name} size={48} />
                    <span className="text-[15px] font-medium flex-1">{u.display_name}</span>
                    <button
                      onClick={e => { e.stopPropagation(); toggleFollowInSheet(u.id) }}
                      className={`text-wiki-small font-medium px-3.5 py-1.5 rounded-md ${myFollowingSet.has(u.id) ? 'text-wiki-secondary bg-wiki-bg-secondary' : 'text-white bg-wiki-blue'}`}
                    >
                      {myFollowingSet.has(u.id) ? '已关注' : (showFollowSheet === 'following' ? '关注' : '回关')}
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function StatItem({ value, label, onClick }: { value: number; label: string; onClick?: () => void }) {
  return (
    <button onClick={onClick} disabled={!onClick} className="text-center disabled:cursor-default">
      <p className="text-[17px] font-bold">{value}</p>
      <p className="text-wiki-small text-wiki-tertiary">{label}</p>
    </button>
  )
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return '刚刚'
  if (min < 60) return `${min}分钟前`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}小时前`
  const day = Math.floor(hr / 24)
  if (day < 7) return `${day}天前`
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}月${d.getDate()}日`
}
