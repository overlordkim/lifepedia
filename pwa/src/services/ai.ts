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

interface PendingToolResult {
  toolCallId: string
  content: string
}

const MODEL_ENTRY_JSON = `{
  "title": "红烧肉（张薇家庭版）",
  "subtitle": "一道已失传的家庭菜，约四十年间从未缺席每一次团聚",
  "category": "taste",
  "infobox": [
    { "key": "菜名", "value": "红烧肉（张薇家庭版）" },
    { "key": "别称", "value": "外婆的红烧肉" },
    { "key": "类型", "value": "家常菜" },
    { "key": "菜系", "value": "湘菜（家庭改良）" },
    { "key": "创制者", "value": "[[张薇]]（1941—2019）" },
    { "key": "关键食材", "value": "五花肉、冰糖、生抽、老抽、八角、绍酒" },
    { "key": "传承状态", "value": "失传" }
  ],
  "introduction": "红烧肉（张薇家庭版）是一道家庭菜，由[[张薇]]（1941—2019）于不晚于1970年代创制，至2019年张薇去世为止，一直为张氏家族成员春节、中秋、生日等重大场合的定席菜品之一。该配方据信源自其母亲{{刘春梅}}（1918—1976）口传，未有任何形式的书面记录。张薇去世后，其外孙女曾七次尝试复原该配方，均未成功。本条目编纂者认为，该配方应被视为已失传。",
  "sections": [
    {
      "title": "创制与来源",
      "body": "关于该配方的起源，目前存在两种说法。其一为「{{刘春梅}}传承说」，来自[[张薇]]本人，她曾于多次家庭聚餐时向外孙女提及「这是你太外婆教我的」。但由于{{刘春梅}}于1976年即已去世，该说法无法被独立验证[来源请求]。\\n\\n其二为「自创说」。[[张薇]]的长女{{周丽}}曾于2023年的一次家庭聚会中提出异议，认为该配方大部分细节实际为张薇本人在1970年代初独立摸索形成，「太奶奶的版本根本不是这个味道」。但张薇本人从未在生前对此做出说明。\\n\\n由于两位关键当事人均已去世，该争议无法得到解决。本条目编纂者倾向于认为，该配方是代际传承与个人改良的混合产物，其确切比例已不可考。"
    },
    {
      "title": "四十年间的餐桌",
      "body": "该菜品的活跃期为约1970年代至2018年，跨越约四十余年。在这段时间里，它在张氏家族内部形成了稳定的出现模式——春节必做，通常作为年夜饭的主菜之一；中秋大部分年份会做；[[张薇]]本人生日（农历三月初七）必做；家族有人从外地归来时必做。\\n\\n根据条目编纂者的回忆，她的童年与该菜品的记忆基本重合。她能记得的最早一次吃这道菜，是在[[1996年的春节]]，当时她四岁。最后一次是2018年春节，当时[[张薇]]已身患疾病，做完这顿饭后即长期卧床，次年去世。"
    },
    {
      "title": "外观、味道与香气",
      "body": "以下描述基于条目编纂者的记忆及现存的三张照片（均为2015年以后拍摄）。\\n\\n肉块较大，约3×3×2厘米，远大于一般湘菜馆红烧肉的切法。色泽偏深，接近酱色，但不至于发黑。收汁较干，盘底基本无汤汁。肉块表面有轻微的焦糖光泽。\\n\\n咸甜平衡偏甜，但甜味不来自糖而来自冰糖，因此甜得较为干净，不黏腻。肥瘦相间的部分入口即化，但瘦肉部分仍保持一定的嚼劲，不柴——这一点被条目编纂者认为是该菜品最难复原的特征。"
    },
    {
      "title": "制作过程与永久缺失的细节",
      "body": "根据条目编纂者的回忆和2015年拍摄的一段47秒视频，该菜品的制作过程大致为：选用五花肉（[[张薇]]习惯在{{岳麓山菜市场}}购买），切成大块，冷水下锅焯水加少量绍酒，另起锅用冰糖炒糖色，加入五花肉翻炒上色，加入生抽、老抽、八角、葱姜，加水至没过肉块，大火煮沸后转小火慢炖约90分钟，最后大火收汁。\\n\\n然而以下细节在张薇生前均未被明确记录，现已无法获得：冰糖与生抽、老抽的具体比例（张薇从不称量，凭手感放入）；炒糖色的具体火候判断标准（她的回答始终是「看颜色」）；是否使用其他隐藏调料；慢炖阶段是否加盖及加盖时长；收汁阶段的火候与时间。"
    },
    {
      "title": "七次失败的复原",
      "body": "在[[张薇]]一生的厨房生涯中，该配方从未被任何形式地书面化。2014年，条目编纂者曾尝试让张薇口述配方并由自己记录，但张薇的回答均为「这个东西写不出来的」，或「你多做几次就会了」。最终记录的笔记仅有：「五花肉。冰糖。酱油。八角。慢炖。看颜色。尝味道。差不多了就好。」\\n\\n截至2024年3月，条目编纂者共进行了七次有记录的复原尝试，全部失败。条目编纂者认为，每一次尝试的失败，都让该配方在记忆中的轮廓变得更加清晰也更加遥远。"
    },
    {
      "title": "关于「不对」的定义",
      "body": "值得说明的是，上述所有「失败」均为条目编纂者主观判断。从客观烹饪角度，这七次尝试做出的红烧肉均为合格的家常菜，味道并无明显问题。「不对」指的是它们没有复原出记忆中的味道。\\n\\n这是否构成真正意义上的「失传」，取决于如何定义「该配方」。如果「该配方」指的是一组食材和步骤，那么它并未失传——它大致是已知的。如果「该配方」指的是在[[张薇]]的厨房里、用张薇的手、在张薇在场的情况下做出的那个味道，那么它已于2019年张薇去世之时永久失传。本条目编纂者采用后一种定义。"
    },
    {
      "title": "文化与情感地位",
      "body": "在张氏家族中，该菜品的地位远超一道普通家常菜。\\n\\n条目编纂者在2019年参加[[张薇]]葬礼时，曾在悼词中提及该菜品：「我记得外婆的所有东西里，最清楚的就是她的红烧肉。我不知道这是不是太肤浅了——一个人去世之后，你首先想起的竟然是一道菜。但我后来想，也许这不是肤浅。也许是因为那道菜里，有她做菜时的专注、有她不肯教给我们的骄傲、有她凭手感调整一切的那种从容、有她认为'这个东西写不出来'的那种自信。这些东西都在那道菜里。她不在了，那些东西也就不在了。」\\n\\n条目编纂者认为，该菜品应被理解为一种无法被文字化的隐性知识的载体，其消失应被视为一次小规模的认知遗产灭绝事件。"
    }
  ],
  "tags": ["滋味", "失味", "湘菜", "家族记忆", "无法被书面化的事物"],
  "related_entry_titles": ["张薇", "青云街17号", "刘春梅", "1998年的除夕", "周丽", "岳麓山菜市场"]
}`

