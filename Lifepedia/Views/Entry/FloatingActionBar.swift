import SwiftUI

struct FloatingActionBar: View {
    let entry: Entry
    @Binding var isLiked: Bool
    @Binding var isBookmarked: Bool
    var onCommentTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Divider().foregroundColor(.wikiDivider)

            HStack {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isLiked.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(isLiked ? .wikiHeartActive : .wikiText)
                                .scaleEffect(isLiked ? 1.15 : 1.0)
                            Text("\(entry.likeCount + (isLiked ? 1 : 0))")
                                .font(.system(size: 13))
                                .foregroundColor(.wikiSecondary)
                        }
                    }

                    Button { onCommentTap() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.wikiText)
                            Text("\(entry.commentCount)")
                                .font(.system(size: 13))
                                .foregroundColor(.wikiSecondary)
                        }
                    }

                    Button { } label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(.wikiText)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isBookmarked.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(isBookmarked ? .wikiBookmarkActive : .wikiText)
                            .scaleEffect(isBookmarked ? 1.15 : 1.0)
                        Text("\(entry.collectCount + (isBookmarked ? 1 : 0))")
                            .font(.system(size: 13))
                            .foregroundColor(.wikiSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.wikiBg)
    }
}
