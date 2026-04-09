// 七大分类
export type EntryCategory = 'person' | 'place' | 'companion' | 'taste' | 'keepsake' | 'moment' | 'era'

export const CATEGORY_META: Record<EntryCategory, { label: string; subtitle: string; defaultInfoboxKeys: string[] }> = {
  person:    { label: '人物', subtitle: '那些走进过你生命的人', defaultInfoboxKeys: ['全名','生年','卒年','关系','籍贯','职业','状态'] },
  place:     { label: '栖居', subtitle: '那些容纳过你生活的地方', defaultInfoboxKeys: ['地点名','类型','位置','建成','现状','作者居住时期'] },
  companion: { label: '相伴', subtitle: '那些陪过你的非人之物', defaultInfoboxKeys: ['名字','物种','品种','性别','毛色','性情','状态'] },
  taste:     { label: '滋味', subtitle: '那些喂养过你的食物', defaultInfoboxKeys: ['菜名','类型','菜系','创制者','关键食材','传承状态'] },
  keepsake:  { label: '旧物', subtitle: '那些被你拥有过的东西', defaultInfoboxKeys: ['物品名','类型','来历','获得时间','当前状态'] },
  moment:    { label: '际遇', subtitle: '那些发生过的事', defaultInfoboxKeys: ['事件名','类型','日期','地点','参与者'] },
  era:       { label: '流年', subtitle: '那些走过的时期', defaultInfoboxKeys: ['时期名','开始','结束','作者年龄','主要居所'] },
}

export const ALL_CATEGORIES: EntryCategory[] = ['person','place','companion','taste','keepsake','moment','era']

// 三个域
export type EntryScope = 'private' | 'collaborative' | 'public'

export const SCOPE_META: Record<EntryScope, { label: string; icon: string }> = {
  private:       { label: '私人', icon: 'Lock' },
  collaborative: { label: '合编', icon: 'Users' },
  public:        { label: '公共', icon: 'Globe' },
}

// 信息框
export interface InfoboxField {
  key: string
  value: string
}

// 章节
export interface EntrySection {
  title: string
  body: string
  image_refs?: string[]
}

// 图片
export interface EntryImage {
  id: string
  url: string
  caption: string
  is_ai_generated: boolean
}

// 修订记录
export interface Revision {
  id: string
  editor_name: string
  timestamp: string
  summary: string
}

// 评论
export interface Comment {
  id: string
  author_name: string
  author_avatar?: string
  body: string
  created_at: string
  like_count: number
  parent_id?: string
  reply_to_name?: string
}

// 聊天
export type ChatRole = 'user' | 'assistant' | 'system'

export interface ChatMessage {
  id: string
  role: ChatRole
  content: string
  timestamp: string
}

// 词条状态
export type EntryStatus = 'draft' | 'published'

// Supabase entries 表结构
export interface SupabaseEntry {
  id: string
  title: string
  subtitle?: string | null
  category: string
  scope: string
  infobox?: InfoboxField[] | null
  introduction?: string | null
  sections?: EntrySection[] | null
  tags?: string[] | null
  cover_image_url?: string | null
  author_name: string
  author_id: string
  contributor_names?: string[] | null
  like_count: number
  collect_count: number
  comment_count: number
  view_count: number
  status: string
  created_at: string
  updated_at: string
  published_at?: string | null
}

// 用户
export interface UserProfile {
  id: string
  username: string
  display_name: string
  bio: string
  avatar_seed: number
}

// 简化用户
export interface SimpleUser {
  id: string
  display_name: string
  avatar_seed: number
}

// 通知
export type NotificationType = 'comment' | 'like' | 'follow' | 'coEdit' | 'aiUpdate' | 'collabInvite' | 'collabRequest'

export const NOTIFICATION_ICONS: Record<NotificationType, string> = {
  comment: 'MessageSquare',
  like: 'Heart',
  follow: 'UserPlus',
  coEdit: 'Users',
  aiUpdate: 'Sparkles',
  collabInvite: 'Mail',
  collabRequest: 'Hand',
}

export interface AppNotification {
  id: string
  type: NotificationType
  title: string
  body: string
  related_entry_id?: string | null
  from_user_name?: string | null
  from_user_id?: string | null
  is_read: boolean
  created_at: string
}

// AI 结果
export interface AIEntryData {
  title?: string
  subtitle?: string
  category?: string
  infobox?: InfoboxField[]
  introduction?: string
  sections?: EntrySection[]
  tags?: string[]
  related_entry_titles?: string[]
  revision_summary?: string
  cover_image_url?: string
  image_prompts_by_section?: Record<string, string[]>
}

export interface AIResult {
  reply: string
  entry_data?: AIEntryData | null
  actions: string[]
  image_gen_tasks: { section_title: string; prompt: string }[]
}

// 草稿（localStorage）
export interface EntryDraft extends Partial<SupabaseEntry> {
  messages?: ChatMessage[]
  last_edited_at: string
}

// 附件
export type AttachmentType = 'image' | 'file' | 'link' | 'audio'

export interface AttachmentItem {
  id: string
  type: AttachmentType
  name: string
  image_base64?: string
  link_url?: string
}
