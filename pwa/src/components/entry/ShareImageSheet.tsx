import { useState, useEffect, useRef, useCallback } from 'react'
import { Download, Send, Check } from 'lucide-react'
import html2canvas from 'html2canvas'
import { avatarURL } from '../../lib/supabase'
import type { SupabaseEntry, EntryCategory, EntryScope } from '../../types'
import { CATEGORY_META, SCOPE_META } from '../../types'

interface Props {
  entry: SupabaseEntry
  onClose: () => void
}

export default function ShareImageSheet({ entry, onClose }: Props) {
  const cardRef = useRef<HTMLDivElement>(null)
  const [renderedBlob, setRenderedBlob] = useState<Blob | null>(null)
  const [previewURL, setPreviewURL] = useState<string | null>(null)
  const [rendering, setRendering] = useState(true)
  const [saved, setSaved] = useState(false)

  const renderImage = useCallback(async () => {
    if (!cardRef.current) return
    try {
      await new Promise(r => setTimeout(r, 500))
      const canvas = await html2canvas(cardRef.current, {
        scale: 3,
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#FFFFFF',
        width: 375,
        windowWidth: 375,
      })
      canvas.toBlob(blob => {
        if (blob) {
          setRenderedBlob(blob)
          setPreviewURL(URL.createObjectURL(blob))
        }
        setRendering(false)
      }, 'image/png')
    } catch {
      setRendering(false)
    }
  }, [])

  useEffect(() => {
    renderImage()
    return () => { if (previewURL) URL.revokeObjectURL(previewURL) }
  }, [])

  function handleDownload() {
    if (!renderedBlob) return
    const a = document.createElement('a')
    a.href = URL.createObjectURL(renderedBlob)
    a.download = `${entry.title || '词条'}.png`
    a.click()
    URL.revokeObjectURL(a.href)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }

  function handleShare() {
    if (!renderedBlob) return
    const file = new File([renderedBlob], `${entry.title || '词条'}.png`, { type: 'image/png' })
    if (navigator.share && navigator.canShare?.({ files: [file] })) {
      navigator.share({ files: [file], title: entry.title }).catch(() => {})
    } else {
      handleDownload()
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-[#F5F5F5] flex flex-col">
      <div className="flex items-center px-4 h-12 shrink-0 bg-[#F5F5F5]">
        <button onClick={onClose} className="text-[15px] text-wiki-text">关闭</button>
        <span className="flex-1 text-center text-[16px] font-semibold">分享长图</span>
        <div className="w-10" />
      </div>

      <div className="flex-1 overflow-y-auto px-5 py-4">
        {rendering ? (
          <div className="flex flex-col items-center justify-center h-64 gap-4">
            <span className="w-8 h-8 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" />
            <span className="text-[14px] text-wiki-secondary">正在生成长图…</span>
          </div>
        ) : previewURL ? (
          <img src={previewURL} alt="分享长图" className="w-full rounded-lg shadow-[0_4px_16px_rgba(0,0,0,0.08)]" />
        ) : (
          <div className="flex flex-col items-center justify-center h-64 gap-3 text-wiki-secondary">
            <span className="text-3xl">⚠</span>
            <span className="text-[14px]">生成失败，请重试</span>
          </div>
        )}
      </div>

      {renderedBlob && (
        <div className="flex gap-4 px-5 pb-6 pt-2 bg-gradient-to-t from-[#F5F5F5] via-[#F5F5F5] to-transparent">
          <button
            onClick={handleDownload}
            className={`flex-1 flex items-center justify-center gap-1.5 py-3.5 rounded-xl text-[15px] font-medium text-white ${saved ? 'bg-green-500' : 'bg-black'}`}
          >
            {saved ? <Check size={16} /> : <Download size={16} />}
            {saved ? '已保存' : '保存图片'}
          </button>
          <button
            onClick={handleShare}
            className="flex-1 flex items-center justify-center gap-1.5 py-3.5 rounded-xl text-[15px] font-medium text-black border border-black"
          >
            <Send size={16} />
            分享
          </button>
        </div>
      )}

      {/* 屏幕外渲染卡片 */}
      <div style={{ position: 'fixed', left: -9999, top: 0 }}>
        <div ref={cardRef} style={{ width: 375, background: '#fff', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif' }}>
          <ShareCard entry={entry} />
        </div>
      </div>
    </div>
  )
}

/* ═══════════════════════════════════════════════════
   ShareCard - 完整长图卡片（纯 inline style，兼容 html2canvas）
   ═══════════════════════════════════════════════════ */

const S = {
  bg: '#FFFFFF',
  text: '#1A1A1A',
  secondary: '#666666',
  tertiary: '#999999',
  blue: '#2563EB',
  red: '#DC2626',
  divider: '#E5E5E5',
  bgSec: '#F5F5F5',
  serif: 'Georgia, "Times New Roman", serif',
  sans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif',
}

function ShareCard({ entry }: { entry: SupabaseEntry }) {
  const [avatarFailed, setAvatarFailed] = useState(false)
  const coverURL = entry.cover_image_url || (entry.sections || []).find(s => s.image_refs?.length)?.image_refs?.[0]
  const catMeta = CATEGORY_META[entry.category as EntryCategory]
  const scopeMeta = SCOPE_META[entry.scope as EntryScope]

  return (
    <div style={{ width: 375, background: S.bg }}>
      {/* ── 顶栏 ── */}
      <div style={{
        display: 'flex', alignItems: 'center', padding: '0 16px', height: 48,
        borderBottom: `0.5px solid ${S.divider}`, boxSizing: 'border-box',
      }}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={S.text} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M15 18l-6-6 6-6" />
        </svg>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 12, height: 28 }}>
          {avatarFailed ? (
            <div style={{
              width: 28, height: 28, borderRadius: '50%', background: S.bgSec,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 12, fontWeight: 600, color: S.secondary, lineHeight: '28px',
            }}>
              {(entry.author_name || '?')[0]}
            </div>
          ) : (
            <img
              src={avatarURL(entry.author_id)} alt=""
              width={28} height={28}
              style={{ borderRadius: '50%', objectFit: 'cover', display: 'block' }}
              onError={() => setAvatarFailed(true)}
              crossOrigin="anonymous"
            />
          )}
          <span style={{ fontSize: 14, fontWeight: 600, color: S.text, lineHeight: '28px' }}>
            {entry.author_name}
          </span>
        </div>
        <div style={{ flex: 1 }} />
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={S.text} strokeWidth="2.5" strokeLinecap="round">
          <circle cx="12" cy="12" r="1" /><circle cx="5" cy="12" r="1" /><circle cx="19" cy="12" r="1" />
        </svg>
      </div>

      {/* ── Hero ── */}
      {coverURL ? (
        <img src={coverURL} alt="" style={{ width: '100%', display: 'block' }} crossOrigin="anonymous" />
      ) : (
        <HeroPlaceholder title={entry.title} />
      )}

      {/* ── 正文区 ── */}
      <div style={{ padding: '20px 16px 0' }}>
        {/* 标题 */}
        <div style={{ fontFamily: S.serif, fontSize: 24, fontWeight: 700, color: entry.title ? S.text : S.tertiary, lineHeight: 1.3, margin: 0 }}>
          {entry.title || '未命名词条'}
        </div>
        {entry.subtitle && (
          <div style={{ fontSize: 14, color: S.secondary, marginTop: 4 }}>{entry.subtitle}</div>
        )}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 8, fontSize: 12, color: S.tertiary }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
            <TagIcon />{catMeta?.label || entry.category}
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
            <ScopeIcon scope={entry.scope as EntryScope} />{scopeMeta?.label || entry.scope}
          </span>
        </div>
        <div style={{ height: 1, background: S.divider, marginTop: 12 }} />

        {/* 信息框 */}
        {(entry.infobox || []).length > 0 && (
          <div style={{ marginTop: 20 }}>
            <InlineInfobox category={entry.category as EntryCategory} fields={entry.infobox!} />
          </div>
        )}

        {/* 引言 */}
        {entry.introduction && (
          <div style={{ fontSize: 15, lineHeight: 1.8, color: S.text, marginTop: 20 }}>
            {renderWikiInline(entry.introduction)}
          </div>
        )}

        {/* 章节 */}
        {(entry.sections || []).map((sec, i) => (
          <div key={i} style={{ marginTop: 24 }}>
            <div style={{ fontFamily: S.serif, fontSize: 18, fontWeight: 700, color: S.text, margin: 0 }}>{sec.title}</div>
            <div style={{ height: 1, background: S.divider, marginTop: 4 }} />
            <div style={{ fontSize: 15, lineHeight: 1.8, color: S.text, marginTop: 10, whiteSpace: 'pre-wrap' }}>
              {renderWikiInline(sec.body)}
            </div>
            {(sec.image_refs || []).map((url, j) => (
              <img key={j} src={url} alt="" style={{ width: '100%', borderRadius: 8, marginTop: 10, display: 'block' }} crossOrigin="anonymous" />
            ))}
          </div>
        ))}

        {/* 标签 */}
        {entry.tags && entry.tags.length > 0 && (
          <div style={{ marginTop: 24 }}>
            <div style={{ height: 1, background: S.divider }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 14 }}>
              {entry.tags.map(tag => (
                <span key={tag} style={{
                  display: 'inline-block', padding: '5px 12px',
                  fontSize: 12, fontStyle: 'italic', color: S.secondary,
                  background: S.bgSec, borderRadius: 14,
                  lineHeight: '16px',
                }}>
                  # {tag}
                </span>
              ))}
            </div>
          </div>
        )}

        <div style={{ height: 28 }} />
      </div>

      {/* ── 品牌 Footer ── */}
      <div style={{ borderTop: `0.5px solid ${S.divider}`, textAlign: 'center', padding: '28px 0', background: S.bg }}>
        <img src="/logo.png" alt="" width={44} height={44} style={{ display: 'inline-block', objectFit: 'contain' }} crossOrigin="anonymous" />
        <div style={{ marginTop: 10 }}>
          <span style={{ fontFamily: S.serif, fontStyle: 'italic', fontSize: 18, fontWeight: 700, color: S.text }}>
            Lifepedia
          </span>
          <span style={{ fontSize: 15, fontWeight: 600, color: S.text, marginLeft: 6 }}>
            人间词条
          </span>
        </div>
        <div style={{ fontSize: 12, color: S.tertiary, marginTop: 6 }}>你的生命值得一座百科</div>
      </div>
    </div>
  )
}

