import SwiftUI
import SwiftData

struct MyPageView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @State private var selectedSubTab: SubTab = .authored
    @State private var selectedCategory: EntryCategory?
    @Binding var hideTabBar: Bool
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false
    @AppStorage("user_display_name") private var displayName = "我"
    @AppStorage("user_bio") private var bio = "用百科的方式，记录我的人生"
    @AppStorage("user_avatar_seed") private var avatarSeed = 32

    enum SubTab: String, CaseIterable {
        case authored  = "编纂"
        case coEditing = "合编"
        case favorited = "收藏"
    }

    private var draftEntries: [Entry] {
        allEntries.filter { $0.isDraft && $0.authorId == "self" }
    }

    private var publishedEntries: [Entry] {
        var entries: [Entry]
        switch selectedSubTab {
        case .authored:
            entries = allEntries.filter { $0.authorId == "self" && !$0.isDraft }
        case .coEditing:
            entries = allEntries.filter {
                !$0.isDraft && $0.authorId != "self" &&
                ($0.scope == .collaborative || $0.scope == .public) &&
                (($0.contributorNames ?? []).contains("我") || ($0.contributorNames ?? []).contains(displayName))
            }
        case .favorited:
            entries = allEntries.filter { $0.authorId != "self" && !$0.isDraft }
        }
        if let cat = selectedCategory {
            entries = entries.filter { $0.category == cat }
        }
        return entries
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    // 自定义顶栏
                    HStack {
                        Text("Lifepedia")
                            .font(.custom("Baskerville-BoldItalic", size: 28))
                            .foregroundColor(.wikiText)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.wikiText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)

                    profileHeader
                    statsRow
                    subTabBar

                    CategoryFilterBar(selected: $selectedCategory)

                    if selectedSubTab == .authored && !draftEntries.isEmpty {
                        draftSection
                    }

                    entryList
                }
                .padding(.bottom, 100)
            }
            .background(Color.wikiBg)
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { entryId in
                let isDraft = allEntries.first(where: { $0.id == entryId })?.isDraft ?? false
                EntryPageView(entryId: entryId, startInEditMode: isDraft, onNavigateToMyPage: {
                    navigationPath = NavigationPath()
                    hideTabBar = false
                })
                .navigationBarHidden(true)
            }
            .navigationDestination(for: UserDestination.self) { dest in
                UserProfileView(userName: dest.userName, userId: dest.userId)
                    .navigationBarHidden(true)
            }
        }
        .onChange(of: navigationPath.count) {
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = !navigationPath.isEmpty
            }
        }
    }

    // MARK: - 个人信息 + 统计（ins 横向布局）

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                AsyncImage(url: URL(string: "https://i.pravatar.cc/160?img=\(avatarSeed)")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.wikiBgSecondary)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.wikiTertiary)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())

                HStack(spacing: 0) {
                    statItem(value: allEntries.filter { $0.authorId == "self" && !$0.isDraft }.count, label: "词条")
                    statItem(value: followingSet.count, label: "关注", action: { showFollowingSheet = true })
                    statItem(value: followerNames.count, label: "被关注", action: { showFollowersSheet = true })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(.wikiSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showFollowingSheet) {
            followListSheet(title: "关注", users: Array(followingSet).map { ($0, resolveUserId(for: $0), abs($0.hashValue) % 70) }, isFollowingList: true)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFollowersSheet) {
            followListSheet(title: "被关注", users: followerNames.map { ($0, resolveUserId(for: $0), abs($0.hashValue) % 70) }, isFollowingList: false)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func followListSheet(title: String, users: [(String, String, Int)], isFollowingList: Bool) -> some View {
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
                    Text(isFollowingList ? "还没有关注任何人" : "还没有人关注你")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users, id: \.0) { user in
                            Button {
                                showFollowingSheet = false
                                showFollowersSheet = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigationPath.append(UserDestination(userName: user.0, userId: user.1))
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(user.2)")) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Circle().fill(Color.wikiBgSecondary)
                                                .overlay(
                                                    Text(String(user.0.prefix(1)))
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.wikiSecondary)
                                                )
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.0)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.wikiText)
                                        Text("@\(user.1)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.wikiTertiary)
                                    }

                                    Spacer()

                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            followService.toggle(user.0)
                                        }
                                    } label: {
                                        Text(followService.isFollowing(user.0) ? "已关注" : (isFollowingList ? "关注" : "回关"))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(followService.isFollowing(user.0) ? .wikiSecondary : .white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(followService.isFollowing(user.0) ? Color.wikiBgSecondary : Color.wikiBlue)
                                            )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .background(Color.wikiBg)
    }

    private func resolveUserId(for name: String) -> String {
        let knownUsers: [String: String] = [
            "昱东": "yudong", "林清": "linqing", "陈小鱼": "chenxiaoyu",
            "爸爸": "baba", "妈妈": "mama", "姐姐": "sister",
            "阿花": "ahua", "小明": "xiaoming", "大壮": "dazhuang"
        ]
        return knownUsers[name] ?? name.lowercased()
    }

    private var statsRow: some View { EmptyView() }

    private func statItem(value: Int, label: String, action: (() -> Void)? = nil) -> some View {
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

    // MARK: - 子 Tab

    private var subTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SubTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSubTab = tab
                        selectedCategory = nil
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(selectedSubTab == tab ? .wikiFilterSelected : .wikiFilterDefault)
                            .foregroundColor(selectedSubTab == tab ? .wikiText : .wikiTertiary)
                        Rectangle()
                            .fill(selectedSubTab == tab ? Color.wikiBlue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 草稿列表

    @State private var draftsExpanded = false

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    draftsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.wikiBlue)
                    Text("草稿")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.wikiText)
                    Text("\(draftEntries.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.wikiBgSecondary))
                    Spacer()
                    Image(systemName: draftsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if draftsExpanded {
                ForEach(draftEntries) { draft in
                    NavigationLink(value: draft.id) {
                        draftCard(draft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    @Environment(\.modelContext) private var modelContext

    private func draftCard(_ draft: Entry) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.wikiBgSecondary)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(draft.category.label.prefix(1))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(draft.title.isEmpty ? "未命名词条" : draft.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(draft.title.isEmpty ? .wikiTertiary : .wikiText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(draft.category.label)
                        .font(.system(size: 11))
                        .foregroundColor(.wikiTertiary)
                    Text("·")
                        .foregroundColor(.wikiTertiary)
                    Text(draftRelativeTime(draft.updatedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.wikiTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.wikiTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(draft)
                try? modelContext.save()
            } label: {
                Label("删除草稿", systemImage: "trash")
            }
        }
    }

    private func draftRelativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    // MARK: - 词条列表

    private var entryList: some View {
        LazyVStack(spacing: 12) {
            ForEach(publishedEntries) { entry in
                NavigationLink(value: entry.id) {
                    FeedCard(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    // MARK: - 关注数据

    @State private var showFollowingSheet = false
    @State private var showFollowersSheet = false

    private var followService: FollowService { FollowService.shared }
    private var followingSet: Set<String> { followService.followingSet }
    private var followerNames: [String] { followService.followerNames }

}
