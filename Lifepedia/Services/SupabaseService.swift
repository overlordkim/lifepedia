import Foundation

/// Supabase PostgREST 客户端 —— 零依赖，直接走 HTTP
final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    private let session = URLSession.shared
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // Supabase 返回 `2026-04-07T12:00:00.123456+00:00` 带小数秒
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFallback = ISO8601DateFormatter()
        isoFallback.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            if let date = iso.date(from: str) { return date }
            if let date = isoFallback.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    private var restURL: String { "\(Secrets.supabaseURL)/rest/v1" }

    private var headers: [String: String] {
        [
            "apikey": Secrets.supabaseAnonKey,
            "Authorization": "Bearer \(Secrets.supabaseAnonKey)",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }

    // MARK: - 拉取所有已发布词条（Feed 用）

    func fetchPublishedEntries() async throws -> [SupabaseEntry] {
        let url = URL(string: "\(restURL)/entries?status=eq.published&order=created_at.desc&limit=50")!
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SupabaseError.requestFailed(String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode([SupabaseEntry].self, from: data)
    }

    // MARK: - Upsert（创建或更新）

    func upsertEntry(_ entry: Entry) async throws {
        let dto = SupabaseEntry(from: entry)
        let body = try encoder.encode(dto)

        var request = URLRequest(url: URL(string: "\(restURL)/entries")!)
        request.httpMethod = "POST"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.requestFailed(msg)
        }
    }

    // MARK: - 删除

    func deleteEntry(id: UUID) async throws {
        let url = URL(string: "\(restURL)/entries?id=eq.\(id.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (_, _) = try await session.data(for: request)
    }

    // MARK: - 同步：把远程数据合并到本地 SwiftData

    func syncToLocal(remoteEntries: [SupabaseEntry], localEntries: [Entry], insert: (Entry) -> Void) {
        let localIds = Set(localEntries.map(\.id))
        for remote in remoteEntries {
            if localIds.contains(remote.id) {
                if let local = localEntries.first(where: { $0.id == remote.id }) {
                    remote.apply(to: local)
                }
            } else {
                let newEntry = remote.toEntry()
                insert(newEntry)
            }
        }
    }
}

// MARK: - DTO

struct SupabaseEntry: Codable {
    let id: UUID
    var title: String
    var subtitle: String?
    var category: String
    var scope: String
    var infobox: [SupabaseInfoboxField]?
    var introduction: String?
    var sections: [SupabaseSection]?
    var tags: [String]?
    var coverImageUrl: String?
    var authorName: String
    var authorId: String
    var contributorNames: [String]?
    var likeCount: Int
    var collectCount: Int
    var commentCount: Int
    var viewCount: Int
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var publishedAt: Date?

    struct SupabaseInfoboxField: Codable {
        var key: String
        var value: String
    }

    struct SupabaseSection: Codable {
        var title: String
        var body: String
    }

    /// SwiftData Entry → DTO
    init(from entry: Entry) {
        self.id = entry.id
        self.title = entry.title
        self.subtitle = entry.subtitle
        self.category = entry.categoryRaw
        self.scope = entry.scopeRaw
        self.infobox = entry.infobox.fields.map { SupabaseInfoboxField(key: $0.key, value: $0.value) }
        self.introduction = entry.introductionText
        self.sections = entry.sections.map { SupabaseSection(title: $0.title, body: $0.body) }
        self.tags = entry.tags
        self.coverImageUrl = entry.coverImageURL
        self.authorName = entry.authorName
        self.authorId = entry.authorId
        self.contributorNames = entry.contributorNames
        self.likeCount = entry.likeCount
        self.collectCount = entry.collectCount
        self.commentCount = entry.commentCount
        self.viewCount = entry.viewCount
        self.status = entry.statusRaw
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
        self.publishedAt = entry.publishedAt
    }

    /// DTO → SwiftData Entry
    func toEntry() -> Entry {
        Entry(
            id: id,
            title: title,
            subtitle: subtitle,
            category: EntryCategory(rawValue: category) ?? .person,
            scope: EntryScope(rawValue: scope) ?? .private,
            infobox: InfoboxData(fields: (infobox ?? []).map { InfoboxField(key: $0.key, value: $0.value) }),
            introduction: introduction,
            sections: (sections ?? []).map { EntrySection(title: $0.title, body: $0.body) },
            tags: tags ?? [],
            coverImageURL: coverImageUrl,
            authorName: authorName,
            authorId: authorId,
            contributorNames: contributorNames ?? [],
            likeCount: likeCount,
            collectCount: collectCount,
            commentCount: commentCount,
            viewCount: viewCount,
            status: EntryStatus(rawValue: status) ?? .published,
            createdAt: createdAt,
            updatedAt: updatedAt,
            publishedAt: publishedAt
        )
    }

    /// 把远程数据更新到已有的本地 Entry
    func apply(to entry: Entry) {
        if updatedAt > entry.updatedAt {
            entry.title = title
            entry.subtitle = subtitle
            entry.categoryRaw = category
            entry.scopeRaw = scope
            entry.infobox = InfoboxData(fields: (infobox ?? []).map { InfoboxField(key: $0.key, value: $0.value) })
            entry.introductionText = introduction
            entry.sections = (sections ?? []).map { EntrySection(title: $0.title, body: $0.body) }
            entry.tags = tags
            entry.coverImageURL = coverImageUrl
            entry.authorName = authorName
            entry.likeCount = likeCount
            entry.collectCount = collectCount
            entry.commentCount = commentCount
            entry.viewCount = viewCount
            entry.updatedAt = updatedAt
        }
    }
}

enum SupabaseError: LocalizedError {
    case requestFailed(String)
    var errorDescription: String? {
        switch self {
        case .requestFailed(let msg): return "Supabase 请求失败: \(msg)"
        }
    }
}
