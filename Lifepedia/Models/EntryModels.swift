import Foundation
import SwiftData

// MARK: - 七大分类

enum EntryCategory: String, Codable, CaseIterable, Identifiable {
    case person    = "person"
    case place     = "place"
    case companion = "companion"
    case taste     = "taste"
    case keepsake  = "keepsake"
    case moment    = "moment"
    case era       = "era"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .person:    return "人物"
        case .place:     return "栖居"
        case .companion: return "相伴"
        case .taste:     return "滋味"
        case .keepsake:  return "旧物"
        case .moment:    return "际遇"
        case .era:       return "流年"
        }
    }

    var subtitle: String {
        switch self {
        case .person:    return "那些走进过你生命的人"
        case .place:     return "那些容纳过你生活的地方"
        case .companion: return "那些陪过你的非人之物"
        case .taste:     return "那些喂养过你的食物"
        case .keepsake:  return "那些被你拥有过的东西"
        case .moment:    return "那些发生过的事"
        case .era:       return "那些走过的时期"
        }
    }

    var defaultInfoboxKeys: [String] {
        switch self {
        case .person:
            return ["全名", "生年", "卒年", "关系", "籍贯", "职业", "状态"]
        case .place:
            return ["地点名", "类型", "位置", "建成", "现状", "作者居住时期"]
        case .companion:
            return ["名字", "物种", "品种", "性别", "毛色", "性情", "状态"]
        case .taste:
            return ["菜名", "类型", "菜系", "创制者", "关键食材", "传承状态"]
        case .keepsake:
            return ["物品名", "类型", "来历", "获得时间", "当前状态"]
        case .moment:
            return ["事件名", "类型", "日期", "地点", "参与者"]
        case .era:
            return ["时期名", "开始", "结束", "作者年龄", "主要居所"]
        }
    }
}

// MARK: - 三个域

enum EntryScope: String, Codable {
    case `private`      = "private"
    case collaborative  = "collaborative"
    case `public`       = "public"

    var label: String {
        switch self {
        case .private:       return "私人"
        case .collaborative: return "合编"
        case .public:        return "公共"
        }
    }

    var icon: String {
        switch self {
        case .private:       return "lock"
        case .collaborative: return "person.2"
        case .public:        return "globe"
        }
    }
}

// MARK: - 信息框

struct InfoboxField: Codable, Identifiable, Hashable {
    var id: String { key }
    var key: String
    var value: String
}

struct InfoboxData: Codable {
    var fields: [InfoboxField]
    static let empty = InfoboxData(fields: [])
}

// MARK: - 章节

struct EntrySection: Codable, Identifiable, Hashable {
    var id: String { title }
    var title: String
    var body: String
    var imageRefs: [String]

    init(title: String, body: String, imageRefs: [String] = []) {
        self.title = title
        self.body = body
        self.imageRefs = imageRefs
    }
}

// MARK: - 图片

struct EntryImage: Codable, Identifiable, Hashable {
    var id: String
    var url: String
    var caption: String
    var isAIGenerated: Bool

    init(id: String = UUID().uuidString, url: String, caption: String, isAIGenerated: Bool = false) {
        self.id = id
        self.url = url
        self.caption = caption
        self.isAIGenerated = isAIGenerated
    }
}

// MARK: - 修订记录

struct Revision: Codable, Identifiable, Hashable {
    var id: String
    var editorName: String
    var timestamp: Date
    var summary: String

    init(id: String = UUID().uuidString, editorName: String, timestamp: Date = .now, summary: String) {
        self.id = id
        self.editorName = editorName
        self.timestamp = timestamp
        self.summary = summary
    }
}

// MARK: - 评论

struct Comment: Codable, Identifiable, Hashable {
    var id: String
    var authorName: String
    var authorAvatar: String?
    var body: String
    var createdAt: Date
    var likeCount: Int
    var parentId: String?
    var replyToName: String?

    init(id: String = UUID().uuidString, authorName: String = "我", authorAvatar: String? = nil, body: String, createdAt: Date = .now, likeCount: Int = 0, parentId: String? = nil, replyToName: String? = nil) {
        self.id = id
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.body = body
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.parentId = parentId
        self.replyToName = replyToName
    }
}

