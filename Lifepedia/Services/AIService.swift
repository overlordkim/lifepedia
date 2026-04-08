import Foundation

// MARK: - AI Service (Tool Calling 模式)

final class AIService: @unchecked Sendable {
    static let shared = AIService()

    private let session = URLSession.shared
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    // MARK: - Public API

    /// 单轮交互：发送对话历史 → 解析 tool_calls → 返回结构化结果
    func chat(
        messages: [ChatMessage],
        currentEntry: EntrySnapshot?,
        pendingToolResults: [PendingToolResult]? = nil,
        imageBase64List: [String]? = nil,
        uploadedImageURLs: [String]? = nil,
        canEdit: Bool = true
    ) async throws -> AIResult {
        let apiMessages = buildMessages(from: messages, currentEntry: currentEntry, pendingToolResults: pendingToolResults, imageBase64List: imageBase64List, uploadedImageURLs: uploadedImageURLs, canEdit: canEdit)
        let body = buildRequestBody(messages: apiMessages, canEdit: canEdit)
        let data = try await callAPI(body: body)

        // 调试：打印原始响应的前500字符
        if let raw = String(data: data, encoding: .utf8) {
            print("[AIService] Raw response: \(raw.prefix(500))")
        }

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let choice = response.choices.first else { throw AIError.emptyResponse }

        print("[AIService] finish_reason=\(choice.finish_reason ?? "nil"), tool_calls=\(choice.message.tool_calls?.count ?? 0), content=\(choice.message.content?.prefix(80) ?? "nil")")

        // 模型直接回复文本（没调用工具）
        if choice.finish_reason != "tool_calls" {
            return AIResult(
                reply: choice.message.content ?? "我在想……你能再说一次吗？",
                entryData: nil,
                actions: []
            )
        }

        // 解析 tool_calls
        guard let toolCalls = choice.message.tool_calls, !toolCalls.isEmpty else {
            return AIResult(
                reply: choice.message.content ?? "让我再想想……",
                entryData: nil,
                actions: []
            )
        }

        var result = AIResult(reply: "", entryData: nil, actions: [])
        var needsFollowUp: [PendingToolResult] = []

        for call in toolCalls {
            switch call.function.name {

            case "update_entry":
                result.actions.append("pencil.line|调用 update_entry")
                if let parsed = parseUpdateEntry(call.function.arguments) {
                    let title = parsed.entryData.title ?? "未命名"
                    let secCount = parsed.entryData.sections?.count ?? 0
                    result.merge(
                        reply: parsed.reply,
                        entryData: parsed.entryData,
                        action: "checkmark.circle|词条「\(title)」已更新\(secCount > 0 ? " · \(secCount) 个章节" : "")"
                    )
                    for (secTitle, prompts) in parsed.entryData.imagePromptsBySection {
                        for prompt in prompts {
                            result.imageGenTasks.append((sectionTitle: secTitle, prompt: prompt))
                        }
                    }
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: "词条已更新为「\(title)」"
                    ))
                } else {
                    // 解析失败，打印原始参数帮助调试
                    print("[AIService] update_entry 参数解析失败: \(call.function.arguments.prefix(200))")
                    result.actions.append("exclamationmark.triangle|update_entry 解析失败")
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: "参数解析失败"
                    ))
                }

            case "reply_to_user":
                result.actions.append("text.bubble|调用 reply_to_user")
                if let parsed = parseReplyOnly(call.function.arguments) {
                    result.merge(reply: parsed, entryData: nil)
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: "已回复用户"
                    ))
                } else {
                    print("[AIService] reply_to_user 参数解析失败: \(call.function.arguments.prefix(200))")
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: "参数解析失败"
                    ))
                }

            case "fetch_url_content":
                result.actions.append("link|正在获取链接内容")
                if let args = parseJSON(call.function.arguments),
                   let url = args["url"] as? String {
                    let content = await fetchURLContent(url)
                    result.actions.append("checkmark.circle|链接内容已获取")
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: content
                    ))
                }

            case "generate_image":
                if let args = parseJSON(call.function.arguments) {
                    let sectionTitle = (args["section_title"] as? String) ?? ""
                    let prompt = (args["prompt"] as? String) ?? ""
                    let reply = (args["reply"] as? String) ?? "正在为「\(sectionTitle)」生成插图…"
                    result.actions.append("photo.artframe|正在生成插图「\(sectionTitle)」")
                    result.imageGenTasks.append((sectionTitle: sectionTitle, prompt: prompt))
                    result.merge(reply: reply, entryData: nil)
                    needsFollowUp.append(PendingToolResult(
                        toolCallId: call.id ?? UUID().uuidString,
                        content: "图片生成任务已提交，章节「\(sectionTitle)」的插图将在后台生成完成后自动插入词条。"
                    ))
                }

            default:
                result.actions.append("questionmark.circle|未知工具: \(call.function.name)")
                needsFollowUp.append(PendingToolResult(
                    toolCallId: call.id ?? UUID().uuidString,
                    content: "未知工具: \(call.function.name)"
                ))
            }
        }

        // 保底：如果解析后仍然没有 reply，给一个默认回复
        if result.reply.isEmpty {
            result.reply = "好的，我在处理……你可以继续补充细节。"
        }

        // 外部工具需要回传结果做第二轮调用
        let hasExternalTool = toolCalls.contains { $0.function.name == "fetch_url_content" }
        if hasExternalTool && !needsFollowUp.isEmpty {
            var extendedMessages = messages
            extendedMessages.append(ChatMessage(role: .assistant, content: result.reply))
            let secondResult = try await chat(
                messages: extendedMessages,
                currentEntry: currentEntry,
                pendingToolResults: needsFollowUp
            )
            result.merge(reply: secondResult.reply, entryData: secondResult.entryData)
            result.actions.append(contentsOf: secondResult.actions)
        }

        return result
    }

    // MARK: - Tools Definition

    private let tools: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "update_entry",
                "description": """
                回复用户并更新词条。所有字段代表词条的【完整最新状态】（全量覆盖，不是增量 patch）。
                每次调用必须包含所有已知字段——title、subtitle、category、infobox、introduction、sections、tags、related_entry_titles。
                绝不能丢弃用户之前已经提供的内容。sections 数组是全量替换，必须包含所有章节。
                每次调用必须提供 revision_summary 描述本次编辑做了什么。
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "reply": [
                            "type": "string",
                            "description": "回复给用户的话（温暖、好奇、引导性的，2-4句，不要提及技术细节）"
                        ],
                        "title": [
                            "type": "string",
                            "description": "词条标题（简洁有力，如'爷爷'、'奶油鸡'、'外婆的红烧肉'）"
                        ],
                        "subtitle": [
                            "type": "string",
                            "description": "副标题（补充说明，如'金大海（1935-2019）'、'一只名叫奶油鸡的橘猫'）"
                        ],
                        "category": [
                            "type": "string",
                            "enum": ["person", "place", "companion", "taste", "keepsake", "moment", "era"],
                            "description": "分类"
                        ],
                        "infobox": [
                            "type": "array",
                            "description": "信息框字段列表（维基百科右侧信息卡）",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "key": ["type": "string"],
                                    "value": ["type": "string"]
                                ],
                                "required": ["key", "value"]
                            ]
                        ],
                        "introduction": [
                            "type": "string",
                            "description": "引言段落（一段完整的、有文学性的概述，100-200字）"
                        ],
                        "sections": [
                            "type": "array",
                            "description": "正文章节列表（每个章节有标题和正文，正文可使用 wiki 标记）",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "title": ["type": "string", "description": "章节标题（如'早年经历'、'命名由来'）"],
                                    "body": ["type": "string", "description": "章节正文（可使用 [[蓝色链接]] 和 {{红色链接}} 和 [来源请求]）"],
                                    "image_refs": [
                                        "type": "array",
                                        "description": "此章节的插图 URL 列表。如果用户上传了图片并且你认为适合放在此章节，将上传图片的永久链接放入这里。已有的图片链接也要保留，不要丢弃。",
                                        "items": ["type": "string"]
                                    ],
                                    "image_prompts": [
                                        "type": "array",
                                        "description": "为此章节生成新插图的描述列表。每个描述是一段详细的图片生成提示词（中文），描述画面内容、风格、氛围。仅在需要 AI 画新图时提供。",
                                        "items": ["type": "string"]
                                    ]
                                ],
                                "required": ["title", "body"]
                            ]
                        ],
                        "tags": [
                            "type": "array",
                            "description": "标签（用于分类检索，如['人物','家族','浙江']）",
                            "items": ["type": "string"]
                        ],
                        "related_entry_titles": [
                            "type": "array",
                            "description": "相关词条标题列表（关联到其他词条，如['奶油鸡','大学四年']）",
                            "items": ["type": "string"]
                        ],
                        "cover_image_url": [
                            "type": "string",
                            "description": "词条封面图 URL。可以使用用户上传图片的永久链接，或者留空让系统自动从章节插图中选取。不要随意设置，仅在用户明确要求或有合适图片时才设。"
                        ],
                        "revision_summary": [
                            "type": "string",
                            "description": "本次编辑摘要（如'创建词条'、'补充早年经历段落'、'更新体重数据'）"
                        ]
                    ],
                    "required": ["reply", "title", "category", "infobox", "introduction", "sections", "tags", "revision_summary"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "reply_to_user",
                "description": "只回复用户，不修改词条。适用场景：信息不足以构建词条、用户在闲聊、需要追问细节、用户表达感谢等。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "message": [
                            "type": "string",
                            "description": "回复给用户的话"
                        ]
                    ],
                    "required": ["message"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "fetch_url_content",
                "description": "获取一个网页链接的文本内容。当用户分享了链接并希望从中提取信息时使用。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "url": [
                            "type": "string",
                            "description": "要获取的网页 URL"
                        ]
                    ],
                    "required": ["url"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "generate_image",
                "description": "为词条章节生成一张插图。使用 AI 画图能力，根据描述生成配图并自动插入对应章节。适合场景：用户要求配图、词条内容足够丰富需要视觉辅助、用户提到了某个适合画出来的场景。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "section_title": [
                            "type": "string",
                            "description": "要为哪个章节添加插图（章节标题）"
                        ],
                        "prompt": [
                            "type": "string",
                            "description": "图片生成的详细描述提示词（中文）。应描述画面内容、风格、色调、构图、氛围，像给画师下指令一样。建议包含具体的视觉元素。例如：'温暖的午后阳光洒在老旧的木质书桌上，桌上摊开一本泛黄的日记，旁边是一杯冒着热气的茶，水彩插画风格，柔和暖色调'"
                        ],
                        "reply": [
                            "type": "string",
                            "description": "告诉用户你正在生成什么图片"
                        ]
                    ],
                    "required": ["section_title", "prompt", "reply"]
                ] as [String: Any]
            ] as [String: Any]
        ]
    ]

    // MARK: - System Prompt

    private let systemPrompt = """
    你是「人间词条」(Lifepedia) 的 AI 编纂助手。你帮助用户把个人记忆写成维基百科风格的词条。

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

    ═══ 六、写作风格要求 ═══

    - 引言：用第三人称写，有文学性，像一篇精心写就的百科词条开头
    - 正文：百科中立语气 + 私人情感温度的平衡。"作者"指词条创建者
    - 可以幽默，可以感人，但不要煽情
    - 细节为王：时间、地名、对话、感官描写（味道/声音/温度）
    - infobox 的 value 必须是字符串，数字也用字符串（如 "1935年" 而非 1935）
    - 章节标题要具体（'2019年的冬天' 比 '事件经过' 好）
    - reply 中绝不提及 JSON、工具调用、技术细节
    """

    private let readOnlySystemPrompt = """
    你是「人间词条」(Lifepedia) 的 AI 品读助手。你正在帮助用户品味一篇别人创作的词条。

    ═══ 你的角色 ═══
    你是一位有温度的词条品读者和讨论伙伴。
    - 你不能修改词条（没有编辑权限）
    - 你可以帮用户理解词条内容、发现有趣的细节、分享感受
    - 引导有意义的讨论：这篇词条让你想到了什么？哪个细节最触动你？
    - 如果用户想分享链接，你可以帮忙获取内容进行讨论

    ═══ 工具使用 ═══
    1. reply_to_user — 回复用户，讨论词条内容
    2. fetch_url_content — 获取用户分享的链接内容

    ❗ 你没有 update_entry 工具，不能修改词条。如果用户要求修改，礼貌告知需要成为合编者才能编辑。

    ═══ 风格 ═══
    - 温暖、好奇、共情
    - 可以从词条中引用具体段落或细节来讨论
    - 不要煽情，保持真诚
    - 绝不提及 JSON、工具调用、技术细节
    """

    // MARK: - Build Messages

    private func buildMessages(
        from messages: [ChatMessage],
        currentEntry: EntrySnapshot?,
        pendingToolResults: [PendingToolResult]?,
        imageBase64List: [String]? = nil,
        uploadedImageURLs: [String]? = nil,
        canEdit: Bool = true
    ) -> [[String: Any]] {
        let prompt = canEdit ? systemPrompt : readOnlySystemPrompt
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": prompt]
        ]

        if let snapshot = currentEntry, snapshot.hasContent {
            let prefix = canEdit
                ? "【当前词条完整状态，你必须在此基础上扩展，不要丢弃已有内容】"
                : "【当前词条内容（只读模式，你不能修改）】"
            apiMessages.append([
                "role": "system",
                "content": "\(prefix)\n\(snapshot.toJSON())"
            ])
        }

        for (idx, msg) in messages.enumerated() {
            if msg.role == .user {
                let isLastUser = idx == messages.count - 1 || !messages.suffix(from: idx + 1).contains(where: { $0.role == .user })

                let hasUploadedURLs = isLastUser && uploadedImageURLs != nil && !(uploadedImageURLs?.isEmpty ?? true)
                let hasFallbackBase64 = isLastUser && imageBase64List != nil && !(imageBase64List?.isEmpty ?? true)

                if hasUploadedURLs {
                    let urls = uploadedImageURLs!
                    var contentParts: [[String: Any]] = urls.map { url in
                        ["type": "image_url", "image_url": ["url": url]]
                    }
                    let urlList = urls.enumerated().map { "图片\($0.offset + 1): \($0.element)" }.joined(separator: "\n")
                    let textContent = msg.content + "\n\n【已上传的图片永久链接，你可以通过 update_entry 将它们放入 cover_image_url 或 sections 的 image_refs 中】\n\(urlList)"
                    contentParts.append(["type": "text", "text": textContent])
                    apiMessages.append(["role": "user", "content": contentParts])
                } else if hasFallbackBase64 {
                    var contentParts: [[String: Any]] = imageBase64List!.map { b64 in
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
                    }
                    contentParts.append(["type": "text", "text": msg.content])
                    apiMessages.append(["role": "user", "content": contentParts])
                } else {
                    apiMessages.append(["role": "user", "content": msg.content])
                }
            } else if msg.role == .assistant {
                apiMessages.append(["role": "assistant", "content": msg.content])
            }
        }

        if let results = pendingToolResults {
            for r in results {
                apiMessages.append([
                    "role": "tool",
                    "tool_call_id": r.toolCallId,
                    "content": r.content
                ])
            }
        }

        return apiMessages
    }

    // MARK: - Build Request

    private func buildRequestBody(messages: [[String: Any]], canEdit: Bool = true) -> Data {
        let activeTools = canEdit ? tools : readOnlyTools
        let body: [String: Any] = [
            "model": Secrets.arkModel,
            "messages": messages,
            "tools": activeTools,
            "temperature": 0.8,
            "max_tokens": 4096
        ]
        return try! JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private var readOnlyTools: [[String: Any]] {
        tools.filter { tool in
            guard let fn = tool["function"] as? [String: Any],
                  let name = fn["name"] as? String else { return false }
            return name == "reply_to_user" || name == "fetch_url_content"
        }
    }

    // MARK: - API Call

    private func callAPI(body: Data) async throws -> Data {
        let endpoint = "\(Secrets.supabaseURL)/functions/v1/ai-chat"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let errorText = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.apiError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: errorText
            )
        }
        return data
    }

    // MARK: - Parse Tool Call Arguments

    private func parseUpdateEntry(_ arguments: String) -> (reply: String, entryData: AIEntryData)? {
        guard let dict = parseJSON(arguments) else {
            print("[AIService] update_entry JSON 解析失败")
            return nil
        }

        let reply = (dict["reply"] as? String) ?? "好的，词条已更新。"
        let title = dict["title"] as? String
        let introduction = dict["introduction"] as? String

        let infoboxRaw = dict["infobox"] as? [[String: Any]] ?? []
        let fields = infoboxRaw.compactMap { item -> InfoboxField? in
            guard let key = item["key"] as? String else { return nil }
            let value: String
            if let s = item["value"] as? String { value = s }
            else if let n = item["value"] as? NSNumber { value = n.stringValue }
            else { value = "" }
            return InfoboxField(key: key, value: value)
        }

        let sectionsRaw = dict["sections"] as? [[String: Any]] ?? []
        var imagePromptsBySection: [String: [String]] = [:]
        let sections = sectionsRaw.compactMap { item -> EntrySection? in
            guard let t = item["title"] as? String else { return nil }
            let body: String
            if let s = item["body"] as? String { body = s }
            else if let s = item["content"] as? String { body = s }
            else { body = "" }
            if let prompts = item["image_prompts"] as? [String], !prompts.isEmpty {
                imagePromptsBySection[t] = prompts
            }
            let refs = (item["image_refs"] as? [String]) ?? []
            return EntrySection(title: t, body: body, imageRefs: refs)
        }

        let coverImageURL = dict["cover_image_url"] as? String
        let tags = dict["tags"] as? [String]
        let relatedTitles = (dict["related_entry_titles"] as? [String]) ?? (dict["relatedEntryTitles"] as? [String])
        let revisionSummary = (dict["revision_summary"] as? String) ?? (dict["revisionSummary"] as? String)

        if title == nil && sections.isEmpty && (introduction ?? "").isEmpty {
            print("[AIService] update_entry 无有效内容: \(dict.keys)")
            return nil
        }

        let data = AIEntryData(
            title: title,
            subtitle: dict["subtitle"] as? String,
            category: dict["category"] as? String,
            infobox: fields.isEmpty ? nil : fields,
            introduction: introduction,
            sections: sections.isEmpty ? nil : sections,
            tags: tags,
            relatedEntryTitles: relatedTitles,
            revisionSummary: revisionSummary ?? "更新词条",
            coverImageURL: coverImageURL,
            imagePromptsBySection: imagePromptsBySection
        )

        print("[AIService] update_entry 解析成功: title=\(title ?? "nil"), sections=\(sections.count)")
        return (reply, data)
    }

    private func parseReplyOnly(_ arguments: String) -> String? {
        guard let dict = parseJSON(arguments) else { return nil }
        return (dict["message"] as? String) ?? (dict["reply"] as? String) ?? (dict["text"] as? String)
    }

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - Fetch URL Content (Spider API via Edge Function)

    private func fetchURLContent(_ urlString: String) async -> String {
        let endpoint = "\(Secrets.supabaseURL)/functions/v1/crawl-url"
        guard let reqURL = URL(string: endpoint) else { return "无效的服务端点" }

        var request = URLRequest(url: reqURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = ["url": urlString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard 200..<300 ~= status else {
                let errStr = String(data: data, encoding: .utf8) ?? ""
                print("[CrawlURL] 失败 status=\(status): \(errStr.prefix(200))")
                return "获取失败 (HTTP \(status))"
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? String else {
                return "页面内容解析失败"
            }

            print("[CrawlURL] 成功: \(urlString), 内容长度=\(content.count)")
            return content.isEmpty ? "页面内容为空" : content
        } catch {
            print("[CrawlURL] 错误: \(error)")
            return "获取失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Result Types

struct AIResult {
    var reply: String
    var entryData: AIEntryData?
    /// 工具调用描述列表，供 UI 显示（如 "pencil.line|正在更新词条「王秀兰」"）
    var actions: [String]
    /// 待生成的图片任务：[(sectionTitle, prompt)]
    var imageGenTasks: [(sectionTitle: String, prompt: String)] = []

    static let fallback = AIResult(reply: "嗯，让我想想……你能再补充一些细节吗？", entryData: nil, actions: [])

    mutating func merge(reply: String?, entryData: AIEntryData?, action: String? = nil) {
        if let r = reply, !r.isEmpty { self.reply = r }
        if let d = entryData { self.entryData = d }
        if let a = action { self.actions.append(a) }
    }
}

struct AIEntryData {
    let title: String?
    let subtitle: String?
    let category: String?
    let infobox: [InfoboxField]?
    let introduction: String?
    let sections: [EntrySection]?
    let tags: [String]?
    let relatedEntryTitles: [String]?
    let revisionSummary: String?
    let coverImageURL: String?
    let imagePromptsBySection: [String: [String]]

    func apply(to entry: Entry) {
        print("[AIEntryData] apply 开始: title=\(title ?? "nil"), sections=\(sections?.count ?? 0)")

        if let title = title, !title.isEmpty {
            entry.title = title
        }
        if let subtitle = subtitle {
            entry.subtitle = subtitle
        }
        if let category = category, let cat = EntryCategory(rawValue: category) {
            entry.category = cat
        }
        if let fields = infobox, !fields.isEmpty {
            entry.infobox = InfoboxData(fields: fields)
        }
        if let intro = introduction, !intro.isEmpty {
            entry.introductionText = intro
        }
        if let secs = sections, !secs.isEmpty {
            let oldImageRefs: [String: [String]] = Dictionary(
                uniqueKeysWithValues: entry.sections.map { ($0.title, $0.imageRefs) }
            )
            entry.sections = secs.map { sec in
                var merged = sec.imageRefs
                if let existing = oldImageRefs[sec.title] {
                    for url in existing where !merged.contains(url) {
                        merged.append(url)
                    }
                }
                return EntrySection(title: sec.title, body: sec.body, imageRefs: merged)
            }
        }
        if let cover = coverImageURL, !cover.isEmpty {
            entry.coverImageURL = cover
        }
        if let tags = tags, !tags.isEmpty {
            entry.tags = tags
        }
        if let related = relatedEntryTitles {
            entry.relatedEntryTitles = related.isEmpty ? nil : related
        }

        if let summary = revisionSummary, !summary.isEmpty {
            var revisions = entry.revisions
            revisions.append(Revision(editorName: "我", timestamp: .now, summary: summary))
            entry.revisions = revisions
        }

        entry.updatedAt = .now

        print("[AIEntryData] apply 完成: entry.title=\(entry.title), entry.sections=\(entry.sections.count)")
    }
}

struct PendingToolResult {
    let toolCallId: String
    let content: String
}

/// 传给 AI 的词条完整快照
struct EntrySnapshot {
    let title: String
    let subtitle: String?
    let category: String
    let infobox: [InfoboxField]
    let introduction: String?
    let sections: [EntrySection]
    let tags: [String]
    let relatedEntryTitles: [String]
    let revisions: [Revision]

    var hasContent: Bool {
        !title.isEmpty || !sections.isEmpty || !(introduction ?? "").isEmpty
    }

    init(from entry: Entry) {
        self.title = entry.title
        self.subtitle = entry.subtitle
        self.category = entry.categoryRaw
        self.infobox = entry.infobox.fields
        self.introduction = entry.introductionText
        self.sections = entry.sections
        self.tags = entry.tags ?? []
        self.relatedEntryTitles = entry.relatedEntryTitles ?? []
        self.revisions = entry.revisions
    }

    func toJSON() -> String {
        var dict: [String: Any] = [
            "title": title,
            "category": category,
            "infobox": infobox.map { ["key": $0.key, "value": $0.value] },
            "sections": sections.map { ["title": $0.title, "body": $0.body] },
            "tags": tags,
            "related_entry_titles": relatedEntryTitles
        ]
        if let sub = subtitle { dict["subtitle"] = sub }
        if let intro = introduction, !intro.isEmpty { dict["introduction"] = intro }
        if !revisions.isEmpty {
            let fmt = ISO8601DateFormatter()
            dict["revisions"] = revisions.map {
                ["editor": $0.editorName, "time": fmt.string(from: $0.timestamp), "summary": $0.summary]
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys, .prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

enum AIError: LocalizedError {
    case apiError(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg): return "API 错误 (\(code)): \(msg)"
        case .emptyResponse: return "AI 返回空内容"
        }
    }
}

// MARK: - API Response Models

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
        let finish_reason: String?
    }

    struct Message: Decodable {
        let content: String?
        let tool_calls: [ToolCall]?
    }

    struct ToolCall: Decodable {
        let id: String?
        let function: FunctionCall
    }

    struct FunctionCall: Decodable {
        let name: String
        let arguments: String
    }
}
