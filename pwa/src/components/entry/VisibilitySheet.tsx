import { Lock, Users, Globe } from 'lucide-react'
import type { EntryScope } from '../../types'

interface Props {
  current: EntryScope
  onChange: (scope: EntryScope) => void
  onClose: () => void
}

const SCOPES: { key: EntryScope; label: string; desc: string; icon: typeof Lock }[] = [
  { key: 'private', label: '私人', desc: '仅自己可见', icon: Lock },
  { key: 'collaborative', label: '合编', desc: '邀请他人一起编辑', icon: Users },
  { key: 'public', label: '公共', desc: '所有人可见', icon: Globe },
]

export default function VisibilitySheet({ current, onChange, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={onClose}>
      <div className="bg-white rounded-t-2xl w-full max-w-lg pb-safe" onClick={e => e.stopPropagation()}>
        <div className="text-center py-4 border-b border-wiki-divider">
          <p className="font-semibold">词条可见性</p>
        </div>
        <div className="py-2">
          {SCOPES.map(s => {
            const Icon = s.icon
            const selected = current === s.key
            return (
              <button
                key={s.key}
                onClick={() => { onChange(s.key); onClose() }}
                className="w-full flex items-center gap-3 px-5 py-3.5 hover:bg-wiki-bg-secondary"
              >
                <Icon size={20} className={selected ? 'text-wiki-blue' : 'text-wiki-tertiary'} />
                <div className="text-left flex-1">
                  <p className={`text-[15px] ${selected ? 'font-semibold text-wiki-blue' : ''}`}>{s.label}</p>
                  <p className="text-wiki-small text-wiki-tertiary">{s.desc}</p>
                </div>
                {selected && <span className="text-wiki-blue font-bold">✓</span>}
              </button>
            )
          })}
        </div>
        <button onClick={onClose} className="w-full py-4 text-wiki-tertiary text-[15px] border-t border-wiki-divider">
          取消
        </button>
      </div>
    </div>
  )
}
