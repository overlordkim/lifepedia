import SwiftUI

// MARK: - 正文标记解析器
// 把 [[蓝色链接]]、{{红色链接}}、[来源请求] 解析成富文本

enum WikiSegmentType {
    case plain
    case blueLink(title: String)
    case redLink(title: String)
    case citationNeeded
    case bold
}

struct WikiSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: WikiSegmentType
}

struct WikiTextParser {
    
    /// 把原始 wiki 标记文本解析成 AttributedString
    static func parse(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var remaining = raw
        
        while !remaining.isEmpty {
            // 查找最近的标记
            let patterns: [(String, String, (String) -> AttributedString)] = [
                ("**", "**", { parseBold($0) }),
                ("[[", "]]", { parseBlueLink($0) }),
                ("{{", "}}", { parseRedLink($0) }),
            ]
            
            var nearestStart = remaining.endIndex
            var nearestPattern: (String, String, (String) -> AttributedString)?
            
            for (open, close, handler) in patterns {
                if let openRange = remaining.range(of: open) {
                    if openRange.lowerBound < nearestStart {
                        if let closeRange = remaining[openRange.upperBound...].range(of: close) {
                            nearestStart = openRange.lowerBound
                            nearestPattern = (open, close, handler)
                            _ = closeRange
                        }
                    }
                }
            }
            
            // 检查 [来源请求]
            if let cnRange = remaining.range(of: "[来源请求]") {
                if cnRange.lowerBound < nearestStart {
                    let before = String(remaining[remaining.startIndex..<cnRange.lowerBound])
                    if !before.isEmpty {
                        result += AttributedString(before)
                    }
                    result += parseCitationNeeded()
                    remaining = String(remaining[cnRange.upperBound...])
                    continue
                }
            }
            
            if let (open, close, handler) = nearestPattern,
               let openRange = remaining.range(of: open),
               let closeRange = remaining[openRange.upperBound...].range(of: close) {
                
                let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
                if !before.isEmpty {
                    result += AttributedString(before)
                }
                
                let inner = String(remaining[openRange.upperBound..<closeRange.lowerBound])
                result += handler(inner)
                
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                result += AttributedString(remaining)
                break
            }
        }
        
        return result
    }
    
    private static func parseBold(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = .body.bold()
        return attr
    }
    
    private static func parseBlueLink(_ title: String) -> AttributedString {
        var attr = AttributedString(title)
        attr.foregroundColor = .wikiBlue
        attr.underlineStyle = .single
        attr.link = URL(string: "wikilink://\(title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? title)")
        return attr
    }
    
    private static func parseRedLink(_ title: String) -> AttributedString {
        var attr = AttributedString(title)
        attr.foregroundColor = .wikiRed
        attr.link = URL(string: "redlink://\(title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? title)")
        return attr
    }
    
    private static func parseCitationNeeded() -> AttributedString {
        var attr = AttributedString("[来源请求]")
        attr.foregroundColor = .wikiGray
        attr.font = .wikiSuperscript
        attr.baselineOffset = 6
        attr.link = URL(string: "citation://needed")
        return attr
    }
}
