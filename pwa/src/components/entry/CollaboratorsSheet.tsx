import { useState, useEffect } from 'react'
import { X, Search, UserPlus, UserMinus } from 'lucide-react'
import { searchUsers } from '../../services/follows'
import { updateCollaborators } from '../../services/entries'
import Avatar from '../shared/Avatar'
import type { SimpleUser } from '../../types'

interface Props {
  entryId: string
  authorId: string
  authorName: string
  contributors: string[]
  onUpdate: (names: string[]) => void
  onClose: () => void
}

export default function CollaboratorsSheet({ entryId, authorId, authorName, contributors, onUpdate, onClose }: Props) {
  const [searchText, setSearchText] = useState('')
  const [results, setResults] = useState<SimpleUser[]>([])
  const [names, setNames] = useState<string[]>(contributors)

  useEffect(() => {
    if (searchText.trim().length < 1) { setResults([]); return }
    const timer = setTimeout(async () => {
      const users = await searchUsers(searchText.trim())
      setResults(users.filter(u => u.id !== authorId))
    }, 300)
    return () => clearTimeout(timer)
  }, [searchText, authorId])

  async function toggleContributor(user: SimpleUser) {
    let updated: string[]
    if (names.includes(user.display_name)) {
      updated = names.filter(n => n !== user.display_name)
    } else {
      updated = [...names, user.display_name]
    }
    setNames(updated)
    try {
      await updateCollaborators(entryId, updated)
      onUpdate(updated)
    } catch {
      setNames(names)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={onClose}>
      <div className="bg-white rounded-t-2xl w-full max-w-lg max-h-[80vh] flex flex-col" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between px-4 py-3 border-b border-wiki-divider shrink-0">
          <h3 className="font-semibold">合编者管理</h3>
          <button onClick={onClose}><X size={20} className="text-wiki-tertiary" /></button>
        </div>

        {/* 搜索 */}
        <div className="px-4 py-2 border-b border-wiki-divider shrink-0">
          <div className="flex items-center gap-2 px-3 py-2 bg-wiki-bg-secondary rounded-lg">
            <Search size={14} className="text-wiki-tertiary" />
            <input
              value={searchText}
              onChange={e => setSearchText(e.target.value)}
              placeholder="搜索用户……"
              className="flex-1 bg-transparent text-sm"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {/* 创建者 */}
          <div className="px-4 py-3 border-b border-wiki-divider">
            <p className="text-wiki-small text-wiki-tertiary mb-2">创建者</p>
            <div className="flex items-center gap-3">
              <Avatar userId={authorId} name={authorName} size={36} />
              <span className="text-sm font-medium">{authorName}</span>
            </div>
          </div>

          {/* 合编者 */}
          {names.length > 0 && (
            <div className="px-4 py-3 border-b border-wiki-divider">
              <p className="text-wiki-small text-wiki-tertiary mb-2">合编者</p>
              {names.map(name => (
                <div key={name} className="flex items-center justify-between py-2">
                  <span className="text-sm">{name}</span>
                  <button
                    onClick={() => setNames(prev => { const n = prev.filter(x => x !== name); updateCollaborators(entryId, n); onUpdate(n); return n })}
                    className="text-wiki-tertiary"
                  >
                    <UserMinus size={16} />
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* 搜索结果 */}
          {results.length > 0 && (
            <div className="px-4 py-3">
              <p className="text-wiki-small text-wiki-tertiary mb-2">搜索结果</p>
              {results.map(user => (
                <div key={user.id} className="flex items-center gap-3 py-2">
                  <Avatar userId={user.id} name={user.display_name} size={36} />
                  <span className="text-sm flex-1">{user.display_name}</span>
                  <button
                    onClick={() => toggleContributor(user)}
                    className={`text-sm px-3 py-1 rounded ${
                      names.includes(user.display_name)
                        ? 'text-wiki-secondary bg-wiki-bg-secondary'
                        : 'text-white bg-wiki-blue'
                    }`}
                  >
                    {names.includes(user.display_name) ? '已邀请' : '邀请'}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
