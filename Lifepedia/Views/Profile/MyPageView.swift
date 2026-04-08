import SwiftUI
import SwiftData

struct MyPageView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @State private var selectedSubTab: SubTab = .authored
    @State private var selectedCategory: EntryCategory?
    @Binding var hideTabBar: Bool
    @State private var navigationPath = NavigationPath()

    enum SubTab: String, CaseIterable {
        case authored  = "编纂"
        case coEditing = "合编"
        case favorited = "收藏"
        case relations = "关系"
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
            entries = allEntries.filter { $0.scope == .collaborative || (($0.contributorNames ?? []).contains("我")) }
        case .favorited:
            entries = allEntries.filter { $0.authorId != "self" && !$0.isDraft }
        case .relations:
            return []
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
                        Button { } label: {
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

                    if selectedSubTab == .relations {
                        relationsContent
                    } else {
                        CategoryFilterBar(selected: $selectedCategory)

                        if selectedSubTab == .authored && !draftEntries.isEmpty {
                            draftEntry
                        }

                        entryList
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color.wikiBg)
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { entryId in
                EntryPageView(entryId: entryId, onNavigateToMyPage: {
                    navigationPath = NavigationPath()
                })
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
                // 头像
                AsyncImage(url: URL(string: "https://i.pravatar.cc/160?img=32")) { phase in
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

                // 统计：编纂 / 合编中 / 收藏
                HStack(spacing: 0) {
                    statItem(value: allEntries.filter { $0.authorId == "self" && !$0.isDraft }.count, label: "编纂")
                    statItem(value: allEntries.filter { $0.scope == .collaborative }.count, label: "合编中")
                    statItem(value: 3, label: "收藏")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // 名字 + bio
            VStack(alignment: .leading, spacing: 4) {
                Text("我")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text("用百科的方式，记录我的人生")
                    .font(.system(size: 14))
                    .foregroundColor(.wikiSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    private var statsRow: some View { EmptyView() }

    private func statItem(value: Int, label: String) -> some View {
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

    // MARK: - 草稿入口

    private var draftEntry: some View {
        NavigationLink(value: draftEntries.first!.id) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.wikiBgSecondary)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 20))
                            .foregroundColor(.wikiTertiary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("草稿")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(.wikiText)
                        Text("(\(draftEntries.count))")
                            .font(.wikiMeta)
                            .foregroundColor(.wikiTertiary)
                    }
                    if let first = draftEntries.first {
                        Text(first.title.isEmpty ? "未命名词条" : first.title)
                            .font(.wikiSmall)
                            .foregroundColor(.wikiSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.wikiTertiary)
            }
            .padding(14)
            .background(Color.wikiBg)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.wikiBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 词条列表

    private var entryList: some View {
        LazyVStack(spacing: 20) {
            ForEach(publishedEntries) { entry in
                NavigationLink(value: entry.id) {
                    FeedCard(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - 关系 Tab

    @State private var followingSet: Set<String> = ["昱东", "妈妈"]
    @State private var showUserDirectory = false

    private var relationsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 合编小组
            relationSection(title: "合编小组", icon: "person.2.fill") {
                groupCard(name: "我家", members: ["爸爸", "妈妈", "姐姐"], entries: 3)
                groupCard(name: "高中同学", members: ["昱东", "小明", "阿花", "大壮"], entries: 1)

                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("创建新小组")
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

            // 我关注的人
            relationSection(title: "我关注的人", icon: "heart.fill") {
                followRow(name: "昱东", username: "@yudong", entries: 12, avatarSeed: 15)
                followRow(name: "妈妈", username: "@mama_zhang", entries: 3, avatarSeed: 45)
            }

            // 关注我的人
            relationSection(title: "关注我的人", icon: "person.fill.checkmark") {
                followRow(name: "姐姐", username: "@sister_lin", entries: 5, avatarSeed: 28, isFollower: true)
                followRow(name: "昱东", username: "@yudong", entries: 12, avatarSeed: 15, isFollower: true)
                followRow(name: "小明", username: "@xiaoming", entries: 2, avatarSeed: 60, isFollower: true)

                Button { } label: {
                    Text("查看全部 5 人")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.wikiBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }

            // 发现用户
            Button { showUserDirectory = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(.wikiBlue)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.wikiBlue.opacity(0.1)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("发现用户")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.wikiText)
                        Text("找到有趣的人，关注他们的百科")
                            .font(.system(size: 12))
                            .foregroundColor(.wikiTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.wikiBgSecondary)
                )
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 20)
        }
        .padding(.top, 16)
        .sheet(isPresented: $showUserDirectory) {
            UserDirectorySheet()
        }
    }

    // MARK: - 关系分区

    private func relationSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.wikiBlue)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wikiText)
            }
            .padding(.horizontal, 16)

            content()
        }
    }

    // MARK: - 小组卡片

    private func groupCard(name: String, members: [String], entries: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                Text("\(members.count + 1) 人 · \(entries) 个合编词条")
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
            }
            Spacer()
            HStack(spacing: -8) {
                ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { _, member in
                    let seed = abs(member.hashValue) % 200
                    AsyncImage(url: URL(string: "https://i.pravatar.cc/48?img=\(seed)")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.wikiBgSecondary)
                        }
                    }
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.wikiBg, lineWidth: 1.5))
                }
                if members.count > 3 {
                    Text("+\(members.count - 3)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                        .padding(.leading, 12)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.wikiBgSecondary)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 关注行

    private func followRow(name: String, username: String, entries: Int, avatarSeed: Int, isFollower: Bool = false) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(avatarSeed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 14, weight: .medium))
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
                Text("\(username) · \(entries) 篇词条")
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
            }

            Spacer()

            let isFollowing = followingSet.contains(name)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isFollowing {
                        followingSet.remove(name)
                    } else {
                        followingSet.insert(name)
                    }
                }
            } label: {
                Text(isFollowing ? "已关注" : "关注")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isFollowing ? .wikiSecondary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isFollowing ? Color.wikiBgSecondary : Color.wikiBlue)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isFollowing ? Color.wikiDivider : Color.clear, lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - 用户目录 Sheet

