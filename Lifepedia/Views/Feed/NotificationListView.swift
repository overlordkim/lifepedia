import SwiftUI
import SwiftData

struct NotificationListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Entry.updatedAt, order: .reverse) private var allEntries: [Entry]

    private var service: NotificationService { NotificationService.shared }

    @State private var selectedEntryId: UUID?
    @State private var selectedUser: UserDestination?

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if service.notifications.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary)
                    Text("暂时没有通知")
                        .font(.system(size: 15))
                        .foregroundColor(.wikiTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.notifications) { notification in
                            notificationRow(notification)
                            Divider().padding(.leading, 60)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.wikiBg)
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedEntryId) { entryId in
            EntryPageView(entryId: entryId)
                .navigationBarHidden(true)
        }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(userName: user.userName, userId: user.userId)
                .navigationBarHidden(true)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }
            Spacer()
            Text("通知")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.wikiText)
            Spacer()
            if service.unreadCount > 0 {
                Button {
                    withAnimation { service.markAllRead() }
                } label: {
                    Text("全部已读")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.wikiBlue)
                }
            } else {
                Color.clear.frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.wikiBg)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(.wikiDivider),
            alignment: .bottom
        )
    }

    private func notificationRow(_ n: AppNotification) -> some View {
        Button {
            service.markAsRead(n.id)
            handleTap(n)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor(n.type).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: n.type.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor(n.type))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(n.title)
                        .font(.system(size: 14, weight: n.isRead ? .regular : .semibold))
                        .foregroundColor(.wikiText)
                        .lineLimit(1)

                    Text(n.body)
                        .font(.system(size: 13))
                        .foregroundColor(.wikiSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(relativeTime(n.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.wikiTertiary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if !n.isRead {
                        Circle()
                            .fill(Color.wikiBlue)
                            .frame(width: 8, height: 8)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.wikiTertiary)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(n.isRead ? Color.clear : Color.wikiBlue.opacity(0.03))
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ n: AppNotification) {
        switch n.type {
        case .comment, .like, .coEdit, .aiUpdate, .collabInvite, .collabRequest:
            if let entryId = n.relatedEntryId {
                selectedEntryId = entryId
            }
        case .follow:
            if let name = n.fromUserName {
                let userId = n.fromUserId ?? name.lowercased()
                selectedUser = UserDestination(userName: name, userId: userId)
            }
        }
    }

    private func iconColor(_ type: NotificationType) -> Color {
        switch type {
        case .comment:        return .wikiBlue
        case .like:           return .red
        case .follow:         return .wikiBlue
        case .coEdit:         return .green
        case .aiUpdate:       return .purple
        case .collabInvite:   return .orange
        case .collabRequest:  return .orange
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }
}
