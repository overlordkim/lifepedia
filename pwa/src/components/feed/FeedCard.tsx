import { useState, useMemo } from 'react'
import { Heart, MessageCircle } from 'lucide-react'
import { CATEGORY_META, type SupabaseEntry, type EntryCategory } from '../../types'
import Avatar from '../shared/Avatar'

interface Props {
  entry: SupabaseEntry
  onClick: () => void
}

export default function FeedCard({ entry, onClick }: Props) {
  const [liked, setLiked] = useState(false)

  const coverURL = entry.cover_image_url
    || entry.sections?.find(s => s.image_refs?.length)?.image_refs?.[0]
    || null

  const seed = Math.abs(hashCode(entry.title)) % 1000
  const ratios = [4/3, 3/2, 16/9, 1]
  const ratio = ratios[seed % ratios.length]
  const hue = (seed % 360)

  const highlights = (entry.infobox || []).slice(0, 3).map(f => f.value).join('  ·  ')
  const catLabel = CATEGORY_META[entry.category as EntryCategory]?.label || entry.category

  return (
    <div
      onClick={onClick}
      className="bg-white rounded-md shadow-[0_2px_6px_rgba(0,0,0,0.05)] overflow-hidden cursor-pointer active:scale-[0.99] transition-transform"
    >
      {/* 封面 */}
      <div className="relative w-full overflow-hidden" style={{ aspectRatio: ratio }}>
        {coverURL ? (
          <img src={coverURL} alt="" className="w-full h-full object-cover" loading="lazy" />
        ) : (
          <div
            className="w-full h-full flex items-center justify-center"
            style={{
              background: `linear-gradient(135deg, hsl(${hue}, 8%, 97%), hsl(${hue}, 12%, 93%))`,
            }}
          >
            <svg className="w-6 h-6" style={{ color: `hsl(${hue}, 15%, 82%)` }} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91M3.75 21h16.5a1.5 1.5 0 001.5-1.5V5.25a1.5 1.5 0 00-1.5-1.5H3.75a1.5 1.5 0 00-1.5 1.5v14.25a1.5 1.5 0 001.5 1.5z" />
            </svg>
          </div>
        )}
      </div>

      {/* 内容 */}
      <div className="px-3 pt-3 pb-2.5">
        <h3 className="font-serif text-lg font-bold text-wiki-text line-clamp-2">{entry.title}</h3>

        {highlights && (
          <p className="text-wiki-small text-wiki-tertiary mt-1 truncate">{highlights}</p>
        )}

        {entry.introduction && (
          <p className="text-[13.5px] text-wiki-secondary mt-1.5 line-clamp-2 leading-relaxed">
            {entry.introduction}
          </p>
        )}

        {/* 底栏 */}
        <div className="flex items-center gap-2 mt-2.5">
          <Avatar userId={entry.author_id} name={entry.author_name} size={20} />
          <span className="text-wiki-small font-medium text-wiki-secondary">{entry.author_name}</span>
          <span className="text-[11px] text-wiki-border">·</span>
          <span className="text-wiki-small text-wiki-tertiary">{catLabel}</span>
          <div className="flex-1" />

          <button
            onClick={e => { e.stopPropagation(); setLiked(!liked) }}
            className="flex items-center gap-0.5"
          >
            <Heart
              size={13}
              className={liked ? 'text-wiki-heart-active fill-current' : 'text-wiki-tertiary'}
            />
            {(entry.like_count > 0 || liked) && (
              <span className="text-[11px] text-wiki-tertiary">{entry.like_count + (liked ? 1 : 0)}</span>
            )}
          </button>

          <div className="flex items-center gap-0.5">
            <MessageCircle size={12} className="text-wiki-tertiary" />
            {entry.comment_count > 0 && (
              <span className="text-[11px] text-wiki-tertiary">{entry.comment_count}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function hashCode(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  return h
}
