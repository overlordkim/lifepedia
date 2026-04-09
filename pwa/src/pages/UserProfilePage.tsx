import { useState, useEffect, useCallback } from 'react'
import { useParams, useNavigate, useLocation } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { fetchEntriesByAuthor } from '../services/entries'
import { loadFollowing, loadFollowers, followUser, unfollowUser, fetchUserProfiles } from '../services/follows'
import { supabaseGet } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import Avatar from '../components/shared/Avatar'
import FeedCard from '../components/feed/FeedCard'
import type { SupabaseEntry, UserProfile, SimpleUser } from '../types'

export default function UserProfilePage() {
  const { userId } = useParams<{ userId: string }>()
  const navigate = useNavigate()
  const location = useLocation()
  const { user: me } = useAuth()
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [entries, setEntries] = useState<SupabaseEntry[]>([])
  const [isFollowing, setIsFollowing] = useState(false)
  const [followingList, setFollowingList] = useState<{ id: string; name: string }[]>([])
  const [followerList, setFollowerList] = useState<{ id: string; name: string }[]>([])
  const [showFollowSheet, setShowFollowSheet] = useState<'following' | 'followers' | null>(null)
  const [sheetUsers, setSheetUsers] = useState<SimpleUser[]>([])
  const [myFollowingSet, setMyFollowingSet] = useState<Set<string>>(new Set())
  const [userBio, setUserBio] = useState('用百科的方式，记录人生')

  const passedName = (location.state as any)?.name

  useEffect(() => {
    if (!userId) return
    supabaseGet<UserProfile[]>(`users?id=eq.${userId}&select=id,display_name,bio,avatar_seed&limit=1`)
      .then(r => { if (r[0]) { setProfile(r[0]); if (r[0].bio) setUserBio(r[0].bio) } }).catch(() => {})
    fetchEntriesByAuthor(userId).then(setEntries).catch(() => {})
    fetchUserFollows(userId)
    if (me) loadFollowing(me.id).then(ids => { setIsFollowing(ids.includes(userId)); setMyFollowingSet(new Set(ids)) }).catch(() => {})
  }, [userId, me])

  async function fetchUserFollows(uid: string) {
    const [fing, fers] = await Promise.all([
      loadFollowing(uid),
      loadFollowers(uid),
    ])
    const allIds = [...new Set([...fing, ...fers])]
    const profiles = allIds.length > 0 ? await fetchUserProfiles(allIds) : []
    const nameMap = Object.fromEntries(profiles.map(p => [p.id, p.display_name]))
    setFollowingList(fing.map(id => ({ id, name: nameMap[id] || '…' })))
    setFollowerList(fers.map(id => ({ id, name: nameMap[id] || '…' })))
  }

  const toggleFollow = useCallback(async () => {
    if (!me || !userId) return
    const newState = !isFollowing
    setIsFollowing(newState)
    try { newState ? await followUser(me.id, userId) : await unfollowUser(me.id, userId) } catch { setIsFollowing(!newState) }
  }, [me, userId, isFollowing])

  const toggleFollowInSheet = useCallback(async (targetId: string) => {
    if (!me) return
    const following = myFollowingSet.has(targetId)
    setMyFollowingSet(prev => { const s = new Set(prev); following ? s.delete(targetId) : s.add(targetId); return s })
    try { following ? await unfollowUser(me.id, targetId) : await followUser(me.id, targetId) } catch {
      setMyFollowingSet(prev => { const s = new Set(prev); following ? s.add(targetId) : s.delete(targetId); return s })
    }
  }, [me, myFollowingSet])

  async function openFollowSheet(type: 'following' | 'followers') {
    setShowFollowSheet(type)
    const ids = (type === 'following' ? followingList : followerList).map(x => x.id)
    const profiles = ids.length > 0 ? await fetchUserProfiles(ids) : []
    setSheetUsers(profiles)
  }

  const displayName = profile?.display_name || passedName || userId

  return (
    <div className="flex flex-col h-screen bg-white">
      {/* 顶栏 */}
      <div className="flex items-center px-4 h-12 shrink-0 border-b border-wiki-divider">
        <button onClick={() => navigate(-1)}><ArrowLeft size={16} strokeWidth={2} /></button>
        <div className="flex-1 text-center">
          <span className="text-base font-semibold">{displayName}</span>
        </div>
        <div className="w-7" />
      </div>

      <div className="overflow-y-auto flex-1 pb-20">
        {/* Instagram 风格头部 */}
        <div className="px-4 pt-4">
          <div className="flex items-center gap-5">
            <Avatar userId={userId || ''} name={displayName} size={80} />
            <div className="flex-1 flex justify-around">
              <StatItem value={entries.length} label="词条" />
              <StatItem value={followingList.length} label="关注" onClick={() => openFollowSheet('following')} />
              <StatItem value={followerList.length} label="被关注" onClick={() => openFollowSheet('followers')} />
            </div>
          </div>
          <div className="mt-3">
            <p className="text-[15px] font-semibold">{displayName}</p>
            <p className="text-sm text-wiki-secondary">{userBio}</p>
          </div>
        </div>

        {/* 全宽关注按钮 */}
        {me?.id !== userId && (
          <div className="px-4 pt-3.5 pb-4">
            <button
              onClick={toggleFollow}
              className={`w-full h-9 rounded-lg text-sm font-semibold transition-colors ${
                isFollowing
                  ? 'text-wiki-secondary bg-wiki-bg-secondary border border-wiki-divider'
                  : 'text-white bg-wiki-blue'
              }`}
            >
              {isFollowing ? '已关注' : '关注'}
            </button>
          </div>
        )}

        {/* ta 的词条 */}
        <div className="bg-wiki-bg-secondary h-2" />
        <div className="flex items-center gap-2 px-4 py-3.5">
          <span className="text-[15px] font-semibold">ta 的词条</span>
          <span className="text-wiki-meta text-wiki-tertiary">{entries.length}</span>
        </div>

        {entries.length === 0 ? (
          <div className="flex flex-col items-center py-10 text-wiki-tertiary gap-2.5">
            <svg className="w-8 h-8 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" /></svg>
            <p className="text-sm">还没有公开的词条</p>
          </div>
        ) : (
          <div className="px-4 space-y-4 pb-4">
            {entries.map(entry => (
              <FeedCard key={entry.id} entry={entry} onClick={() => navigate(`/entry/${entry.id}`)} />
            ))}
          </div>
        )}
      </div>

      {/* 关注/被关注列表 */}
      {showFollowSheet && (
        <div className="fixed inset-0 z-50 bg-black/35 flex items-end justify-center" onClick={() => setShowFollowSheet(null)}>
          <div className="bg-white rounded-t-2xl w-full max-w-lg max-h-[70vh] overflow-hidden" onClick={e => e.stopPropagation()}>
            <p className="text-base font-semibold text-center pt-[18px] pb-[14px]">{showFollowSheet === 'following' ? '关注' : '被关注'}</p>
            <div className="h-px bg-wiki-divider" />
            {sheetUsers.length === 0 ? (
              <div className="flex flex-col items-center py-16 text-wiki-tertiary gap-2.5">
                <span className="text-3xl">👥</span>
                <p className="text-sm">{showFollowSheet === 'following' ? '还没有关注任何人' : '还没有人关注 ta'}</p>
              </div>
            ) : (
              <div className="overflow-y-auto max-h-[60vh]">
                {sheetUsers.map(u => (
                  <div key={u.id} className="flex items-center gap-3 px-4 py-2.5" onClick={() => { setShowFollowSheet(null); navigate(`/user/${u.id}`, { state: { name: u.display_name } }) }}>
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
