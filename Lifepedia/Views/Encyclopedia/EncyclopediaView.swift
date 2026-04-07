import SwiftUI
import SwiftData

struct EncyclopediaView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var entries: [Entry]
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var hasLoadedMock = false
    
    private var filteredEntries: [Entry] {
        if searchText.isEmpty { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var allRedLinks: [String] {
        var links: [String] = []
        let titles = Set(entries.map(\.title))
        for entry in entries {
            for link in entry.allRedLinks where !titles.contains(link) {
                links.append(link)
            }
        }
        return Array(Set(links))
    }
    
    private var allCategories: [(String, Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for cat in entry.categories {
                counts[cat, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 百科全书封面
                    headerSection
                    
                    // 最近编辑
                    if !entries.isEmpty {
                        recentSection
                    }
                    
                    // 等待编纂（红色链接）
                    if !allRedLinks.isEmpty {
                        redLinksSection
                    }
                    
                    // 分类发现
                    if !allCategories.isEmpty {
                        categoriesSection
                    }
                    
                    // 全部词条
                    if !filteredEntries.isEmpty {
                        allEntriesSection
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.white)
            .searchable(text: $searchText, prompt: "搜索你的百科全书")
            .navigationTitle("百科")
            .onAppear { loadMockDataIfNeeded() }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("我的百科全书")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(.wikiText)
            
            Text("已收录 \(entries.count) 篇词条 · \(allRedLinks.count) 个红色链接待编纂")
                .font(.wikiCategory)
                .foregroundColor(.wikiGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - Recent
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("最近编辑")
            
            ForEach(entries.prefix(3)) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    HStack(spacing: 12) {
                        Text(entry.type.icon)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.wikiText)
                            Text(entry.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.wikiCategory)
                                .foregroundColor(.wikiGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.wikiGray)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Red Links
    
    private var redLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("等待编纂")
            
            ForEach(allRedLinks, id: \.self) { link in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.wikiRed)
                        .frame(width: 6, height: 6)
                    Text(link)
                        .font(.wikiBody)
                        .foregroundColor(.wikiRed)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Categories
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("分类发现")
            
            FlowLayout(spacing: 8) {
                ForEach(allCategories, id: \.0) { cat, count in
                    Text("\(cat)（\(count)）")
                        .font(.wikiCategory)
                        .foregroundColor(.wikiAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.wikiInfobox)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.wikiInfoboxBorder, lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - All Entries
    
    private var allEntriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("全部词条")
            
            ForEach(filteredEntries) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    HStack(spacing: 12) {
                        Text(entry.type.icon)
                        
                        Text(entry.title)
                            .font(.wikiBody)
                            .foregroundColor(.wikiBlue)
                        
                        if let sub = entry.subtitle {
                            Text(sub)
                                .font(.wikiCategory)
                                .foregroundColor(.wikiGray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundColor(.wikiText)
            Rectangle()
                .fill(Color.wikiSectionLine)
                .frame(height: 0.5)
        }
    }
    
    private func loadMockDataIfNeeded() {
        guard !hasLoadedMock && entries.isEmpty else { return }
        hasLoadedMock = true
        for entry in MockEntries.loadAll() {
            context.insert(entry)
        }
    }
}

// MARK: - FlowLayout（标签云布局）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
