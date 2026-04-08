import SwiftUI
import SwiftData

struct UserProfileView: View {
    let userName: String
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @State private var showFollowingSheet = false
    @State private var showFollowersSheet = false
    @State private var remoteUser: SimpleUser?
    @State private var followService = FollowService.shared

    @State private var userFollowingList: [(id: String, name: String)] = []
    @State private var userFollowerList: [(id: String, name: String)] = []
    @State private var userBio: String = "用百科的方式，记录人生"

    private var isFollowing: Bool { followService.isFollowing(userId) }

    private var userEntries: [Entry] {
        allEntries.filter { $0.authorId == userId && !$0.isDraft }
    }

    private var displayName: String {
        remoteUser?.displayName ?? followService.displayName(for: userId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topBar
                profileSection
                entriesSection
            }
            .padding(.bottom, 40)
        }
        .background(Color.wikiBg)
        .sheet(isPresented: $showFollowingSheet) {
            followListSheet(title: "关注", users: userFollowingList, isFollowingList: true)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFollowersSheet) {
            followListSheet(title: "被关注", users: userFollowerList, isFollowingList: false)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await fetchUserProfile()
            await fetchUserFollows()
        }
    }

    // MARK: - Data Fetching

    private func fetchUserProfile() async {
        let query = "id=eq.\(userId)&select=id,display_name,bio,avatar_seed&limit=1"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/users?\(query)") else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
        struct Row: Decodable {
            let id: String; let displayName: String; let bio: String; let avatarSeed: Int
            enum CodingKeys: String, CodingKey {
                case id; case displayName = "display_name"; case bio; case avatarSeed = "avatar_seed"
            }
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data), let r = rows.first else { return }
        await MainActor.run {
            remoteUser = SimpleUser(id: r.id, displayName: r.displayName, avatarSeed: r.avatarSeed)
            userBio = r.bio
        }
    }

    private func fetchUserFollows() async {
        async let following = fetchFollowIds(query: "follower_id=eq.\(userId)&select=following_id")
        async let followers = fetchFollowIds(query: "following_id=eq.\(userId)&select=follower_id")
        let (fing, fers) = await (following, followers)

        let followingIds = fing.compactMap { $0["following_id"] }
        let followerIds = fers.compactMap { $0["follower_id"] }

        let allIds = Set(followingIds + followerIds)
        let profiles = await fetchUserNames(ids: allIds)

        await MainActor.run {
            userFollowingList = followingIds.map { id in (id: id, name: profiles[id] ?? "…") }
            userFollowerList = followerIds.map { id in (id: id, name: profiles[id] ?? "…") }
        }
    }

    private func fetchFollowIds(query: String) async -> [[String: String]] {
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/follows?\(query)") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONDecoder().decode([[String: String]].self, from: data) else { return [] }
        return rows
    }

    private func fetchUserNames(ids: Set<String>) async -> [String: String] {
        guard !ids.isEmpty else { return [:] }
        let idList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let query = "id=in.(\(idList))&select=id,display_name"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/users?\(query)") else { return [:] }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return [:] }
        struct Row: Decodable {
            let id: String; let displayName: String
            enum CodingKeys: String, CodingKey { case id; case displayName = "display_name" }
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.displayName) })
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }
            Spacer()
            Text(displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.wikiText)
            Spacer()
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.wikiBg)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(.wikiDivider),
            alignment: .bottom
        )
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                AsyncImage(url: Secrets.avatarURL(for: userId)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.wikiBgSecondary)
                            .overlay(
                                Text(String(displayName.prefix(1)))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.wikiSecondary)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                HStack(spacing: 0) {
                    profileStatItem(value: userEntries.count, label: "词条")
                    profileStatItem(value: userFollowingList.count, label: "关注", action: { showFollowingSheet = true })
                    profileStatItem(value: userFollowerList.count, label: "被关注", action: { showFollowersSheet = true })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text(userBio)
                    .font(.system(size: 14))
                    .foregroundColor(.wikiSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    followService.toggle(userId)
                }
            } label: {
                Text(isFollowing ? "已关注" : "关注")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFollowing ? .wikiSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isFollowing ? Color.wikiBgSecondary : Color.wikiBlue)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isFollowing ? Color.wikiDivider : Color.clear, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private func profileStatItem(value: Int, label: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.wikiText)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
    }

    // MARK: - Entries Section

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.wikiBgSecondary)
                .frame(height: 8)

            HStack {
                Text("ta 的词条")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text("\(userEntries.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.wikiTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if userEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary)
                    Text("还没有公开的词条")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(userEntries) { entry in
                        NavigationLink(value: entry.id) {
                            FeedCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Follow List Sheet

    private func followListSheet(title: String, users: [(id: String, name: String)], isFollowingList: Bool) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.wikiText)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            if users.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary)
                    Text(isFollowingList ? "还没有关注任何人" : "还没有人关注 ta")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users, id: \.id) { user in
                            HStack(spacing: 12) {
                                AsyncImage(url: Secrets.avatarURL(for: user.id)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Circle().fill(Color.wikiBgSecondary)
                                            .overlay(
                                                Text(String(user.name.prefix(1)))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.wikiSecondary)
                                            )
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())

                                Text(user.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.wikiText)

                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        followService.toggle(user.id)
                                    }
                                } label: {
                                    Text(followService.isFollowing(user.id) ? "已关注" : (isFollowingList ? "关注" : "回关"))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(followService.isFollowing(user.id) ? .wikiSecondary : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(followService.isFollowing(user.id) ? Color.wikiBgSecondary : Color.wikiBlue)
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .background(Color.wikiBg)
    }
}