/* ── Wiki 文本解析（inline style 版，用于 html2canvas 兼容） ── */

function renderWikiInline(text: string) {
  const pattern = /(\[\[([^\]]+)\]\]|\{\{([^}]+)\}\}|\[来源请求\])/g
  const parts: (string | JSX.Element)[] = []
  let lastIdx = 0
  let match: RegExpExecArray | null

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIdx) parts.push(text.slice(lastIdx, match.index))
    if (match[2]) {
      parts.push(<span key={`b${match.index}`} style={{ color: S.blue, textDecoration: 'underline', textUnderlineOffset: 2 }}>{match[2]}</span>)
    } else if (match[3]) {
      parts.push(<span key={`r${match.index}`} style={{ color: S.red, textDecoration: 'underline', textUnderlineOffset: 2 }}>{match[3]}</span>)
    } else {
      parts.push(<sup key={`c${match.index}`} style={{ color: S.blue, fontSize: 10 }}>[来源请求]</sup>)
    }
    lastIdx = match.index + match[0].length
  }
  if (lastIdx < text.length) parts.push(text.slice(lastIdx))
  return <>{parts}</>
}

/* ── 信息框（inline style 版） ── */

function InlineInfobox({ category, fields }: { category: EntryCategory; fields: { key: string; value: string }[] }) {
  if (!fields.length) return null
  const catMeta = CATEGORY_META[category]
  return (
    <div style={{ borderRadius: 10, background: '#FAFAFA', border: '0.5px solid #EEEEEE', overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '10px 14px' }}>
        <TagIcon color={S.blue} />
        <span style={{ fontSize: 13, fontWeight: 600, color: S.text }}>{catMeta?.label || category}</span>
      </div>
      {fields.map((f, i) => (
        <div key={f.key}>
          {i > 0 && <div style={{ height: 0.5, background: 'rgba(0,0,0,0.06)', marginLeft: 106, marginRight: 14 }} />}
          <div style={{ display: 'flex', alignItems: 'flex-start', padding: '5px 14px' }}>
            <span style={{ width: 80, flexShrink: 0, textAlign: 'right', paddingRight: 12, fontSize: 12, fontWeight: 500, color: S.tertiary }}>
              {f.key}
            </span>
            <span style={{ flex: 1, fontSize: 13, color: S.text }}>{f.value}</span>
          </div>
        </div>
      ))}
      <div style={{ height: 10 }} />
    </div>
  )
}

