import SwiftUI
import SwiftData

struct CollaboratorsSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showInviteField = false
    @FocusState private var isFocused: Bool

    private var isOwner: Bool { entry.authorId == "self" }
    private var isPublic: Bool { entry.scope == .public }

    private var collaborators: [String] {
        entry.contributorNames ?? []
    }

    private let knownUsers: [(name: String, id: String)] = [
        ("昱东", "yudong"), ("林清", "linqing"), ("陈小鱼", "chenxiaoyu"),
        ("爸爸", "baba"), ("妈妈", "mama"), ("姐姐", "sister"),
        ("阿花", "ahua"), ("小明", "xiaoming"), ("大壮", "dazhuang")
    ]

    private var searchResults: [(name: String, id: String)] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return knownUsers.filter { user in
            user.name.lowercased().contains(q) &&
            user.name != entry.authorName &&
            !collaborators.contains(user.name)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetTopBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    memberRow(
                        name: entry.authorName,
                        role: "创建者",
                        isOwner: true
                    )

                    if !collaborators.isEmpty {
                        ForEach(collaborators, id: \.self) { name in
                            memberRow(name: name, role: "合编者") {
                                removeCollaborator(name)
                            }
                        }
                    }

                    Divider().padding(.horizontal, 16).padding(.vertical, 8)

                    if isOwner || isPublic {
                        inviteSection
                    } else {
                        requestSection
                    }
                }
                .padding(.bottom, 20)
            }

            footerHint
        }
        .background(Color.wikiBg)
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

    private func memberRow(name: String, role: String, isOwner: Bool = false, onRemove: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            let seed = abs(name.hashValue) % 200
            AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(seed)")) { phase in
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
                Button { onRemove() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.wikiBgSecondary))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Invite (owner of private/collaborative entries)

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
                        let seed = abs(user.name.hashValue) % 200
                        AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(seed)")) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Circle().fill(Color.wikiBgSecondary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.wikiText)
                            Text("@\(user.id)")
                                .font(.system(size: 11))
                                .foregroundColor(.wikiTertiary)
                        }

                        Spacer()

                        Button {
                            sendInvite(to: user.name)
                        } label: {
                            Text("邀请")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.wikiBlue))
                        }
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

    // MARK: - Request (non-owner on public entries)

    @State private var hasRequested = false

    private var requestSection: some View {
        VStack(spacing: 12) {
            if hasRequested {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    Text("已发送申请，等待创建者同意")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiSecondary)
                }
                .padding(.horizontal, 16)
            } else {
                Button {
                    sendRequest()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 14))
                        Text("申请成为合编者")
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
                .padding(.horizontal, 16)
            }
        }
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

    private func sendInvite(to name: String) {
        var list = entry.contributorNames ?? []
        guard !list.contains(name) else { return }
        list.append(name)
        entry.contributorNames = list
        if entry.scope == .private {
            entry.scope = .collaborative
        }
        try? modelContext.save()
        searchText = ""

        NotificationService.shared.add(AppNotification(
            type: .collabInvite,
            title: "合编邀请",
            body: "你被邀请成为「\(entry.title.isEmpty ? "未命名词条" : entry.title)」的合编者",
            relatedEntryId: entry.id,
            fromUserName: name
        ))
    }

    private func sendRequest() {
        withAnimation(.spring(response: 0.3)) { hasRequested = true }

        NotificationService.shared.add(AppNotification(
            type: .collabRequest,
            title: "合编申请",
            body: "有人申请成为「\(entry.title.isEmpty ? "未命名词条" : entry.title)」的合编者",
            relatedEntryId: entry.id,
            fromUserName: "我"
        ))
    }

    private func removeCollaborator(_ name: String) {
        var list = entry.contributorNames ?? []
        list.removeAll { $0 == name }
        entry.contributorNames = list
        try? modelContext.save()
    }
}
