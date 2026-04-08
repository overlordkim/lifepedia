import SwiftUI
import SwiftData

struct CollaboratorsSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    private var myId: String {
        AuthService.shared.currentUser?.id ?? "self"
    }
    private var myName: String {
        AuthService.shared.currentUser?.displayName ?? ""
    }
    private var isOwner: Bool {
        entry.authorId == myId
    }

    private var collaborators: [String] {
        entry.contributorNames ?? []
    }

    private var isCollaborator: Bool {
        collaborators.contains(myName)
    }

    @State private var searchResults: [(name: String, id: String)] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var nameToId: [String: String] = [:]
    @State private var isSyncing = false
    @State private var syncError: String?

    var body: some View {
        VStack(spacing: 0) {
            sheetTopBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    memberRow(
                        name: entry.authorName,
                        odUserId: entry.authorId,
                        role: "创建者",
                        isOwner: true
                    )

                    if !collaborators.isEmpty {
                        ForEach(collaborators, id: \.self) { name in
                            memberRow(name: name, odUserId: nameToId[name], role: "合编者") {
                                removeCollaborator(name)
                            }
                        }
                    }

                    Divider().padding(.horizontal, 16).padding(.vertical, 8)

                    if isOwner {
                        inviteSection
                    } else if !isCollaborator {
                        joinSection
                    } else {
                        alreadyCollaboratorHint
                    }

                    if let error = syncError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 20)
            }

            footerHint
        }
        .background(Color.wikiBg)
        .task { await resolveCollaboratorIds() }
        .onChange(of: searchText) {
            searchTask?.cancel()
            let q = searchText
            guard !q.isEmpty else { searchResults = []; return }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await searchUsers(query: q)
            }
        }
    }

    private func searchUsers(query: String) async {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "\(Secrets.supabaseURL)/rest/v1/users?display_name=ilike.*\(encoded)*&select=id,display_name&limit=10"
        guard let url = URL(string: endpoint) else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
        struct Row: Decodable {
            let id: String; let displayName: String
            enum CodingKeys: String, CodingKey { case id; case displayName = "display_name" }
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { return }
        let currentCollabs = collaborators
        let filtered = rows
            .filter { $0.id != entry.authorId && !currentCollabs.contains($0.displayName) }
            .map { (name: $0.displayName, id: $0.id) }
        await MainActor.run { searchResults = filtered }
    }

    private func resolveCollaboratorIds() async {
        let names = collaborators
        guard !names.isEmpty else { return }
        let nameList = names.map { "\"\($0)\"" }.joined(separator: ",")
        let query = "display_name=in.(\(nameList))&select=id,display_name"
        guard let url = URL(string: "\(Secrets.supabaseURL)/rest/v1/users?\(query)") else { return }
        var req = URLRequest(url: url)
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
        struct Row: Decodable {
            let id: String; let displayName: String
            enum CodingKeys: String, CodingKey { case id; case displayName = "display_name" }
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { return }
        var map: [String: String] = [:]
        for r in rows { map[r.displayName] = r.id }
        await MainActor.run { nameToId = map }
    }

    // MARK: - Top bar

    private var sheetTopBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }
            Spacer()
            Text("合编者")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.wikiText)
            Spacer()
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Member row

    private func memberRow(name: String, odUserId: String?, role: String, isOwner: Bool = false, onRemove: (() -> Void)? = nil) -> some View {
        let avatarId = odUserId ?? nameToId[name] ?? entry.authorId
        return HStack(spacing: 12) {
            AsyncImage(url: Secrets.avatarURL(for: avatarId)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.wikiSecondary)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.wikiText)
                Text(role)
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
            }

            Spacer()

            if isOwner {
                Text("创建者")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.wikiBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.wikiBlue.opacity(0.1)))
            } else if let onRemove = onRemove, self.isOwner {
                Button {
                    onRemove()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.wikiTertiary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.wikiBgSecondary))
                    }
                }
                .disabled(isSyncing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Invite (owner)

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.wikiTertiary)
                TextField("搜索用户名…", text: $searchText)
                    .font(.system(size: 14))
                    .focused($isFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.wikiBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 16)

            if !searchResults.isEmpty {
                ForEach(searchResults, id: \.id) { user in
                    HStack(spacing: 12) {
                        AsyncImage(url: Secrets.avatarURL(for: user.id)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Circle().fill(Color.wikiBgSecondary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                        Text(user.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.wikiText)

                        Spacer()

                        Button {
                            addCollaborator(name: user.name, userId: user.id)
                        } label: {
                            if isSyncing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                            } else {
                                Text("邀请")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.wikiBlue))
                            }
                        }
                        .disabled(isSyncing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            } else if !searchText.isEmpty {
                Text("没有找到用户")
                    .font(.system(size: 13))
                    .foregroundColor(.wikiTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Join (non-owner, not yet collaborator)

    private var joinSection: some View {
        VStack(spacing: 12) {
            Button {
                addCollaborator(name: myName, userId: myId)
            } label: {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .tint(.wikiBlue)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                    }
                    Text("加入合编")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.wikiBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.wikiBlue.opacity(0.06))
                )
            }
            .disabled(isSyncing)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Already collaborator hint

    private var alreadyCollaboratorHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
            Text("你已是该词条的合编者")
                .font(.system(size: 14))
                .foregroundColor(.wikiSecondary)
        }
        .padding(.horizontal, 16)
    }

    private var footerHint: some View {
        Text(isOwner ? "搜索用户并邀请 ta 成为合编者" : "合编者可以与词条的 AI 对话并编辑内容")
            .font(.system(size: 12))
            .foregroundColor(.wikiTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.wikiBg)
    }

    // MARK: - Actions

    private func addCollaborator(name: String, userId: String) {
        var list = entry.contributorNames ?? []
        guard !list.contains(name) else { return }
        list.append(name)
        entry.contributorNames = list
        nameToId[name] = userId
        if entry.scope == .private {
            entry.scope = .collaborative
        }
        try? modelContext.save()
        searchText = ""
        searchResults = []

        syncCollaboratorsToRemote(list)
    }

    private func removeCollaborator(_ name: String) {
        var list = entry.contributorNames ?? []
        list.removeAll { $0 == name }
        entry.contributorNames = list
        try? modelContext.save()

        syncCollaboratorsToRemote(list)
    }

    private func syncCollaboratorsToRemote(_ names: [String]) {
        guard entry.status == .published else { return }
        isSyncing = true
        syncError = nil
        Task {
            do {
                try await SupabaseService.shared.updateCollaborators(
                    entryId: entry.id,
                    names: names
                )
                await MainActor.run { isSyncing = false }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncError = "同步失败，请重试"
                }
            }
        }
    }
}