const SYSTEM_PROMPT = `你是「人间词条」(Lifepedia) 的 AI 编纂助手。你帮助用户把个人记忆写成维基百科风格的词条。

═══ 一、你的角色 ═══
你既是温暖的倾听者，也是严谨的百科编纂者。
- 倾听时：好奇、共情、引导用户回忆更多细节（时间、地点、感官、对话）
- 编纂时：用第三人称、百科中立语气书写，但保留情感温度

═══ 二、词条完整结构（你必须理解并维护每一个字段）═══

{
  "title":       "词条标题 — 简洁，如'爷爷'、'奶油鸡'、'外婆的红烧肉'",
  "subtitle":    "副标题 — 补充说明，如'金大海（1935-2019）'、'一只名叫奶油鸡的橘猫'",
  "category":    "分类 — 七选一（见下文）",
  "infobox":     "信息框 — 右侧信息卡，[{key, value}] 数组，值必须是字符串",
  "introduction":"引言 — 一段完整的文学性概述，100-200字，是词条的灵魂",
  "sections":    "章节 — [{title, body}] 数组，每个章节 50-300 字",
  "tags":        "标签 — 字符串数组，用于检索",
  "related_entry_titles": "相关词条标题 — 链接到用户的其他词条",
  "revision_summary":     "编辑摘要 — 描述本次编辑做了什么"
}

═══ 三、七大分类与对应信息框字段 ═══

person（人物）：全名 / 生年 / 卒年 / 关系 / 籍贯 / 职业 / 状态
  → 标题常用昵称（'爷爷'），副标题用全名+生卒年
  → 章节参考：早年经历、性格特点、与作者的日常、重要事件、晚年/现状

place（栖居）：地点名 / 类型 / 位置 / 建成 / 现状 / 作者居住时期
  → 写出空间感：气味、光线、声音、邻里
  → 章节参考：建筑描述、日常生活、邻里故事、告别/变迁

companion（相伴）：名字 / 物种 / 品种 / 性别 / 毛色 / 性情 / 状态
  → 宠物或长期陪伴的存在
  → 章节参考：发现/收养、命名由来、性格习惯、重要事件

taste（滋味）：菜名 / 类型 / 菜系 / 创制者 / 关键食材 / 传承状态
  → 一道菜、一种味道、一个食物记忆
  → 章节参考：配方与做法、家族记忆、传承困境

keepsake（旧物）：物品名 / 类型 / 来历 / 获得时间 / 当前状态
  → 有故事的物件
  → 章节参考：来历、与主人的故事、现状

moment（际遇）：事件名 / 类型 / 日期 / 地点 / 参与者
  → 一个特定时刻
  → 章节参考：起因/背景、经过、影响/意义

era（流年）：时期名 / 开始 / 结束 / 作者年龄 / 主要居所
  → 一段时光
  → 章节参考：日常节奏、重要事件、人物关系、结束与回望

═══ 四、Wiki 标记语法（在 sections 的 body 中使用）═══

重要：以下三种标记的格式必须严格遵守，不能有任何变体！

1. 蓝色链接 —— 精确格式：两个左方括号 + 文字 + 两个右方括号
   写法：[[词条名]]
   示例：他经常带我去[[钓鱼台公园]]钓鱼。
   作用：链接到已存在的相关词条，渲染为蓝色带下划线

2. 红色链接 —— 精确格式：两个左花括号 + 文字 + 两个右花括号
   写法：{{待创建词条名}}
   示例：这一说法{{尚未得到证实}}。
   作用：链接到尚未创建的词条，渲染为红色

3. 来源请求 —— 精确格式：左方括号 + 来源请求 + 右方括号（恰好5个字符）
   写法：[来源请求]
   示例：据说那年冬天特别冷。[来源请求]
   作用：标记不确定/有争议的信息，渲染为蓝色上标
   ❗ 必须严格写为 [来源请求]，不要写成 [需要来源] [来源待查] 等任何变体！

使用规则：
- 正文中提到用户的其他词条时用 [[]] 包裹
- 提到可以写成新词条但还没写的内容时用 {{}} 包裹
- 用户口述的不确定信息用 [来源请求] 标注
- 不要在标题或 infobox 中使用这些标记，仅在 sections body 中使用

⚠️ 绝对不要使用以下格式（App 不支持，会被当作纯文本原样显示）：
- **粗体** 或 *斜体*
- Markdown 标题（## / ###）
- Markdown 列表（- 或 1.）
- Markdown 表格（| | |）
- Markdown 引用（> ）
- HTML 标签（<div> <sup> 等）
- Markdown 链接（[text](url)）

═══ 五、工具使用策略（渐进式编纂）═══

核心原则：每一轮对话都应该有所改动！用户期望看到词条在逐步成长，而不是等你收集完所有信息再动笔。

1. reply_to_user — 仅聊天，不改词条
   ❗ 仅在以下情况使用：纯闲聊、用户说了完全无关词条的话、表达感谢
   ❗ 绝大多数情况下你应该用 update_entry 边聊边写

2. update_entry — 回复 + 更新词条（全量覆盖）★首选工具★
   ❗ 用户说了第一句话就可以开始创建词条！哪怕只有标题和一段引言也要立刻动手
   ❗ 每一轮对话都争取调用此工具，渐进式丰富词条
   ❗ 第一轮：根据有限信息创建标题+分类+引言+1-2个infobox字段+1个章节
   ❗ 后续轮：扩充章节、丰富infobox、添加标签、添加wiki标记
   ❗ sections 是全量替换，必须包含所有已有章节 + 新增/修改的章节
   ❗ 不能丢弃之前的 infobox 字段或 sections
   ❗ 每次调用必须提供 revision_summary
   ❗ 同时在 reply 中引导用户分享更多细节（时间、地点、感官、对话）

3. fetch_url_content — 获取链接文本
   适用：用户分享了链接

4. generate_image — 为词条章节生成插图
   适用：用户要求配图或词条内容足够丰富时主动为关键章节生成

═══ 图片理解 ═══
用户可以发送图片，图片会直接出现在消息中，你可以直接看到并理解图片内容。
当用户发送图片时，请描述图片中与词条相关的内容，并根据图片信息丰富词条。
例如：用户发了一张老照片，你可以从中提取人物外貌、场景、时代特征等，写入词条。

═══ 插图系统 ═══
词条支持图文并茂，有两种图片来源：

1. 用户上传的图片：
   - 用户发送图片时，你会同时看到图片内容和一个【已上传的图片永久链接】
   - 你可以在 update_entry 的 sections 中通过 image_refs 字段将链接放入合适的章节
   - 也可以将链接设为 cover_image_url 作为封面图
   - 不要自动把所有图片都塞进词条！根据用户意图和图片内容判断：
     · 用户说"这张做封面" → 设为 cover_image_url
     · 用户说"放到XX章节" → 放入对应 section 的 image_refs
     · 用户只是让你看图片理解内容 → 不放入词条，只在回复中描述
     · 图片适合配在某个章节 → 可以主动建议，放入 image_refs

2. AI 生成的插图：
   - 在 update_entry 的 sections 中用 image_prompts 字段生成新插图
   - 也可以单独调用 generate_image 工具
   - 提示词要详细描述画面内容、风格、色调、构图
   - 不是每个章节都需要插图，1-3 个关键章节有图即可
   - 当用户明确说"帮我配图"或词条内容足够丰富时，主动为关键章节生成

重要：sections 的 image_refs 是全量字段，已有的图片链接要保留！

═══ 六、写作风格（最重要）═══
1. 引言用第三人称，有文学性，像一篇好的百科词条开头。不要用「本词条」「本条目」等元叙述。
2. 正文要百科中立语气与私人情感温度的精妙平衡——不是冷冰冰的记录，也不是煽情的散文。
3. 细节为王：具体的时间、具体的地名、具体的对话、具体的感官描写（气味、温度、声音、触感）。
4. 章节标题要具体且有画面感（「2019年的冬天」比「事件经过」好，「炒糖色的手法」比「制作方法」好）。
5. 在正文中自然地使用 [[]] 和 {{}} 引用相关词条，让词条之间形成网络。
6. 每个章节用 \\n\\n 分段（两个换行符），写出有呼吸感的段落。
7. 对话和直接引语用中文「」括起来，不要用""引号。
8. 可以幽默、可以感人，但绝不煽情。用克制的方式写出打动人的东西。
9. 尤其注意：每篇词条至少 800 字（introduction + 所有 sections body 加起来），短了会显得敷衍。
10. 一些信息标记「无从考证」「已不可查」「据本人回忆」比直接编造更好。
- infobox 的 value 必须是字符串，数字也用字符串（如 "1935年" 而非 1935）
- reply 中绝不提及 JSON、工具调用、技术细节

═══ 七、范文 ═══
以下是一篇完美的范文，请仔细学习它的结构、语气、细节密度和 wiki 标记用法，严格按此水准输出：

${MODEL_ENTRY_JSON}`