/* ── 小图标 ── */

function TagIcon({ color = '#999' }: { color?: string }) {
  return (
    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2H2v10l9.29 9.29c.94.94 2.48.94 3.42 0l6.58-6.58c.94-.94.94-2.48 0-3.42L12 2z" />
      <path d="M7 7h.01" />
    </svg>
  )
}

function ScopeIcon({ scope }: { scope: EntryScope }) {
  if (scope === 'private') return (
    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#999" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" />
    </svg>
  )
  if (scope === 'collaborative') return (
    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#999" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 00-3-3.87" /><path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  )
  return (
    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#999" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" /><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z" />
    </svg>
  )
}

function HeroPlaceholder({ title }: { title: string }) {
  const seed = Math.abs(hashCode(title)) % 1000
  const hue = seed % 360
  return (
    <div style={{
      width: '100%', aspectRatio: '16/9',
      background: `linear-gradient(135deg, hsl(${hue},8%,97%), hsl(${hue},15%,90%))`,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke={`hsl(${hue},10%,75%)`} strokeWidth="1" opacity="0.5">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
      </svg>
      {title && <span style={{ fontSize: 14, fontWeight: 500, color: `hsl(${hue},10%,60%)`, opacity: 0.6, marginTop: 6 }}>{title}</span>}
    </div>
  )
}

function hashCode(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  return h
}
