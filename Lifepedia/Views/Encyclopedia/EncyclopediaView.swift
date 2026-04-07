import SwiftUI
import SwiftData

struct EncyclopediaView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var entries: [Entry]
    
    var body: some View {
        NavigationStack {
            Text("我的百科全书 · 已收录 \(entries.count) 篇词条")
                .foregroundColor(.wikiGray)
                .navigationTitle("百科")
        }
    }
}
