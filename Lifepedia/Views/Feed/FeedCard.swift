import SwiftUI

struct FeedCard: View {
    let entry: Entry

    @State private var isLiked = false
    @State private var isBookmarked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverImage

            VStack(alignment: .leading, spacing: 10) {
                // 标题
                Text(entry.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.wikiText)
                    .lineLimit(2)

                // 亮点（从 infobox 提取关键信息，一行流式展示）
                if !entry.infobox.fields.isEmpty {
                    highlightsLine
                }

                // 引言
                if let intro = entry.introductionText, !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 14))
                        .foregroundColor(.wikiSecondary)
                        .lineLimit(2)
                        .lineSpacing(3)
                }

                // 底栏：头像 + 作者 + 分类 ............. 互动
                bottomRow
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .background(Color.wikiBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    // MARK: - 封面图

    private var coverImage: some View {
        Group {
            if let url = entry.coverImageURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                    } else {
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }

    private var coverPlaceholder: some View {
        let seed = abs(entry.title.hashValue) % 1000
        return AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/800/450")) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(hex: 0xEEEEEE))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: 0xCCCCCC))
                    )
            }
        }
    }

    // MARK: - 亮点行（替代 ugly 的信息框表格）

    private var highlightsLine: some View {
        let keywords = entry.infobox.fields
            .prefix(3)
            .map(\.value)
            .joined(separator: "  ·  ")

        return Text(keywords)
            .font(.system(size: 12))
            .foregroundColor(.wikiTertiary)
            .lineLimit(1)
    }

    // MARK: - 底栏

    private var bottomRow: some View {
        HStack(spacing: 8) {
            // 头像（真实图片）
            let seed = abs(entry.authorName.hashValue) % 70
            AsyncImage(url: URL(string: "https://i.pravatar.cc/48?img=\(seed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color(hex: 0xEEEEEE))
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())

            Text(entry.authorName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.wikiSecondary)

            Text("·")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xCCCCCC))

            Text(entry.category.label)
                .font(.system(size: 12))
                .foregroundColor(.wikiTertiary)

            Spacer()

            // 互动（极简）
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isLiked.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isLiked ? .wikiHeartActive : .wikiTertiary)
                            .scaleEffect(isLiked ? 1.15 : 1.0)
                        if entry.likeCount > 0 {
                            Text("\(entry.likeCount + (isLiked ? 1 : 0))")
                                .font(.system(size: 11))
                                .foregroundColor(.wikiTertiary)
                        }
                    }
                }

                Button { } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 13))
                            .foregroundColor(.wikiTertiary)
                        if entry.commentCount > 0 {
                            Text("\(entry.commentCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.wikiTertiary)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isBookmarked.toggle()
                    }
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundColor(isBookmarked ? .wikiBookmarkActive : .wikiTertiary)
                        .scaleEffect(isBookmarked ? 1.15 : 1.0)
                }
            }
        }
    }
}
