import { ArrowLeft, Clock } from 'lucide-react'
import type { Revision } from '../../types'

interface Props {
  revisions: Revision[]
  onClose: () => void
}

export default function RevisionHistory({ revisions, onClose }: Props) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={onClose}>
      <div className="bg-white rounded-t-2xl w-full max-w-lg max-h-[70vh] flex flex-col" onClick={e => e.stopPropagation()}>
        <div className="flex items-center gap-3 px-4 py-3 border-b border-wiki-divider shrink-0">
          <button onClick={onClose}><ArrowLeft size={20} /></button>
          <h3 className="font-semibold">修订历史</h3>
        </div>
        <div className="flex-1 overflow-y-auto">
          {revisions.length === 0 ? (
            <p className="text-center text-wiki-tertiary py-16">暂无修订记录</p>
          ) : (
            revisions.map(rev => (
              <div key={rev.id} className="px-4 py-3 border-b border-wiki-divider">
                <div className="flex items-center gap-2">
                  <Clock size={14} className="text-wiki-tertiary" />
                  <span className="text-wiki-small text-wiki-tertiary">
                    {new Date(rev.timestamp).toLocaleString('zh-CN')}
                  </span>
                </div>
                <p className="text-sm font-medium mt-1">{rev.summary}</p>
                <p className="text-wiki-small text-wiki-secondary">{rev.editor_name}</p>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
