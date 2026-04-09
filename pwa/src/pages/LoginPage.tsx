import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { BookOpen } from 'lucide-react'

export default function LoginPage() {
  const { login, register } = useAuth()
  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [shake, setShake] = useState(false)

  const canSubmit = username.trim().length >= 2 && password.trim().length >= 4

  async function handleSubmit() {
    if (!canSubmit || loading) return
    setError(null)
    setLoading(true)
    try {
      if (mode === 'login') {
        await login(username.trim(), password)
      } else {
        await register(username.trim(), password)
      }
    } catch (e: any) {
      setError(e.message || (mode === 'login' ? '登录失败' : '注册失败'))
      setShake(true)
      setTimeout(() => setShake(false), 400)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-white flex flex-col items-center px-8">
      <div className="h-[16vh]" />

      <div className="flex flex-col items-center gap-3 mb-10">
        <BookOpen size={48} strokeWidth={1} className="text-wiki-text" />
        <h1 className="font-serif text-[32px] font-bold text-wiki-text">人间词条</h1>
        <p className="font-serif italic text-wiki-tertiary text-base">Lifepedia</p>
      </div>

      <div className="flex bg-wiki-bg-secondary rounded-lg p-0.5 mb-6 w-full max-w-sm">
        <button
          onClick={() => { setMode('login'); setError(null) }}
          className={`flex-1 py-2 text-sm font-medium rounded-md transition-all ${
            mode === 'login'
              ? 'bg-white text-wiki-text shadow-sm'
              : 'text-wiki-tertiary'
          }`}
        >
          登录
        </button>
        <button
          onClick={() => { setMode('register'); setError(null) }}
          className={`flex-1 py-2 text-sm font-medium rounded-md transition-all ${
            mode === 'register'
              ? 'bg-white text-wiki-text shadow-sm'
              : 'text-wiki-tertiary'
          }`}
        >
          注册
        </button>
      </div>

      <div className={`w-full max-w-sm space-y-4 ${shake ? 'animate-shake' : ''}`}>
        <div>
          <label className="block text-[13px] font-medium text-wiki-secondary mb-1.5">用户名</label>
          <input
            type="text"
            value={username}
            onChange={e => setUsername(e.target.value)}
            placeholder={mode === 'register' ? '至少 2 个字符' : '输入用户名'}
            autoCapitalize="none"
            autoCorrect="off"
            className="w-full px-3.5 py-3 text-base bg-wiki-bg-secondary rounded-[10px] border border-wiki-border/50 outline-none focus:border-wiki-blue/40 transition-colors"
          />
        </div>
        <div>
          <label className="block text-[13px] font-medium text-wiki-secondary mb-1.5">密码</label>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleSubmit()}
            placeholder={mode === 'register' ? '至少 4 位' : '输入密码'}
            className="w-full px-3.5 py-3 text-base bg-wiki-bg-secondary rounded-[10px] border border-wiki-border/50 outline-none focus:border-wiki-blue/40 transition-colors"
          />
        </div>

        {error && <p className="text-red-500 text-[13px] text-center">{error}</p>}

        <button
          onClick={handleSubmit}
          disabled={!canSubmit || loading}
          className="w-full py-3.5 rounded-xl text-base font-semibold text-white transition-colors disabled:opacity-40"
          style={{ backgroundColor: canSubmit ? '#0645AD' : undefined }}
        >
          {loading ? (
            <span className="inline-block w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : mode === 'login' ? '登录' : '注册'}
        </button>
      </div>

      <p className="mt-6 text-[13px] text-wiki-tertiary">
        {mode === 'login' ? '还没有账号？' : '已有账号？'}
        <button
          onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setError(null) }}
          className="text-wiki-blue ml-1"
        >
          {mode === 'login' ? '立即注册' : '去登录'}
        </button>
      </p>

      <style>{`
        @keyframes shake { 0%,100% { transform: translateX(0); } 25% { transform: translateX(8px); } 75% { transform: translateX(-8px); } }
        .animate-shake { animation: shake 0.3s ease-in-out; }
      `}</style>
    </div>
  )
}
