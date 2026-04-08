import SwiftUI

struct InfoboxView: View {
    let infobox: InfoboxData
    let category: EntryCategory

    var body: some View {
        if infobox.fields.isEmpty { EmptyView() } else {
            VStack(spacing: 0) {
                // 标题行
                Text("\(category.label)信息")
                    .font(.wikiInfoboxKey)
                    .foregroundColor(.wikiText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.wikiBgSecondary)

                Divider().foregroundColor(.wikiDivider)

                // 字段
                ForEach(Array(infobox.fields.enumerated()), id: \.element.id) { idx, field in
                    HStack(alignment: .top, spacing: 0) {
                        Text(field.key)
                            .font(.wikiInfoboxKey)
                            .foregroundColor(.wikiSecondary)
                            .frame(width: 90, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.leading, 12)

                        Text(field.value)
                            .font(.wikiInfoboxValue)
                            .foregroundColor(.wikiText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.trailing, 12)
                    }

                    if idx < infobox.fields.count - 1 {
                        Divider()
                            .foregroundColor(.wikiDivider)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(Color.wikiBgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.wikiBorder, lineWidth: 1)
            )
        }
    }
}
