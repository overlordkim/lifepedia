import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct EntryPageView: View {
    let entryId: UUID
    var startInEditMode: Bool = false
    var onDismissToFeed: (() -> Void)?
    var onNavigateToMyPage: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [Entry]
    @State private var showChat = false
    @State private var isLiked = false
    @State private var isBookmarked = false

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var aiStatus: AIStatus? = nil

    @State private var showAttachmentSheet = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [AttachmentItem] = []
    @State private var showMoreMenu = false
    @State private var showVisibilitySheet = false
    @State private var showCollaboratorsSheet = false
    @State private var newDiscussionText = ""
    @State private var scrollToDiscussion = false
    @State private var showAuthorProfile = false
    @FocusState private var discussionFocused: Bool

    private var entry: Entry? {
        allEntries.first { $0.id == entryId }
    }

    var body: some View {
        Group {
            if let entry = entry {
                mainContent(entry)
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .background(Color.wikiBg)
            }
        }
        .onAppear {
            if startInEditMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showChat = true
                    }
                }
            }
            if messages.isEmpty {
                let greeting = (entry?.canEdit == true)
                    ? "你好，我是你的词条编纂助手。告诉我一段回忆，我来帮你写成百科词条。"
                    : "你好，让我们一起品味这篇词条吧。你觉得哪里最打动你？"
                messages = [ChatMessage(role: .assistant, content: greeting)]
            }
        }
    }

    // MARK: - Main（词条内容始终在上方，聊天面板从底部滑入）

    @ViewBuilder
    private func mainContent(_ entry: Entry) -> some View {
        GeometryReader { geo in
            let topBarH: CGFloat = 48
            let available = geo.size.height - topBarH

            VStack(spacing: 0) {
                entryTopBar(entry)

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        if showChat && entry.isDraft && entry.title.isEmpty {
                            draftEmptyState
                        } else {
                            entryContent(entry)
                            inlineDiscussion(entry)
                        }
                    }
                    .frame(height: showChat ? available * 0.4 : nil)
                    .clipped()
                    .onChange(of: discussionFocused) {
                        if discussionFocused {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scrollProxy.scrollTo("discussion-input", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: scrollToDiscussion) {
                        if scrollToDiscussion {
                            withAnimation(.easeOut(duration: 0.4)) {
                                scrollProxy.scrollTo("discussion-header", anchor: .top)
                            }
                            scrollToDiscussion = false
                        }
                    }

                    if showChat {
                        Divider().foregroundColor(.wikiDivider)
                        VStack(spacing: 0) {
                            chatArea
                            inputBar
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        FloatingActionBar(
                            entry: entry,
                            isLiked: $isLiked,
                            isBookmarked: $isBookmarked,
                            onCommentTap: {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    scrollProxy.scrollTo("discussion-header", anchor: .top)
                                }
                            }
                        )
                        .transition(.opacity)
                    }
                }
            }
        }
        .background(Color.wikiBg)
        .navigationBarHidden(true)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showChat)
        .overlay(alignment: .topTrailing) {
            if showMoreMenu {
                moreMenuOverlay(entry)
            }
        }
        .navigationDestination(isPresented: $showAuthorProfile) {
            if let entry = entry {
                UserProfileView(
                    userName: entry.authorName,
                    userId: entry.authorId
                )
                .navigationBarHidden(true)
            }
        }
        .sheet(isPresented: $showVisibilitySheet) {
            VisibilitySheet(entry: entry)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCollaboratorsSheet) {
            CollaboratorsSheet(entry: entry)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 自定义顶栏

    private func entryTopBar(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            Button {
                if let goHome = onDismissToFeed {
                    goHome()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: onDismissToFeed != nil ? "xmark" : "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.wikiText)
                    .frame(width: 28, height: 28)
            }

            Button {
                if entry.authorId == "self" {
                    if let goMyPage = onNavigateToMyPage {
                        goMyPage()
                    } else {
                        dismiss()
                    }
                } else {
                    showAuthorProfile = true
                }
            } label: {
                HStack(spacing: 8) {
                    let seed = abs(entry.authorName.hashValue) % 200
                    AsyncImage(url: URL(string: "https://i.pravatar.cc/80?img=\(seed)")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.wikiBgSecondary)
                                .overlay(
                                    Text(String(entry.authorName.prefix(1)))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.wikiSecondary)
                                )
                        }
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                    Text(entry.authorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.wikiText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showChat.toggle()
                }
            } label: {
                Image(systemName: showChat ? "xmark" : (entry.canEdit ? "square.and.pencil" : "text.bubble"))
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.wikiText)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.wikiText)
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

    // MARK: - 更多菜单（自定义覆盖层）

    private func moreMenuOverlay(_ entry: Entry) -> some View {
        ZStack(alignment: .topTrailing) {
            // 背景遮罩
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showMoreMenu = false
                    }
                }

            // 菜单卡片
            VStack(alignment: .leading, spacing: 0) {
                // 可见性
                moreMenuItem(icon: entry.scope.icon, title: "可见性", subtitle: entry.scope.label) {
                    closeMenuThen { showVisibilitySheet = true }
                }

                if entry.scope == .collaborative || entry.scope == .public {
                    moreMenuItem(icon: "person.2", title: "合编者", subtitle: "\(entry.contributorNames?.count ?? 0) 人") {
                        closeMenuThen { showCollaboratorsSheet = true }
                    }
                }

                menuDivider

                moreMenuItem(icon: "bubble.left.and.text.bubble.right", title: "讨论", subtitle: "\(entry.commentCount)") {
                    closeMenuThen { scrollToDiscussion = true }
                }

                moreMenuItem(icon: "clock.arrow.circlepath", title: "修订历史") {
                    closeMenuThen { }
                }

                menuDivider

                moreMenuItem(icon: "link", title: "复制链接") {
                    UIPasteboard.general.string = "lifepedia://entry/\(entry.id.uuidString)"
                    closeMenuThen { }
                }

                moreMenuItem(icon: "square.and.arrow.up", title: "分享") {
                    closeMenuThen { }
                }

                if entry.authorId != "self" {
                    moreMenuItem(icon: "flag", title: "举报") {
                        closeMenuThen { }
                    }
                }

                if entry.canEdit {
                    menuDivider
                    moreMenuItem(icon: "trash", title: "删除", isDestructive: true) {
                        closeMenuThen {
                            let id = entry.id
                            modelContext.delete(entry)
                            try? modelContext.save()
                            Task { try? await SupabaseService.shared.deleteEntry(id: id) }
                            if let goHome = onDismissToFeed { goHome() } else { dismiss() }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.top, 54)
            .padding(.trailing, 12)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity),
                removal: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity)
            ))
        }
    }

    private func moreMenuItem(icon: String, title: String, subtitle: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isDestructive ? .red : .wikiSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isDestructive ? .red : .primary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.wikiTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
    }

    private func closeMenuThen(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showMoreMenu = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
        }
    }

    // MARK: - 词条内容

    private func entryContent(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroImage(entry)

            VStack(alignment: .leading, spacing: 20) {
                titleSection(entry)
                InfoboxView(infobox: entry.infobox, category: entry.category)

                if let intro = entry.introductionText, !intro.isEmpty {
                    Text(intro)
                        .font(.wikiBody)
                        .foregroundColor(.wikiText)
                        .wikiReadingStyle()
                }

                ForEach(entry.sections) { section in
                    sectionView(section)
                }

                if let related = entry.relatedEntryTitles, !related.isEmpty {
                    relatedSection(related)
                }

                if !entry.revisions.isEmpty {
                    revisionEntry(entry)
                }

                if let tags = entry.tags, !tags.isEmpty {
                    tagsSection(tags)
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }

    // MARK: - 内联讨论区（小红书风格）

    private func inlineDiscussion(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.wikiBgSecondary)
                .frame(height: 8)

            // 标题栏
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.wikiText)
                Text("讨论")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.wikiText)
                Text("\(entry.comments.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.wikiTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .id("discussion-header")

            // 评论列表
            if entry.comments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary)
                    Text("还没有讨论，来说点什么吧")
                        .font(.system(size: 14))
                        .foregroundColor(.wikiTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(entry.comments) { comment in
                    discussionRow(comment, entry: entry)
                }
            }

            // 输入区
            discussionInput(entry)
                .id("discussion-input")

            Spacer().frame(height: 40)
        }
    }

    private func discussionRow(_ comment: Comment, entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            let seed = abs(comment.authorName.hashValue) % 200
            AsyncImage(url: URL(string: "https://i.pravatar.cc/64?img=\(seed)")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.wikiBgSecondary)
                        .overlay(
                            Text(String(comment.authorName.prefix(1)))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.wikiSecondary)
                        )
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.wikiSecondary)
                    if comment.authorName == entry.authorName {
                        Text("作者")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.wikiBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.wikiBlue.opacity(0.1)))
                    }
                }

                Text(comment.body)
                    .font(.system(size: 14))
                    .foregroundColor(.wikiText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Text(discussionRelativeTime(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.wikiTertiary)

                    Button {} label: {
                        Text("回复")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.wikiTertiary)
                    }

                    Spacer()

                    Button {
                        toggleDiscussionLike(comment, entry: entry)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: comment.likeCount > 0 ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(comment.likeCount > 0 ? .red.opacity(0.7) : .wikiTertiary)
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.wikiTertiary)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func discussionInput(_ entry: Entry) -> some View {
        HStack(spacing: 10) {
            // 当前用户头像
            Circle()
                .fill(Color.wikiBlue.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.wikiBlue)
                )

            TextField("说点什么…", text: $newDiscussionText, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...3)
                .focused($discussionFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.wikiBgSecondary)
                )

            if !newDiscussionText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    postDiscussionComment(to: entry)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.wikiBlue)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.25), value: newDiscussionText.isEmpty)
    }

    private func postDiscussionComment(to entry: Entry) {
        let text = newDiscussionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let comment = Comment(body: text)
        var comments = entry.comments
        comments.append(comment)
        entry.comments = comments
        entry.commentCount = comments.count
        try? modelContext.save()
        newDiscussionText = ""
        discussionFocused = false
    }

    private func toggleDiscussionLike(_ comment: Comment, entry: Entry) {
        var comments = entry.comments
        if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[idx].likeCount = comment.likeCount > 0 ? 0 : comment.likeCount + 1
            entry.comments = comments
            try? modelContext.save()
        }
    }

    private func discussionRelativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    // MARK: - Hero

    private func heroImage(_ entry: Entry) -> some View {
        let seed = abs(entry.title.hashValue) % 1000
        return AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/1200/675")) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } else {
                Rectangle().fill(Color.wikiBgSecondary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.wikiTertiary)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }

    // MARK: - Title

    private func titleSection(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title.isEmpty ? "未命名词条" : entry.title)
                .font(.wikiTitle)
                .foregroundColor(entry.title.isEmpty ? .wikiTertiary : .wikiText)

            if let sub = entry.subtitle, !sub.isEmpty {
                Text(sub).font(.wikiMeta).foregroundColor(.wikiSecondary)
            }

            HStack(spacing: 12) {
                Label(entry.category.label, systemImage: "tag")
                Label(entry.scope.label, systemImage: entry.scope.icon)
                if entry.isDraft {
                    Label("草稿", systemImage: "pencil").foregroundColor(.wikiRed)
                }
            }
            .font(.wikiSmall)
            .foregroundColor(.wikiTertiary)

            Divider().foregroundColor(.wikiDivider)
        }
    }

    // MARK: - Section

    private func sectionView(_ section: EntrySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title).font(.wikiSectionTitle).foregroundColor(.wikiText)
                Rectangle().fill(Color.wikiDivider).frame(height: 1)
            }
            Text(parseWikiText(section.body))
                .font(.wikiBody).foregroundColor(.wikiText).wikiReadingStyle()
        }
    }

    private func relatedSection(_ titles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("相关条目").font(.wikiSectionTitle).foregroundColor(.wikiText)
                Rectangle().fill(Color.wikiDivider).frame(height: 1)
            }
            ForEach(titles, id: \.self) { title in
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right").font(.system(size: 12))
                    Text(title).underline()
                }
                .font(.wikiBody).foregroundColor(.wikiBlue)
            }
        }
    }

    private func revisionEntry(_ entry: Entry) -> some View {
        NavigationLink {
            RevisionHistoryView(revisions: entry.revisions)
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 14))
                Text("\(entry.revisions.count) 次编辑 · 查看全部").font(.wikiMeta)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12))
            }
            .foregroundColor(.wikiBlue)
            .padding(12)
            .background(Color.wikiBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().foregroundColor(.wikiDivider)
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.wikiSmall).italic()
                        .foregroundColor(.wikiTertiary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.wikiBorder, lineWidth: 0.5)
                        )
                }
            }
        }
    }

    // MARK: - 草稿空态

    private var draftEmptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "text.book.closed")
                .font(.system(size: 36)).foregroundColor(.wikiTertiary)
            Text("新词条")
                .font(.wikiSectionTitle).foregroundColor(.wikiTertiary)
            Text("在下方和 AI 对话，词条将在这里生长")
                .font(.wikiMeta).foregroundColor(.wikiTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 对话区

    private var chatArea: some View {
        ChatAreaView(messages: messages, aiStatus: aiStatus)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        VStack(spacing: 0) {
            if !attachments.isEmpty {
                attachmentBar
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
        .sheet(isPresented: $showAttachmentSheet) {
            attachmentSheet.presentationDetents([.medium])
        }
    }

    private var attachmentSheet: some View {
        NavigationStack {
            List {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                    Label("从相册选图", systemImage: "photo.on.rectangle")
                }
                Button { showAttachmentSheet = false } label: {
                    Label("拍照", systemImage: "camera")
                }
                Button { showAttachmentSheet = false } label: {
                    Label("选择文件", systemImage: "doc")
                }
                Button {
                    attachments.append(AttachmentItem(type: .link, name: "已粘贴链接"))
                    showAttachmentSheet = false
                } label: {
                    Label("粘贴链接", systemImage: "link")
                }
                Button { showAttachmentSheet = false } label: {
                    Label("录音", systemImage: "mic")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("添加内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showAttachmentSheet = false }.font(.wikiButton)
                }
            }
        }
        .onChange(of: selectedPhotos) {
            for item in selectedPhotos {
                attachments.append(AttachmentItem(type: .image, name: item.itemIdentifier ?? "图片"))
            }
            selectedPhotos = []
            showAttachmentSheet = false
        }
    }

    private var attachmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { att in
                    HStack(spacing: 6) {
                        Image(systemName: att.type.icon).font(.system(size: 12))
                        Text(att.name).font(.wikiSmall).lineLimit(1)
                        Button {
                            withAnimation { attachments.removeAll { $0.id == att.id } }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(.wikiSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.wikiBgSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.wikiBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.wikiBgSecondary)
    }

    // MARK: - Send（Tool Calling）

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        attachments = []

        withAnimation { aiStatus = .thinking }

        Task {
            do {
                let snapshot = entry.map { EntrySnapshot(from: $0) }
                let result = try await AIService.shared.chat(
                    messages: messages,
                    currentEntry: snapshot
                )

                await MainActor.run {
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

                    if let data = result.entryData, let entry = entry, entry.canEdit {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            data.apply(to: entry)
                        }
                        try? modelContext.save()
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

    // MARK: - Wiki Text

    private func parseWikiText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[text.startIndex...]
        while !remaining.isEmpty {
            if remaining.hasPrefix("[["), let end = remaining.range(of: "]]") {
                let s = remaining.index(remaining.startIndex, offsetBy: 2)
                var attr = AttributedString(String(remaining[s..<end.lowerBound]))
                attr.foregroundColor = .wikiBlue
                attr.underlineStyle = .single
                result += attr
                remaining = remaining[end.upperBound...]
            } else if remaining.hasPrefix("{{"), let end = remaining.range(of: "}}") {
                let s = remaining.index(remaining.startIndex, offsetBy: 2)
                var attr = AttributedString(String(remaining[s..<end.lowerBound]))
                attr.foregroundColor = .wikiRed
                result += attr
                remaining = remaining[end.upperBound...]
            } else if remaining.hasPrefix("[来源请求]") {
                var attr = AttributedString("[来源请求]")
                attr.foregroundColor = .wikiBlue
                attr.font = .system(size: 10)
                result += attr
                remaining = remaining[remaining.index(remaining.startIndex, offsetBy: 5)...]
            } else {
                result += AttributedString(String(remaining.prefix(1)))
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }
        return result
    }
}

// MARK: - 附件模型

struct AttachmentItem: Identifiable {
    let id = UUID()
    var type: AttachmentType
    var name: String
}

enum AttachmentType {
    case image, file, link, audio
    var icon: String {
        switch self {
        case .image: return "photo"
        case .file:  return "doc"
        case .link:  return "link"
        case .audio: return "mic"
        }
    }
}
