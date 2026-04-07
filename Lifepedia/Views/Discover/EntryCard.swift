import SwiftUI

struct EntryCard: View {
    let entry: Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面图区域
            coverSection
            
            // 文字区域
            VStack(alignment: .leading, spacing: 6) {
                // 类型标签
                Text(entry.type.icon + " " + entry.type.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.wikiGray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.wikiInfobox)
                    .cornerRadius(3)
                
                // 词条标题
                Text(entry.title)
                    .font(.wikiCardTitle)
                    .foregroundColor(.wikiText)
                    .lineLimit(2)
                
                // 副标题
                if let sub = entry.subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(.wikiGray)
                }
                
                // 正文摘要（含蓝色链接视觉）
                if let firstSection = entry.sections.first {
                    Text(WikiTextParser.parse(String(firstSection.content.prefix(120)) + "…"))
                        .font(.wikiCardBody)
                        .foregroundColor(.wikiText)
                        .lineSpacing(3)
                        .lineLimit(4)
                        .tint(.wikiBlue)
                }
                
                // 分类标签
                if !entry.categories.isEmpty {
                    Text(entry.categories.prefix(3).joined(separator: " | "))
                        .font(.system(size: 10))
                        .foregroundColor(.wikiGray)
                        .lineLimit(1)
                }
                
                // 底部作者栏
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.wikiAccent.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(entry.authorName.prefix(1)))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.wikiAccent)
                        )
                    
                    Text(entry.authorName + " 的百科全书")
                        .font(.system(size: 11))
                        .foregroundColor(.wikiGray)
                    
                    Spacer()
                    
                    Image(systemName: "heart")
                        .font(.system(size: 11))
                        .foregroundColor(.wikiGray)
                }
                .padding(.top, 4)
            }
            .padding(10)
        }
        .background(.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Cover
    
    @ViewBuilder
    private var coverSection: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(entry.type.icon)
                .font(.system(size: 36))
                .opacity(0.5)
                .padding(12)
        }
        .frame(height: coverHeight)
        .frame(maxWidth: .infinity)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 8, topTrailingRadius: 8
            )
        )
    }
    
    private var coverHeight: CGFloat {
        switch entry.type {
        case .person: return 120
        case .place:  return 100
        case .object: return 80
        case .event:  return 90
        case .period: return 110
        }
    }
    
    private var gradientColors: [Color] {
        switch entry.type {
        case .person: return [Color(hex: "#F5E6D3"), Color(hex: "#E8D5C4")]
        case .place:  return [Color(hex: "#D3E5F5"), Color(hex: "#C4D8E8")]
        case .object: return [Color(hex: "#F5F0D3"), Color(hex: "#E8E0C4")]
        case .event:  return [Color(hex: "#F5D3D3"), Color(hex: "#E8C4C4")]
        case .period: return [Color(hex: "#E3D3F5"), Color(hex: "#D4C4E8")]
        }
    }
}
