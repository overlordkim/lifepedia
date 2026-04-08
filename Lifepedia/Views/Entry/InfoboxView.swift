import SwiftUI

struct InfoboxView: View {
    let infobox: InfoboxData
    let category: EntryCategory

    var body: some View {
        if infobox.fields.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.wikiBlue)
                    Text(category.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wikiText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                ForEach(Array(infobox.fields.enumerated()), id: \.element.id) { idx, field in
                    HStack(alignment: .top, spacing: 0) {
                        Text(field.key)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.wikiTertiary)
                            .frame(width: 80, alignment: .trailing)
                            .padding(.trailing, 12)

                        Text(field.value)
                            .font(.system(size: 13))
                            .foregroundColor(.wikiText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)

                    if idx < infobox.fields.count - 1 {
                        Rectangle()
                            .fill(Color.wikiDivider.opacity(0.5))
                            .frame(height: 0.5)
                            .padding(.leading, 106)
                            .padding(.trailing, 14)
                    }
                }

                Spacer().frame(height: 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xFAFAFA))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: 0xEEEEEE), lineWidth: 0.5)
            )
        }
    }
}
