import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .feed
    @State private var hideTabBar = false
    @State private var composeEntry: Entry?

    enum Tab: Equatable {
        case feed, myPage
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .feed:
                    FeedView(hideTabBar: $hideTabBar, onNavigateToMyPage: {
                        hideTabBar = false
                        selectedTab = .myPage
                    })
                case .myPage:
                    MyPageView(hideTabBar: $hideTabBar)
                }
            }
            .transition(.opacity)

            if !hideTabBar {
                bottomBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hideTabBar)
        .fullScreenCover(item: $composeEntry) { entry in
            NavigationStack {
                ComposeEntryWrapper(
                    entry: entry,
                    onPublish: { publishAndDismiss(entry) },
                    onSaveDraft: { saveDraftAndDismiss(entry) },
                    onDiscard: { discardAndDismiss(entry) }
                )
            }
        }
    }

    // MARK: - 底部栏

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(
                iconDefault: "safari",
                iconSelected: "safari.fill",
                tab: .feed
            )

            Button {
                createNewDraftAndPresent()
            } label: {
                Image(systemName: "plus.app")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(.wikiTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TabButtonStyle())

            tabButton(
                iconDefault: "person.crop.circle",
                iconSelected: "person.crop.circle.fill",
                tab: .myPage
            )
        }
        .frame(height: 49)
        .background(
            Rectangle()
                .fill(Color.wikiBg)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(.wikiDivider),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(iconDefault: String, iconSelected: String, tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: selectedTab == tab ? iconSelected : iconDefault)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(selectedTab == tab ? .wikiBlue : .wikiTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(TabButtonStyle())
    }

    // MARK: - 草稿管理

    private func createNewDraftAndPresent() {
        // 复用已有的空草稿
        let desc = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.statusRaw == "draft" && $0.title == "" }
        )
        if let existing = try? modelContext.fetch(desc).first {
            composeEntry = existing
            return
        }

        let entry = Entry(title: "", category: .person, scope: .private, status: .draft)
        entry.draft = EntryDraft(lastEditedAt: .now, lastEditedBy: "我")
        modelContext.insert(entry)
        try? modelContext.save()
        composeEntry = entry
    }

    private func publishAndDismiss(_ entry: Entry) {
        entry.status = .published
        entry.publishedAt = .now
        entry.updatedAt = .now
        entry.draft = nil
        try? modelContext.save()
        Task { try? await SupabaseService.shared.upsertEntry(entry) }
        composeEntry = nil
    }

    private func saveDraftAndDismiss(_ entry: Entry) {
        entry.status = .draft
        entry.draft = EntryDraft(
            title: entry.title,
            category: entry.category,
            introduction: entry.introductionText,
            lastEditedAt: .now
        )
        entry.updatedAt = .now
        try? modelContext.save()
        composeEntry = nil
    }

    private func discardAndDismiss(_ entry: Entry) {
        modelContext.delete(entry)
        try? modelContext.save()
        composeEntry = nil
    }
}

// MARK: - 创作页面（直接持有 Entry，聊天面板单独滑入）

struct ComposeEntryWrapper: View {
    @Bindable var entry: Entry
    let onPublish: () -> Void
    let onSaveDraft: () -> Void
    let onDiscard: () -> Void
    @Environment(\.modelContext) private var modelContext
    @AppStorage("user_display_name") private var displayName = "我"
    @AppStorage("user_avatar_seed") private var avatarSeed = 32

    @State private var showChat = false
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var aiStatus: AIStatus? = nil
    @State private var showAttachmentSheet = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [AttachmentItem] = []
    @State private var showExitConfirmation = false

