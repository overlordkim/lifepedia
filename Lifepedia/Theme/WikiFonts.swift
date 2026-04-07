import SwiftUI

extension Font {
    // 词条标题 — 衬线体，大号
    static let wikiTitle = Font.system(size: 26, weight: .bold, design: .serif)
    
    // 章节标题 — 衬线体，中号
    static let wikiSectionTitle = Font.system(size: 20, weight: .semibold, design: .serif)
    
    // 正文
    static let wikiBody = Font.system(size: 17, weight: .regular, design: .default)
    
    // 信息框 key
    static let wikiInfoboxKey = Font.system(size: 14, weight: .medium, design: .default)
    
    // 信息框 value
    static let wikiInfoboxValue = Font.system(size: 14, weight: .regular, design: .default)
    
    // 分类标签
    static let wikiCategory = Font.system(size: 13, weight: .regular, design: .default)
    
    // 上标标注（来源请求）
    static let wikiSuperscript = Font.system(size: 11, weight: .regular, design: .default)
    
    // 卡片标题（瀑布流）
    static let wikiCardTitle = Font.system(size: 16, weight: .bold, design: .serif)
    
    // 卡片摘要
    static let wikiCardBody = Font.system(size: 13, weight: .regular, design: .default)
}
