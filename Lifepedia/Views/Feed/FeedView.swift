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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                topBar

                if showSearch {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                CategoryFilterBar(selected: $selectedCategory)

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(value: entry.id) {
                                FeedCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
        }
        .onChange(of: navigationPath.count) {
            withAnimation(.easeInOut(duration: 0.25)) {
                hideTabBar = !navigationPath.isEmpty
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
                Button { } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.wikiText)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(.wikiTertiary)
            TextField("搜索词条、作者……", text: $searchText)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: 0xF0F0F0))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}
