import SwiftUI
import SwiftData

struct VisibilitySheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScope: EntryScope = .private

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("谁可以看到这篇词条？")
                    .font(.system(size: 13))
                    .foregroundColor(.wikiSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                VStack(spacing: 0) {
                    scopeRow(
                        scope: .private,
                        description: "只有你自己可以看到"
                    )
                    thinDivider
                    scopeRow(
                        scope: .collaborative,
                        description: "你和合编者可以看到和编辑"
                    )
                    thinDivider
                    scopeRow(
                        scope: .public,
                        description: "所有人可以浏览，合编者可编辑"
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.wikiBgSecondary)
                )
                .padding(.horizontal, 16)

                if selectedScope != entry.scope {
                    Text(scopeChangeHint)
                        .font(.system(size: 12))
                        .foregroundColor(.wikiBlue)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                Spacer()
            }
            .navigationTitle("可见性")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.wikiSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确认") { applyChange() }
                        .fontWeight(.semibold)
                        .foregroundColor(.wikiBlue)
                        .disabled(selectedScope == entry.scope)
                }
            }
            .onAppear { selectedScope = entry.scope }
        }
    }

    private func scopeRow(scope: EntryScope, description: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedScope = scope
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: scope.icon)
                    .font(.system(size: 16))
                    .foregroundColor(selectedScope == scope ? .wikiBlue : .wikiSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.wikiTertiary)
                }

                Spacer()

                if selectedScope == scope {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.wikiBlue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private var scopeChangeHint: String {
        switch selectedScope {
        case .public:
            return "公开后，所有人都可以在发现页看到这篇词条"
        case .collaborative:
            return "转为合编后，可邀请朋友一起维护这篇词条"
        case .private:
            return "转为私人后，其他人将无法再看到此词条"
        }
    }

    private func applyChange() {
        entry.scope = selectedScope
        entry.updatedAt = .now
        try? modelContext.save()
        Task { try? await SupabaseService.shared.upsertEntry(entry) }
        dismiss()
    }
}
