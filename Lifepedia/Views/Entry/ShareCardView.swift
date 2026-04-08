import SwiftUI

struct ShareCardView: View {
    let entry: Entry
    let coverImage: UIImage?
    let sectionImages: [String: UIImage]
    let avatarImage: UIImage?

    private let cardWidth: CGFloat = 375
    private let hPad: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            heroImage
            VStack(alignment: .leading, spacing: 20) {
                titleSection
                infoboxBlock
                introBlock
                sectionsBlock
                relatedBlock
                tagsBlock
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 20)
            brandFooter
        }
        .frame(width: cardWidth)
        .background(Color.wikiBg)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.wikiText)
                .frame(width: 28, height: 28)

            HStack(spacing: 8) {
                if let avatar = avatarImage {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(entry.authorName.prefix(1)))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.wikiSecondary)
                        )
                }
                Text(entry.authorName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.wikiText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.wikiText)
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, hPad)
        .frame(height: 48)
        .background(Color.wikiBg)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(.wikiDivider),
            alignment: .bottom
        )
    }

    // MARK: - Hero Image

    @ViewBuilder
    private var heroImage: some View {
        let url = entry.coverImageURL
            ?? entry.sections.first(where: { !$0.imageRefs.isEmpty })?.imageRefs.first
        let ratio: CGFloat = 16 / 9

        if let img = coverImage ?? (url.flatMap { sectionImages[$0] }) {
            let imgRatio = img.size.width / max(img.size.height, 1)
            Color.clear
                .aspectRatio(imgRatio, contentMode: .fit)
                .frame(width: cardWidth)
                .overlay(
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(Rectangle())
        } else {
            let seed = abs(entry.title.hashValue) % 1000
            let hue = Double(seed % 360) / 360.0
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.08, brightness: 0.97),
                            Color(hue: hue, saturation: 0.15, brightness: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(ratio, contentMode: .fit)
                .frame(width: cardWidth)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(.wikiTertiary.opacity(0.5))
                        if !entry.title.isEmpty {
                            Text(entry.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.wikiTertiary.opacity(0.6))
                        }
                    }
                )
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title.isEmpty ? "未命名词条" : entry.title)
                .font(.wikiTitle)
                .foregroundColor(entry.title.isEmpty ? .wikiTertiary : .wikiText)

            if let sub = entry.subtitle, !sub.isEmpty {
                Text(sub).font(.wikiMeta).foregroundColor(.wikiSecondary)
            }

            HStack(spacing: 12) {
                Label(entry.category.label, systemImage: "tag")
                Label(entry.scope.label, systemImage: entry.scope.icon)
            }
            .font(.wikiSmall)
            .foregroundColor(.wikiTertiary)

            Divider().foregroundColor(.wikiDivider)
        }
    }

    // MARK: - Infobox

    @ViewBuilder
    private var infoboxBlock: some View {
        InfoboxView(infobox: entry.infobox, category: entry.category)
    }

    // MARK: - Introduction

    @ViewBuilder
    private var introBlock: some View {
        if let intro = entry.introductionText, !intro.isEmpty {
            Text(intro)
                .font(.wikiBody)
                .foregroundColor(.wikiText)
                .wikiReadingStyle()
        }
    }

    // MARK: - Sections

    private var sectionsBlock: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(entry.sections) { section in
                sectionBlock(section)
            }
        }
    }

    private func sectionBlock(_ section: EntrySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title).font(.wikiSectionTitle).foregroundColor(.wikiText)
                Rectangle().fill(Color.wikiDivider).frame(height: 1)
            }

            Text(parseWikiText(section.body))
                .font(.wikiBody).foregroundColor(.wikiText).wikiReadingStyle()

            ForEach(section.imageRefs, id: \.self) { urlStr in
                if let img = sectionImages[urlStr] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Related

    @ViewBuilder
    private var relatedBlock: some View {
        if let related = entry.relatedEntryTitles, !related.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相关条目").font(.wikiSectionTitle).foregroundColor(.wikiText)
                    Rectangle().fill(Color.wikiDivider).frame(height: 1)
                }
                ForEach(related, id: \.self) { title in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right").font(.system(size: 12))
                        Text(title).underline()
                    }
                    .font(.wikiBody).foregroundColor(.wikiBlue)
                }
            }
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private var tagsBlock: some View {
        if let tags = entry.tags, !tags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider().foregroundColor(.wikiDivider)
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.wikiSmall).italic()
                            .foregroundColor(.wikiTertiary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.wikiBorder, lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Wiki Text Parser

    private func parseWikiText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[text.startIndex...]
        while !remaining.isEmpty {
            if remaining.hasPrefix("[["), let end = remaining.range(of: "]]") {
                let s = remaining.index(remaining.startIndex, offsetBy: 2)
                var attr = AttributedString(String(remaining[s..<end.lowerBound]))
                attr.foregroundColor = .wikiBlue
                attr.underlineStyle = .single
                result += attr
                remaining = remaining[end.upperBound...]
            } else if remaining.hasPrefix("{{"), let end = remaining.range(of: "}}") {
                let s = remaining.index(remaining.startIndex, offsetBy: 2)
                var attr = AttributedString(String(remaining[s..<end.lowerBound]))
                attr.foregroundColor = .wikiRed
                result += attr
                remaining = remaining[end.upperBound...]
            } else if remaining.hasPrefix("[来源请求]") {
                var attr = AttributedString("[来源请求]")
                attr.foregroundColor = .wikiBlue
                attr.font = .system(size: 10)
                result += attr
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 5)...]
            } else {
                result += AttributedString(String(remaining.prefix(1)))
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }
        return result
    }

    // MARK: - Brand Footer

    private var brandFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.wikiDivider)
                .frame(height: 0.5)

            VStack(spacing: 8) {
                Image("LifepediaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                Text("人间词条 Lifepedia")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.wikiText)

                Text("你的生命值得一座百科")
                    .font(.system(size: 12))
                    .foregroundColor(.wikiTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
        .background(Color.wikiBg)
    }
}
