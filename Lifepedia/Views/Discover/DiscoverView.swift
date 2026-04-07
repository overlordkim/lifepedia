import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query(
        filter: #Predicate<Entry> { $0.isPublic },
        sort: \Entry.createdAt,
        order: .reverse
    ) private var entries: [Entry]
    
    @State private var selectedFilter: EntryType?
    
    private var filteredEntries: [Entry] {
        guard let filter = selectedFilter else { return entries }
        return entries.filter { $0.type == filter }
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 顶部标语
                    Text("每个普通人的一生，都值得一整座维基百科。")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.wikiGray)
                        .padding(.top, 4)
                    
                    // 筛选标签栏
                    filterBar
                    
                    // 双列瀑布流
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                EntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.bottom, 40)
            }
            .background(Color.wikiBg)
            .navigationTitle("发现")
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "全部", type: nil)
                
                ForEach(EntryType.allCases) { type in
                    filterChip(label: type.icon + " " + type.label, type: type)
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    private func filterChip(label: String, type: EntryType?) -> some View {
        let isSelected = selectedFilter == type
        return Button(action: { selectedFilter = type }) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .wikiText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.wikiAccent : Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color.wikiInfoboxBorder, lineWidth: 0.5)
                )
        }
    }
}
