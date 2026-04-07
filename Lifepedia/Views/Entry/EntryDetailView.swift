import SwiftUI
import SwiftData

struct EntryDetailView: View {
    let entry: Entry
    @State private var showCitationAlert = false
    @State private var citationReason = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 词条标题
                titleSection
                
                // 信息框
                InfoboxView(
                    title: entry.title,
                    type: entry.type,
                    infobox: entry.infobox,
                    coverImagePath: entry.coverImagePath
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // 目录（章节数 > 2 时显示）
                if entry.sections.count > 2 {
                    tableOfContents
                }
                
                // 正文章节
                ForEach(entry.sections) { section in
                    sectionView(section)
                }
                
                // 参见
                if !entry.seeAlso.isEmpty {
                    seeAlsoSection
                }
                
                // 分类标签
                if !entry.categories.isEmpty {
                    categoriesSection
                }
                
                // 参考来源
                referencesSection
                
                // 编辑历史入口
                revisionFooter
            }
            .padding(.bottom, 40)
        }
        .background(.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            handleURL(url)
            return .handled
        })
        .alert("来源请求", isPresented: $showCitationAlert) {
            Button("我来补充") {}
            Button("保留原样", role: .cancel) {}
        } message: {
            Text("这个说法目前只基于你的单一记忆。你确定是这样的吗？")
        }
    }
    
    // MARK: - Title
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.wikiTitle)
                .foregroundColor(.wikiText)
            
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.wikiBody)
                    .foregroundColor(.wikiGray)
            }
            
            Rectangle()
                .fill(Color.wikiSectionLine)
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Table of Contents
    
    private var tableOfContents: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("目录")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.wikiText)
            
            ForEach(Array(entry.sections.enumerated()), id: \.offset) { index, section in
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.system(size: 13))
                        .foregroundColor(.wikiAccent)
                    Text(section.title)
                        .font(.system(size: 13))
                        .foregroundColor(.wikiAccent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wikiInfobox)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.wikiInfoboxBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Section
    
    private func sectionView(_ section: EntrySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 章节标题
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.wikiSectionTitle)
                    .foregroundColor(.wikiText)
                
                Rectangle()
                    .fill(Color.wikiSectionLine)
                    .frame(height: 0.5)
            }
            
            // 章节正文
            Text(WikiTextParser.parse(section.content))
                .font(.wikiBody)
                .foregroundColor(.wikiText)
                .lineSpacing(6)
                .tint(.wikiBlue)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - See Also
    
    private var seeAlsoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("参见")
                    .font(.wikiSectionTitle)
                    .foregroundColor(.wikiText)
                Rectangle()
                    .fill(Color.wikiSectionLine)
                    .frame(height: 0.5)
            }
            
            ForEach(entry.seeAlso, id: \.self) { link in
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundColor(.wikiGray)
                    Text(link)
                        .font(.wikiBody)
                        .foregroundColor(.wikiBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - Categories
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.wikiSectionLine)
                .frame(height: 0.5)
            
            HStack(spacing: 4) {
                Text("分类：")
                    .font(.wikiCategory)
                    .foregroundColor(.wikiGray)
                
                Text(entry.categories.joined(separator: " | "))
                    .font(.wikiCategory)
                    .foregroundColor(.wikiAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - References
    
    private var referencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("参考来源")
                    .font(.wikiSectionTitle)
                    .foregroundColor(.wikiText)
                Rectangle()
                    .fill(Color.wikiSectionLine)
                    .frame(height: 0.5)
            }
            
            HStack(alignment: .top, spacing: 4) {
                Text("[1]")
                    .font(.wikiCategory)
                    .foregroundColor(.wikiAccent)
                Text("词条创建者口述，\(entry.createdAt.formatted(date: .long, time: .omitted))")
                    .font(.wikiCategory)
                    .foregroundColor(.wikiGray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - Revision Footer
    
    private var revisionFooter: some View {
        Text("本词条于 \(entry.createdAt.formatted(date: .long, time: .omitted)) 首次创建")
            .font(.wikiCategory)
            .foregroundColor(.wikiGray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
    }
    
    // MARK: - URL Handling
    
    private func handleURL(_ url: URL) {
        if url.scheme == "citation" {
            showCitationAlert = true
        }
    }
}
