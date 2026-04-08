import SwiftUI

extension Color {
    // MARK: - 基础色板 (doc.md 16.2)

    /// 主背景 #FFFFFF
    static let wikiBg = Color.white
    /// 次背景 #F8F8F8（信息框、卡片内部）
    static let wikiBgSecondary = Color(hex: 0xF8F8F8)
    /// 主文字 #000000
    static let wikiText = Color.black
    /// 二级文字 #666666
    static let wikiSecondary = Color(hex: 0x666666)
    /// 三级/元数据 #999999
    static let wikiTertiary = Color(hex: 0x999999)
    /// 链接蓝 #0645AD — 唯一强调色
    static let wikiBlue = Color(hex: 0x0645AD)
    /// 红色链接 #BA0000
    static let wikiRed = Color(hex: 0xBA0000)
    /// 边框 #CCCCCC
    static let wikiBorder = Color(hex: 0xCCCCCC)
    /// 分割线 #E0E0E0
    static let wikiDivider = Color(hex: 0xE0E0E0)

    // MARK: - 互动图标

    /// 心形 / 收藏默认态
    static let wikiIconDefault = Color(hex: 0x999999)
    /// 心形点亮
    static let wikiHeartActive = Color(hex: 0xED4956)
    /// 收藏点亮
    static let wikiBookmarkActive = Color(hex: 0xF5C518)

    // MARK: - Hex Init

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
