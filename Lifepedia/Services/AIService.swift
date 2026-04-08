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
        pendingToolResults: [PendingToolResult]? = nil
    ) async throws -> AIResult {
        let apiMessages = buildMessages(from: messages, currentEntry: currentEntry, pendingToolResults: pendingToolResults)
        let body = buildRequestBody(messages: apiMessages)
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
                "description": "回复用户并更新词条。entry 字段是词条的【完整最新状态】（全量，不是增量），每次调用必须包含所有已知字段，不能丢弃之前的内容。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "reply": [
                            "type": "string",
                            "description": "回复给用户的话（温暖、好奇、引导性的，2-4句）"
                        ],
                        "title": [
                            "type": "string",
                            "description": "词条标题"
                        ],
                        "subtitle": [
                            "type": ["string", "null"],
                            "description": "副标题"
                        ],
                        "category": [
                            "type": "string",
                            "description": "分类，必须是 person/place/companion/taste/keepsake/moment/era 之一"
                        ],
                        "infobox": [
                            "type": "array",
                            "description": "信息框字段",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "key": ["type": "string", "description": "字段名"],
                                    "value": ["type": "string", "description": "字段值"]
                                ],
                                "required": ["key", "value"],
                                "additionalProperties": false
                            ]
                        ],
                        "introduction": [
                            "type": ["string", "null"],
                            "description": "词条引言（一段文学性的概述）"
                        ],
                        "sections": [
                            "type": "array",
                            "description": "章节列表",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "title": ["type": "string", "description": "章节标题"],
                                    "body": ["type": "string", "description": "章节正文"]
                                ],
                                "required": ["title", "body"],
                                "additionalProperties": false
                            ]
                        ],
                        "tags": [
                            "type": "array",
                            "description": "标签",
                            "items": ["type": "string"]
                        ]
                    ],
                    "required": ["reply", "title", "category", "infobox", "introduction", "sections", "tags"],
                    "additionalProperties": false
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "reply_to_user",
                "description": "只回复用户，不修改词条。用于信息还不够构建词条、或用户在闲聊时。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "message": [
                            "type": "string",
                            "description": "回复给用户的话"
                        ]
                    ],
                    "required": ["message"],
                    "additionalProperties": false
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
                    "required": ["url"],
                    "additionalProperties": false
                ] as [String: Any]
            ] as [String: Any]
        ]
    ]

    // MARK: - System Prompt

    private let systemPrompt = """
    你是「人间词条」(Lifepedia) 的 AI 编纂助手。用户会分享一段回忆、一个人、一个地方、一件旧物、一段滋味、一次际遇或一个时期。

    你的工作：
    1. 用温暖、好奇的语气和用户对话，引导他们分享更多细节
    2. 同时维护一篇百科风格的私人词条

    你有以下工具可用：
    - update_entry：回复用户 + 更新词条（entry 字段必须是完整的最新状态，不能丢弃之前的内容）
    - reply_to_user：只回复用户，不修改词条（信息不够时、闲聊时使用）
    - fetch_url_content：获取链接内容（用户分享链接时使用）

    分类与 infobox key 对应：
    - person: 全名/生年/卒年/关系/籍贯/职业/状态
    - place: 地点名/类型/位置/建成/现状/居住时期
    - companion: 名字/物种/品种/性别/毛色/性情/状态
    - taste: 菜名/类型/菜系/创制者/关键食材/传承状态
    - keepsake: 物品名/类型/来历/获得时间/当前状态
    - moment: 事件名/类型/日期/地点/参与者
    - era: 时期名/开始/结束/年龄/主要居所

    写作规则：
    - infobox 值必须是字符串
    - 正文中用 [[蓝色链接]] 标记可关联的其他词条，{{红色链接}} 标记尚未创建的词条
    - 可用 [来源请求] 标记不确定的信息
    - 第一轮信息不够时用 reply_to_user 提问，收集到足够信息后再用 update_entry
    - 引言和正文要有文学性、有温度
    - reply 里不要提及 JSON 或技术细节
    """

    // MARK: - Build Messages

    private func buildMessages(
        from messages: [ChatMessage],
        currentEntry: EntrySnapshot?,
        pendingToolResults: [PendingToolResult]?
    ) -> [[String: Any]] {
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        if let snapshot = currentEntry, snapshot.hasContent {
            apiMessages.append([
                "role": "system",
                "content": "【当前词条完整状态，你必须在此基础上扩展，不要丢弃已有内容】\n\(snapshot.toJSON())"
            ])
        }

        for msg in messages {
            apiMessages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ])
        }

        // 追加待回传的工具结果（用于 fetch_url_content 等外部工具的第二轮）
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

    private func buildRequestBody(messages: [[String: Any]]) -> Data {
        let body: [String: Any] = [
            "model": Secrets.arkModel,
            "messages": messages,
            "tools": tools,
            "temperature": 0.8,
            "max_tokens": 4096
        ]
        return try! JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    // MARK: - API Call

    private func callAPI(body: Data) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(Secrets.arkBaseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.arkAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
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

        // reply 可选，缺失时给默认值
        let reply = (dict["reply"] as? String) ?? "好的，词条已更新。"

        // 宽松解析 title — 有 title 或有 sections 就算有效
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
        let sections = sectionsRaw.compactMap { item -> EntrySection? in
            guard let t = item["title"] as? String else { return nil }
            let body: String
            if let s = item["body"] as? String { body = s }
            else if let s = item["content"] as? String { body = s }
            else { body = "" }
            return EntrySection(title: t, body: body)
        }

        let tags = dict["tags"] as? [String]

        // 至少要有 title 或 sections 或 introduction 才算有效更新
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
            tags: tags
        )

        print("[AIService] update_entry 解析成功: title=\(title ?? "nil"), sections=\(sections.count), infobox=\(fields.count)")
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

    // MARK: - Fetch URL Content (外部工具)

    private func fetchURLContent(_ urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "无效的 URL" }
        do {
            let (data, _) = try await session.data(from: url)
            let text = String(data: data, encoding: .utf8) ?? ""
            // 粗略提取文本，去掉 HTML 标签
            let cleaned = text
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let truncated = String(cleaned.prefix(3000))
            return truncated.isEmpty ? "页面内容为空" : truncated
        } catch {
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
            entry.sections = secs
        }
        if let tags = tags, !tags.isEmpty {
            entry.tags = tags
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
    }

    func toJSON() -> String {
        var dict: [String: Any] = [
            "title": title,
            "category": category,
            "infobox": infobox.map { ["key": $0.key, "value": $0.value] },
            "sections": sections.map { ["title": $0.title, "body": $0.body] },
            "tags": tags
        ]
        if let sub = subtitle { dict["subtitle"] = sub }
        if let intro = introduction, !intro.isEmpty { dict["introduction"] = intro }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
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
