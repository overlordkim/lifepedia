import SwiftUI

struct RevisionHistoryView: View {
    let revisions: [Revision]

    var body: some View {
        List {
            ForEach(revisions) { rev in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(rev.editorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.wikiBlue)
                        Spacer()
                        Text(rev.timestamp, style: .date)
                            .font(.wikiSmall)
                            .foregroundColor(.wikiTertiary)
                    }
                    Text(rev.summary)
                        .font(.wikiBody)
                        .foregroundColor(.wikiText)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("修订记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}
