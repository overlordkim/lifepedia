import Foundation
import CryptoKit

struct UserProfile: Codable, Equatable {
    let id: String
    let username: String
    let displayName: String
    let bio: String
    let avatarSeed: Int
}

@Observable
final class AuthService {
    static let shared = AuthService()

    var currentUser: UserProfile?

    var isLoggedIn: Bool { currentUser != nil }

    private let session = URLSession.shared

    private init() {
        restoreSession()
    }

    // MARK: - Login

    func login(username: String, password: String) async throws {
        let hash = sha256(password)
        let query = "username=eq.\(username)&password_hash=eq.\(hash)&limit=1"
        let endpoint = "\(Secrets.supabaseURL)/rest/v1/users?\(query)"

        guard let url = URL(string: endpoint) else {
            throw AuthError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AuthError.networkError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let users = try decoder.decode([UserProfile].self, from: data)

        guard let user = users.first else {
            throw AuthError.invalidCredentials
        }

        await MainActor.run {
            self.currentUser = user
            saveSession(user)
        }
    }

    // MARK: - Logout

    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "auth_user_json")
        UserDefaults.standard.removeObject(forKey: "user_display_name")
        UserDefaults.standard.removeObject(forKey: "user_bio")
        UserDefaults.standard.removeObject(forKey: "user_avatar_seed")
    }

    // MARK: - Session Persistence

    private func saveSession(_ user: UserProfile) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "auth_user_json")
        }
        UserDefaults.standard.set(user.displayName, forKey: "user_display_name")
        UserDefaults.standard.set(user.bio, forKey: "user_bio")
        UserDefaults.standard.set(user.avatarSeed, forKey: "user_avatar_seed")
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: "auth_user_json"),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        currentUser = user
    }

    // MARK: - Helpers

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "用户名或密码错误"
        case .networkError: return "网络连接失败"
        case .invalidRequest: return "请求无效"
        }
    }
}
