import { callEdgeFunction } from '../lib/supabase'
import { ARK_MODEL } from '../lib/supabase'
import type { ChatMessage, InfoboxField, EntrySection, AIEntryData, AIResult } from '../types'

interface EntrySnapshot {
  title: string
  subtitle?: string
  category: string
  infobox: InfoboxField[]
  introduction?: string
  sections: EntrySection[]
  tags: string[]
  related_entry_titles: string[]
}

const SYSTEM_PROMPT = `你是「人间词条」(Lifepedia) 的 AI 编纂助手。你帮助用户把个人记忆写成维基百科风格的词条。

═══ 一、你的角色 ═══
你既是温暖的倾听者，也是严谨的百科编纂者。
- 倾听时：好奇、共情、引导用户回忆更多细节（时间、地点、感官、对话）
- 编纂时：用第三人称、百科中立语气书写，但保留情感温度

═══ 二、词条完整结构 ═══
title / subtitle / category / infobox / introduction / sections / tags / related_entry_titles / revision_summary

═══ 三、七大分类 ═══
person（人物）、place（栖居）、companion（相伴）、taste（滋味）、keepsake（旧物）、moment（际遇）、era（流年）

═══ 四、Wiki 标记语法 ═══
1. [[蓝色链接]] — 链接到已存在的相关词条
2. {{红色链接}} — 链接到尚未创建的词条
3. [来源请求] — 标记不确定信息

═══ 五、工具使用策略 ═══
核心：每一轮对话都应有所改动！
1. reply_to_user — 仅聊天
2. update_entry — 回复 + 更新词条（★首选★）
3. fetch_url_content — 获取链接
4. generate_image — 为章节生成插图

═══ 六、写作风格 ═══
- 引言：第三人称，有文学性
- 正文：百科中立 + 情感温度
- infobox value 必须是字符串
- reply 中不提及技术细节`

