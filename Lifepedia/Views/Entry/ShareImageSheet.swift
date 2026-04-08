import SwiftUI

struct ShareImageSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: UIImage?
    @State private var isRendering = true
    @State private var saved = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 245/255, green: 245/255, blue: 245/255)
                    .ignoresSafeArea()

                if isRendering {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成长图…")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else if let image = renderedImage {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    }

                    VStack {
                        Spacer()
                        actionButtons(image: image)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("生成失败，请重试")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("分享长图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task { await render() }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ActivitySheet(items: [image])
            }
        }
    }

    private func actionButtons(image: UIImage) -> some View {
        HStack(spacing: 16) {
            Button {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                withAnimation { saved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { saved = false }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                    Text(saved ? "已保存" : "保存到相册")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(saved ? Color.green : Color.black)
                )
            }

            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane")
                    Text("分享")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0), Color(red: 245/255, green: 245/255, blue: 245/255)],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Render

    @MainActor
    private func render() async {
        let coverImage = await downloadImage(entry.coverImageURL)
        let avatarImage = await downloadImage(Secrets.avatarURL(for: entry.authorId)?.absoluteString)

        var sectionImages: [String: UIImage] = [:]
        for section in entry.sections {
            for urlStr in section.imageRefs {
                if sectionImages[urlStr] == nil {
                    sectionImages[urlStr] = await downloadImage(urlStr)
                }
            }
        }

        let card = ShareCardView(
            entry: entry,
            coverImage: coverImage,
            sectionImages: sectionImages,
            avatarImage: avatarImage
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
        isRendering = false
    }

    private func downloadImage(_ urlStr: String?) async -> UIImage? {
        guard let urlStr, let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
