import Foundation

@Observable
final class FollowService {
    static let shared = FollowService()

    private(set) var followingSet: Set<String> = []
    private(set) var followerNames: [String] = []

    private let followingKey = "user_following_set"
    private let followersKey = "user_followers_list"

    private init() {
        load()
        if followingSet.isEmpty && followerNames.isEmpty {
            seedMockData()
        }
    }

    var followingCount: Int { followingSet.count }
    var followerCount: Int { followerNames.count }
    var followingList: [String] { Array(followingSet).sorted() }

    func isFollowing(_ userId: String) -> Bool {
        followingSet.contains(userId)
    }

    func follow(_ userId: String) {
        guard !followingSet.contains(userId) else { return }
        followingSet.insert(userId)
        if !followerNames.contains(userId) { }
        save()

        NotificationService.shared.add(AppNotification(
            type: .follow,
            title: "你关注了 \(userId)",
            body: "开始关注 ta 的词条动态",
            fromUserName: userId
        ))
    }

    func unfollow(_ userId: String) {
        followingSet.remove(userId)
        save()
    }

    func toggle(_ userId: String) {
        if isFollowing(userId) {
            unfollow(userId)
        } else {
            follow(userId)
        }
    }

    private func seedMockData() {
        followingSet = ["昱东", "妈妈"]
        followerNames = ["姐姐", "昱东", "小明", "大壮", "阿花"]
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(followingSet), forKey: followingKey)
        UserDefaults.standard.set(followerNames, forKey: followersKey)
    }

    private func load() {
        if let arr = UserDefaults.standard.array(forKey: followingKey) as? [String] {
            followingSet = Set(arr)
        }
        if let arr = UserDefaults.standard.array(forKey: followersKey) as? [String] {
            followerNames = arr
        }
    }
}
