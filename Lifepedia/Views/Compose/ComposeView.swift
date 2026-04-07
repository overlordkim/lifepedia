import SwiftUI
import SwiftData

// MARK: - Compose phases

enum ComposePhase {
    case idle           // 还没开始
    case conversation   // 对话中
    case generating     // AI 正在生成词条
    case result         // 展示编纂成果
}

struct ComposeView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = ComposeViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch vm.phase {
                case .idle:
                    idleView
                case .conversation:
                    conversationView
                case .generating:
                    generatingView
                case .result:
                    resultView
                }
            }
            .navigationTitle("编纂")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.phase == .conversation {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成编纂") {
                            Task { await vm.finishConversation() }
                        }
                        .disabled(!vm.canFinish)
                    }
                }
            }
        }
    }
    
    // MARK: - Idle (开屏)
    
    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("今天想记录什么？")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(.wikiText)
            
            Text("和你的编辑搭档聊聊，\n把生命中的人、事、物变成百科词条。")
                .font(.wikiBody)
                .foregroundColor(.wikiGray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                startChip("一个人", icon: "👤")
                startChip("一个地方", icon: "📍")
                startChip("一段往事", icon: "📅")
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private func startChip(_ label: String, icon: String) -> some View {
        Button(action: { vm.startConversation(hint: label) }) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 28))
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.wikiText)
            }
            .frame(width: 88, height: 80)
            .background(Color.wikiInfobox)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.wikiInfoboxBorder, lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Conversation
    
    private var conversationView: some View {
        VStack(spacing: 0) {
            // 草稿栏
            draftBar
            
            Divider()
            
            // 对话区
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(vm.messages.enumerated()), id: \.offset) { index, msg in
                            MessageBubble(message: msg)
                                .id(index)
                        }
                        
                        if vm.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("编辑搭档正在思考...")
                                    .font(.caption)
                                    .foregroundColor(.wikiGray)
                            }
                            .padding(.leading, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) {
                    withAnimation {
                        proxy.scrollTo(vm.messages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // 输入框
            inputBar
        }
    }
    
    private var draftBar: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { vm.isDraftExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                    Text("正在编纂 \(vm.identifiedEntries.count) 篇词条")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: vm.isDraftExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.wikiText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.wikiInfobox)
            }
            
            if vm.isDraftExpanded && !vm.identifiedEntries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.identifiedEntries) { entry in
                            DraftMiniCard(entry: entry)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(Color.wikiInfobox)
                .frame(height: 100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("告诉编辑搭档你的故事…", text: $vm.inputText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.wikiInfobox)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.wikiInfoboxBorder, lineWidth: 0.5)
                )
            
            Button(action: { Task { await vm.sendMessage() } }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(vm.inputText.isEmpty ? .wikiGray : .wikiAccent)
            }
            .disabled(vm.inputText.isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white)
    }
    
    // MARK: - Generating
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("正在为你编纂词条…")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(.wikiText)
            Text("\(vm.identifiedEntries.count) 篇词条即将诞生")
                .font(.wikiBody)
                .foregroundColor(.wikiGray)
            Spacer()
        }
    }
    
    // MARK: - Result (星座图)
    
    private var resultView: some View {
        VStack(spacing: 24) {
            Text("编纂成果")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(.wikiText)
                .padding(.top, 24)
            
            Text("\(vm.generatedEntries.count) 篇新词条")
                .font(.wikiBody)
                .foregroundColor(.wikiGray)
            
            // 词条列表（简化版星座图）
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.generatedEntries) { entry in
                        NavigationLink(destination: EntryDetailView(entry: entry)) {
                            resultCard(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // 收录按钮
            Button(action: {
                for entry in vm.generatedEntries {
                    context.insert(entry)
                }
                vm.reset()
            }) {
                Text("收录到我的百科全书")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.wikiAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private func resultCard(_ entry: Entry) -> some View {
        HStack(spacing: 14) {
            Text(entry.type.icon)
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(Color.wikiInfobox)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.wikiText)
                
                if let sub = entry.subtitle {
                    Text(sub)
                        .font(.wikiCategory)
                        .foregroundColor(.wikiGray)
                }
                
                Text(entry.type.label + " · " + "\(entry.sections.count) 个章节")
                    .font(.system(size: 12))
                    .foregroundColor(.wikiGray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.wikiGray)
        }
        .padding(14)
        .background(.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessageItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Text("📝")
                    .font(.system(size: 20))
                
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.wikiText)
                    .padding(12)
                    .background(Color.wikiInfobox)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.wikiText)
                    .padding(12)
                    .background(Color.wikiAccent.opacity(0.08))
                    .cornerRadius(12)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Draft Mini Card

struct DraftMiniCard: View {
    let entry: IdentifiedEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.entryType.icon)
                .font(.system(size: 18))
            
            Text(entry.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.wikiText)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 6, height: 6)
                Text(confidenceLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.wikiGray)
            }
        }
        .padding(10)
        .frame(width: 100, height: 76)
        .background(.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.wikiInfoboxBorder, lineWidth: 0.5)
        )
    }
    
    private var confidenceColor: Color {
        switch entry.confidence {
        case "high": return .green
        case "medium": return .orange
        default: return .wikiGray
        }
    }
    
    private var confidenceLabel: String {
        switch entry.confidence {
        case "high": return "素材充足"
        case "medium": return "待补充"
        default: return "刚提到"
        }
    }
}
