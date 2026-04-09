import { useState } from 'react'
import { Heart, MessageCircle, Send as Paperplane, Bookmark } from 'lucide-react'

interface Props {
  likeCount: number
  commentCount: number
  collectCount: number
  onCommentClick?: () => void
  onShare?: () => void
}

export default function FloatingActionBar({ likeCount, commentCount, collectCount, onCommentClick, onShare }: Props) {
  const [liked, setLiked] = useState(false)
  const [bookmarked, setBookmarked] = useState(false)

  return (
    <div className="fixed bottom-0 left-0 right-0 z-30 bg-white border-t border-wiki-divider safe-bottom">
      <div className="flex items-center px-4 py-3">
        {/* 左侧：赞 + 评论 + 分享 */}
        <div className="flex items-center gap-4">
          <button
            onClick={() => setLiked(!liked)}
            className="flex items-center gap-1.5 active:scale-90 transition-transform"
          >
            <Heart
              size={24}
              strokeWidth={1}
              className={`transition-transform ${liked ? 'text-wiki-heart-active fill-current scale-110' : 'text-wiki-text'}`}
            />
            <span className="text-[13px] text-wiki-secondary">{likeCount + (liked ? 1 : 0)}</span>
          </button>

          <button
            onClick={onCommentClick}
            className="flex items-center gap-1.5 active:scale-90 transition-transform"
          >
            <MessageCircle size={22} strokeWidth={1} className="text-wiki-text" />
            <span className="text-[13px] text-wiki-secondary">{commentCount}</span>
          </button>

          <button
            onClick={onShare}
            className="active:scale-90 transition-transform"
          >
            <Paperplane size={22} strokeWidth={1} className="text-wiki-text" />
          </button>
        </div>

        <div className="flex-1" />

        {/* 右侧：收藏 */}
        <button
          onClick={() => setBookmarked(!bookmarked)}
          className="flex items-center gap-1.5 active:scale-90 transition-transform"
        >
          <Bookmark
            size={22}
            strokeWidth={1}
            className={`transition-transform ${bookmarked ? 'text-wiki-bookmark-active fill-current scale-110' : 'text-wiki-text'}`}
          />
          <span className="text-[13px] text-wiki-secondary">{collectCount + (bookmarked ? 1 : 0)}</span>
        </button>
      </div>
    </div>
  )
}
