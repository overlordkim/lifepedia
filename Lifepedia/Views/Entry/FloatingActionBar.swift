import SwiftUI

struct FloatingActionBar: View {
    let entry: Entry
    @Binding var isLiked: Bool
    @Binding var isBookmarked: Bool
    var onCommentTap: () -> Void = {}
    var onShareImage: () -> Void = {}
    @State private var showShareOptions = false

    var body: some View {
        VStack(spacing: 0) {
            Divider().foregroundColor(.wikiDivider)

            HStack {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isLiked.toggle()
                        }
                        if isLiked && entry.authorId != (AuthService.shared.currentUser?.id ?? "self") {
                            let myName = AuthService.shared.currentUser?.displayName ?? "我"
                            NotificationService.shared.add(AppNotification(
                                type: .like,
                                title: "\(myName) 赞了词条",
                                body: "「\(entry.title)」",
                                relatedEntryId: entry.id,
                                fromUserName: myName
                            ))
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(isLiked ? .wikiHeartActive : .wikiText)
                                .scaleEffect(isLiked ? 1.15 : 1.0)
                            Text("\(entry.likeCount + (isLiked ? 1 : 0))")
                                .font(.system(size: 13))
                                .foregroundColor(.wikiSecondary)
                        }
                    }

                    Button { onCommentTap() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.wikiText)
                            Text("\(entry.commentCount)")
                                .font(.system(size: 13))
                                .foregroundColor(.wikiSecondary)
                        }
                    }

                    Button { showShareOptions = true } label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(.wikiText)
                    }
                    .confirmationDialog("分享", isPresented: $showShareOptions) {
                        Button("生成长图") { onShareImage() }
                        Button("分享文字") {
                            let text = "来看看「\(entry.title)」这篇词条 — 人间词条 Lifepedia"
                            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        }
                        Button("取消", role: .cancel) {}
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isBookmarked.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(isBookmarked ? .wikiBookmarkActive : .wikiText)
                            .scaleEffect(isBookmarked ? 1.15 : 1.0)
                        Text("\(entry.collectCount + (isBookmarked ? 1 : 0))")
                            .font(.system(size: 13))
                            .foregroundColor(.wikiSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.wikiBg)
    }
}
