import SwiftUI

struct CategoryFilterBar: View {
    @Binding var selected: EntryCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(label: "全部", isSelected: selected == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = nil }
                }

                ForEach(EntryCategory.allCases) { cat in
                    chip(label: cat.label, isSelected: selected == cat) {
                        withAnimation(.easeInOut(duration: 0.2)) { selected = cat }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .wikiSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.wikiText : Color(hex: 0xF0F0F0))
                )
        }
        .buttonStyle(.plain)
    }
}
