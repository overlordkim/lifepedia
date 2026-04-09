import { useState, useEffect, useRef, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, MoreHorizontal, Send, Plus, X,
  Image as ImageIcon, Link, Sparkles, PenLine,
  Tag, Lock, Users, Globe, Eye, UserPlus, UserMinus,
  Trash2, Clock, ArrowRight, Heart, MessageCircle,
  Search, CheckCircle, User as UserIcon, ArrowUpCircle,
} from 'lucide-react'
import { supabaseGet, avatarURL } from '../lib/supabase'
import { fetchEntryById, upsertEntry, uploadBase64Image, deleteEntry, updateCollaborators, persistImageFromURL } from '../services/entries'
import { chat as aiChat } from '../services/ai'
import { generateImage } from '../services/imageGen'
import { addNotification } from '../services/notifications'
import { useAuth } from '../contexts/AuthContext'
import InfoboxView from '../components/entry/InfoboxView'
import FloatingActionBar from '../components/entry/FloatingActionBar'
import ShareImageSheet from '../components/entry/ShareImageSheet'
import Avatar from '../components/shared/Avatar'
import { parseWikiText } from '../utils/wiki'
import type { SupabaseEntry, EntryCategory, EntryScope, ChatMessage, AttachmentItem, Comment } from '../types'
import { SCOPE_META, CATEGORY_META } from '../types'

type AIStatus = 'thinking' | 'updatingEntry' | 'generatingImage' | null

