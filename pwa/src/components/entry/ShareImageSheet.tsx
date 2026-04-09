import { useState, useEffect, useCallback } from 'react'
import { Download, Send, Check, RotateCcw } from 'lucide-react'
import type { SupabaseEntry } from '../../types'

interface Props { entry: SupabaseEntry; onClose: () => void }

export default function ShareImageSheet({ entry, onClose }: Props) {
  const [imageURL, setImageURL] = useState<string | null>(null)
  const [rendering, setRendering] = useState(true)
  const [error, setError] = useState(false)
  const [saved, setSaved] = useState(false)

  const renderImage = useCallback(async () => {
    setRendering(true)
    setError(false)
    setImageURL(null)
    try {
      // Step 1: 让服务器生成图片并上传到 Supabase，返回 URL（小 JSON，不走大文件传输）
      const res = await fetch('/api/render-share', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ entry }),
      })
      if (!res.ok) throw new Error(`${res.status}`)
      const { url } = await res.json()
      if (!url) throw new Error('no url')
      setImageURL(url)
    } catch {
      setError(true)
    }
    setRendering(false)
  }, [entry])

  useEffect(() => { renderImage() }, [renderImage])

  async function handleDownload() {
    if (!imageURL) return
    try {
      // 直接从 Supabase CDN 下载，不走 Pinggy
      const res = await fetch(imageURL)
      const blob = await res.blob()
      const a = document.createElement('a')
      a.href = URL.createObjectURL(blob)
      a.download = `${entry.title || '词条'}.png`
      a.click()
      URL.revokeObjectURL(a.href)
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    } catch {
      // 兜底：直接打开 URL
      window.open(imageURL, '_blank')
    }
  }

  async function handleShare() {
    if (!imageURL) return
    try {
      const res = await fetch(imageURL)
      const blob = await res.blob()
      const file = new File([blob], `${entry.title || '词条'}.png`, { type: 'image/png' })
      if (navigator.share && navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file], title: entry.title })
      } else {
        await handleDownload()
      }
    } catch {
      await handleDownload()
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
        ) : error ? (
          <div className="flex flex-col items-center justify-center h-64 gap-3 text-wiki-secondary">
            <span className="text-3xl">⚠</span>
            <span className="text-[14px]">生成失败</span>
            <button onClick={renderImage}
              className="flex items-center gap-1.5 mt-2 px-4 py-2 rounded-lg bg-black text-white text-[13px]">
              <RotateCcw size={14} />重试
            </button>
          </div>
        ) : imageURL ? (
          <img src={imageURL} alt="长图" className="w-full rounded-lg shadow-[0_4px_16px_rgba(0,0,0,0.08)]" />
        ) : null}
      </div>

      {imageURL && (
        <div className="flex gap-4 px-5 pb-6 pt-2 bg-gradient-to-t from-[#F5F5F5] via-[#F5F5F5] to-transparent">
          <button onClick={handleDownload}
            className={`flex-1 flex items-center justify-center gap-1.5 py-3.5 rounded-xl text-[15px] font-medium text-white ${saved ? 'bg-green-500' : 'bg-black'}`}>
            {saved ? <Check size={16} /> : <Download size={16} />}{saved ? '已保存' : '保存图片'}
          </button>
          <button onClick={handleShare}
            className="flex-1 flex items-center justify-center gap-1.5 py-3.5 rounded-xl text-[15px] font-medium text-black border border-black">
            <Send size={16} />分享
          </button>
        </div>
      )}
    </div>
  )
}
