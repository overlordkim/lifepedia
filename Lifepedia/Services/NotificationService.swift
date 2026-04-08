import Foundation
import SwiftUI

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var notifications: [AppNotification] = []

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private let storageKey = "app_notifications_v1"

    private init() {
        load()
        if notifications.isEmpty {
            seedMockNotifications()
        }
    }

    func add(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        save()
    }

    func markAsRead(_ id: String) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
            save()
        }
    }

    func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else { return }
        notifications = decoded
    }

    // MARK: - Mock

    private func seedMockNotifications() {
        let now = Date.now
        notifications = [
            AppNotification(
                type: .comment, title: "昱东 评论了你的词条",
                body: "「外婆家的红烧肉」—— 这个太有共鸣了！",
                fromUserName: "昱东",
                createdAt: now.addingTimeInterval(-300)
            ),
            AppNotification(
                type: .like, title: "林清 赞了你的词条",
                body: "「我的高中时代」",
                fromUserName: "林清",
                createdAt: now.addingTimeInterval(-1800)
            ),
            AppNotification(
                type: .follow, title: "陈小鱼 关注了你",
                body: "ta 也开始用 Lifepedia 了",
                fromUserName: "陈小鱼",
                createdAt: now.addingTimeInterval(-7200)
            ),
            AppNotification(
                type: .coEdit, title: "合编动态",
                body: "妈妈 更新了「我家」小组的词条",
                fromUserName: "妈妈",
                createdAt: now.addingTimeInterval(-86400)
            ),
            AppNotification(
                type: .aiUpdate, title: "词条编纂完成",
                body: "AI 助手完成了「老家的院子」的更新",
                isRead: true,
                createdAt: now.addingTimeInterval(-172800)
            ),
        ]
        save()
    }
}
