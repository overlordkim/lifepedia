import { ALL_CATEGORIES, CATEGORY_META, type EntryCategory } from '../../types'

interface Props {
  selected: EntryCategory | null
  onSelect: (cat: EntryCategory | null) => void
}

export default function CategoryFilterBar({ selected, onSelect }: Props) {
  return (
    <div className="flex overflow-x-auto no-scrollbar gap-2.5 px-4 py-2.5 bg-white">
      <Chip label="全部" isSelected={selected === null} onClick={() => onSelect(null)} />
      {ALL_CATEGORIES.map(cat => (
        <Chip
          key={cat}
          label={CATEGORY_META[cat].label}
          isSelected={selected === cat}
          onClick={() => onSelect(selected === cat ? null : cat)}
        />
      ))}
    </div>
  )
}

function Chip({ label, isSelected, onClick }: { label: string; isSelected: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`shrink-0 px-3.5 py-1.5 rounded-md text-[13px] transition-colors ${
        isSelected
          ? 'font-semibold text-white bg-wiki-text'
          : 'text-wiki-secondary bg-[#F0F0F0]'
      }`}
    >
      {label}
    </button>
  )
}