// MARK: - 聊天消息

struct ChatMessage: Identifiable, Codable {
    var id: String
    var role: ChatRole
    var content: String
    var timestamp: Date

    init(id: String = UUID().uuidString, role: ChatRole, content: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum ChatRole: String, Codable {
    case user, assistant, system
}

// MARK: - 草稿

struct EntryDraft: Codable {
    var title: String?
    var categoryRaw: String?
    var scopeRaw: String?
    var infobox: InfoboxData?
    var introduction: String?
    var sections: [EntrySection]?
    var images: [EntryImage]?
    var lastEditedAt: Date
    var lastEditedBy: String

    init(
        title: String? = nil,
        category: EntryCategory? = nil,
        scope: EntryScope? = nil,
        infobox: InfoboxData? = nil,
        introduction: String? = nil,
        sections: [EntrySection]? = nil,
        images: [EntryImage]? = nil,
        lastEditedAt: Date = .now,
        lastEditedBy: String = "我"
    ) {
        self.title = title
        self.categoryRaw = category?.rawValue
        self.scopeRaw = scope?.rawValue
        self.infobox = infobox
        self.introduction = introduction
        self.sections = sections
        self.images = images
        self.lastEditedAt = lastEditedAt
        self.lastEditedBy = lastEditedBy
    }
}

// MARK: - 词条状态

enum EntryStatus: String, Codable {
    case draft     = "draft"
    case published = "published"
}

// MARK: - 词条（核心模型）

@Model
final class Entry {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var categoryRaw: String
    var scopeRaw: String

    // JSON 存储
    var infoboxJSON: Data?
    var introductionText: String?
    var sectionsJSON: Data?
    var imagesJSON: Data?
    var relatedEntryTitles: [String]?
    var tags: [String]?
    var revisionsJSON: Data?
    var commentsJSON: Data?

    // 图片
    var coverImageURL: String?

    // 作者
    var authorName: String
    var authorId: String
    var contributorNames: [String]?

    // 互动
    var likeCount: Int
    var collectCount: Int
    var commentCount: Int
    var viewCount: Int

    // 草稿 & 状态
    var draftJSON: Data?
    var statusRaw: String

    // 时间
    var createdAt: Date
    var updatedAt: Date
    var publishedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        category: EntryCategory,
        scope: EntryScope = .private,
        infobox: InfoboxData = .empty,
        introduction: String? = nil,
        sections: [EntrySection] = [],
        images: [EntryImage] = [],
        relatedEntryTitles: [String] = [],
        tags: [String] = [],
        revisions: [Revision] = [],
        comments: [Comment] = [],
        coverImageURL: String? = nil,
        authorName: String = "我",
        authorId: String = "self",
        contributorNames: [String] = [],
        likeCount: Int = 0,
        collectCount: Int = 0,
        commentCount: Int = 0,
        viewCount: Int = 0,
        status: EntryStatus = .published,
        draft: EntryDraft? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.categoryRaw = category.rawValue
        self.scopeRaw = scope.rawValue
        self.infoboxJSON = try? JSONEncoder().encode(infobox)
        self.introductionText = introduction
        self.sectionsJSON = try? JSONEncoder().encode(sections)
        self.imagesJSON = try? JSONEncoder().encode(images)
        self.relatedEntryTitles = relatedEntryTitles
        self.tags = tags
        self.revisionsJSON = try? JSONEncoder().encode(revisions)
        self.commentsJSON = try? JSONEncoder().encode(comments)
        self.coverImageURL = coverImageURL
        self.authorName = authorName
        self.authorId = authorId
        self.contributorNames = contributorNames
        self.likeCount = likeCount
        self.collectCount = collectCount
        self.commentCount = commentCount
        self.viewCount = viewCount
        self.statusRaw = status.rawValue
        self.draftJSON = try? JSONEncoder().encode(draft)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedAt = publishedAt ?? (status == .published ? createdAt : nil)
    }

    // MARK: - Computed

    var category: EntryCategory {
        get { EntryCategory(rawValue: categoryRaw) ?? .person }
        set { categoryRaw = newValue.rawValue }
    }

    var scope: EntryScope {
        get { EntryScope(rawValue: scopeRaw) ?? .private }
        set { scopeRaw = newValue.rawValue }
    }

    var infobox: InfoboxData {
        get { (try? infoboxJSON.flatMap { try JSONDecoder().decode(InfoboxData.self, from: $0) }) ?? .empty }
        set { infoboxJSON = try? JSONEncoder().encode(newValue) }
    }

    var sections: [EntrySection] {
        get { (try? sectionsJSON.flatMap { try JSONDecoder().decode([EntrySection].self, from: $0) }) ?? [] }
        set { sectionsJSON = try? JSONEncoder().encode(newValue) }
    }

    var images: [EntryImage] {
        get { (try? imagesJSON.flatMap { try JSONDecoder().decode([EntryImage].self, from: $0) }) ?? [] }
        set { imagesJSON = try? JSONEncoder().encode(newValue) }
    }

    var revisions: [Revision] {
        get { (try? revisionsJSON.flatMap { try JSONDecoder().decode([Revision].self, from: $0) }) ?? [] }
        set { revisionsJSON = try? JSONEncoder().encode(newValue) }
    }

    var comments: [Comment] {
        get { (try? commentsJSON.flatMap { try JSONDecoder().decode([Comment].self, from: $0) }) ?? [] }
        set { commentsJSON = try? JSONEncoder().encode(newValue) }
    }

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .published }
        set { statusRaw = newValue.rawValue }
    }

    var draft: EntryDraft? {
        get { try? draftJSON.flatMap { try JSONDecoder().decode(EntryDraft.self, from: $0) } }
        set { draftJSON = try? newValue.flatMap { try JSONEncoder().encode($0) } }
    }

    var isDraft: Bool { status == .draft }
    var hasPendingDraft: Bool { status == .published && draft != nil }

    var canEdit: Bool {
        let currentId = AuthService.shared.currentUser?.id
        let currentName = AuthService.shared.currentUser?.displayName
        if authorId == currentId || authorId == "self" { return true }
        let contributors = contributorNames ?? []
        if let name = currentName, contributors.contains(name) {
            return true
        }
        return false
    }

    /// 从正文中提取 [[蓝色链接]]
    var allBlueLinks: [String] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var links: [String] = []
        for section in sections {
            let range = NSRange(section.body.startIndex..., in: section.body)
            for match in regex.matches(in: section.body, range: range) {
                if let r = Range(match.range(at: 1), in: section.body) {
                    links.append(String(section.body[r]))
                }
            }
        }
        return Array(Set(links))
    }

    /// 从正文中提取 {{红色链接}}
    var allRedLinks: [String] {
        let pattern = #"\{\{([^\}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var links: [String] = []
        for section in sections {
            let range = NSRange(section.body.startIndex..., in: section.body)
            for match in regex.matches(in: section.body, range: range) {
                if let r = Range(match.range(at: 1), in: section.body) {
                    links.append(String(section.body[r]))
                }
            }
        }
        return Array(Set(links))
    }
}

