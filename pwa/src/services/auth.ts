import { sha256 } from 'js-sha256'
import { supabaseGet } from '../lib/supabase'
import type { UserProfile } from '../types'

const STORAGE_KEY = 'auth_user_json'

export function getStoredUser(): UserProfile | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}

export function storeUser(user: UserProfile) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(user))
  localStorage.setItem('user_display_name', user.display_name)
  localStorage.setItem('user_bio', user.bio)
  localStorage.setItem('user_avatar_seed', String(user.avatar_seed))
}

export function clearUser() {
  localStorage.removeItem(STORAGE_KEY)
  localStorage.removeItem('user_display_name')
  localStorage.removeItem('user_bio')
  localStorage.removeItem('user_avatar_seed')
}

export async function login(username: string, password: string): Promise<UserProfile> {
  const hash = sha256(password)
  const users = await supabaseGet<UserProfile[]>(
    `users?username=eq.${encodeURIComponent(username)}&password_hash=eq.${hash}&limit=1`
  )
  if (!users.length) throw new Error('用户名或密码错误')
  const user = users[0]
  storeUser(user)
  return user
}