    var body: some View {
        GeometryReader { geo in
            let topBarH: CGFloat = 48
            let available = geo.size.height - topBarH

            VStack(spacing: 0) {
                composeTopBar

                // 预览区（始终在上方）
                ScrollView {
                    entryPreview
                }
                .frame(height: showChat ? available * 0.35 : nil)
                .clipped()

                // 聊天面板从底部滑入
                if showChat {
                    Divider().foregroundColor(.wikiDivider)
                    VStack(spacing: 0) {
                        chatArea
                        composeInputBar
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color.wikiBg)
        .navigationBarHidden(true)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showChat)
        .overlay {
            if showExitConfirmation {
                exitConfirmationOverlay
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showChat = true
                }
            }
            messages = [ChatMessage(role: .assistant, content: "你好，我是你的词条编纂助手。告诉我一段回忆、一个人、或一件旧物，我来帮你写成百科词条。")]
        }
    }

    // MARK: - 顶栏

    private var hasContent: Bool {
        !entry.title.isEmpty || !entry.sections.isEmpty || !(entry.introductionText ?? "").isEmpty
    }

    private var composeTopBar: some View {
        HStack(spacing: 12) {
            Button {
                if hasContent {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showExitConfirmation = true
                    }
                } else {
                    onDiscard()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }

            AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(avatarSeed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())

            Text(displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.wikiText)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showChat.toggle()
                }
            } label: {
                Image(systemName: showChat ? "xmark" : "square.and.pencil")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.wikiText)
                    .contentTransition(.symbolEffect(.replace))
            }

