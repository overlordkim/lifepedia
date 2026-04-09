import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { BookOpen } from 'lucide-react'

export default function LoginPage() {
  const { login } = useAuth()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [shake, setShake] = useState(false)

  const canLogin = username.trim() && password.trim()

  async function handleLogin() {
    if (!canLogin || loading) return
    setError(null)
    setLoading(true)
    try {
      await login(username.trim(), password)
    } catch (e: any) {
      setError(e.message || '登录失败')
      setShake(true)
      setTimeout(() => setShake(false), 400)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-white flex flex-col items-center px-8">
      <div className="h-[18vh]" />

      <div className="flex flex-col items-center gap-3 mb-12">
        <BookOpen size={48} strokeWidth={1} className="text-wiki-text" />
        <h1 className="font-serif text-[32px] font-bold text-wiki-text">人间词条</h1>
        <p className="font-serif italic text-wiki-tertiary text-base">Lifepedia</p>
      </div>

      <div className={`w-full max-w-sm space-y-4 ${shake ? 'animate-shake' : ''}`}>
        <div>
          <label className="block text-[13px] font-medium text-wiki-secondary mb-1.5">用户名</label>
          <input
            type="text"
            value={username}
            onChange={e => setUsername(e.target.value)}
            placeholder="输入用户名"
            autoCapitalize="none"
            autoCorrect="off"
            className="w-full px-3.5 py-3 text-base bg-wiki-bg-secondary rounded-[10px] border border-wiki-border/50"
          />
        </div>
        <div>
          <label className="block text-[13px] font-medium text-wiki-secondary mb-1.5">密码</label>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleLogin()}
            placeholder="输入密码"
            className="w-full px-3.5 py-3 text-base bg-wiki-bg-secondary rounded-[10px] border border-wiki-border/50"
          />
        </div>

        {error && <p className="text-red-500 text-[13px] text-center">{error}</p>}

        <button
          onClick={handleLogin}
          disabled={!canLogin || loading}
          className="w-full py-3.5 rounded-xl text-base font-semibold text-white transition-colors disabled:opacity-40"
          style={{ backgroundColor: canLogin ? '#0645AD' : undefined }}
        >
          {loading ? (
            <span className="inline-block w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : '登录'}
        </button>
      </div>

      <style>{`
        @keyframes shake { 0%,100% { transform: translateX(0); } 25% { transform: translateX(8px); } 75% { transform: translateX(-8px); } }
        .animate-shake { animation: shake 0.3s ease-in-out; }
      `}</style>
    </div>
  )
}
