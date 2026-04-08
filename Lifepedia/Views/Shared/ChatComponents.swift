import SwiftUI

// MARK: - AI 状态枚举

enum AIStatus: Equatable {
    case thinking
    case updatingEntry(String)
    case fetchingURL
    case analyzing
    case generatingImage

    var label: String {
        switch self {
        case .thinking:             return "正在思考"
        case .updatingEntry(let t): return t.isEmpty ? "正在编纂词条" : "正在编纂「\(t)」"
        case .fetchingURL:          return "正在获取链接"
        case .analyzing:            return "正在分析"
        case .generatingImage:      return "正在生成插图"
        }
    }

    var icon: String {
        switch self {
        case .thinking:         return "sparkles"
        case .updatingEntry:    return "pencil.line"
        case .fetchingURL:      return "link"
        case .analyzing:        return "eye"
        case .generatingImage:  return "photo.artframe"
        }
    }
}

// MARK: - 状态指示器（替代旧的三点 TypingIndicator）

struct AIStatusBubble: View {
    let status: AIStatus
    @State private var dotPhase = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.wikiBlue)
                .symbolEffect(.pulse, options: .repeating)

            Text(status.label)
                .font(.system(size: 13))
                .foregroundColor(.wikiSecondary)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.wikiTertiary)
                        .frame(width: 4, height: 4)
                        .scaleEffect(dotPhase ? 1.0 : 0.4)
                        .opacity(dotPhase ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: dotPhase
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.wikiBgSecondary)
        )
        .onAppear { dotPhase = true }
    }
}

// MARK: - 聊天气泡

struct ChatBubbleView: View {
    let message: ChatMessage
    let showTimestamp: Bool

    init(_ message: ChatMessage, showTimestamp: Bool = false) {
        self.message = message
        self.showTimestamp = showTimestamp
    }

    var body: some View {
        switch message.role {
        case .system:
            actionCard
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        }
    }

    // MARK: - 用户消息（右对齐，蓝色）

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                Spacer(minLength: 60)
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.wikiBlue)
                    )
            }
            if showTimestamp {
                timestamp.padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - AI 消息（左对齐，带头像）

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                aiAvatar

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.wikiText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.wikiBgSecondary)
                    )

                Spacer(minLength: 48)
            }
            if showTimestamp {
                timestamp.padding(.leading, 36)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 动作卡片（居中，系统消息）

    private var actionCard: some View {
        let parts = message.content.split(separator: "|", maxSplits: 1)
        let icon = parts.count > 1 ? String(parts[0]) : "sparkles"
        let text = parts.count > 1 ? String(parts[1]) : message.content
        let style = ActionCardStyle.from(icon: icon)

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(style.color)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(style.textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(style.bgColor)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    // MARK: - 小组件

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.wikiBlue.opacity(0.15), Color.wikiBlue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.wikiBlue)
        }
        .frame(width: 26, height: 26)
    }

    private var timestamp: some View {
        Text(relativeTime(message.timestamp))
            .font(.system(size: 10))
            .foregroundColor(.wikiTertiary.opacity(0.7))
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60)) 分钟前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Action Card 样式

private enum ActionCardStyle {
    case progress, success, warning, info

    var color: Color {
        switch self {
        case .progress: return .wikiBlue
        case .success:  return Color(red: 0.2, green: 0.72, blue: 0.45)
        case .warning:  return .orange
        case .info:     return .wikiSecondary
        }
    }

    var textColor: Color {
        switch self {
        case .progress: return .wikiBlue.opacity(0.8)
        case .success:  return Color(red: 0.2, green: 0.72, blue: 0.45).opacity(0.8)
        case .warning:  return .orange.opacity(0.8)
        case .info:     return .wikiSecondary
        }
    }

    var bgColor: Color {
        switch self {
        case .progress: return .wikiBlue.opacity(0.08)
        case .success:  return Color(red: 0.2, green: 0.72, blue: 0.45).opacity(0.08)
        case .warning:  return .orange.opacity(0.08)
        case .info:     return Color.wikiTertiary.opacity(0.1)
        }
    }

    static func from(icon: String) -> ActionCardStyle {
        if icon.contains("checkmark") { return .success }
        if icon.contains("exclamationmark") || icon.contains("triangle") { return .warning }
        if icon.contains("pencil") || icon.contains("link") || icon.contains("text.bubble") { return .progress }
        return .info
    }
}

// MARK: - 完整聊天区域

struct ChatAreaView: View {
    let messages: [ChatMessage]
    let aiStatus: AIStatus?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                        let showTime = shouldShowTimestamp(at: index)
                        ChatBubbleView(msg, showTimestamp: showTime)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if let status = aiStatus {
                        HStack {
                            AIStatusBubble(status: status)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.leading, 34)
                        .id("ai-status")
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messages.count)
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: aiStatus) {
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if aiStatus != nil {
                proxy.scrollTo("ai-status", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let current = messages[index].timestamp
        let previous = messages[index - 1].timestamp
        return current.timeIntervalSince(previous) > 300
    }
}
