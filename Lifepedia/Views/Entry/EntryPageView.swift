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
    @State private var targetUser: UserDestination?
    @State private var showUserProfile = false
    @State private var replyTarget: Comment?
    @State private var hasRequestedCollab = false
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
        .navigationDestination(isPresented: $showUserProfile) {
            if let user = targetUser {
                UserProfileView(userName: user.userName, userId: user.userId)
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
                    targetUser = UserDestination(userName: entry.authorName, userId: entry.authorId)
                    showUserProfile = true
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

            if entry.isDraft {
                Text("草稿")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))

                Button {
                    entry.status = .published
                    entry.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    Text("发布")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.wikiBlue))
                }
            }

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

            if !entry.isDraft {
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
                if entry.canEdit {
                    moreMenuItem(icon: entry.scope.icon, title: "可见性", subtitle: entry.scope.label) {
                        closeMenuThen { showVisibilitySheet = true }
                    }

                    if entry.scope == .collaborative || entry.scope == .public {
                        moreMenuItem(icon: "person.2", title: "合编者", subtitle: "\(entry.contributorNames?.count ?? 0) 人") {
                            closeMenuThen { showCollaboratorsSheet = true }
                        }
                    }

                    if entry.authorId != "self" {
                        menuDivider
                        moreMenuItem(icon: "rectangle.portrait.and.arrow.right", title: "退出合编", isDestructive: true) {
                            closeMenuThen { leaveCollaboration(entry) }
                        }
                    }

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
                } else {
                    if (entry.scope == .collaborative || entry.scope == .public) {
                        moreMenuItem(icon: "person.2", title: "合编者", subtitle: "\(entry.contributorNames?.count ?? 0) 人") {
                            closeMenuThen { showCollaboratorsSheet = true }
                        }
                        menuDivider
                    }

                    if entry.scope == .public {
                        moreMenuItem(icon: "person.badge.plus", title: hasRequestedCollab ? "已申请合编" : "申请成为合编者") {
                            closeMenuThen {
                                if !hasRequestedCollab { requestCollaboration(entry) }
                            }
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
        let topLevel = entry.comments.filter { $0.parentId == nil }
        let repliesMap = Dictionary(grouping: entry.comments.filter { $0.parentId != nil }, by: { $0.parentId! })

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.wikiBgSecondary)
                .frame(height: 8)

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
                ForEach(topLevel) { comment in
                    discussionRow(comment, entry: entry)
                    if let replies = repliesMap[comment.id] {
                        ForEach(replies) { reply in
                            discussionReplyRow(reply, entry: entry)
                        }
                    }
                }
            }

            discussionInput(entry)
                .id("discussion-input")

            Spacer().frame(height: 40)
        }
    }

    private func discussionRow(_ comment: Comment, entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            let seed = abs(comment.authorName.hashValue) % 200

            Button {
                navigateToCommentAuthor(comment.authorName)
            } label: {
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
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        navigateToCommentAuthor(comment.authorName)
                    } label: {
                        Text(comment.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.wikiSecondary)
                    }
                    .buttonStyle(.plain)

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

                    Button {
                        replyTarget = comment
                        discussionFocused = true
                    } label: {
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

    private func discussionReplyRow(_ reply: Comment, entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            let seed = abs(reply.authorName.hashValue) % 200
            Button {
                navigateToCommentAuthor(reply.authorName)
            } label: {
                AsyncImage(url: URL(string: "https://i.pravatar.cc/48?img=\(seed)")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.wikiBgSecondary)
                            .overlay(
                                Text(String(reply.authorName.prefix(1)))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.wikiSecondary)
                            )
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(reply.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wikiSecondary)
                    if reply.authorName == entry.authorName {
                        Text("作者")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.wikiBlue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.wikiBlue.opacity(0.1)))
                    }
                }

                HStack(spacing: 0) {
                    if let replyTo = reply.replyToName {
                        Text("回复 ")
                            .font(.system(size: 13))
                            .foregroundColor(.wikiTertiary)
                        Text("@\(replyTo) ")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.wikiBlue)
                    }
                    Text(reply.body)
                        .font(.system(size: 13))
                        .foregroundColor(.wikiText)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    Text(discussionRelativeTime(reply.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.wikiTertiary)
                    Button {
                        replyTarget = reply
                        discussionFocused = true
                    } label: {
                        Text("回复")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.wikiTertiary)
                    }
                    Spacer()
                    Button {
                        toggleDiscussionLike(reply, entry: entry)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: reply.likeCount > 0 ? "heart.fill" : "heart")
                                .font(.system(size: 10))
                                .foregroundColor(reply.likeCount > 0 ? .red.opacity(0.7) : .wikiTertiary)
                            if reply.likeCount > 0 {
                                Text("\(reply.likeCount)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.wikiTertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 56)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
    }

    private func discussionInput(_ entry: Entry) -> some View {
        VStack(spacing: 0) {
            if let target = replyTarget {
                HStack(spacing: 6) {
                    Text("回复 @\(target.authorName)")
                        .font(.system(size: 12))
                        .foregroundColor(.wikiSecondary)
                    Spacer()
                    Button {
                        withAnimation { replyTarget = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.wikiTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.wikiBgSecondary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.wikiBlue.opacity(0.12))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.wikiBlue)
                    )

                TextField(replyTarget != nil ? "回复 @\(replyTarget!.authorName)…" : "说点什么…", text: $newDiscussionText, axis: .vertical)
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
        }
        .animation(.spring(response: 0.25), value: newDiscussionText.isEmpty)
        .animation(.spring(response: 0.25), value: replyTarget?.id)
    }

    private func postDiscussionComment(to entry: Entry) {
        let text = newDiscussionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let parentId: String?
        let replyToName: String?
        if let target = replyTarget {
            parentId = target.parentId ?? target.id
            replyToName = target.authorName
        } else {
            parentId = nil
            replyToName = nil
        }

        let comment = Comment(body: text, parentId: parentId, replyToName: replyToName)
        var comments = entry.comments
        comments.append(comment)
        entry.comments = comments
        entry.commentCount = comments.count
        try? modelContext.save()

        if entry.authorId != "self" {
            let myName = UserDefaults.standard.string(forKey: "user_display_name") ?? "我"
            NotificationService.shared.add(AppNotification(
                type: .comment,
                title: "\(myName) 评论了词条",
                body: "「\(entry.title)」—— \(text.prefix(30))",
                relatedEntryId: entry.id,
                fromUserName: myName
            ))
        }

        newDiscussionText = ""
        replyTarget = nil
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

    private func navigateToCommentAuthor(_ authorName: String) {
        let myName = UserDefaults.standard.string(forKey: "user_display_name") ?? "我"
        if authorName == myName {
            if let goMyPage = onNavigateToMyPage {
                goMyPage()
            }
        } else {
            let userId = resolveUserId(for: authorName)
            targetUser = UserDestination(userName: authorName, userId: userId)
            showUserProfile = true
        }
    }

    private func resolveUserId(for name: String) -> String {
        let knownUsers: [String: String] = [
            "昱东": "yudong", "林清": "linqing", "陈小鱼": "chenxiaoyu",
            "爸爸": "baba", "妈妈": "mama", "姐姐": "sister",
            "阿花": "ahua", "小明": "xiaoming", "大壮": "dazhuang"
        ]
        return knownUsers[name] ?? name.lowercased()
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
        let realURL: String? = entry.coverImageURL
            ?? entry.sections.first(where: { !$0.imageRefs.isEmpty })?.imageRefs.first

        let seed = abs(entry.title.hashValue) % 1000
        let ratios: [CGFloat] = [4.0/3, 3.0/2, 16.0/9, 1.0]
        let ratio = ratios[seed % ratios.count]

        return Group {
            if let urlStr = realURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        heroPlaceholder(entry: entry, ratio: ratio)
                    } else {
                        Rectangle().fill(Color.wikiBgSecondary)
                            .overlay(ProgressView())
                    }
                }
            } else {
                heroPlaceholder(entry: entry, ratio: ratio)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(ratio, contentMode: .fit)
        .clipped()
    }

    private func heroPlaceholder(entry: Entry, ratio: CGFloat) -> some View {
        let seed = abs(entry.title.hashValue) % 1000
        let hue = Double(seed % 360) / 360.0
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.08, brightness: 0.97),
                        Color(hue: hue, saturation: 0.15, brightness: 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(ratio, contentMode: .fit)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.wikiTertiary.opacity(0.5))
                    if !entry.title.isEmpty {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.wikiTertiary.opacity(0.6))
                    }
                }
            )
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

            if !section.imageRefs.isEmpty {
                ForEach(section.imageRefs, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                            case .failure:
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.wikiBgSecondary)
                                    .frame(height: 120)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.wikiTertiary)
                                    )
                            case .empty:
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.wikiBgSecondary)
                                    .frame(height: 200)
                                    .overlay(
                                        ProgressView()
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                }
            }
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

    @State private var showLinkInput = false
    @State private var linkInputText = ""

    private var attachmentSheet: some View {
        NavigationStack {
            List {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                    Label("从相册选图", systemImage: "photo.on.rectangle")
                }
                Button {
                    showLinkInput = true
                } label: {
                    Label("粘贴链接", systemImage: "link")
                }
            }
            .alert("粘贴链接", isPresented: $showLinkInput) {
                TextField("https://...", text: $linkInputText)
                Button("取消", role: .cancel) { linkInputText = "" }
                Button("添加") {
                    let url = linkInputText.trimmingCharacters(in: .whitespaces)
                    if !url.isEmpty {
                        attachments.append(AttachmentItem(type: .link, name: url, linkURL: url))
                    }
                    linkInputText = ""
                    showAttachmentSheet = false
                }
            } message: {
                Text("输入要添加的网页链接")
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

        let imageData = attachments.compactMap(\.imageBase64)
        let hasImages = !imageData.isEmpty
        print("🔴🔴🔴 sendMessage called: text=\(text.prefix(30)), hasImages=\(hasImages), imageCount=\(imageData.count), b64Lengths=\(imageData.map(\.count))")
        let displayText = hasImages ? "📷×\(imageData.count) \(text)" : text
        messages.append(ChatMessage(role: .user, content: displayText))
        inputText = ""
        attachments = []

        withAnimation { aiStatus = .thinking }

        Task {
            do {
                // 用户上传的图片 → 持久化到 Storage，拿到永久 URL
                var uploadedURLs: [String] = []
                if hasImages {
                    for (idx, b64) in imageData.enumerated() {
                        print("[Upload] 图片\(idx+1) base64长度=\(b64.count)")
                        do {
                            let url = try await SupabaseService.shared.uploadBase64Image(b64)
                            uploadedURLs.append(url)
                            print("[Upload] 图片\(idx+1) 上传成功: \(url)")
                        } catch {
                            print("[Upload] 图片\(idx+1) 上传失败: \(error)")
                        }
                    }
                }

                let snapshot = entry.map { EntrySnapshot(from: $0) }
                let editable = entry?.canEdit ?? false
                // 优先用 URL（AI 既能看图又能拿到链接），上传失败时才 fallback base64
                let useBase64Fallback = hasImages && uploadedURLs.isEmpty
                let result = try await AIService.shared.chat(
                    messages: messages,
                    currentEntry: snapshot,
                    imageBase64List: useBase64Fallback ? imageData : nil,
                    uploadedImageURLs: uploadedURLs.isEmpty ? nil : uploadedURLs,
                    canEdit: editable
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

                        NotificationService.shared.add(AppNotification(
                            type: .aiUpdate,
                            title: "词条编纂完成",
                            body: "AI 助手完成了「\(entry.title)」的更新",
                            relatedEntryId: entry.id
                        ))
                    }
                }

                if !result.imageGenTasks.isEmpty, let entry = entry {
                    await MainActor.run {
                        withAnimation { aiStatus = .generatingImage }
                        messages.append(ChatMessage(role: .system, content: "photo.artframe|正在生成 \(result.imageGenTasks.count) 张插图…"))
                    }

                    for task in result.imageGenTasks {
                        do {
                            let tempURL = try await ImageGenerationService.shared.generate(
                                prompt: task.prompt,
                                sectionTitle: task.sectionTitle
                            )

                            // 将临时 URL 持久化到 Supabase Storage
                            let persistedURL: String
                            do {
                                persistedURL = try await SupabaseService.shared.persistImageFromURL(tempURL)
                            } catch {
                                print("[ImageGen] Storage 持久化失败，使用临时 URL: \(error)")
                                persistedURL = tempURL
                            }

                            await MainActor.run {
                                if let idx = entry.sections.firstIndex(where: { $0.title == task.sectionTitle }) {
                                    var refs = entry.sections[idx].imageRefs
                                    refs.append(persistedURL)
                                    entry.sections[idx] = EntrySection(
                                        title: entry.sections[idx].title,
                                        body: entry.sections[idx].body,
                                        imageRefs: refs
                                    )
                                } else if !entry.sections.isEmpty {
                                    var refs = entry.sections[0].imageRefs
                                    refs.append(persistedURL)
                                    entry.sections[0] = EntrySection(
                                        title: entry.sections[0].title,
                                        body: entry.sections[0].body,
                                        imageRefs: refs
                                    )
                                }
                                if entry.coverImageURL == nil || entry.coverImageURL?.isEmpty == true {
                                    entry.coverImageURL = persistedURL
                                }
                                try? modelContext.save()
                                messages.append(ChatMessage(role: .system, content: "checkmark.circle|「\(task.sectionTitle)」插图已生成"))
                            }
                        } catch {
                            await MainActor.run {
                                messages.append(ChatMessage(role: .system, content: "exclamationmark.triangle|插图生成失败: \(error.localizedDescription)"))
                            }
                        }
                    }

                    await MainActor.run {
                        withAnimation { aiStatus = nil }
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

    // MARK: - Collaboration Actions

    private func requestCollaboration(_ entry: Entry) {
        withAnimation(.spring(response: 0.3)) { hasRequestedCollab = true }
        NotificationService.shared.add(AppNotification(
            type: .collabRequest,
            title: "合编申请",
            body: "有人申请成为「\(entry.title.isEmpty ? "未命名词条" : entry.title)」的合编者",
            relatedEntryId: entry.id,
            fromUserName: "我"
        ))
    }

    private func leaveCollaboration(_ entry: Entry) {
        var list = entry.contributorNames ?? []
        list.removeAll { $0 == "我" }
        entry.contributorNames = list
        try? modelContext.save()
        dismiss()
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
    var imageBase64: String?
    var linkURL: String?
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
