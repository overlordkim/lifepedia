import Foundation

@Observable
final class ImageGenerationService {
    static let shared = ImageGenerationService()

    private(set) var pendingTasks: [String: ImageGenTask] = [:]

    struct ImageGenTask: Identifiable {
        let id: String
        let prompt: String
        let sectionTitle: String
        var status: Status
        var imageURL: String?

        enum Status {
            case generating, completed, failed
        }
    }

    private init() {}

    /// Synchronous Seedream API — returns image URL directly
    func generate(prompt: String, sectionTitle: String) async throws -> String {
        let taskId = UUID().uuidString
        let task = ImageGenTask(id: taskId, prompt: prompt, sectionTitle: sectionTitle, status: .generating)
        pendingTasks[taskId] = task

        do {
            let url = try await callSeedreamAPI(prompt: prompt)
            pendingTasks[taskId]?.status = .completed
            pendingTasks[taskId]?.imageURL = url
            return url
        } catch {
            pendingTasks[taskId]?.status = .failed
            throw error
        }
    }

    func clearCompleted() {
        pendingTasks = pendingTasks.filter { $0.value.status == .generating }
    }

    var isGenerating: Bool {
        pendingTasks.values.contains { $0.status == .generating }
    }

    var generatingPrompts: [String] {
        pendingTasks.values.filter { $0.status == .generating }.map(\.prompt)
    }

    // MARK: - Seedream API

    private func callSeedreamAPI(prompt: String) async throws -> String {
        let endpoint = "\(Secrets.supabaseURL)/functions/v1/generate-image"
        guard let url = URL(string: endpoint) else {
            throw ImageGenError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "prompt": prompt,
            "size": "1024x1024"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[ImageGen] 开始生成: \(prompt.prefix(40))…")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            print("[ImageGen] API 错误 \(httpResponse.statusCode): \(bodyStr)")
            throw ImageGenError.apiError(statusCode: httpResponse.statusCode, message: bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageUrl = json["url"] as? String else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            print("[ImageGen] 解析失败: \(bodyStr)")
            throw ImageGenError.parseError
        }

        print("[ImageGen] 生成成功: \(imageUrl.prefix(60))…")
        return imageUrl
    }

    enum ImageGenError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .invalidResponse: return "Invalid response from server"
            case .apiError(let code, let msg): return "API error \(code): \(msg)"
            case .parseError: return "Failed to parse image URL from response"
            }
        }
    }
}