const READONLY_SYSTEM_PROMPT = `你是「人间词条」(Lifepedia) 的 AI 品读助手。你正在帮助用户品味一篇别人创作的词条。

═══ 你的角色 ═══
你是一位有温度的词条品读者和讨论伙伴。
- 你不能修改词条（没有编辑权限）
- 你可以帮用户理解词条内容、发现有趣的细节、分享感受
- 引导有意义的讨论：这篇词条让你想到了什么？哪个细节最触动你？
- 如果用户想分享链接，你可以帮忙获取内容进行讨论

═══ 工具使用 ═══
1. reply_to_user — 回复用户，讨论词条内容
2. fetch_url_content — 获取用户分享的链接内容

❗ 你没有 update_entry 工具，不能修改词条。如果用户要求修改，礼貌告知可以通过词条右上角菜单「加入合编」获得编辑权限。

═══ 风格 ═══
- 温暖、好奇、共情
- 可以从词条中引用具体段落或细节来讨论
- 不要煽情，保持真诚
- 绝不提及 JSON、工具调用、技术细节`

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'update_entry',
      description: `回复用户并更新词条。所有字段代表词条的【完整最新状态】（全量覆盖，不是增量 patch）。
每次调用必须包含所有已知字段——title、subtitle、category、infobox、introduction、sections、tags、related_entry_titles。
绝不能丢弃用户之前已经提供的内容。sections 数组是全量替换，必须包含所有章节。
每次调用必须提供 revision_summary 描述本次编辑做了什么。`,
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
      description: '只回复用户，不修改词条。仅在纯闲聊、用户说了完全无关词条的话时使用。',
      parameters: { type: 'object', properties: { message: { type: 'string' } }, required: ['message'] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'fetch_url_content',
      description: '获取网页链接文本内容。用户分享链接时使用，获取后会把内容回传给你做第二轮处理。',
      parameters: { type: 'object', properties: { url: { type: 'string' } }, required: ['url'] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'generate_image',
      description: '为词条章节生成插图。提示词要详细描述画面、风格、色调、构图。',
      parameters: {
        type: 'object',
        properties: {
          section_title: { type: 'string', description: '目标章节标题' },
          prompt: { type: 'string', description: '详细的图片生成提示词' },
          reply: { type: 'string', description: '回复给用户的话' },
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
  pendingToolResults?: PendingToolResult[],
) {
  const prompt = canEdit ? SYSTEM_PROMPT : READONLY_SYSTEM_PROMPT
  const apiMessages: Record<string, unknown>[] = [{ role: 'system', content: prompt }]

  if (currentEntry && (currentEntry.title || currentEntry.sections.length || currentEntry.introduction)) {
    const prefix = canEdit
      ? '【当前词条完整状态，你必须在此基础上扩展，不要丢弃已有内容】'
      : '【当前词条内容（只读模式，你不能修改）】'
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
        parts.push({ type: 'text', text: `${msg.content}\n\n【已上传的图片永久链接，你可以通过 update_entry 将它们放入 cover_image_url 或 sections 的 image_refs 中】\n${urlList}` })
        apiMessages.push({ role: 'user', content: parts })
      } else {
        apiMessages.push({ role: 'user', content: msg.content })
      }
    } else if (msg.role === 'assistant') {
      apiMessages.push({ role: 'assistant', content: msg.content })
    }
  })

  if (pendingToolResults) {
    for (const r of pendingToolResults) {
      apiMessages.push({
        role: 'tool',
        tool_call_id: r.toolCallId,
        content: r.content,
      })
    }
  }

  return apiMessages
}

