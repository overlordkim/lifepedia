import { Tag } from 'lucide-react'
import type { InfoboxField, EntryCategory } from '../../types'
import { CATEGORY_META } from '../../types'

interface Props {
  category: EntryCategory
  fields: InfoboxField[]
}

export default function InfoboxView({ category, fields }: Props) {
  if (!fields.length) return null
  const catMeta = CATEGORY_META[category]

  return (
    <div className="rounded-[10px] bg-[#FAFAFA] border-[0.5px] border-[#EEEEEE] overflow-hidden">
      <div className="flex items-center gap-1.5 px-3.5 py-2.5">
        <Tag size={11} strokeWidth={2} className="text-wiki-blue" />
        <span className="text-[13px] font-semibold text-wiki-text">{catMeta?.label || category}</span>
      </div>

      {fields.map((f, i) => (
        <div key={f.key}>
          {i > 0 && (
            <div className="h-px bg-wiki-divider/50" style={{ marginLeft: 106, marginRight: 14 }} />
          )}
          <div className="flex items-start px-3.5 py-[5px]">
            <span className="w-20 shrink-0 text-right pr-3 text-[12px] font-medium text-wiki-tertiary">
              {f.key}
            </span>
            <span className="flex-1 text-[13px] text-wiki-text">
              {f.value}
            </span>
          </div>
        </div>
      ))}

      <div className="h-2.5" />
    </div>
  )
}
