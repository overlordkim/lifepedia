import Foundation
import SwiftUI

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var notifications: [AppNotification] = []

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private let storageKey = "app_notifications_v2"

    private init() {
        load()
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

    func clearAll() {
        notifications = []
        save()
    }
}
