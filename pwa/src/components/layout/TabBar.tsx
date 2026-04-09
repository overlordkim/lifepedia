import { Compass, PlusSquare, User } from 'lucide-react'

type Tab = 'feed' | 'myPage'

interface Props {
  selected: Tab
  onSelect: (tab: Tab) => void
  onCompose: () => void
  visible: boolean
}

export default function TabBar({ selected, onSelect, onCompose, visible }: Props) {
  if (!visible) return null

  return (
    <div className="fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-wiki-divider safe-bottom">
      <div className="flex h-[49px] max-w-lg mx-auto">
        <button
          onClick={() => onSelect('feed')}
          className="flex-1 flex items-center justify-center active:scale-90 transition-transform"
        >
          <Compass
            size={24}
            strokeWidth={1.5}
            className={selected === 'feed' ? 'text-wiki-blue' : 'text-wiki-tertiary'}
            fill={selected === 'feed' ? 'currentColor' : 'none'}
          />
        </button>
        <button
          onClick={onCompose}
          className="flex-1 flex items-center justify-center active:scale-90 transition-transform"
        >
          <PlusSquare size={26} strokeWidth={1} className="text-wiki-tertiary" />
        </button>
        <button
          onClick={() => onSelect('myPage')}
          className="flex-1 flex items-center justify-center active:scale-90 transition-transform"
        >
          <User
            size={24}
            strokeWidth={1.5}
            className={selected === 'myPage' ? 'text-wiki-blue' : 'text-wiki-tertiary'}
            fill={selected === 'myPage' ? 'currentColor' : 'none'}
          />
        </button>
      </div>
    </div>
  )
}
