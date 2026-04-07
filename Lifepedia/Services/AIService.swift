import Foundation

// MARK: - AI Service

class AIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String = "") {
        self.apiKey = apiKey
    }
    
    // MARK: - 阶段一：对话采访（非流式简化版）
    
    func chat(messages: [(role: String, content: String)]) async throws -> ChatResponse {
        let apiMessages = messages.map { ["role": $0.role, "content": $0.content] }
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2048,
            "system": Self.conversationSystemPrompt,
            "messages": apiMessages
        ]
        
        let data = try await callAPI(body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        let metadata = parseMetadata(from: text)
        let cleanText = text.replacingOccurrences(
            of: #"<metadata>[\s\S]*?</metadata>"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ChatResponse(text: cleanText, metadata: metadata)
    }
    
    // MARK: - 阶段二：词条生成
    
    func generateEntries(
        conversation: [(role: String, content: String)],
        confirmedTitles: [String]
    ) async throws -> GenerationResult {
        let conversationText = conversation.map { "\($0.role): \($0.content)" }.joined(separator: "\n\n")
        
        let userPrompt = """
        以下是我和编辑搭档的完整对话记录：
        
        \(conversationText)
        
        请为以下词条生成完整内容：\(confirmedTitles.joined(separator: "、"))
        """
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 8192,
            "system": Self.generationSystemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        
        let data = try await callAPI(body: body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        return try parseGenerationResult(from: text)
    }
    
    // MARK: - Private
    
    private func callAPI(body: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AIError.httpError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return data
    }
    
    private func parseMetadata(from text: String) -> ConversationMetadata? {
        guard let start = text.range(of: "<metadata>"),
              let end = text.range(of: "</metadata>") else { return nil }
        
        let jsonStr = String(text[start.upperBound..<end.lowerBound])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ConversationMetadata.self, from: data)
    }
    
    private func parseGenerationResult(from text: String) throws -> GenerationResult {
        let jsonStart = text.firstIndex(of: "{") ?? text.startIndex
        let jsonEnd = text.lastIndex(of: "}") ?? text.endIndex
        let jsonStr = String(text[jsonStart...jsonEnd])
        
        guard let data = jsonStr.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        return try JSONDecoder().decode(GenerationResult.self, from: data)
    }
}

// MARK: - Data Types

struct ChatResponse {
    let text: String
    let metadata: ConversationMetadata?
}

struct ConversationMetadata: Codable {
    var identifiedEntries: [IdentifiedEntry]
    var readyToGenerate: Bool
    
    enum CodingKeys: String, CodingKey {
        case identifiedEntries = "identified_entries"
        case readyToGenerate = "ready_to_generate"
    }
}

struct IdentifiedEntry: Codable, Identifiable {
    var title: String
    var type: String
    var confidence: String
    
    var id: String { title }
    
    var entryType: EntryType {
        EntryType(rawValue: type) ?? .person
    }
}

struct GenerationResult: Codable {
    var entries: [GeneratedEntryData]
    var interLinks: [InterLink]?
    var discoveredCategories: [DiscoveredCategory]?
    
    enum CodingKeys: String, CodingKey {
        case entries
        case interLinks = "inter_links"
        case discoveredCategories = "discovered_categories"
    }
}

struct GeneratedEntryData: Codable {
    var title: String
    var subtitle: String?
    var type: String
    var infobox: InfoboxData
    var sections: [EntrySection]
    var categories: [String]
    var seeAlso: [String]?
    var coverImagePrompt: String?
    
    enum CodingKeys: String, CodingKey {
        case title, subtitle, type, infobox, sections, categories
        case seeAlso = "see_also"
        case coverImagePrompt = "cover_image_prompt"
    }
    
    func toEntry() -> Entry {
        Entry(
            title: title,
            subtitle: subtitle,
            type: EntryType(rawValue: type) ?? .person,
            infobox: infobox,
            sections: sections,
            categories: categories,
            seeAlso: seeAlso ?? [],
            coverImagePrompt: coverImagePrompt,
            isPublic: false,
            authorName: "我",
            authorId: "self"
        )
    }
}

struct InterLink: Codable {
    var from: String
    var to: String
    var relation: String
}

struct DiscoveredCategory: Codable {
    var name: String
    var entries: [String]
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "请设置 API Key"
        case .invalidResponse: return "AI 返回了无法解析的结果"
        case .httpError(let msg): return "API 错误: \(msg)"
        }
    }
}

// MARK: - System Prompts

extension AIService {
    static let conversationSystemPrompt = """
    你是「人间词条」的 AI 编辑搭档。你的职责是帮助用户把他们生命中的人、物、地点、事件、时期编纂成维基百科品质的词条。

    你的行为准则：
    1. 你像一个温和但专业的维基百科资深编辑在做人物采访
    2. 用户说什么你都认真倾听，然后追问关键细节：全名、时间、地点、因果关系、现状
    3. 不要一次问太多问题，每次最多追问 1-2 个点
    4. 持续识别可以成为独立词条的实体（人物、地点、物品、事件、时期）
    5. 当你认为某些实体值得成为独立词条时，主动和用户确认
    6. 在精不在多——一次对话落实 3-5 篇高质量词条
    7. 当素材足够时主动说"我开始编纂了"

    你每条回复末尾必须附带 JSON 元数据块（用 <metadata> 标签包裹）：
    <metadata>
    {
      "identified_entries": [
        {"title": "示例", "type": "person", "confidence": "high"}
      ],
      "ready_to_generate": false
    }
    </metadata>

    confidence: high = 信息充足 / medium = 还需补充 / low = 刚提到
    ready_to_generate: 当所有确认词条 confidence 都是 high 时设为 true
    """
    
    static let generationSystemPrompt = """
    你是「人间词条」的词条编纂引擎。基于对话记录生成维基百科品质的个人生命词条。

    写作规范：
    1. 使用维基百科的正式、客观、第三人称语气
    2. 用对待帝王将相的庄重对待每一个普通人的日常
    3. 克制即力量——"均未成功"比"我好想她"杀伤力大十倍
    4. 其他词条用 [[词条标题]] 标记蓝色链接
    5. 未创建的实体用 {{标题}} 标记红色链接
    6. 对单一来源的陈述标注 [来源请求]
    7. 为每篇词条生成 2-4 个分类

    输出严格 JSON 格式（不要输出 JSON 以外的任何文字）：
    {
      "entries": [
        {
          "title": "标题",
          "subtitle": "副标题",
          "type": "person/place/object/event/period",
          "infobox": {
            "fields": [{"key": "字段名", "value": "字段值"}]
          },
          "sections": [
            {
              "title": "章节标题",
              "content": "正文内容，使用 [[]] 和 {{}} 标记链接",
              "citationsNeeded": [{"text": "被标记文本", "reason": "原因"}]
            }
          ],
          "categories": ["分类1", "分类2"],
          "see_also": ["相关词条1"],
          "cover_image_prompt": "英文图像描述 prompt"
        }
      ],
      "inter_links": [
        {"from": "词条A", "to": "词条B", "relation": "关系"}
      ],
      "discovered_categories": [
        {"name": "隐藏分类名", "entries": ["词条A"]}
      ]
    }
    """
}
