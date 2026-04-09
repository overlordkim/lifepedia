import { useState, useEffect, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { X, Send, Plus, Image, Link, Sparkles, PenLine, ArrowUpCircle } from 'lucide-react'
import { chat as aiChat } from '../services/ai'
import { generateImage } from '../services/imageGen'
import { upsertEntry, uploadBase64Image, persistImageFromURL } from '../services/entries'
import { addNotification } from '../services/notifications'
import { useAuth } from '../contexts/AuthContext'
import Avatar from '../components/shared/Avatar'
import { parseWikiText } from '../utils/wiki'
import type { ChatMessage, SupabaseEntry, InfoboxField, EntrySection, AppNotification, AttachmentItem } from '../types'

type AIStatus = 'thinking' | 'updatingEntry' | 'generatingImage' | null

export default function ComposePage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [entry, setEntry] = useState<SupabaseEntry>(() => {
    const drafts: SupabaseEntry[] = JSON.parse(localStorage.getItem('drafts') || '[]')
    const emptyDraft = drafts.find(d => !d.title && !(d.sections || []).length)
    if (emptyDraft) return emptyDraft
    return makeEmptyEntry(user)
  })
  const [showChat, setShowChat] = useState(true)
  const [messages, setMessages] = useState<ChatMessage[]>([
    { id: '0', role: 'assistant', content: '你好，我是你的词条编纂助手。告诉我一段回忆、一个人、或一件旧物，我来帮你写成百科词条。', timestamp: new Date().toISOString() }
  ])
  const [inputText, setInputText] = useState('')
  const [aiStatus, setAiStatus] = useState<AIStatus>(null)
  const [showExitDialog, setShowExitDialog] = useState(false)
  const [showAttachments, setShowAttachments] = useState(false)
  const [attachments, setAttachments] = useState<AttachmentItem[]>([])
  const [showLinkInput, setShowLinkInput] = useState(false)
  const [linkText, setLinkText] = useState('')
  const chatEndRef = useRef<HTMLDivElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages])

  const hasContent = entry.title || (entry.sections || []).length > 0 || entry.introduction

  function handleClose() {
    if (hasContent) setShowExitDialog(true)
    else navigate(-1)
  }

  async function handlePublish() {
    const updated = { ...entry, status: 'published', published_at: new Date().toISOString(), updated_at: new Date().toISOString() }
    try {
      await upsertEntry(updated)
      const drafts: SupabaseEntry[] = JSON.parse(localStorage.getItem('drafts') || '[]')
      localStorage.setItem('drafts', JSON.stringify(drafts.filter(d => d.id !== entry.id)))
      navigate('/', { replace: true })
    } catch (err: any) {
      alert('发布失败: ' + err.message)
    }
  }

  function handleSaveDraft() {
    const drafts: SupabaseEntry[] = JSON.parse(localStorage.getItem('drafts') || '[]')
    const idx = drafts.findIndex(d => d.id === entry.id)
    const saved = { ...entry, updated_at: new Date().toISOString() }
    if (idx >= 0) drafts[idx] = saved
    else drafts.push(saved)
    localStorage.setItem('drafts', JSON.stringify(drafts))
    navigate(-1)
  }

  function handleDiscard() {
    const drafts: SupabaseEntry[] = JSON.parse(localStorage.getItem('drafts') || '[]')
    localStorage.setItem('drafts', JSON.stringify(drafts.filter(d => d.id !== entry.id)))
    navigate(-1)
  }

  function handleAddImages() {
    fileInputRef.current?.click()
    setShowAttachments(false)
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files
    if (!files) return
    Array.from(files).forEach(file => {
      const reader = new FileReader()
      reader.onload = () => {
        const base64 = (reader.result as string).split(',')[1]
        setAttachments(prev => [...prev, { id: crypto.randomUUID(), type: 'image', name: file.name, image_base64: base64 }])
      }
      reader.readAsDataURL(file)
    })
    e.target.value = ''
  }

  function handleAddLink() {
    const url = linkText.trim()
    if (url) {
      setAttachments(prev => [...prev, { id: crypto.randomUUID(), type: 'link', name: url, link_url: url }])
    }
    setLinkText('')
    setShowLinkInput(false)
  }

  async function sendMessage() {
    const text = inputText.trim()
    if (!text || aiStatus) return

    const imageData = attachments.filter(a => a.image_base64).map(a => a.image_base64!)
    const links = attachments.filter(a => a.link_url).map(a => a.link_url!)
    let displayText = text
    if (imageData.length) displayText = `📷×${imageData.length} ${displayText}`
    if (links.length) displayText += '\n' + links.map(u => `🔗 ${u}`).join('\n')

    const newMsg: ChatMessage = { id: crypto.randomUUID(), role: 'user', content: displayText, timestamp: new Date().toISOString() }
    const allMessages = [...messages, newMsg]
    setMessages(allMessages)
    setInputText('')
    setAttachments([])
    setAiStatus('thinking')

    try {
      let uploadedURLs: string[] = []
      for (const b64 of imageData) {
        try {
          const url = await uploadBase64Image(b64)
          uploadedURLs.push(url)
        } catch {}
      }

      const snapshot = entry.title ? {
        title: entry.title,
        subtitle: entry.subtitle || undefined,
        category: entry.category,
        infobox: entry.infobox || [],
        introduction: entry.introduction || undefined,
        sections: entry.sections || [],
        tags: entry.tags || [],
        related_entry_titles: [],
      } : null

      const result = await aiChat(allMessages, snapshot, uploadedURLs, true)

      for (const action of result.actions) {
        setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: action, timestamp: new Date().toISOString() }])
      }

      if (result.entry_data) {
        setAiStatus('updatingEntry')
        await new Promise(r => setTimeout(r, 500))

        setEntry(prev => {
          const d = result.entry_data!
          const updated = { ...prev }
          if (d.title) updated.title = d.title
          if (d.subtitle !== undefined) updated.subtitle = d.subtitle
          if (d.category) updated.category = d.category
          if (d.infobox?.length) updated.infobox = d.infobox
          if (d.introduction) updated.introduction = d.introduction
          if (d.sections?.length) updated.sections = d.sections
          if (d.tags?.length) updated.tags = d.tags
          if (d.cover_image_url) updated.cover_image_url = d.cover_image_url
          updated.updated_at = new Date().toISOString()
          return updated
        })

        if (result.entry_data.title) {
          addNotification({
            id: crypto.randomUUID(),
            type: 'aiUpdate',
            title: '词条编纂完成',
            body: `AI 助手完成了「${result.entry_data.title}」的更新`,
            related_entry_id: entry.id,
            is_read: false,
            created_at: new Date().toISOString(),
          })
        }
      }

      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: result.reply, timestamp: new Date().toISOString() }])

      if (result.image_gen_tasks.length > 0) {
        setAiStatus('generatingImage')
        setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: `photo.artframe|正在生成 ${result.image_gen_tasks.length} 张插图…`, timestamp: new Date().toISOString() }])

        for (const task of result.image_gen_tasks) {
          try {
            const tempURL = await generateImage(task.prompt)
            let finalURL: string
            try { finalURL = await persistImageFromURL(tempURL) } catch { finalURL = tempURL }

            setEntry(prev => {
              const sections = [...(prev.sections || [])]
              const idx = sections.findIndex(s => s.title === task.section_title)
              if (idx >= 0) sections[idx] = { ...sections[idx], image_refs: [...(sections[idx].image_refs || []), finalURL] }
              return { ...prev, sections, cover_image_url: prev.cover_image_url || finalURL }
            })
            setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: `checkmark.circle|「${task.section_title}」插图已生成`, timestamp: new Date().toISOString() }])
          } catch {
            setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: `exclamationmark.triangle|插图生成失败`, timestamp: new Date().toISOString() }])
          }
        }
      }
    } catch (err: any) {
      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: `抱歉，遇到了问题：${err.message}`, timestamp: new Date().toISOString() }])
    } finally {
      setAiStatus(null)
    }
  }

  const coverURL = entry.cover_image_url || (entry.sections || []).find(s => s.image_refs?.length)?.image_refs?.[0]

  return (
    <div className="flex flex-col h-screen bg-white">
      {/* 顶栏 */}
      <div className="flex items-center gap-3 px-4 h-12 shrink-0 border-b border-wiki-divider">
        <button onClick={handleClose}><X size={16} strokeWidth={2} /></button>
        <Avatar userId={user?.id || 'self'} name={user?.display_name} size={28} />
        <span className="text-sm font-medium">{user?.display_name || '我'}</span>
        <div className="flex-1" />
        <button onClick={() => setShowChat(!showChat)}>
          {showChat ? <X size={18} strokeWidth={1.5} /> : <PenLine size={18} strokeWidth={1.5} />}
        </button>
        {hasContent && (
          <button onClick={handlePublish} className="px-4 py-1.5 bg-wiki-blue text-white text-sm font-semibold rounded-full">
            发布
          </button>
        )}
      </div>

      {/* 预览区 */}
      <div className={`overflow-y-auto ${showChat ? 'h-[35%]' : 'flex-1'} transition-all`}>
        {!entry.title && !(entry.sections || []).length ? (
          <div className="flex flex-col items-center justify-center h-full text-wiki-tertiary gap-3">
            <PenLine size={36} strokeWidth={1} />
            <p className="font-serif text-lg">新词条</p>
            <p className="text-wiki-small">{showChat ? '在下方和 AI 对话，词条将在这里生长' : '点击右上角编辑按钮，与 AI 对话来创建内容'}</p>
          </div>
        ) : (
          <div className="px-4 py-4 space-y-3">
            {coverURL && <img src={coverURL} alt="" className="w-full aspect-video object-cover rounded-lg" />}
            <h1 className="font-serif text-wiki-title">{entry.title}</h1>
            {entry.introduction && <p className="text-wiki-body wiki-reading">{entry.introduction}</p>}
            {(entry.sections || []).map((sec, i) => (
              <div key={i}>
                <h2 className="font-serif text-wiki-section border-b border-wiki-divider pb-1 mb-2">{sec.title}</h2>
                <p className="text-wiki-body wiki-reading whitespace-pre-wrap">{parseWikiText(sec.body)}</p>
                {(sec.image_refs || []).map((url, j) => (
                  <img key={j} src={url} alt="" className="w-full rounded-lg mt-2 shadow-sm" loading="lazy" />
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 聊天面板 */}
      {showChat && (
        <>
          <div className="h-px bg-wiki-divider shrink-0" />
          <div className="flex-1 flex flex-col overflow-hidden">
            <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
              {messages.map(msg => <ChatBubble key={msg.id} msg={msg} />)}
              {aiStatus && (
                <div className="flex items-start gap-2 px-0 pl-[34px]">
                  <div className="flex items-center gap-2 px-3.5 py-2.5 bg-wiki-bg-secondary rounded-2xl">
                    <Sparkles size={12} className="text-wiki-blue animate-pulse" />
                    <span className="text-[13px] text-wiki-secondary">
                      {aiStatus === 'thinking' ? '正在思考' : aiStatus === 'updatingEntry' ? '正在编纂词条' : '正在生成插图'}
                    </span>
                    <span className="flex gap-1">
                      {[0, 1, 2].map(i => (
                        <span key={i} className="w-1 h-1 bg-wiki-tertiary rounded-full animate-bounce" style={{ animationDelay: `${i * 150}ms` }} />
                      ))}
                    </span>
                  </div>
                </div>
              )}
              <div ref={chatEndRef} />
            </div>

            {/* 附件条 */}
            {attachments.length > 0 && (
              <div className="flex gap-2 px-3 py-1.5 overflow-x-auto no-scrollbar">
                {attachments.map(a => (
                  <div key={a.id} className="flex items-center gap-1.5 px-2.5 py-1 bg-wiki-bg-secondary rounded-full text-wiki-small shrink-0">
                    {a.type === 'image' ? <Image size={12} /> : <Link size={12} />}
                    <span className="max-w-[100px] truncate">{a.name}</span>
                    <button onClick={() => setAttachments(prev => prev.filter(x => x.id !== a.id))} className="text-wiki-tertiary">×</button>
                  </div>
                ))}
              </div>
            )}

            {/* 输入栏 */}
            <div className="flex items-center gap-2 px-3 py-2 border-t border-wiki-divider shrink-0 bg-white safe-bottom relative">
              <button onClick={() => setShowAttachments(!showAttachments)}>
                <Plus size={20} strokeWidth={1.5} className={`text-wiki-tertiary transition-transform ${showAttachments ? 'rotate-45' : ''}`} />
              </button>
              <input
                type="text"
                value={inputText}
                onChange={e => setInputText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && !e.nativeEvent.isComposing && sendMessage()}
                placeholder="说点什么……"
                className="flex-1 px-3 py-2 text-base bg-wiki-bg-secondary rounded-full"
              />
              <button
                onClick={sendMessage}
                disabled={!inputText.trim() || !!aiStatus}
              >
                <ArrowUpCircle size={28} className={!inputText.trim() || aiStatus ? 'text-wiki-tertiary' : 'text-wiki-blue'} fill={!inputText.trim() || aiStatus ? 'transparent' : 'currentColor'} />
              </button>

              {showAttachments && (
                <div className="absolute bottom-full left-3 mb-2 bg-white rounded-xl shadow-lg p-3 flex gap-3">
                  <button onClick={handleAddImages} className="flex flex-col items-center gap-1 w-16 h-16 bg-wiki-bg-secondary rounded-lg justify-center">
                    <Image size={22} className="text-wiki-blue" />
                    <span className="text-[11px] text-wiki-secondary">相册</span>
                  </button>
                  <button onClick={() => { setShowLinkInput(true); setShowAttachments(false) }} className="flex flex-col items-center gap-1 w-16 h-16 bg-wiki-bg-secondary rounded-lg justify-center">
                    <Link size={22} className="text-wiki-blue" />
                    <span className="text-[11px] text-wiki-secondary">链接</span>
                  </button>
                </div>
              )}
            </div>
          </div>
        </>
      )}

      <input ref={fileInputRef} type="file" accept="image/*" multiple className="hidden" onChange={handleFileChange} />

      {/* 退出确认 */}
      {showExitDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35" onClick={() => setShowExitDialog(false)}>
          <div className="bg-white rounded-2xl w-[280px] overflow-hidden" onClick={e => e.stopPropagation()}>
            <p className="text-center font-semibold py-5">保存词条？</p>
            {[
              { label: '发布', icon: '↑', action: handlePublish, color: 'text-wiki-blue' },
              { label: '存为草稿', icon: '📄', action: handleSaveDraft, color: '' },
              { label: '丢弃', icon: '🗑', action: handleDiscard, color: 'text-red-500' },
            ].map(item => (
              <button key={item.label} onClick={item.action} className={`w-full text-left px-5 py-3 text-[15px] font-medium hover:bg-wiki-bg-secondary ${item.color}`}>
                {item.icon} {item.label}
              </button>
            ))}
            <button onClick={() => setShowExitDialog(false)} className="w-full py-3.5 text-wiki-tertiary text-[15px] text-center">取消</button>
          </div>
        </div>
      )}

      {/* 链接输入 */}
      {showLinkInput && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35" onClick={() => setShowLinkInput(false)}>
          <div className="bg-white rounded-2xl w-[300px] p-5 space-y-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center gap-2">
              <Link size={15} className="text-wiki-blue" />
              <span className="font-semibold">粘贴链接</span>
            </div>
            <input
              type="url"
              value={linkText}
              onChange={e => setLinkText(e.target.value)}
              placeholder="https://..."
              className="w-full px-3 py-2.5 bg-wiki-bg-secondary rounded-lg text-[15px]"
              autoFocus
            />
            <div className="flex gap-3">
              <button onClick={() => { setLinkText(''); setShowLinkInput(false) }} className="flex-1 py-2.5 text-[15px] text-wiki-secondary bg-wiki-bg-secondary rounded-lg">取消</button>
              <button onClick={handleAddLink} className="flex-1 py-2.5 text-[15px] text-white bg-wiki-blue rounded-lg font-semibold">添加</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function ChatBubble({ msg }: { msg: ChatMessage }) {
  if (msg.role === 'system') {
    const parts = msg.content.split('|')
    const icon = parts.length > 1 ? parts[0] : 'sparkles'
    const text = parts.length > 1 ? parts[1] : msg.content
    const style = getActionStyle(icon)
    return (
      <div className="flex justify-center py-0.5">
        <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-medium ${style.bgClass} ${style.textClass}`}>
          {style.emoji}{text}
        </span>
      </div>
    )
  }
  const isUser = msg.role === 'user'
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} px-4`}>
      {!isUser && (
        <div className="w-[26px] h-[26px] rounded-full bg-gradient-to-br from-wiki-blue/15 to-wiki-blue/5 flex items-center justify-center mr-2 shrink-0 mt-1">
          <Sparkles size={11} className="text-wiki-blue" />
        </div>
      )}
      <div className={`max-w-[75%] px-3.5 py-2.5 rounded-[18px] text-[15px] leading-relaxed ${
        isUser ? 'bg-wiki-blue text-white rounded-br-[4px]' : 'bg-wiki-bg-secondary text-wiki-text rounded-bl-[4px]'
      }`}>
        {msg.content}
      </div>
    </div>
  )
}

function getActionStyle(icon: string): { bgClass: string; textClass: string; emoji: string } {
  if (icon.includes('checkmark')) return { bgClass: 'bg-green-500/[0.08]', textClass: 'text-green-600', emoji: '✓ ' }
  if (icon.includes('exclamationmark') || icon.includes('triangle')) return { bgClass: 'bg-orange-500/[0.08]', textClass: 'text-orange-600', emoji: '⚠ ' }
  if (icon.includes('pencil') || icon.includes('link') || icon.includes('bubble')) return { bgClass: 'bg-wiki-blue/[0.08]', textClass: 'text-wiki-blue', emoji: '' }
  return { bgClass: 'bg-wiki-tertiary/10', textClass: 'text-wiki-secondary', emoji: '' }
}

function makeEmptyEntry(user: { id: string; display_name: string } | null): SupabaseEntry {
  return {
    id: crypto.randomUUID(),
    title: '',
    category: 'person',
    scope: 'private',
    author_name: user?.display_name || '我',
    author_id: user?.id || 'self',
    like_count: 0,
    collect_count: 0,
    comment_count: 0,
    view_count: 0,
    status: 'draft',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }
}
