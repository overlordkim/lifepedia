import { avatarURL } from '../../lib/supabase'
import { useState } from 'react'

interface Props {
  userId: string
  name?: string
  size?: number
  className?: string
}

export default function Avatar({ userId, name, size = 32, className = '' }: Props) {
  const [failed, setFailed] = useState(false)
  const initial = (name || '?')[0]

  if (failed) {
    return (
      <div
        className={`rounded-full bg-wiki-bg-secondary flex items-center justify-center text-wiki-secondary font-semibold shrink-0 ${className}`}
        style={{ width: size, height: size, fontSize: size * 0.4 }}
      >
        {initial}
      </div>
    )
  }

  return (
    <img
      src={avatarURL(userId)}
      alt={name || userId}
      className={`rounded-full object-cover shrink-0 ${className}`}
      style={{ width: size, height: size }}
      onError={() => setFailed(true)}
    />
  )
}
