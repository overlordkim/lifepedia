import Foundation
import SwiftUI

enum MessageRole: String {
    case user
    case assistant
}

struct ChatMessageItem: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
}

@MainActor
class ComposeViewModel: ObservableObject {
    @Published var phase: ComposePhase = .idle
    @Published var messages: [ChatMessageItem] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isDraftExpanded = false
    @Published var identifiedEntries: [IdentifiedEntry] = []
    @Published var generatedEntries: [Entry] = []
    @Published var errorMessage: String?
    
    private let ai = AIService(apiKey: UserDefaults.standard.string(forKey: "claude_api_key") ?? "")
    
    var canFinish: Bool {
        identifiedEntries.contains { $0.confidence == "high" }
    }
    
    // MARK: - Actions
    
    func startConversation(hint: String) {
        phase = .conversation
        messages = []
        identifiedEntries = []
        
        let greeting = "你想记录\(hint)？聊聊吧，你最先想到的是什么？"
        messages.append(ChatMessageItem(role: .assistant, content: greeting))
    }
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        messages.append(ChatMessageItem(role: .user, content: text))
        isLoading = true
        
        do {
            let apiMessages = messages.map { (role: $0.role.rawValue, content: $0.content) }
            let response = try await ai.chat(messages: apiMessages)
            
            messages.append(ChatMessageItem(role: .assistant, content: response.text))
            
            if let meta = response.metadata {
                withAnimation {
                    identifiedEntries = meta.identifiedEntries
                }
                if meta.readyToGenerate {
                    await finishConversation()
                }
            }
        } catch {
            // 如果 API 调用失败（比如没有 key），用模拟回复
            let mockReply = generateMockReply(for: text)
            messages.append(ChatMessageItem(role: .assistant, content: mockReply))
        }
        
        isLoading = false
    }
    
    func finishConversation() async {
        phase = .generating
        
        do {
            let apiMessages = messages.map { (role: $0.role.rawValue, content: $0.content) }
            let titles = identifiedEntries.map(\.title)
            let result = try await ai.generateEntries(conversation: apiMessages, confirmedTitles: titles)
            
            generatedEntries = result.entries.map { $0.toEntry() }
            phase = .result
        } catch {
            // API 失败时用 mock 数据演示
            generatedEntries = MockEntries.loadAll().prefix(3).map { $0 }
            phase = .result
        }
    }
    
    func reset() {
        phase = .idle
        messages = []
        inputText = ""
        identifiedEntries = []
        generatedEntries = []
    }
    
    // MARK: - Mock (离线演示用)
    
    private func generateMockReply(for userText: String) -> String {
        let replies = [
            "这很珍贵。能告诉我更多细节吗？比如具体是在什么时间、什么地方？",
            "我注意到你提到了一些重要的人和地方。能说说他们的全名吗？还有，这些事情大概是什么年份发生的？",
            "谢谢你分享这些。我现在已经识别出几个值得记录的词条了。你还有什么想补充的吗？如果没有，我可以开始编纂。",
        ]
        
        let count = messages.filter { $0.role == .user }.count
        
        if count <= 1 {
            if identifiedEntries.isEmpty {
                identifiedEntries = [
                    IdentifiedEntry(title: "提到的人", type: "person", confidence: "low")
                ]
            }
            return replies[0]
        } else if count <= 3 {
            identifiedEntries = [
                IdentifiedEntry(title: "提到的人", type: "person", confidence: "medium"),
                IdentifiedEntry(title: "提到的地方", type: "place", confidence: "low"),
                IdentifiedEntry(title: "提到的事", type: "event", confidence: "low"),
            ]
            return replies[1]
        } else {
            identifiedEntries = identifiedEntries.map {
                IdentifiedEntry(title: $0.title, type: $0.type, confidence: "high")
            }
            return replies[2]
        }
    }
}
