import SwiftUI

struct InfoboxView: View {
    let title: String
    let type: EntryType
    let infobox: InfoboxData
    let coverImagePath: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 封面图区域
            coverImageSection
            
            // 信息框标题栏
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.wikiInfobox)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.wikiInfoboxBorder),
                    alignment: .bottom
                )
            
            // 字段列表
            ForEach(Array(infobox.fields.enumerated()), id: \.offset) { index, field in
                HStack(alignment: .top, spacing: 0) {
                    // Key
                    Text(field.key)
                        .font(.wikiInfoboxKey)
                        .foregroundColor(.wikiGray)
                        .frame(width: 72, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.vertical, 6)
                    
                    Rectangle()
                        .fill(Color.wikiInfoboxBorder)
                        .frame(width: 1)
                    
                    // Value
                    Text(WikiTextParser.parse(field.value))
                        .font(.wikiInfoboxValue)
                        .foregroundColor(.wikiText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .padding(.vertical, 6)
                }
                .background(index % 2 == 0 ? Color.clear : Color.wikiInfobox.opacity(0.5))
                
                if index < infobox.fields.count - 1 {
                    Rectangle()
                        .fill(Color.wikiInfoboxBorder.opacity(0.5))
                        .frame(height: 0.5)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.wikiInfoboxBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    @ViewBuilder
    private var coverImageSection: some View {
        ZStack {
            // 占位背景：类型对应的渐变色
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 类型图标
            Text(type.icon)
                .font(.system(size: 48))
                .opacity(0.6)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
    }
    
    private var gradientColors: [Color] {
        switch type {
        case .person: return [Color(hex: "#F5E6D3"), Color(hex: "#E8D5C4")]
        case .place:  return [Color(hex: "#D3E5F5"), Color(hex: "#C4D8E8")]
        case .object: return [Color(hex: "#F5F0D3"), Color(hex: "#E8E0C4")]
        case .event:  return [Color(hex: "#F5D3D3"), Color(hex: "#E8C4C4")]
        case .period: return [Color(hex: "#E3D3F5"), Color(hex: "#D4C4E8")]
        }
    }
}