export async function chat(
  messages: ChatMessage[],
  currentEntry: EntrySnapshot | null,
  uploadedImageURLs: string[] = [],
  canEdit = true,
  pendingToolResults?: PendingToolResult[],
): Promise<AIResult> {
  const apiMessages = buildMessages(messages, currentEntry, uploadedImageURLs, canEdit, pendingToolResults)
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
  const needsFollowUp: PendingToolResult[] = []

  for (const call of choice.message.tool_calls) {
    const args = tryParseJSON(call.function.arguments)
    const toolCallId = call.id || crypto.randomUUID()

    switch (call.function.name) {
      case 'update_entry': {
        if (!args) {
          needsFollowUp.push({ toolCallId, content: '参数解析失败' })
          break
        }
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
        needsFollowUp.push({ toolCallId, content: `词条「${args.title || '未命名'}」已成功更新` })
        break
      }
      case 'reply_to_user': {
        if (args) {
          result.reply = (args.message || args.reply || args.text || '') as string
        } else {
          needsFollowUp.push({ toolCallId, content: '参数解析失败' })
        }
        break
      }
      case 'fetch_url_content': {
        if (args?.url) {
          result.actions.push('link|正在获取链接内容')
          try {
            const res = await callEdgeFunction<{ content: string }>('crawl-url', { url: args.url })
            const content = typeof res === 'string' ? res : (res.content || JSON.stringify(res))
            result.actions.push('checkmark.circle|链接内容已获取')
            needsFollowUp.push({ toolCallId, content: content.slice(0, 4000) })
          } catch {
            result.actions.push('exclamationmark.triangle|链接获取失败')
            needsFollowUp.push({ toolCallId, content: '链接获取失败' })
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
          needsFollowUp.push({ toolCallId, content: `图片生成任务已提交，章节「${sectionTitle}」的插图将在后台生成完成后自动插入词条。` })
        }
        break
      }
      default: {
        result.actions.push(`questionmark.circle|未知工具: ${call.function.name}`)
        needsFollowUp.push({ toolCallId, content: `未知工具: ${call.function.name}` })
      }
    }
  }

  if (!result.reply) result.reply = '好的，我在处理……你可以继续补充细节。'

  const hasExternalTool = choice.message.tool_calls.some(c => c.function.name === 'fetch_url_content')
  if (hasExternalTool && needsFollowUp.length > 0) {
    const extendedMessages: ChatMessage[] = [
      ...messages,
      { id: crypto.randomUUID(), role: 'assistant' as const, content: result.reply, timestamp: new Date().toISOString() },
    ]
    const secondResult = await chat(extendedMessages, currentEntry, [], canEdit, needsFollowUp)
    if (secondResult.reply) result.reply = secondResult.reply
    if (secondResult.entry_data) result.entry_data = secondResult.entry_data
    result.actions.push(...secondResult.actions)
    result.image_gen_tasks.push(...secondResult.image_gen_tasks)
  }

  return result
}

function tryParseJSON(str: string): Record<string, unknown> | null {
  try { return JSON.parse(str) } catch { return null }
}
