import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react'
import type { UserProfile } from '../types'
import { getStoredUser, storeUser, clearUser, login as doLogin, register as doRegister } from '../services/auth'

interface AuthCtx {
  user: UserProfile | null
  isLoggedIn: boolean
  login: (username: string, password: string) => Promise<void>
  register: (username: string, password: string) => Promise<void>
  logout: () => void
  updateLocalProfile: (patch: Partial<Pick<UserProfile, 'display_name' | 'bio'>>) => void
}

const AuthContext = createContext<AuthCtx | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserProfile | null>(() => getStoredUser())

  const login = useCallback(async (username: string, password: string) => {
    const u = await doLogin(username, password)
    setUser(u)
  }, [])

  const register = useCallback(async (username: string, password: string) => {
    const u = await doRegister(username, password)
    setUser(u)
  }, [])

  const logout = useCallback(() => {
    clearUser()
    setUser(null)
  }, [])

  const updateLocalProfile = useCallback((patch: Partial<Pick<UserProfile, 'display_name' | 'bio'>>) => {
    setUser(prev => {
      if (!prev) return prev
      const updated = { ...prev, ...patch }
      storeUser(updated)
      return updated
    })
  }, [])

  return (
    <AuthContext.Provider value={{ user, isLoggedIn: !!user, login, register, logout, updateLocalProfile }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