export default function EntryPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { user } = useAuth()

  const [entry, setEntry] = useState<SupabaseEntry | null>(null)
  const [loading, setLoading] = useState(true)
  const [showChat, setShowChat] = useState(false)
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [inputText, setInputText] = useState('')
  const [aiStatus, setAiStatus] = useState<AIStatus>(null)
  const [showMoreMenu, setShowMoreMenu] = useState(false)
  const [showVisibility, setShowVisibility] = useState(false)
  const [showAttachments, setShowAttachments] = useState(false)
  const [showLinkInput, setShowLinkInput] = useState(false)
  const [linkText, setLinkText] = useState('')
  const [attachments, setAttachments] = useState<AttachmentItem[]>([])
  const [showShareSheet, setShowShareSheet] = useState(false)
  const [showShareImage, setShowShareImage] = useState(false)

  const [comments, setComments] = useState<Comment[]>([])
  const [newComment, setNewComment] = useState('')
  const [replyTarget, setReplyTarget] = useState<Comment | null>(null)
  const [commentFocused, setCommentFocused] = useState(false)
  const commentInputRef = useRef<HTMLInputElement>(null)

  const [showCollaborators, setShowCollaborators] = useState(false)

  const chatEndRef = useRef<HTMLDivElement>(null)
  const discussionRef = useRef<HTMLDivElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const canEdit = entry && user && (
    entry.author_id === user.id ||
    (entry.contributor_names || []).includes(user.display_name)
  )
  const isOwner = entry && user && entry.author_id === user.id

  const greeting = useCallback(() => {
    if (!entry || !user) return '你好，让我们一起品味这篇词条吧。'
    if (canEdit) {
      return isOwner
        ? '你好，我是你的词条编纂助手。告诉我一段回忆，我来帮你写成百科词条。'
        : '你好，你已是这篇词条的合编者，可以和我一起编辑完善它。'
    }
    return '你好，让我们一起品味这篇词条吧。你觉得哪里最打动你？'
  }, [entry, user, canEdit, isOwner])

  useEffect(() => {
    if (!id) return
    fetchEntryById(id).then(e => {
      setEntry(e)
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [id])

  useEffect(() => {
    if (entry && messages.length === 0) {
      setMessages([{ id: '0', role: 'assistant', content: greeting(), timestamp: new Date().toISOString() }])
    }
  }, [entry])

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages])

  // ── 操作 ──

  async function handleDelete() {
    if (!entry || !confirm('确定要删除这篇词条吗？')) return
    try { await deleteEntry(entry.id); navigate('/', { replace: true }) } catch (e: any) { alert('删除失败: ' + e.message) }
  }

  function handleShare() {
    if (!entry) return
    setShowShareSheet(true)
  }

  function doShareText() {
    if (!entry) return
    const text = `来看看「${entry.title}」这篇词条 — 人间词条 Lifepedia`
    if (navigator.share) {
      navigator.share({ title: entry.title, text, url: window.location.href }).catch(() => {})
    } else {
      navigator.clipboard.writeText(`${text}\n${window.location.href}`).then(() => {
        alert('已复制到剪贴板')
      }).catch(() => {
        prompt('复制下方链接分享', window.location.href)
      })
    }
    setShowShareSheet(false)
  }

  function doShareCopyLink() {
    navigator.clipboard.writeText(window.location.href).then(() => {
      alert('链接已复制')
    }).catch(() => {
      prompt('复制下方链接', window.location.href)
    })
    setShowShareSheet(false)
  }

  async function handlePublishDraft() {
    if (!entry) return
    const updated = { ...entry, status: 'published', published_at: new Date().toISOString(), updated_at: new Date().toISOString() }
    setEntry(updated)
    try { await upsertEntry(updated) } catch {}
  }

  async function handleJoinCollab() {
    if (!entry || !user) return
    const list = [...(entry.contributor_names || []), user.display_name]
    setEntry(prev => prev ? { ...prev, contributor_names: list } : prev)
    try { await updateCollaborators(entry.id, list) } catch {}
    closeMenu()
  }

  async function handleLeaveCollab() {
    if (!entry || !user) return
    const list = (entry.contributor_names || []).filter(n => n !== user.display_name)
    setEntry(prev => prev ? { ...prev, contributor_names: list } : prev)
    try { await updateCollaborators(entry.id, list) } catch {}
    closeMenu()
    navigate(-1)
  }

  function handleChangeVisibility(scope: EntryScope) {
    if (!entry) return
    const updated = { ...entry, scope }
    setEntry(updated)
    upsertEntry(updated).catch(console.error)
    setShowVisibility(false)
  }

  function closeMenu() { setShowMoreMenu(false) }
  function closeMenuThen(fn: () => void) { setShowMoreMenu(false); setTimeout(fn, 200) }

  // ── 评论 ──

  function postComment() {
    if (!entry || !newComment.trim()) return
    const myName = user?.display_name || '我'
    const parentId = replyTarget ? (replyTarget.parent_id || replyTarget.id) : undefined
    const replyToName = replyTarget?.author_name
    const c: Comment = {
      id: crypto.randomUUID(), author_name: myName, body: newComment.trim(),
      created_at: new Date().toISOString(), like_count: 0, parent_id: parentId, reply_to_name: replyToName,
    }
    setComments(prev => [...prev, c])
    setNewComment('')
    setReplyTarget(null)
    setCommentFocused(false)
  }

  function toggleCommentLike(commentId: string) {
    setComments(prev => prev.map(c => c.id === commentId ? { ...c, like_count: c.like_count > 0 ? 0 : c.like_count + 1 } : c))
  }

  // ── 附件 ──

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files; if (!files) return
    Array.from(files).forEach(file => {
      const reader = new FileReader()
      reader.onload = () => {
        const b64 = (reader.result as string).split(',')[1]
        setAttachments(prev => [...prev, { id: crypto.randomUUID(), type: 'image', name: file.name, image_base64: b64 }])
      }
      reader.readAsDataURL(file)
    })
    e.target.value = ''
  }

  // ── AI 发消息 ──

  async function sendMessage() {
    const text = inputText.trim()
    if (!text || aiStatus || !entry) return
    const imageData = attachments.filter(a => a.image_base64).map(a => a.image_base64!)
    const links = attachments.filter(a => a.link_url).map(a => a.link_url!)
    let displayText = text
    if (imageData.length) displayText = `📷×${imageData.length} ${displayText}`
    if (links.length) displayText += '\n' + links.map(u => `🔗 ${u}`).join('\n')
    const newMsg: ChatMessage = { id: crypto.randomUUID(), role: 'user', content: displayText, timestamp: new Date().toISOString() }
    const allMsgs = [...messages, newMsg]
    setMessages(allMsgs)
    setInputText('')
    setAttachments([])
    setAiStatus('thinking')
    try {
      let uploadedURLs: string[] = []
      for (const b64 of imageData) { try { uploadedURLs.push(await uploadBase64Image(b64)) } catch {} }
      const snapshot = entry.title ? { title: entry.title, subtitle: entry.subtitle || undefined, category: entry.category, infobox: entry.infobox || [], introduction: entry.introduction || undefined, sections: entry.sections || [], tags: entry.tags || [], related_entry_titles: [] } : null
      const result = await aiChat(allMsgs, snapshot, uploadedURLs, !!canEdit)
      for (const action of result.actions) setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: action, timestamp: new Date().toISOString() }])
      if (result.entry_data) {
        setAiStatus('updatingEntry')
        await new Promise(r => setTimeout(r, 500))
        setEntry(prev => {
          if (!prev) return prev
          const d = result.entry_data!
          const u = { ...prev }
          if (d.title) u.title = d.title
          if (d.subtitle !== undefined) u.subtitle = d.subtitle
          if (d.category) u.category = d.category
          if (d.infobox?.length) u.infobox = d.infobox
          if (d.introduction) u.introduction = d.introduction
          if (d.sections?.length) u.sections = d.sections
          if (d.tags?.length) u.tags = d.tags
          if (d.cover_image_url) u.cover_image_url = d.cover_image_url
          u.updated_at = new Date().toISOString()
          upsertEntry(u).catch(console.error)
          return u
        })
      }
      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: result.reply, timestamp: new Date().toISOString() }])
      if (result.image_gen_tasks.length > 0) {
        setAiStatus('generatingImage')
        for (const task of result.image_gen_tasks) {
          try {
            const tempURL = await generateImage(task.prompt)
            let finalURL: string; try { finalURL = await persistImageFromURL(tempURL) } catch { finalURL = tempURL }
            setEntry(prev => {
              if (!prev) return prev
              const sections = [...(prev.sections || [])]
              const idx = sections.findIndex(s => s.title === task.section_title)
              if (idx >= 0) sections[idx] = { ...sections[idx], image_refs: [...(sections[idx].image_refs || []), finalURL] }
              const upd = { ...prev, sections, cover_image_url: prev.cover_image_url || finalURL }
              upsertEntry(upd).catch(console.error)
              return upd
            })
            setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: `checkmark.circle|「${task.section_title}」插图已生成`, timestamp: new Date().toISOString() }])
          } catch {
            setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'system', content: `exclamationmark.triangle|插图生成失败`, timestamp: new Date().toISOString() }])
          }
        }
      }
    } catch (err: any) {
      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: `抱歉，遇到了问题：${err.message}`, timestamp: new Date().toISOString() }])
    } finally { setAiStatus(null) }
  }

  function navigateToCommentAuthor(authorName: string) {
    const myName = user?.display_name || ''
    if (authorName === myName) {
      navigate('/me')
    } else if (authorName === entry?.author_name) {
      navigate(`/user/${entry.author_id}`, { state: { name: authorName } })
    } else {
      navigate(`/user/${authorName.toLowerCase()}`, { state: { name: authorName } })
    }
  }

  // ── Loading / Empty ──

  if (loading) return <div className="flex items-center justify-center h-screen bg-white"><span className="w-8 h-8 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" /></div>
  if (!entry) return <div className="flex items-center justify-center h-screen bg-white text-wiki-tertiary">词条不存在</div>

  // ── Computed ──

  const coverURL = entry.cover_image_url || (entry.sections || []).find(s => s.image_refs?.length)?.image_refs?.[0]
  const catMeta = CATEGORY_META[entry.category as EntryCategory]
  const scopeMeta = SCOPE_META[entry.scope as EntryScope]
  const topLevel = comments.filter(c => !c.parent_id)
  const repliesMap = new Map<string, Comment[]>()
  comments.filter(c => c.parent_id).forEach(c => {
    const arr = repliesMap.get(c.parent_id!) || []
    arr.push(c)
    repliesMap.set(c.parent_id!, arr)
  })
  const totalComments = (entry.comment_count || 0) + comments.length

  return (
    <div className="flex flex-col h-screen bg-white">
      {/* ═══ 自定义顶栏 ═══ */}
      <div className="flex items-center gap-3 px-4 h-12 shrink-0 border-b border-wiki-divider/50">
        <button onClick={() => navigate(-1)} className="w-7 h-7 flex items-center justify-center">
          <ArrowLeft size={16} strokeWidth={2} className="text-wiki-text" />
        </button>

        <button className="flex items-center gap-2 min-w-0" onClick={() => {
          if (isOwner) navigate('/me')
          else navigate(`/user/${entry.author_id}`, { state: { name: entry.author_name } })
        }}>
          <Avatar userId={entry.author_id} name={entry.author_name} size={28} />
          <span className="text-sm font-semibold text-wiki-text truncate">{entry.author_name}</span>
        </button>

        <div className="flex-1" />

        {entry.status === 'draft' && (
          <>
            <span className="text-[11px] font-medium text-orange-500 px-2 py-0.5 bg-orange-500/10 rounded-full">草稿</span>
            <button onClick={handlePublishDraft} className="text-[13px] font-semibold text-white px-3.5 py-1.5 bg-wiki-blue rounded-full">发布</button>
          </>
        )}

        <button onClick={() => setShowChat(!showChat)} className="w-7 h-7 flex items-center justify-center">
          {showChat
            ? <X size={18} strokeWidth={1.5} className="text-wiki-text" />
            : canEdit
              ? <PenLine size={18} strokeWidth={1} className="text-wiki-text" />
              : <MessageCircle size={18} strokeWidth={1} className="text-wiki-text" />
          }
        </button>

        {entry.status !== 'draft' && (
          <div className="relative">
            <button onClick={() => setShowMoreMenu(!showMoreMenu)} className="w-7 h-7 flex items-center justify-center">
              <MoreHorizontal size={18} strokeWidth={2} className="text-wiki-text" />
            </button>

            {showMoreMenu && (
              <>
                <div className="fixed inset-0 z-40 bg-black/15" onClick={closeMenu} />
                <div className="absolute right-0 top-[36px] w-[220px] bg-white/90 backdrop-blur-2xl rounded-[14px] shadow-[0_8px_20px_rgba(0,0,0,0.12),0_0_1px_rgba(0,0,0,0.06)] border-[0.5px] border-white/20 z-50 py-1.5">
                  {isOwner && (
                    <MoreMenuItem
                      icon={<ScopeIcon scope={entry.scope as EntryScope} />}
                      label="可见性"
                      subtitle={scopeMeta?.label}
                      onClick={() => closeMenuThen(() => setShowVisibility(true))}
                    />
                  )}
                  {(entry.scope === 'collaborative' || entry.scope === 'public') && (
                    <MoreMenuItem
                      icon={<Users size={14} />}
                      label="合编者"
                      subtitle={`${(entry.contributor_names || []).length} 人`}
                      onClick={() => closeMenuThen(() => setShowCollaborators(true))}
                    />
                  )}
                  {canEdit && !isOwner && (
                    <>
                      <MenuDivider />
                      <MoreMenuItem icon={<UserMinus size={14} />} label="退出合编" destructive onClick={handleLeaveCollab} />
                    </>
                  )}
                  {!canEdit && !(entry.contributor_names || []).includes(user?.display_name || '') && (
                    <MoreMenuItem icon={<UserPlus size={14} />} label="加入合编" onClick={handleJoinCollab} />
                  )}
                  {isOwner && (
                    <>
                      <MenuDivider />
                      <MoreMenuItem icon={<Trash2 size={14} />} label="删除" destructive onClick={() => closeMenuThen(handleDelete)} />
                    </>
                  )}
                </div>
              </>
            )}
          </div>
        )}
      </div>

      {/* ═══ 主内容 ═══ */}
      <div className="flex-1 overflow-hidden flex flex-col">
        <div className={`overflow-y-auto ${showChat ? 'h-[40%]' : 'flex-1'}`}>
          <div className={showChat ? '' : 'pb-20'}>
            {/* ── Hero ── */}
            <HeroImage url={coverURL} title={entry.title} />

            <div className="px-4 pt-5 space-y-5">
              {/* ── 标题 ── */}
              <div>
                <h1 className={`font-serif text-[24px] leading-tight font-bold ${entry.title ? 'text-wiki-text' : 'text-wiki-tertiary'}`}>
                  {entry.title || '未命名词条'}
                </h1>
                {entry.subtitle && <p className="text-[14px] text-wiki-secondary mt-1">{entry.subtitle}</p>}
                <div className="flex items-center gap-3 mt-2 text-[12px] text-wiki-tertiary">
                  <span className="flex items-center gap-1"><Tag size={11} />{catMeta?.label || entry.category}</span>
                  <span className="flex items-center gap-1"><ScopeIcon scope={entry.scope as EntryScope} size={11} />{scopeMeta?.label || entry.scope}</span>
                  {entry.status === 'draft' && <span className="text-wiki-red flex items-center gap-1"><PenLine size={11} />草稿</span>}
                </div>
                <div className="h-px bg-wiki-divider mt-3" />
              </div>

              {/* ── 信息框 ── */}
              <InfoboxView category={entry.category as EntryCategory} fields={entry.infobox || []} />

              {/* ── 引言 ── */}
              {entry.introduction && (
                <p className="text-[15px] leading-[1.8] text-wiki-text">{entry.introduction}</p>
              )}

              {/* ── 章节 ── */}
              {(entry.sections || []).map((sec, i) => (
                <div key={i}>
                  <div className="mb-2.5">
                    <h2 className="font-serif text-[18px] font-bold text-wiki-text">{sec.title}</h2>
                    <div className="h-px bg-wiki-divider mt-1" />
                  </div>
                  <div className="text-[15px] leading-[1.8] text-wiki-text whitespace-pre-wrap">{parseWikiText(sec.body)}</div>
                  {(sec.image_refs || []).map((url, j) => (
                    <SectionImage key={j} url={url} />
                  ))}
                </div>
              ))}

              {/* ── 相关条目（relatedEntryTitles 未存储在Supabase中，暂用空占位） ── */}

              {/* ── 修订历史 ── */}
              {/* revisions 未存储到 Supabase，占位 */}

              {/* ── 标签 ── */}
              {entry.tags && entry.tags.length > 0 && (
                <div>
                  <div className="h-px bg-wiki-divider" />
                  <div className="flex flex-wrap gap-2 mt-3">
                    {entry.tags.map(tag => (
                      <span key={tag} className="px-2.5 py-1 text-[12px] italic text-wiki-tertiary border border-wiki-border/50 rounded">
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              <div className="h-5" />

              {/* ═══ 讨论区 ═══ */}
              <div ref={discussionRef}>
                <div className="h-2 bg-wiki-bg-secondary -mx-4" />

                <div className="flex items-center gap-2 py-3.5" id="discussion-header">
                  <MessageCircle size={14} strokeWidth={2} className="text-wiki-text" />
                  <span className="text-[16px] font-semibold text-wiki-text">讨论</span>
                  <span className="text-[13px] font-medium text-wiki-tertiary">{totalComments}</span>
                </div>

                {totalComments === 0 ? (
                  <div className="text-center py-8">
                    <MessageCircle size={28} strokeWidth={0.5} className="mx-auto text-wiki-tertiary mb-2.5" />
                    <p className="text-[14px] text-wiki-tertiary">还没有讨论，来说点什么吧</p>
                  </div>
                ) : (
                  <div>
                    {topLevel.map(comment => (
                      <div key={comment.id}>
                        <CommentRow comment={comment} entry={entry} currentUserId={user?.id}
                          onReply={() => { setReplyTarget(comment); commentInputRef.current?.focus() }}
                          onLike={() => toggleCommentLike(comment.id)}
                          onNavigate={navigateToCommentAuthor}
                        />
                        {(repliesMap.get(comment.id) || []).map(reply => (
                          <CommentReplyRow key={reply.id} reply={reply} entry={entry} currentUserId={user?.id}
                            onReply={() => { setReplyTarget(reply); commentInputRef.current?.focus() }}
                            onLike={() => toggleCommentLike(reply.id)}
                            onNavigate={navigateToCommentAuthor}
                          />
                        ))}
                      </div>
                    ))}
                  </div>
                )}

                {/* 评论输入 */}
                <div className="py-2.5">
                  {replyTarget && (
                    <div className="flex items-center gap-1.5 px-4 py-1.5 bg-wiki-bg-secondary text-[12px] text-wiki-secondary">
                      <span>回复 @{replyTarget.author_name}</span>
                      <button onClick={() => setReplyTarget(null)} className="ml-auto"><X size={14} className="text-wiki-tertiary" /></button>
                    </div>
                  )}
                  <div className="flex items-center gap-2.5">
                    <div className="w-[30px] h-[30px] rounded-full bg-wiki-blue/[0.12] flex items-center justify-center shrink-0">
                      <UserIcon size={12} className="text-wiki-blue" />
                    </div>
                    <input
                      ref={commentInputRef}
                      type="text"
                      value={newComment}
                      onChange={e => setNewComment(e.target.value)}
                      onKeyDown={e => e.key === 'Enter' && !e.nativeEvent.isComposing && postComment()}
                      onFocus={() => setCommentFocused(true)}
                      onBlur={() => setCommentFocused(false)}
                      placeholder={replyTarget ? `回复 @${replyTarget.author_name}…` : '说点什么…'}
                      className="flex-1 px-3 py-2 text-[14px] bg-wiki-bg-secondary rounded-[18px]"
                    />
                    {newComment.trim() && (
                      <button onClick={postComment} className="transition-transform active:scale-90">
                        <Send size={26} className="text-wiki-blue" />
                      </button>
                    )}
                  </div>
                </div>
              </div>

              <div className="h-10" />
            </div>
          </div>
        </div>

        {/* ═══ 聊天面板 ═══ */}
        {showChat && (
          <>
            <div className="h-px bg-wiki-divider shrink-0" />
            <div className="flex-1 flex flex-col overflow-hidden">
              {/* 消息区 */}
              <div className="flex-1 overflow-y-auto py-3 space-y-2.5">
                {messages.map(msg => <ChatBubble key={msg.id} msg={msg} />)}
                {aiStatus && <AIStatusBubble status={aiStatus} />}
                <div ref={chatEndRef} />
              </div>

              {/* 附件条 */}
              {attachments.length > 0 && (
                <div className="flex gap-2 px-3 py-1.5 overflow-x-auto no-scrollbar border-t border-wiki-divider">
                  {attachments.map(a => (
                    <div key={a.id} className="flex items-center gap-1.5 px-2.5 py-1 bg-wiki-bg-secondary rounded-full text-[12px] shrink-0 border border-wiki-border/50 text-wiki-secondary">
                      {a.type === 'image' ? <ImageIcon size={12} /> : <Link size={12} />}
                      <span className="max-w-[80px] truncate">{a.name}</span>
                      <button onClick={() => setAttachments(prev => prev.filter(x => x.id !== a.id))}><X size={10} className="text-wiki-tertiary" /></button>
                    </div>
                  ))}
                </div>
              )}

              {/* 输入栏 */}
              <div className="flex items-center gap-3 px-3 py-2 border-t border-wiki-divider shrink-0 bg-white safe-bottom relative">
                <button onClick={() => setShowAttachments(!showAttachments)}>
                  <Plus size={20} strokeWidth={1} className={`text-wiki-tertiary transition-transform duration-200 ${showAttachments ? 'rotate-45' : ''}`} />
                </button>
                <input
                  type="text" value={inputText}
                  onChange={e => setInputText(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && !e.nativeEvent.isComposing && sendMessage()}
                  placeholder="说点什么……"
                  className="flex-1 px-3 py-2 text-[15px] bg-wiki-bg-secondary rounded-[20px]"
                />
                <button onClick={sendMessage} disabled={!inputText.trim() || !!aiStatus}>
                  <ArrowUpCircle size={28} className={!inputText.trim() || aiStatus ? 'text-wiki-tertiary' : 'text-wiki-blue'} fill={!inputText.trim() || aiStatus ? 'transparent' : 'currentColor'} />
                </button>

                {showAttachments && (
                  <div className="absolute bottom-full left-3 mb-2 bg-white rounded-[14px] shadow-[0_4px_12px_rgba(0,0,0,0.08)] p-3 flex gap-4 z-50">
                    <button onClick={() => { fileInputRef.current?.click(); setShowAttachments(false) }} className="flex flex-col items-center gap-1.5 w-[72px] h-16 bg-wiki-bg-secondary rounded-[10px] justify-center">
                      <ImageIcon size={22} className="text-wiki-blue" /><span className="text-[11px] text-wiki-secondary">相册</span>
                    </button>
                    <button onClick={() => { setShowLinkInput(true); setShowAttachments(false) }} className="flex flex-col items-center gap-1.5 w-[72px] h-16 bg-wiki-bg-secondary rounded-[10px] justify-center">
                      <Link size={22} className="text-wiki-blue" /><span className="text-[11px] text-wiki-secondary">链接</span>
                    </button>
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>

      {/* ═══ 底部浮动栏 ═══ */}
      {!showChat && (
        <FloatingActionBar
          likeCount={entry.like_count} commentCount={totalComments} collectCount={entry.collect_count}
          onCommentClick={() => discussionRef.current?.scrollIntoView({ behavior: 'smooth' })}
          onShare={handleShare}
        />
      )}

      <input ref={fileInputRef} type="file" accept="image/*" multiple className="hidden" onChange={handleFileChange} />

      {/* ═══ 可见性 Sheet ═══ */}
      {showVisibility && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={() => setShowVisibility(false)}>
          <div className="bg-white rounded-t-2xl w-full max-w-lg pb-safe" onClick={e => e.stopPropagation()}>
            <p className="text-center font-semibold py-4 border-b border-wiki-divider">词条可见性</p>
            {(['private','collaborative','public'] as EntryScope[]).map(s => (
              <button key={s} onClick={() => handleChangeVisibility(s)}
                className={`w-full flex items-center gap-3 px-5 py-3.5 active:bg-wiki-bg-secondary ${entry.scope === s ? 'bg-wiki-blue/[0.03]' : ''}`}>
                <ScopeIcon scope={s} size={20} />
                <div className="text-left flex-1">
                  <p className={`text-[15px] ${entry.scope === s ? 'font-semibold text-wiki-blue' : ''}`}>{SCOPE_META[s].label}</p>
                  <p className="text-[12px] text-wiki-tertiary">{s === 'private' ? '仅自己可见' : s === 'collaborative' ? '邀请他人一起编辑' : '所有人可见'}</p>
                </div>
                {entry.scope === s && <span className="text-wiki-blue font-bold">✓</span>}
              </button>
            ))}
            <button onClick={() => setShowVisibility(false)} className="w-full py-4 text-wiki-tertiary border-t border-wiki-divider">取消</button>
          </div>
        </div>
      )}

      {/* ═══ 分享 Sheet ═══ */}
      {showShareSheet && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={() => setShowShareSheet(false)}>
          <div className="bg-white rounded-t-2xl w-full max-w-lg pb-safe" onClick={e => e.stopPropagation()}>
            <p className="text-center font-semibold py-4 border-b border-wiki-divider">分享</p>
            <button onClick={() => { setShowShareSheet(false); setTimeout(() => setShowShareImage(true), 200) }} className="w-full flex items-center gap-3 px-5 py-3.5 active:bg-wiki-bg-secondary">
              <ImageIcon size={18} className="text-wiki-blue" />
              <span className="text-[15px]">生成长图</span>
            </button>
            <button onClick={doShareText} className="w-full flex items-center gap-3 px-5 py-3.5 active:bg-wiki-bg-secondary">
              <Send size={18} className="text-wiki-blue" />
              <span className="text-[15px]">分享文字</span>
            </button>
            <button onClick={doShareCopyLink} className="w-full flex items-center gap-3 px-5 py-3.5 active:bg-wiki-bg-secondary">
              <Link size={18} className="text-wiki-blue" />
              <span className="text-[15px]">复制链接</span>
            </button>
            <button onClick={() => setShowShareSheet(false)} className="w-full py-4 text-wiki-tertiary border-t border-wiki-divider">取消</button>
          </div>
        </div>
      )}

      {/* ═══ 分享长图 ═══ */}
      {showShareImage && entry && (
        <ShareImageSheet entry={entry} onClose={() => setShowShareImage(false)} />
      )}

      {/* ═══ 合编者 Sheet ═══ */}
      {showCollaborators && entry && (
        <CollaboratorsSheet
          entry={entry}
          isOwner={!!isOwner}
          currentUserId={user?.id || ''}
          currentUserName={user?.display_name || ''}
          onClose={() => setShowCollaborators(false)}
          onUpdate={(names) => {
            setEntry(prev => prev ? { ...prev, contributor_names: names } : prev)
            updateCollaborators(entry.id, names).catch(console.error)
          }}
        />
      )}

      {/* ═══ 链接输入 ═══ */}
      {showLinkInput && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35" onClick={() => setShowLinkInput(false)}>
          <div className="bg-white rounded-2xl w-[300px] p-5 space-y-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center gap-2"><Link size={15} className="text-wiki-blue" /><span className="text-[16px] font-semibold">粘贴链接</span></div>
            <input type="url" value={linkText} onChange={e => setLinkText(e.target.value)} placeholder="https://..." className="w-full px-3.5 py-2.5 bg-wiki-bg-secondary rounded-lg text-[15px]" autoFocus />
            <div className="flex gap-3">
              <button onClick={() => { setLinkText(''); setShowLinkInput(false) }} className="flex-1 py-2.5 text-[15px] text-wiki-secondary bg-wiki-bg-secondary rounded-lg">取消</button>
              <button onClick={() => { if (linkText.trim()) setAttachments(prev => [...prev, { id: crypto.randomUUID(), type: 'link', name: linkText.trim(), link_url: linkText.trim() }]); setLinkText(''); setShowLinkInput(false) }} className="flex-1 py-2.5 text-[15px] text-white bg-wiki-blue rounded-lg font-semibold">添加</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ═══ 更多菜单项 ═══

function MoreMenuItem({ icon, label, subtitle, destructive, onClick }: { icon: React.ReactNode; label: string; subtitle?: string; destructive?: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} className="w-full flex items-center gap-2.5 px-4 py-2.5 active:bg-black/[0.04]">
      <span className={`w-5 flex justify-center ${destructive ? 'text-red-500' : 'text-wiki-secondary'}`}>{icon}</span>
      <span className={`text-[15px] ${destructive ? 'text-red-500' : 'text-wiki-text'}`}>{label}</span>
      <span className="flex-1" />
      {subtitle && <span className="text-[12px] font-medium text-wiki-tertiary">{subtitle}</span>}
    </button>
  )
}

function MenuDivider() {
  return <div className="mx-4 my-0.5 h-px bg-black/[0.08]" />
}

// ═══ Scope 图标 ═══

function ScopeIcon({ scope, size = 14 }: { scope: EntryScope; size?: number }) {
  if (scope === 'private') return <Lock size={size} strokeWidth={1.5} />
  if (scope === 'collaborative') return <Users size={size} strokeWidth={1.5} />
  return <Globe size={size} strokeWidth={1.5} />
}

// ═══ Hero Image ═══

function HeroImage({ url, title }: { url?: string | null; title: string }) {
  const seed = Math.abs(hashCode(title)) % 1000
  const fallbackRatios = [4/3, 3/2, 16/9, 1]
  const fallbackRatio = fallbackRatios[seed % fallbackRatios.length]
  const hue = seed % 360

  if (url) {
    // 有图片：直接渲染，让浏览器自然撑开真实比例，不裁切
    return <img src={url} alt="" className="w-full block" loading="lazy" />
  }

  return (
    <div className="w-full flex flex-col items-center justify-center" style={{ aspectRatio: fallbackRatio, background: `linear-gradient(135deg, hsl(${hue},8%,97%), hsl(${hue},15%,90%))` }}>
      <svg className="w-8 h-8 mb-1.5" style={{ color: `hsl(${hue},10%,75%)`, opacity: 0.5 }} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
      </svg>
      {title && <span className="text-[14px] font-medium" style={{ color: `hsl(${hue},10%,60%)`, opacity: 0.6 }}>{title}</span>}
    </div>
  )
}

// ═══ 章节图片 ═══

function SectionImage({ url }: { url: string }) {
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>('loading')
  return (
    <div className="w-full mt-3">
      {status === 'loading' && (
        <div className="w-full h-[200px] bg-wiki-bg-secondary rounded-lg flex items-center justify-center">
          <span className="w-6 h-6 border-2 border-wiki-border border-t-wiki-blue rounded-full animate-spin" />
        </div>
      )}
      {status === 'error' && (
        <div className="w-full h-[120px] bg-wiki-bg-secondary rounded-lg flex items-center justify-center">
          <ImageIcon size={20} className="text-wiki-tertiary" />
        </div>
      )}
      <img
        src={url} alt=""
        className={`w-full rounded-lg shadow-[0_2px_4px_rgba(0,0,0,0.06)] ${status === 'loaded' ? '' : 'hidden'}`}
        loading="lazy"
        onLoad={() => setStatus('loaded')}
        onError={() => setStatus('error')}
      />
    </div>
  )
}

// ═══ 评论行 ═══

function CommentRow({ comment, entry, currentUserId, onReply, onLike, onNavigate }: {
  comment: Comment; entry: SupabaseEntry; currentUserId?: string
  onReply: () => void; onLike: () => void; onNavigate: (name: string) => void
}) {
  const isAuthor = comment.author_name === entry.author_name
  return (
    <div className="flex gap-2.5 px-4 py-2">
      <button onClick={() => onNavigate(comment.author_name)} className="shrink-0">
        <CommentAvatar name={comment.author_name} entryAuthorId={entry.author_id} entryAuthorName={entry.author_name} currentUserId={currentUserId} size={30} />
      </button>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <button onClick={() => onNavigate(comment.author_name)} className="text-[13px] font-semibold text-wiki-secondary">{comment.author_name}</button>
          {isAuthor && <span className="text-[10px] font-medium text-wiki-blue px-[5px] py-px bg-wiki-blue/10 rounded-full">作者</span>}
        </div>
        <p className="text-[14px] text-wiki-text mt-0.5">{comment.body}</p>
        <div className="flex items-center gap-4 mt-0.5 pt-0.5">
          <span className="text-[11px] text-wiki-tertiary">{relativeTime(comment.created_at)}</span>
          <button onClick={onReply} className="text-[11px] font-medium text-wiki-tertiary">回复</button>
          <div className="flex-1" />
          <button onClick={onLike} className="flex items-center gap-[3px]">
            <Heart size={12} className={comment.like_count > 0 ? 'text-red-400/70 fill-current' : 'text-wiki-tertiary'} />
            {comment.like_count > 0 && <span className="text-[11px] text-wiki-tertiary">{comment.like_count}</span>}
          </button>
        </div>
      </div>
    </div>
  )
}

function CommentReplyRow({ reply, entry, currentUserId, onReply, onLike, onNavigate }: {
  reply: Comment; entry: SupabaseEntry; currentUserId?: string
  onReply: () => void; onLike: () => void; onNavigate: (name: string) => void
}) {
  const isAuthor = reply.author_name === entry.author_name
  return (
    <div className="flex gap-2 pl-14 pr-4 py-1.5">
      <button onClick={() => onNavigate(reply.author_name)} className="shrink-0">
        <CommentAvatar name={reply.author_name} entryAuthorId={entry.author_id} entryAuthorName={entry.author_name} currentUserId={currentUserId} size={24} />
      </button>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1">
          <button onClick={() => onNavigate(reply.author_name)} className="text-[12px] font-semibold text-wiki-secondary">{reply.author_name}</button>
          {isAuthor && <span className="text-[9px] font-medium text-wiki-blue px-1 py-px bg-wiki-blue/10 rounded-full">作者</span>}
        </div>
        <p className="text-[13px] text-wiki-text mt-px">
          {reply.reply_to_name && <><span className="text-wiki-tertiary">回复 </span><span className="text-wiki-blue font-medium">@{reply.reply_to_name} </span></>}
          {reply.body}
        </p>
        <div className="flex items-center gap-3.5 mt-0.5">
          <span className="text-[10px] text-wiki-tertiary">{relativeTime(reply.created_at)}</span>
          <button onClick={onReply} className="text-[10px] font-medium text-wiki-tertiary">回复</button>
          <div className="flex-1" />
          <button onClick={onLike} className="flex items-center gap-[2px]">
            <Heart size={10} className={reply.like_count > 0 ? 'text-red-400/70 fill-current' : 'text-wiki-tertiary'} />
            {reply.like_count > 0 && <span className="text-[10px] text-wiki-tertiary">{reply.like_count}</span>}
          </button>
        </div>
      </div>
    </div>
  )
}

// ═══ 评论头像 ═══

function CommentAvatar({ name, entryAuthorId, entryAuthorName, currentUserId, size }: {
  name: string; entryAuthorId: string; entryAuthorName: string; currentUserId?: string; size: number
}) {
  const [failed, setFailed] = useState(false)
  const initial = (name || '?')[0]

  let userId: string | null = null
  if (currentUserId && name === (localStorage.getItem('user_display_name') || '')) {
    userId = currentUserId
  } else if (name === entryAuthorName) {
    userId = entryAuthorId
  }

  if (!userId || failed) {
    return (
      <div
        className="rounded-full bg-wiki-bg-secondary flex items-center justify-center text-wiki-secondary font-semibold shrink-0"
        style={{ width: size, height: size, fontSize: size * 0.38 }}
      >
        {initial}
      </div>
    )
  }

  return (
    <img
      src={avatarURL(userId)}
      alt={name}
      className="rounded-full object-cover shrink-0"
      style={{ width: size, height: size }}
      onError={() => setFailed(true)}
    />
  )
}

// ═══ 聊天气泡 ═══

function ChatBubble({ msg }: { msg: ChatMessage }) {
  if (msg.role === 'system') return <SystemActionCard content={msg.content} />
  const isUser = msg.role === 'user'
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} px-4`}>
      {!isUser && (
        <div className="w-[26px] h-[26px] rounded-full bg-gradient-to-br from-wiki-blue/15 to-wiki-blue/5 flex items-center justify-center mr-2 shrink-0 mt-1">
          <Sparkles size={11} className="text-wiki-blue" />
        </div>
      )}
      <div className={`max-w-[75%] px-3.5 py-2.5 rounded-[18px] text-[15px] leading-relaxed ${
        isUser
          ? 'bg-wiki-blue text-white rounded-br-[4px]'
          : 'bg-wiki-bg-secondary text-wiki-text rounded-bl-[4px]'
      }`}>
        {msg.content}
      </div>
      {isUser && <div className="w-0" />}
    </div>
  )
}

function SystemActionCard({ content }: { content: string }) {
  const parts = content.split('|')
  const icon = parts.length > 1 ? parts[0] : 'sparkles'
  const text = parts.length > 1 ? parts[1] : content
  const style = getActionStyle(icon)

  return (
    <div className="flex justify-center py-0.5">
      <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[12px] font-medium ${style.bgClass} ${style.textClass}`}>
        {style.emoji}{text}
      </span>
    </div>
  )
}

function getActionStyle(icon: string): { bgClass: string; textClass: string; emoji: string } {
  if (icon.includes('checkmark')) return { bgClass: 'bg-green-500/[0.08]', textClass: 'text-green-600', emoji: '✓ ' }
  if (icon.includes('exclamationmark') || icon.includes('triangle')) return { bgClass: 'bg-orange-500/[0.08]', textClass: 'text-orange-600', emoji: '⚠ ' }
  if (icon.includes('pencil') || icon.includes('link') || icon.includes('bubble')) return { bgClass: 'bg-wiki-blue/[0.08]', textClass: 'text-wiki-blue', emoji: '' }
  return { bgClass: 'bg-wiki-tertiary/10', textClass: 'text-wiki-secondary', emoji: '' }
}

function AIStatusBubble({ status }: { status: AIStatus }) {
  const labels: Record<string, string> = { thinking: '正在思考', updatingEntry: '正在编纂词条', generatingImage: '正在生成插图' }
  return (
    <div className="flex items-start gap-2 px-4 pl-[50px]">
      <div className="flex items-center gap-2 px-3.5 py-2.5 bg-wiki-bg-secondary rounded-2xl">
        <Sparkles size={12} className="text-wiki-blue animate-pulse" />
        <span className="text-[13px] text-wiki-secondary">{labels[status || '']}</span>
        <span className="flex gap-1">
          {[0, 1, 2].map(i => (
            <span key={i} className="w-1 h-1 bg-wiki-tertiary rounded-full animate-bounce" style={{ animationDelay: `${i * 150}ms` }} />
          ))}
        </span>
      </div>
    </div>
  )
}

// ═══ 合编者 Sheet ═══

function CollaboratorsSheet({ entry, isOwner, currentUserId, currentUserName, onClose, onUpdate }: {
  entry: SupabaseEntry; isOwner: boolean; currentUserId: string; currentUserName: string
  onClose: () => void; onUpdate: (names: string[]) => void
}) {
  const [searchText, setSearchText] = useState('')
  const [searchResults, setSearchResults] = useState<{ name: string; id: string }[]>([])
  const [nameToId, setNameToId] = useState<Record<string, string>>({})
  const [isSyncing, setIsSyncing] = useState(false)
  const searchRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const collaborators = entry.contributor_names || []
  const isCollaborator = collaborators.includes(currentUserName)

  useEffect(() => {
    if (!collaborators.length) return
    const nameList = collaborators.map(n => `"${n}"`).join(',')
    supabaseGet<{ id: string; display_name: string }[]>(`users?display_name=in.(${nameList})&select=id,display_name`).then(rows => {
      const map: Record<string, string> = {}
      rows.forEach(r => { map[r.display_name] = r.id })
      setNameToId(map)
    }).catch(() => {})
  }, [])

  useEffect(() => {
    if (searchRef.current) clearTimeout(searchRef.current)
    if (!searchText.trim()) { setSearchResults([]); return }
    searchRef.current = setTimeout(async () => {
      try {
        const q = encodeURIComponent(searchText)
        const rows = await supabaseGet<{ id: string; display_name: string }[]>(`users?display_name=ilike.*${q}*&select=id,display_name&limit=10`)
        const filtered = rows.filter(r => r.id !== entry.author_id && !collaborators.includes(r.display_name))
          .map(r => ({ name: r.display_name, id: r.id }))
        setSearchResults(filtered)
      } catch { setSearchResults([]) }
    }, 300)
    return () => { if (searchRef.current) clearTimeout(searchRef.current) }
  }, [searchText])

  function addCollab(name: string, userId: string) {
    if (collaborators.includes(name)) return
    const list = [...collaborators, name]
    setNameToId(prev => ({ ...prev, [name]: userId }))
    setSearchText('')
    setSearchResults([])
    onUpdate(list)
  }

  function removeCollab(name: string) {
    const list = collaborators.filter(n => n !== name)
    onUpdate(list)
  }

  function joinCollab() {
    addCollab(currentUserName, currentUserId)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35" onClick={onClose}>
      <div className="bg-white rounded-t-2xl w-full max-w-lg max-h-[70vh] flex flex-col pb-safe" onClick={e => e.stopPropagation()}>
        {/* 顶栏 */}
        <div className="flex items-center px-4 h-12 shrink-0">
          <button onClick={onClose} className="w-7 h-7 flex items-center justify-center">
            <X size={14} strokeWidth={2} className="text-wiki-text" />
          </button>
          <span className="flex-1" />
          <span className="text-[16px] font-semibold text-wiki-text">合编者</span>
          <span className="flex-1" />
          <div className="w-7" />
        </div>
        <div className="h-px bg-wiki-divider" />

        <div className="flex-1 overflow-y-auto">
          {/* 创建者 */}
          <CollabMemberRow
            name={entry.author_name}
            odUserId={entry.author_id}
            role="创建者"
            isCreator
          />

          {/* 合编者列表 */}
          {collaborators.map(name => (
            <CollabMemberRow
              key={name}
              name={name}
              odUserId={nameToId[name]}
              role="合编者"
              showRemove={isOwner}
              onRemove={() => removeCollab(name)}
            />
          ))}

          <div className="mx-4 my-2 h-px bg-wiki-divider" />

          {/* 搜索邀请 (owner) / 加入 (non-owner) / 已是合编者提示 */}
          {isOwner ? (
            <div className="px-4 py-2 space-y-2">
              <div className="flex items-center gap-2 px-3 py-2.5 bg-wiki-bg-secondary rounded-lg">
                <Search size={14} className="text-wiki-tertiary shrink-0" />
                <input
                  ref={inputRef}
                  type="text"
                  value={searchText}
                  onChange={e => setSearchText(e.target.value)}
                  placeholder="搜索用户名…"
                  className="flex-1 text-[14px] bg-transparent outline-none"
                  autoFocus
                />
              </div>
              {searchResults.length > 0 ? (
                searchResults.map(u => (
                  <div key={u.id} className="flex items-center gap-3 py-1.5">
                    <CollabAvatar userId={u.id} name={u.name} size={36} />
                    <span className="flex-1 text-[14px] font-medium text-wiki-text">{u.name}</span>
                    <button
                      onClick={() => addCollab(u.name, u.id)}
                      className="text-[12px] font-semibold text-white px-3.5 py-1.5 bg-wiki-blue rounded-full"
                    >
                      邀请
                    </button>
                  </div>
                ))
              ) : searchText.trim() ? (
                <p className="text-[13px] text-wiki-tertiary pt-1">没有找到用户</p>
              ) : null}
            </div>
          ) : !isCollaborator ? (
            <div className="px-4 py-2">
              <button
                onClick={joinCollab}
                className="w-full flex items-center justify-center gap-2 py-3 bg-wiki-blue/[0.06] rounded-[10px]"
              >
                <UserPlus size={14} className="text-wiki-blue" />
                <span className="text-[14px] font-medium text-wiki-blue">加入合编</span>
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-2 px-4 py-3">
              <CheckCircle size={16} className="text-green-500" />
              <span className="text-[14px] text-wiki-secondary">你已是该词条的合编者</span>
            </div>
          )}
        </div>

        {/* 底部提示 */}
        <div className="border-t border-wiki-divider bg-white py-3 px-4">
          <p className="text-[12px] text-wiki-tertiary text-center">
            {isOwner ? '搜索用户并邀请 ta 成为合编者' : '合编者可以与词条的 AI 对话并编辑内容'}
          </p>
        </div>
      </div>
    </div>
  )
}

function CollabMemberRow({ name, odUserId, role, isCreator, showRemove, onRemove }: {
  name: string; odUserId?: string; role: string; isCreator?: boolean; showRemove?: boolean; onRemove?: () => void
}) {
  return (
    <div className="flex items-center gap-3 px-4 py-2.5">
      <CollabAvatar userId={odUserId} name={name} size={40} />
      <div className="flex-1 min-w-0">
        <p className="text-[15px] font-medium text-wiki-text">{name}</p>
        <p className="text-[12px] text-wiki-tertiary">{role}</p>
      </div>
      {isCreator && (
        <span className="text-[11px] font-medium text-wiki-blue px-2 py-1 bg-wiki-blue/10 rounded-full">创建者</span>
      )}
      {showRemove && onRemove && (
        <button onClick={onRemove} className="w-[26px] h-[26px] flex items-center justify-center bg-wiki-bg-secondary rounded-full">
          <X size={11} strokeWidth={2} className="text-wiki-tertiary" />
        </button>
      )}
    </div>
  )
}

function CollabAvatar({ userId, name, size }: { userId?: string; name: string; size: number }) {
  const [failed, setFailed] = useState(false)
  const initial = (name || '?')[0]

  if (!userId || failed) {
    return (
      <div
        className="rounded-full bg-wiki-bg-secondary flex items-center justify-center text-wiki-secondary font-semibold shrink-0"
        style={{ width: size, height: size, fontSize: size * 0.35 }}
      >
        {initial}
      </div>
    )
  }
  return (
    <img
      src={avatarURL(userId)}
      alt={name}
      className="rounded-full object-cover shrink-0"
      style={{ width: size, height: size }}
      onError={() => setFailed(true)}
    />
  )
}

// ═══ 工具函数 ═══

function relativeTime(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const sec = diff / 1000
  if (sec < 60) return '刚刚'
  if (sec < 3600) return `${Math.floor(sec / 60)}分钟前`
  if (sec < 86400) return `${Math.floor(sec / 3600)}小时前`
  if (sec < 604800) return `${Math.floor(sec / 86400)}天前`
  const d = new Date(dateStr)
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

function hashCode(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0
  return h
}
