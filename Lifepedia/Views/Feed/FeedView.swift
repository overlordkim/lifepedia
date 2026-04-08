import SwiftUI
import SwiftData

struct FeedView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: EntryCategory?
    @Binding var hideTabBar: Bool
    var onNavigateToMyPage: (() -> Void)?
    @State private var navigationPath = NavigationPath()
    @State private var isSyncing = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showNotifications = false
    @State private var searchMode: SearchMode = .all

    enum SearchMode: String, CaseIterable {
        case all = "全部"
        case entries = "词条"
        case users = "用户"
    }

    private var notificationService: NotificationService { NotificationService.shared }

    private var filteredEntries: [Entry] {
        var list = allEntries.filter { !$0.isDraft }
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                ($0.introductionText ?? "").lowercased().contains(q) ||
                $0.authorName.lowercased().contains(q)
            }
        }
        return list
    }

    private var matchedUsers: [(name: String, id: String, entryCount: Int, seed: Int)] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        var seen = Set<String>()
        var result: [(String, String, Int, Int)] = []
        for entry in allEntries where !entry.isDraft {
            let aid = entry.authorId
            guard !seen.contains(aid), aid != "self" else { continue }
            if entry.authorName.lowercased().contains(q) {
                seen.insert(aid)
                let count = allEntries.filter { $0.authorId == aid && !$0.isDraft }.count
                let seed = abs(entry.authorName.hashValue) % 70
                result.append((entry.authorName, aid, count, seed))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                topBar

                if showSearch {
                    ZStack(alignment: .topLeading) {
                        searchBar

                        if showSearchModeMenu {
                            searchModeDropdown
                                .padding(.leading, 16)
                                .padding(.top, 42)
                        }
                    }
                    .zIndex(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                CategoryFilterBar(selected: $selectedCategory)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !matchedUsers.isEmpty && searchMode != .entries {
                            VStack(alignment: .leading, spacing: 8) {
                                if searchMode == .all {
                                    Text("用户")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.wikiSecondary)
                                        .padding(.horizontal, 6)
                                }

                                ForEach(matchedUsers, id: \.id) { user in
                                    Button {
                                        navigationPath.append(UserDestination(userName: user.name, userId: user.id))
                                    } label: {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: URL(string: "https://i.pravatar.cc/64?img=\(user.seed)")) { phase in
                                                if let image = phase.image {
                                                    image.resizable().scaledToFill()
                                                } else {
                                                    Circle().fill(Color.wikiBgSecondary)
                                                        .overlay(
                                                            Text(String(user.name.prefix(1)))
                                                                .font(.system(size: 13, weight: .semibold))
                                                                .foregroundColor(.wikiSecondary)
                                                        )
                                                }
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(user.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.wikiText)
                                                Text("\(user.entryCount) 篇词条")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.wikiTertiary)
                                            }
                                            Spacer()

                                            let followSvc = FollowService.shared
                                            Button {
                                                withAnimation(.spring(response: 0.3)) {
                                                    followSvc.toggle(user.name)
                                                }
                                            } label: {
                                                Text(followSvc.isFollowing(user.name) ? "已关注" : "关注")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(followSvc.isFollowing(user.name) ? .wikiSecondary : .white)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                            .fill(followSvc.isFollowing(user.name) ? Color.wikiBgSecondary : Color.wikiBlue)
                                                    )
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.wikiBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 6)
                        }

                        if searchMode != .users {
                            if searchMode == .all && !filteredEntries.isEmpty && !matchedUsers.isEmpty {
                                Text("词条")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.wikiSecondary)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ForEach(filteredEntries) { entry in
                                NavigationLink(value: entry.id) {
                                    FeedCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 90)
                }
                .background(Color(hex: 0xF4F4F4))
                .refreshable { await syncFromSupabase() }
            }
            .background(Color.wikiBg)
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { entryId in
                EntryPageView(entryId: entryId, onNavigateToMyPage: {
                    navigationPath = NavigationPath()
                    onNavigateToMyPage?()
                })
                .navigationBarHidden(true)
            }
            .navigationDestination(for: UserDestination.self) { dest in
                UserProfileView(userName: dest.userName, userId: dest.userId)
                    .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationListView()
            }
        }
        .onChange(of: navigationPath.count) {
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = !navigationPath.isEmpty || showNotifications
            }
        }
        .onChange(of: showNotifications) {
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = !navigationPath.isEmpty || showNotifications
            }
        }
        .task { await syncFromSupabase() }
    }

    private func syncFromSupabase() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let remote = try await SupabaseService.shared.fetchPublishedEntries()
            await MainActor.run {
                SupabaseService.shared.syncToLocal(
                    remoteEntries: remote,
                    localEntries: allEntries,
                    insert: { modelContext.insert($0) }
                )
                try? modelContext.save()
            }
        } catch {
            print("[Supabase sync] \(error.localizedDescription)")
        }
    }

    private var topBar: some View {
        HStack {
            Text("Lifepedia")
                .font(.custom("Baskerville-BoldItalic", size: 28))
                .foregroundColor(.wikiText)

            Spacer()

            HStack(spacing: 18) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.wikiText)
                        .contentTransition(.symbolEffect(.replace))
                }
                Button { showNotifications = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.wikiText)
                        if notificationService.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    @State private var showSearchModeMenu = false

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.25)) { showSearchModeMenu.toggle() }
            } label: {
                HStack(spacing: 3) {
                    Text(searchMode.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.wikiText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.wikiTertiary)
                        .rotationEffect(.degrees(showSearchModeMenu ? 180 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0xE8E8E8)))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.wikiTertiary)
                TextField(searchPlaceholder, text: $searchText)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: 0xF0F0F0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var searchModeDropdown: some View {
        VStack(spacing: 0) {
            ForEach(SearchMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        searchMode = mode
                        showSearchModeMenu = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(searchMode == mode ? .wikiBlue : .wikiText)
                        Spacer()
                        if searchMode == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.wikiBlue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                if mode != SearchMode.allCases.last { Divider() }
            }
        }
        .frame(width: 100)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.wikiBg)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
    }

    private var searchPlaceholder: String {
        switch searchMode {
        case .all:     return "搜索词条、用户……"
        case .entries: return "搜索词条标题、作者……"
        case .users:   return "搜索用户名……"
        }
    }
}
