import Foundation
import SwiftData

// MARK: - 词条类型

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case person  = "person"
    case place   = "place"
    case object  = "object"
    case event   = "event"
    case period  = "period"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .person: return "人物"
        case .place:  return "地点"
        case .object: return "物品"
        case .event:  return "事件"
        case .period: return "时期"
        }
    }
    
    var icon: String {
        switch self {
        case .person: return "👤"
        case .place:  return "📍"
        case .object: return "🔮"
        case .event:  return "📅"
        case .period: return "⏳"
        }
    }
    
    var defaultInfoboxKeys: [String] {
        switch self {
        case .person:
            return ["全名", "出生", "逝世", "籍贯", "关系", "知名于"]
        case .place:
            return ["名称", "位置", "存续时间", "当前状态", "关联人物"]
        case .object:
            return ["名称", "类型", "来源", "获得时间", "当前状态"]
        case .event:
            return ["名称", "日期", "地点", "参与者"]
        case .period:
            return ["名称", "起止时间", "定义特征", "关键事件"]
        }
    }
}

// MARK: - 信息框

struct InfoboxField: Codable, Identifiable, Hashable {
    var id: String { key }
    var key: String
    var value: String
    var linkedEntryTitle: String?
}

struct InfoboxData: Codable {
    var fields: [InfoboxField]
    
    static let empty = InfoboxData(fields: [])
}

// MARK: - 正文章节

struct EntrySection: Codable, Identifiable, Hashable {
    var id: String { title }
    var title: String
    var content: String
    var citationsNeeded: [CitationNeeded]
    
    init(title: String, content: String, citationsNeeded: [CitationNeeded] = []) {
        self.title = title
        self.content = content
        self.citationsNeeded = citationsNeeded
    }
}

struct CitationNeeded: Codable, Hashable {
    var text: String
    var reason: String
}

// MARK: - 词条（核心模型）

@Model
final class Entry {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var typeRaw: String
    var infoboxJSON: Data?
    var sectionsJSON: Data?
    var categoriesJSON: Data?
    var seeAlsoJSON: Data?
    var coverImagePrompt: String?
    var coverImagePath: String?
    var isPublic: Bool
    var authorName: String
    var authorId: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        type: EntryType,
        infobox: InfoboxData = .empty,
        sections: [EntrySection] = [],
        categories: [String] = [],
        seeAlso: [String] = [],
        coverImagePrompt: String? = nil,
        coverImagePath: String? = nil,
        isPublic: Bool = false,
        authorName: String = "我",
        authorId: String = "self",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.typeRaw = type.rawValue
        self.infoboxJSON = try? JSONEncoder().encode(infobox)
        self.sectionsJSON = try? JSONEncoder().encode(sections)
        self.categoriesJSON = try? JSONEncoder().encode(categories)
        self.seeAlsoJSON = try? JSONEncoder().encode(seeAlso)
        self.coverImagePrompt = coverImagePrompt
        self.coverImagePath = coverImagePath
        self.isPublic = isPublic
        self.authorName = authorName
        self.authorId = authorId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed properties
    
    var type: EntryType {
        get { EntryType(rawValue: typeRaw) ?? .person }
        set { typeRaw = newValue.rawValue }
    }
    
    var infobox: InfoboxData {
        get {
            guard let data = infoboxJSON else { return .empty }
            return (try? JSONDecoder().decode(InfoboxData.self, from: data)) ?? .empty
        }
        set { infoboxJSON = try? JSONEncoder().encode(newValue) }
    }
    
    var sections: [EntrySection] {
        get {
            guard let data = sectionsJSON else { return [] }
            return (try? JSONDecoder().decode([EntrySection].self, from: data)) ?? []
        }
        set { sectionsJSON = try? JSONEncoder().encode(newValue) }
    }
    
    var categories: [String] {
        get {
            guard let data = categoriesJSON else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { categoriesJSON = try? JSONEncoder().encode(newValue) }
    }
    
    var seeAlso: [String] {
        get {
            guard let data = seeAlsoJSON else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { seeAlsoJSON = try? JSONEncoder().encode(newValue) }
    }
    
    var allBlueLinks: [String] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        var links: [String] = []
        for section in sections {
            let range = NSRange(section.content.startIndex..., in: section.content)
            let matches = regex?.matches(in: section.content, range: range) ?? []
            for match in matches {
                if let r = Range(match.range(at: 1), in: section.content) {
                    links.append(String(section.content[r]))
                }
            }
        }
        return Array(Set(links))
    }
    
    var allRedLinks: [String] {
        let pattern = #"\{\{([^\}]+)\}\}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        var links: [String] = []
        for section in sections {
            let range = NSRange(section.content.startIndex..., in: section.content)
            let matches = regex?.matches(in: section.content, range: range) ?? []
            for match in matches {
                if let r = Range(match.range(at: 1), in: section.content) {
                    links.append(String(section.content[r]))
                }
            }
        }
        return Array(Set(links))
    }
}