const READONLY_SYSTEM_PROMPT = `你是「人间词条」(Lifepedia) 的 AI 品读助手。你正在帮助用户品味一篇别人创作的词条。
你不能修改词条。你可以帮用户理解词条内容、发现有趣的细节、分享感受。`

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'update_entry',
      description: '回复用户并更新词条。所有字段代表词条的完整最新状态（全量覆盖）。',
      parameters: {
        type: 'object',
        properties: {
          reply: { type: 'string', description: '回复给用户的话' },
          title: { type: 'string' },
          subtitle: { type: 'string' },
          category: { type: 'string', enum: ['person','place','companion','taste','keepsake','moment','era'] },
          infobox: { type: 'array', items: { type: 'object', properties: { key: { type: 'string' }, value: { type: 'string' } }, required: ['key','value'] } },
          introduction: { type: 'string' },
          sections: { type: 'array', items: { type: 'object', properties: { title: { type: 'string' }, body: { type: 'string' }, image_refs: { type: 'array', items: { type: 'string' } }, image_prompts: { type: 'array', items: { type: 'string' } } }, required: ['title','body'] } },
          tags: { type: 'array', items: { type: 'string' } },
          related_entry_titles: { type: 'array', items: { type: 'string' } },
          cover_image_url: { type: 'string' },
          revision_summary: { type: 'string' },
        },
        required: ['reply','title','category','infobox','introduction','sections','tags','revision_summary'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'reply_to_user',
      description: '只回复用户，不修改词条。',
      parameters: { type: 'object', properties: { message: { type: 'string' } }, required: ['message'] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'fetch_url_content',
      description: '获取网页链接文本内容。',
      parameters: { type: 'object', properties: { url: { type: 'string' } }, required: ['url'] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'generate_image',
      description: '为词条章节生成插图。',
      parameters: {
        type: 'object',
        properties: {
          section_title: { type: 'string' },
          prompt: { type: 'string' },
          reply: { type: 'string' },
        },
        required: ['section_title','prompt','reply'],
      },
    },
  },
]

function buildMessages(
  messages: ChatMessage[],
  currentEntry: EntrySnapshot | null,
  uploadedImageURLs: string[],
  canEdit: boolean,
) {
  const prompt = canEdit ? SYSTEM_PROMPT : READONLY_SYSTEM_PROMPT
  const apiMessages: Record<string, unknown>[] = [{ role: 'system', content: prompt }]

  if (currentEntry && (currentEntry.title || currentEntry.sections.length || currentEntry.introduction)) {
    const prefix = canEdit ? '【当前词条完整状态】' : '【当前词条内容（只读）】'
    apiMessages.push({ role: 'system', content: `${prefix}\n${JSON.stringify(currentEntry, null, 2)}` })
  }

  messages.forEach((msg, idx) => {
    if (msg.role === 'user') {
      const isLast = idx === messages.length - 1 || !messages.slice(idx + 1).some(m => m.role === 'user')
      if (isLast && uploadedImageURLs.length > 0) {
        const urlList = uploadedImageURLs.map((u, i) => `图片${i + 1}: ${u}`).join('\n')
        const parts: Record<string, unknown>[] = uploadedImageURLs.map(url => ({
          type: 'image_url', image_url: { url }
        }))
        parts.push({ type: 'text', text: `${msg.content}\n\n【已上传的图片永久链接】\n${urlList}` })
        apiMessages.push({ role: 'user', content: parts })
      } else {
        apiMessages.push({ role: 'user', content: msg.content })
      }
    } else if (msg.role === 'assistant') {
      apiMessages.push({ role: 'assistant', content: msg.content })
    }
  })

  return apiMessages
}

export async function chat(
  messages: ChatMessage[],
  currentEntry: EntrySnapshot | null,
  uploadedImageURLs: string[] = [],
  canEdit = true,
): Promise<AIResult> {
  const apiMessages = buildMessages(messages, currentEntry, uploadedImageURLs, canEdit)
  const activeTools = canEdit ? TOOLS : TOOLS.filter(t => ['reply_to_user', 'fetch_url_content'].includes(t.function.name))

  const body = { model: ARK_MODEL, messages: apiMessages, tools: activeTools, temperature: 0.8, max_tokens: 4096 }
  const response = await callEdgeFunction<{
    choices: { message: { content?: string; tool_calls?: { id?: string; function: { name: string; arguments: string } }[] }; finish_reason?: string }[]
  }>('ai-chat', body)

  const choice = response.choices?.[0]
  if (!choice) return { reply: '我在想……你能再说一次吗？', entry_data: null, actions: [], image_gen_tasks: [] }

  if (choice.finish_reason !== 'tool_calls' || !choice.message.tool_calls?.length) {
    return { reply: choice.message.content || '让我再想想……', entry_data: null, actions: [], image_gen_tasks: [] }
  }

  const result: AIResult = { reply: '', entry_data: null, actions: [], image_gen_tasks: [] }

  for (const call of choice.message.tool_calls) {
    const args = tryParseJSON(call.function.arguments)
    switch (call.function.name) {
      case 'update_entry': {
        if (!args) break
        result.actions.push('pencil.line|调用 update_entry')
        const imagePromptsBySection: Record<string, string[]> = {}
        const sections = (args.sections as Record<string, unknown>[] | undefined)?.map(s => {
          if (Array.isArray(s.image_prompts) && s.image_prompts.length) {
            imagePromptsBySection[s.title as string] = s.image_prompts as string[]
          }
          return { title: s.title as string, body: (s.body || s.content || '') as string, image_refs: (s.image_refs as string[]) || [] }
        })
        for (const [secTitle, prompts] of Object.entries(imagePromptsBySection)) {
          for (const prompt of prompts) {
            result.image_gen_tasks.push({ section_title: secTitle, prompt })
          }
        }
        result.reply = (args.reply as string) || '好的，词条已更新。'
        result.entry_data = {
          title: args.title as string | undefined,
          subtitle: args.subtitle as string | undefined,
          category: args.category as string | undefined,
          infobox: (args.infobox as InfoboxField[] | undefined),
          introduction: args.introduction as string | undefined,
          sections,
          tags: args.tags as string[] | undefined,
          related_entry_titles: args.related_entry_titles as string[] | undefined,
          revision_summary: args.revision_summary as string | undefined,
          cover_image_url: args.cover_image_url as string | undefined,
          image_prompts_by_section: Object.keys(imagePromptsBySection).length ? imagePromptsBySection : undefined,
        }
        result.actions.push(`checkmark.circle|词条「${args.title || '未命名'}」已更新`)
        break
      }
      case 'reply_to_user': {
        if (args) result.reply = (args.message || args.reply || args.text || '') as string
        break
      }
      case 'fetch_url_content': {
        if (args?.url) {
          result.actions.push('link|正在获取链接内容')
          try {
            const content = await callEdgeFunction<{ content: string }>('crawl-url', { url: args.url })
            result.actions.push('checkmark.circle|链接内容已获取')
          } catch {
            result.actions.push('exclamationmark.triangle|链接获取失败')
          }
        }
        break
      }
      case 'generate_image': {
        if (args) {
          const sectionTitle = (args.section_title || '') as string
          const prompt = (args.prompt || '') as string
          result.image_gen_tasks.push({ section_title: sectionTitle, prompt })
          result.reply = (args.reply || `正在为「${sectionTitle}」生成插图…`) as string
          result.actions.push(`photo.artframe|正在生成插图「${sectionTitle}」`)
        }
        break
      }
    }
  }

  if (!result.reply) result.reply = '好的，我在处理……你可以继续补充细节。'
  return result
}

function tryParseJSON(str: string): Record<string, unknown> | null {
  try { return JSON.parse(str) } catch { return null }
}
