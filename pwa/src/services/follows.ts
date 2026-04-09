import { supabaseGet, supabasePost, supabaseDelete } from '../lib/supabase'
import { restURL, SUPABASE_ANON_KEY } from '../lib/supabase'
import type { SimpleUser } from '../types'

export async function loadFollowing(userId: string): Promise<string[]> {
  const rows = await supabaseGet<{following_id: string}[]>(
    `follows?follower_id=eq.${encodeURIComponent(userId)}&select=following_id`
  )
  return rows.map(r => r.following_id)
}

export async function loadFollowers(userId: string): Promise<string[]> {
  const rows = await supabaseGet<{follower_id: string}[]>(
    `follows?following_id=eq.${encodeURIComponent(userId)}&select=follower_id`
  )
  return rows.map(r => r.follower_id)
}

export async function followUser(myId: string, userId: string): Promise<void> {
  const res = await fetch(`${restURL}/follows`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: JSON.stringify({ follower_id: myId, following_id: userId }),
  })
  if (!res.ok) throw new Error('关注失败')
}

export async function unfollowUser(myId: string, userId: string): Promise<void> {
  return supabaseDelete(
    `follows?follower_id=eq.${encodeURIComponent(myId)}&following_id=eq.${encodeURIComponent(userId)}`
  )
}

export async function fetchUserProfiles(ids: string[]): Promise<SimpleUser[]> {
  if (!ids.length) return []
  const idList = ids.map(id => `"${id}"`).join(',')
  return supabaseGet<SimpleUser[]>(
    `users?id=in.(${idList})&select=id,display_name,avatar_seed`
  )
}

export async function searchUsers(query: string): Promise<SimpleUser[]> {
  return supabaseGet<SimpleUser[]>(
    `users?display_name=ilike.*${encodeURIComponent(query)}*&select=id,display_name,avatar_seed&limit=20`
  )
}