struct UserDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let suggestedUsers: [(name: String, username: String, bio: String, seed: Int)] = [
        ("林清", "@linqing", "爱记录旧物和老味道", 33),
        ("张远", "@zhangyuan", "90后，写过三段际遇", 41),
        ("陈小鱼", "@chenxiaoyu", "我家猫叫大橘", 52),
        ("王旅人", "@wanglvren", "用脚步丈量世界", 63),
        ("赵回忆", "@zhaohuiyi", "每个人都是一部百科全书", 71),
    ]

    var filteredUsers: [(name: String, username: String, bio: String, seed: Int)] {
        if searchText.isEmpty { return suggestedUsers }
        return suggestedUsers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiTertiary)
                    TextField("搜索用户名或昵称", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.wikiBgSecondary)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredUsers, id: \.username) { user in
                            userRow(user)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("发现用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.wikiBlue)
                }
            }
        }
    }

    @State private var followedInSheet: Set<String> = []

    private func userRow(_ user: (name: String, username: String, bio: String, seed: Int)) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(user.seed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.wikiText)
                    Text(user.username)
                        .font(.system(size: 13))
                        .foregroundColor(.wikiTertiary)
                }
                Text(user.bio)
                    .font(.system(size: 13))
                    .foregroundColor(.wikiSecondary)
                    .lineLimit(1)
            }

            Spacer()

            let isFollowed = followedInSheet.contains(user.username)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isFollowed {
                        followedInSheet.remove(user.username)
                    } else {
                        followedInSheet.insert(user.username)
                    }
                }
            } label: {
                Text(isFollowed ? "已关注" : "关注")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isFollowed ? .wikiSecondary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(isFollowed ? Color.wikiBgSecondary : Color.wikiBlue))
                    .overlay(Capsule().stroke(isFollowed ? Color.wikiDivider : Color.clear, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