// MARK: - 用户导航目标

struct UserDestination: Hashable {
    let userName: String
    let userId: String
}

// MARK: - 通知

enum NotificationType: String, Codable {
    case comment    = "comment"
    case like       = "like"
    case follow     = "follow"
    case coEdit     = "coEdit"
    case aiUpdate   = "aiUpdate"
    case collabInvite = "collabInvite"
    case collabRequest = "collabRequest"

    var icon: String {
        switch self {
        case .comment:        return "text.bubble.fill"
        case .like:           return "heart.fill"
        case .follow:         return "person.fill.badge.plus"
        case .coEdit:         return "person.2.fill"
        case .aiUpdate:       return "sparkles"
        case .collabInvite:   return "envelope.fill"
        case .collabRequest:  return "hand.raised.fill"
        }
    }

}

struct AppNotification: Identifiable, Codable {
    var id: String
    var type: NotificationType
    var title: String
    var body: String
    var relatedEntryId: UUID?
    var fromUserName: String?
    var fromUserId: String?
    var isRead: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, type: NotificationType, title: String, body: String, relatedEntryId: UUID? = nil, fromUserName: String? = nil, fromUserId: String? = nil, isRead: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.relatedEntryId = relatedEntryId
        self.fromUserName = fromUserName
        self.fromUserId = fromUserId
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
