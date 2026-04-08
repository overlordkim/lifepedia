import SwiftUI
import SwiftData

struct UserProfileView: View {
    let userName: String
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @State private var isFollowing = false

    private var userEntries: [Entry] {
        allEntries.filter { $0.authorId == userId && !$0.isDraft }
    }

    private var avatarSeed: Int {
        abs(userName.hashValue) % 200
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
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }

            Spacer()

            Text(userName)
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

    // MARK: - 个人信息

    private var profileSection: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: "https://i.pravatar.cc/200?img=\(avatarSeed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                        .overlay(
                            Text(String(userName.prefix(1)))
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.wikiSecondary)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            VStack(spacing: 4) {
                Text(userName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.wikiText)
                Text(bioForUser)
                    .font(.system(size: 14))
                    .foregroundColor(.wikiSecondary)
            }

            HStack(spacing: 32) {
                statItem(value: userEntries.count, label: "词条")
                statItem(value: totalLikes, label: "获赞")
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isFollowing.toggle()
                }
            } label: {
                Text(isFollowing ? "已关注" : "关注")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isFollowing ? .wikiSecondary : .white)
                    .frame(width: 120, height: 36)
                    .background(
                        Capsule().fill(isFollowing ? Color.wikiBgSecondary : Color.wikiBlue)
                    )
                    .overlay(
                        Capsule().stroke(isFollowing ? Color.wikiDivider : Color.clear, lineWidth: 0.5)
                    )
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 词条列表

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
        .navigationDestination(for: UUID.self) { entryId in
            EntryPageView(entryId: entryId)
                .navigationBarHidden(true)
        }
    }

    // MARK: - Helpers

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.wikiText)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.wikiTertiary)
        }
    }

    private var totalLikes: Int {
        userEntries.reduce(0) { $0 + $1.likeCount }
    }

    private var bioForUser: String {
        switch userId {
        case "yudong":      return "记录那些温暖的人和事"
        case "linqing":     return "爱记录旧物和老味道"
        case "chenxiaoyu":  return "我家猫叫大橘"
        default:            return "用百科的方式，记录人生"
        }
    }
}
