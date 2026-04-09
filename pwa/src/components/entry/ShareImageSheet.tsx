import { useState, useEffect, useCallback } from 'react'
import { Download, Send, Check, RotateCcw } from 'lucide-react'
import type { SupabaseEntry } from '../../types'

interface Props { entry: SupabaseEntry; onClose: () => void }

export default function ShareImageSheet({ entry, onClose }: Props) {
  const [renderedBlob, setRenderedBlob] = useState<Blob | null>(null)
  const [previewURL, setPreviewURL] = useState<string | null>(null)
  const [rendering, setRendering] = useState(true)
  const [error, setError] = useState(false)
  const [saved, setSaved] = useState(false)

  const renderImage = useCallback(async () => {
    setRendering(true)
    setError(false)
    try {
      const res = await fetch('/api/render-share', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ entry }),
      })
      if (!res.ok) throw new Error(`${res.status}`)
      const blob = await res.blob()
      setRenderedBlob(blob)
      setPreviewURL(URL.createObjectURL(blob))
    } catch {
      setError(true)
    }
    setRendering(false)
  }, [entry])

  useEffect(() => { renderImage() }, [renderImage])
  useEffect(() => () => { if (previewURL) URL.revokeObjectURL(previewURL) }, [previewURL])

  function handleDownload() {
    if (!renderedBlob) return
    const a = document.createElement('a')
    a.href = URL.createObjectURL(renderedBlob)
    a.download = `${entry.title || '词条'}.png`
    a.click()
    URL.revokeObjectURL(a.href)
    setSaved(true); setTimeout(() => setSaved(false), 2000)
  }

  function handleShare() {
    if (!renderedBlob) return
    const file = new File([renderedBlob], `${entry.title || '词条'}.png`, { type: 'image/png' })
    if (navigator.share && navigator.canShare?.({ files: [file] }))
      navigator.share({ files: [file], title: entry.title }).catch(() => {})
    else handleDownload()
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
        ) : previewURL ? (
          <img src={previewURL} alt="长图" className="w-full rounded-lg shadow-[0_4px_16px_rgba(0,0,0,0.08)]" />
        ) : null}
      </div>
      {renderedBlob && (
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
