import SwiftUI

extension Font {
    // MARK: - 衬线（标题 / 章节 / 信息框键名 / 图说 / 卡片标题）

    /// 词条标题 32pt Bold serif
    static let wikiTitle = Font.system(size: 32, weight: .bold, design: .serif)
    /// 章节标题 20pt Bold serif
    static let wikiSectionTitle = Font.system(size: 20, weight: .bold, design: .serif)
    /// 卡片标题 22pt Semibold serif
    static let wikiCardTitle = Font.system(size: 22, weight: .semibold, design: .serif)
    /// 信息框字段名 14pt Bold serif
    static let wikiInfoboxKey = Font.system(size: 14, weight: .bold, design: .serif)
    /// 图说 12pt Regular serif italic
    static let wikiCaption = Font.system(size: 12, weight: .regular, design: .serif).italic()
    /// Logo 字 24pt Bold serif
    static let wikiLogo = Font.system(size: 24, weight: .bold, design: .serif)

    // MARK: - 无衬线（正文 / 元数据 / 信息框值 / UI）

    /// 正文 16pt Regular
    static let wikiBody = Font.system(size: 16, weight: .regular)
    /// 信息框字段值 14pt Regular
    static let wikiInfoboxValue = Font.system(size: 14, weight: .regular)
    /// 正文摘要（卡片引言） 15pt Regular
    static let wikiExcerpt = Font.system(size: 15, weight: .regular)
    /// 元数据 / 作者名 13pt Regular
    static let wikiMeta = Font.system(size: 13, weight: .regular)
    /// 小字 / 修订 / 标签 12pt Regular
    static let wikiSmall = Font.system(size: 12, weight: .regular)
    /// 分类筛选文字（选中态） 15pt Semibold
    static let wikiFilterSelected = Font.system(size: 15, weight: .semibold)
    /// 分类筛选文字（默认态） 15pt Regular
    static let wikiFilterDefault = Font.system(size: 15, weight: .regular)
    /// 按钮 14pt Medium
    static let wikiButton = Font.system(size: 14, weight: .medium)
    /// 上标数字 10pt
    static let wikiSuperscript = Font.system(size: 10)
}

// MARK: - 行高修饰器

struct WikiReadingStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.lineSpacing(16 * 0.7)
    }
}

extension View {
    func wikiReadingStyle() -> some View {
        modifier(WikiReadingStyle())
    }
}
