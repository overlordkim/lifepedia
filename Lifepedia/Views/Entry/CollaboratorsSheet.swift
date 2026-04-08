import SwiftUI
import SwiftData

struct CollaboratorsSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var inviteName = ""
    @State private var showInviteField = false
    @FocusState private var isFocused: Bool

    private var collaborators: [String] {
        entry.contributorNames ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 创建者（始终显示）
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

                if showInviteField {
                    inviteInput
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showInviteField = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.wikiBlue)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.wikiBlue.opacity(0.1)))

                            Text("邀请合编者")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.wikiBlue)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }

                Spacer()

                Text("合编者可以与词条的 AI 对话并编辑内容")
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
            }
            .navigationTitle("合编者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(.wikiBlue)
                }
            }
        }
    }

    // MARK: - 成员行

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
            .frame(width: 38, height: 38)
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
            } else if let onRemove = onRemove, entry.authorId == "self" {
                Button { onRemove() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.wikiTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 邀请输入

    private var inviteInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 14))
                .foregroundColor(.wikiSecondary)
                .frame(width: 20)

            TextField("输入用户名…", text: $inviteName)
                .font(.system(size: 15))
                .focused($isFocused)
                .onSubmit { inviteCollaborator() }

            if !inviteName.trimmingCharacters(in: .whitespaces).isEmpty {
                Button { inviteCollaborator() } label: {
                    Text("邀请")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.wikiBlue))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - 逻辑

    private func inviteCollaborator() {
        let name = inviteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var list = entry.contributorNames ?? []
        guard !list.contains(name) else { return }
        list.append(name)
        entry.contributorNames = list
        if entry.scope == .private {
            entry.scope = .collaborative
        }
        try? modelContext.save()
        inviteName = ""
        showInviteField = false
    }

    private func removeCollaborator(_ name: String) {
        var list = entry.contributorNames ?? []
        list.removeAll { $0 == name }
        entry.contributorNames = list
        try? modelContext.save()
    }
}
