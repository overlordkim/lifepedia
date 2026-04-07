import SwiftUI

extension Color {
    // 维基百科标准色值
    static let wikiBlue         = Color(hex: "#0645AD")  // 蓝色链接
    static let wikiRed          = Color(hex: "#BA0000")  // 红色链接
    static let wikiText         = Color(hex: "#202122")  // 正文
    static let wikiGray         = Color(hex: "#72777D")  // 辅助文字
    static let wikiInfobox      = Color(hex: "#F8F9FA")  // 信息框背景
    static let wikiInfoboxBorder = Color(hex: "#A2A9B1") // 信息框边框
    static let wikiBanner       = Color(hex: "#FEF6E7")  // 横幅提示黄
    static let wikiAccent       = Color(hex: "#3366CC")  // 系统蓝
    static let wikiSectionLine  = Color(hex: "#A2A9B1")  // 章节分隔线
    static let wikiBg           = Color(hex: "#F5F5F5")  // 信息流底色
    
    // 三味色
    static let flavorSweet  = Color(hex: "#FF8FA3")  // 糖
    static let flavorKnife  = Color(hex: "#C4302B")  // 刀
    static let flavorTrash  = Color(hex: "#6B6B6B")  // 史
}

// MARK: - Hex 初始化

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
