import SwiftUI

struct FeedCard: View {
    let entry: Entry

    @State private var isLiked = false
    @State private var isBookmarked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverImage

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.wikiText)
                    .lineLimit(2)

                if !entry.infobox.fields.isEmpty {
                    highlightsLine
                }

                if let intro = entry.introductionText, !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 13.5))
                        .foregroundColor(.wikiSecondary)
                        .lineLimit(2)
                        .lineSpacing(3)
                }

                bottomRow
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(Color.wikiBg)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - 封面图（自适应比例，不固定 16:9）

    private var coverImage: some View {
        let realURL: String? = entry.coverImageURL
            ?? entry.sections.first(where: { !$0.imageRefs.isEmpty })?.imageRefs.first

        let seed = abs(entry.title.hashValue) % 1000
        let ratios: [CGFloat] = [4/3, 3/2, 16/9, 1.0]
        let ratio = ratios[seed % ratios.count]

        return Group {
            if let urlStr = realURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder(ratio: ratio)
                    }
                }
            } else {
                placeholder(ratio: ratio)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(ratio, contentMode: .fit)
        .clipped()
    }

    private func placeholder(ratio: CGFloat) -> some View {
        let seed = abs(entry.title.hashValue) % 1000
        let hue = Double(seed % 360) / 360.0
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.08, brightness: 0.97),
                        Color(hue: hue, saturation: 0.12, brightness: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(ratio, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hue: hue, saturation: 0.15, brightness: 0.82))
            )
    }

    // MARK: - 亮点行

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
            let seed = abs(entry.authorName.hashValue) % 70
            AsyncImage(url: URL(string: "https://i.pravatar.cc/48?img=\(seed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color(hex: 0xEEEEEE))
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())

            Text(entry.authorName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.wikiSecondary)

            Text("·")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: 0xCCCCCC))

            Text(entry.category.label)
                .font(.system(size: 12))
                .foregroundColor(.wikiTertiary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isLiked.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundColor(isLiked ? .wikiHeartActive : .wikiTertiary)
                            .scaleEffect(isLiked ? 1.15 : 1.0)
                        if entry.likeCount > 0 {
                            Text("\(entry.likeCount + (isLiked ? 1 : 0))")
                                .font(.system(size: 11))
                                .foregroundColor(.wikiTertiary)
                        }
                    }
                }

                HStack(spacing: 3) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 12))
                        .foregroundColor(.wikiTertiary)
                    if entry.commentCount > 0 {
                        Text("\(entry.commentCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.wikiTertiary)
                    }
                }
            }
        }
    }
}
