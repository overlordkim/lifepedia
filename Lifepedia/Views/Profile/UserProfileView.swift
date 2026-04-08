import SwiftUI
import SwiftData

struct UserProfileView: View {
    let userName: String
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @State private var showFollowingSheet = false
    @State private var showFollowersSheet = false

    private var followService: FollowService { FollowService.shared }

    private var isFollowing: Bool { followService.isFollowing(userName) }

    private var userEntries: [Entry] {
        allEntries.filter { $0.authorId == userId && !$0.isDraft }
    }

    private var avatarSeed: Int {
        abs(userName.hashValue) % 200
    }

    private var mockFollowing: [String] { followService.followingList.filter { $0 != userName } }
    private var mockFollowers: [String] { followService.followerNames.filter { $0 != userName } }

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
            userFollowListSheet(title: "关注", names: mockFollowing, isFollowingList: true)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFollowersSheet) {
            userFollowListSheet(title: "被关注", names: mockFollowers, isFollowingList: false)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

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

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                AsyncImage(url: URL(string: "https://i.pravatar.cc/200?img=\(avatarSeed)")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.wikiBgSecondary)
                            .overlay(
                                Text(String(userName.prefix(1)))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.wikiSecondary)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                HStack(spacing: 0) {
                    profileStatItem(value: userEntries.count, label: "词条")
                    profileStatItem(value: mockFollowing.count, label: "关注", action: { showFollowingSheet = true })
                    profileStatItem(value: mockFollowers.count, label: "被关注", action: { showFollowersSheet = true })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text(bioForUser)
                    .font(.system(size: 14))
                    .foregroundColor(.wikiSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    followService.toggle(userName)
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
        .navigationDestination(for: UserDestination.self) { dest in
            UserProfileView(userName: dest.userName, userId: dest.userId)
                .navigationBarHidden(true)
        }
    }

    private func userFollowListSheet(title: String, names: [String], isFollowingList: Bool) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.wikiText)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            if names.isEmpty {
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
                        ForEach(names, id: \.self) { name in
                            HStack(spacing: 12) {
                                let seed = abs(name.hashValue) % 70
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
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.wikiText)
                                    Text("用百科的方式，记录人生")
                                        .font(.system(size: 12))
                                        .foregroundColor(.wikiTertiary)
                                }
                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        followService.toggle(name)
                                    }
                                } label: {
                                    Text(followService.isFollowing(name) ? "已关注" : (isFollowingList ? "关注" : "回关"))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(followService.isFollowing(name) ? .wikiSecondary : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(followService.isFollowing(name) ? Color.wikiBgSecondary : Color.wikiBlue)
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

    private var bioForUser: String {
        switch userId {
        case "yudong":      return "记录那些温暖的人和事"
        case "linqing":     return "爱记录旧物和老味道"
        case "chenxiaoyu":  return "我家猫叫大橘"
        default:            return "用百科的方式，记录人生"
        }
    }
}
