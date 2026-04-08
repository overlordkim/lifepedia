import Foundation

struct SimpleUser: Identifiable {
    let id: String
    let displayName: String
    let avatarSeed: Int
}

@Observable
final class FollowService {
    static let shared = FollowService()

    private(set) var followingIds: Set<String> = []
    private(set) var followerIds: Set<String> = []
    private(set) var userCache: [String: SimpleUser] = [:]

    private let session = URLSession.shared

    private init() {}

    var followingCount: Int { followingIds.count }
    var followerCount: Int { followerIds.count }

    func isFollowing(_ userId: String) -> Bool {
        followingIds.contains(userId)
    }

    func displayName(for userId: String) -> String {
        userCache[userId]?.displayName ?? "…"
    }

    func avatarSeed(for userId: String) -> Int {
        userCache[userId]?.avatarSeed ?? abs(userId.hashValue) % 70
    }

    func syncFromRemote() async {
        guard let me = AuthService.shared.currentUser else { return }
        async let fetchFollowing: () = loadFollowing(userId: me.id)
        async let fetchFollowers: () = loadFollowers(userId: me.id)
        _ = await (fetchFollowing, fetchFollowers)
        let allIds = followingIds.union(followerIds)
        if !allIds.isEmpty {
            await fetchUserProfiles(ids: allIds)
        }
    }

    func follow(_ userId: String) {
        guard let me = AuthService.shared.currentUser else { return }
        followingIds.insert(userId)

        Task {
            let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/follows")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONEncoder().encode(
                ["follower_id": me.id, "following_id": userId]
            )
            let (_, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                await MainActor.run { followingIds.remove(userId) }
            }
        }
    }

    func unfollow(_ userId: String) {
        guard let me = AuthService.shared.currentUser else { return }
        followingIds.remove(userId)

        Task {
            let query = "follower_id=eq.\(me.id)&following_id=eq.\(userId)"
            let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/follows?\(query)")!
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            let (_, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                await MainActor.run { followingIds.insert(userId) }
            }
        }
    }

    func toggle(_ userId: String) {
        if isFollowing(userId) {
            unfollow(userId)
        } else {
            follow(userId)
        }
    }

    // MARK: - Private

    private func loadFollowing(userId: String) async {
        let query = "follower_id=eq.\(userId)&select=following_id"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/follows?\(query)") else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await session.data(for: req),
              let rows = try? JSONDecoder().decode([[String: String]].self, from: data) else { return }

        let ids = Set(rows.compactMap { $0["following_id"] })
        await MainActor.run { self.followingIds = ids }
    }

    private func loadFollowers(userId: String) async {
        let query = "following_id=eq.\(userId)&select=follower_id"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/follows?\(query)") else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await session.data(for: req),
              let rows = try? JSONDecoder().decode([[String: String]].self, from: data) else { return }

        let ids = Set(rows.compactMap { $0["follower_id"] })
        await MainActor.run { self.followerIds = ids }
    }

    private func fetchUserProfiles(ids: Set<String>) async {
        let idList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let query = "id=in.(\(idList))&select=id,display_name,avatar_seed"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/users?\(query)") else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await session.data(for: req) else { return }

        struct UserRow: Decodable {
            let id: String
            let displayName: String
            let avatarSeed: Int
            enum CodingKeys: String, CodingKey {
                case id
                case displayName = "display_name"
                case avatarSeed = "avatar_seed"
            }
        }

        guard let rows = try? JSONDecoder().decode([UserRow].self, from: data) else { return }
        var cache: [String: SimpleUser] = [:]
        for r in rows {
            cache[r.id] = SimpleUser(id: r.id, displayName: r.displayName, avatarSeed: r.avatarSeed)
        }
        await MainActor.run { self.userCache = cache }
    }
}