            if hasContent {
                Button { onPublish() } label: {
                    Text("发布")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.wikiBlue))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.wikiBg)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.wikiDivider),
            alignment: .bottom
        )
    }

    // MARK: - 退出确认浮层

    private var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25)) { showExitConfirmation = false }
                }

            VStack(spacing: 0) {
                Text("保存词条？")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.wikiText)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                exitDialogButton(title: "发布", icon: "arrow.up.circle.fill", color: .wikiBlue) {
                    withAnimation { showExitConfirmation = false }
                    onPublish()
                }
                exitDialogButton(title: "存为草稿", icon: "doc.text", color: .wikiSecondary) {
                    withAnimation { showExitConfirmation = false }
                    onSaveDraft()
                }
                exitDialogButton(title: "丢弃", icon: "trash", color: .red) {
                    withAnimation { showExitConfirmation = false }
                    onDiscard()
                }

                Button {
                    withAnimation(.spring(response: 0.25)) { showExitConfirmation = false }
                } label: {
                    Text("取消")
                        .font(.system(size: 15))
                        .foregroundColor(.wikiTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.wikiBg)
            )
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showExitConfirmation)
    }

    private func exitDialogButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(title == "丢弃" ? .red : .wikiText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 预览区

    private var entryPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            if entry.title.isEmpty && entry.sections.isEmpty {
                // 空草稿提示
                VStack(spacing: 12) {
                    Spacer().frame(height: showChat ? 20 : 60)
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary)
                    Text("新词条")
                        .font(.wikiSectionTitle).foregroundColor(.wikiTertiary)
                    if !showChat {
                        Text("点击右上角编辑按钮，与 AI 对话来创建内容")
                            .font(.wikiSmall).foregroundColor(.wikiTertiary)
                    } else {
                        Text("在下方和 AI 对话，词条将在这里生长")
                            .font(.wikiSmall).foregroundColor(.wikiTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // 有内容时显示标题 + 简介
                Text(entry.title)
                    .font(.wikiTitle)
                    .foregroundColor(.wikiText)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if let intro = entry.introductionText, !intro.isEmpty {
                    Text(intro)
                        .font(.wikiBody)
                        .foregroundColor(.wikiText)
                        .padding(.horizontal, 16)
                }

                ForEach(entry.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.wikiSectionTitle)
                            .foregroundColor(.wikiText)
                        Text(section.body)
                            .font(.wikiBody)
                            .foregroundColor(.wikiText)
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - 聊天区

    private var chatArea: some View {
        ChatAreaView(messages: messages, aiStatus: aiStatus)
    }

    // MARK: - 输入栏

    private var composeInputBar: some View {
        VStack(spacing: 0) {
            if !attachments.isEmpty {
                composeAttachmentBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider().foregroundColor(.wikiDivider)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAttachmentSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.wikiTertiary)
                        .rotationEffect(.degrees(showAttachmentSheet ? 45 : 0))
                }

                TextField("说点什么……", text: $inputText)
                    .font(.wikiBody)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.wikiBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(
                            (inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiStatus != nil)
                                ? .wikiTertiary : .wikiBlue
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiStatus != nil)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color.wikiBg)
        .overlay(alignment: .bottom) {
            if showAttachmentSheet {
                composeAttachmentOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showAttachmentSheet)
        .overlay {
            if showComposeLinkInput {
                linkInputOverlay
            }
        }
        .onChange(of: selectedPhotos) {
            let items = selectedPhotos
            selectedPhotos = []
            showAttachmentSheet = false
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let jpeg = uiImage.jpegData(compressionQuality: 0.6) {
                        let b64 = jpeg.base64EncodedString()
                        await MainActor.run {
                            attachments.append(AttachmentItem(type: .image, name: "图片", imageBase64: b64))
                        }
                    }
                }
            }
        }
    }

    @State private var showComposeLinkInput = false
    @State private var composeLinkText = ""

    private var composeAttachmentOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22))
                            .foregroundColor(.wikiBlue)
                        Text("相册")
                            .font(.system(size: 11))
                            .foregroundColor(.wikiSecondary)
                    }
                    .frame(width: 72, height: 64)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.wikiBgSecondary))
                }

                Button {
                    showComposeLinkInput = true
                    showAttachmentSheet = false
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 22))
                            .foregroundColor(.wikiBlue)
                        Text("链接")
                            .font(.system(size: 11))
                            .foregroundColor(.wikiSecondary)
                    }
                    .frame(width: 72, height: 64)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.wikiBgSecondary))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.wikiBg)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
        )
        .padding(.bottom, 56)
    }

    private var linkInputOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showComposeLinkInput = false }
                    composeLinkText = ""
                }

            VStack(spacing: 16) {
                Text("粘贴链接")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.wikiText)

                TextField("https://...", text: $composeLinkText)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.wikiBgSecondary)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack(spacing: 12) {
                    Button {
                        withAnimation { showComposeLinkInput = false }
                        composeLinkText = ""
                    } label: {
                        Text("取消")
                            .font(.system(size: 15))
                            .foregroundColor(.wikiSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.wikiBgSecondary))
                    }

                    Button {
                        let url = composeLinkText.trimmingCharacters(in: .whitespaces)
                        if !url.isEmpty {
                            attachments.append(AttachmentItem(type: .link, name: url, linkURL: url))
                        }
                        composeLinkText = ""
                        withAnimation { showComposeLinkInput = false }
                    } label: {
                        Text("添加")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.wikiBlue))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.wikiBg)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .animation(.spring(response: 0.3), value: showComposeLinkInput)
    }

    private var composeAttachmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { att in
                    HStack(spacing: 6) {
                        Image(systemName: att.type.icon).font(.system(size: 12))
                        Text(att.name).font(.system(size: 12)).lineLimit(1)
                        Button {
                            withAnimation { attachments.removeAll { $0.id == att.id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.wikiTertiary)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.wikiBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }

    // MARK: - 发消息（Tool Calling）

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let imageData = attachments.compactMap(\.imageBase64)
        let hasImages = !imageData.isEmpty
        let displayText = hasImages ? "📷×\(imageData.count) \(text)" : text
        messages.append(ChatMessage(role: .user, content: displayText))
        inputText = ""
        attachments.removeAll()

        withAnimation { aiStatus = .thinking }

        Task {
            do {
                let snapshot = entry.title.isEmpty ? nil : EntrySnapshot(from: entry)
                let result = try await AIService.shared.chat(
                    messages: messages,
                    currentEntry: snapshot,
                    imageBase64List: hasImages ? imageData : nil
                )

                await MainActor.run {
                    // 显示工具调用过程
                    for action in result.actions {
                        messages.append(ChatMessage(role: .system, content: action))
                    }

                    if result.entryData != nil {
                        withAnimation { aiStatus = .updatingEntry(result.entryData?.title ?? "") }
                    }
                }

                if result.entryData != nil {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }

                await MainActor.run {
                    withAnimation { aiStatus = nil }

                    messages.append(ChatMessage(role: .assistant, content: result.reply))

                    if let data = result.entryData {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            data.apply(to: entry)
                            if entry.status == .draft {
                                entry.draft = EntryDraft(
                                    title: entry.title,
                                    category: entry.category,
                                    introduction: entry.introductionText,
                                    lastEditedAt: .now
                                )
                            }
                        }
                        try? modelContext.save()

                        if !entry.title.isEmpty {
                            NotificationService.shared.add(AppNotification(
                                type: .aiUpdate,
                                title: "词条编纂完成",
                                body: "AI 助手完成了「\(entry.title)」的更新",
                                relatedEntryId: entry.id
                            ))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation { aiStatus = nil }
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: "抱歉，遇到了一点问题：\(error.localizedDescription)。请重试一下？"
                    ))
                }
            }
        }
    }
}

// MARK: - Tab 按钮样式

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
