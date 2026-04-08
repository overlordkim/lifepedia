import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("user_display_name") private var displayName = "我"
    @AppStorage("user_bio") private var bio = "用百科的方式，记录我的人生"

    @State private var editingName = ""
    @State private var editingBio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploading = false
    @State private var avatarRefreshId = UUID()
    @FocusState private var focusedField: Field?

    enum Field { case name, bio }

    private var myId: String { AuthService.shared.currentUser?.id ?? "self" }

    var body: some View {
        VStack(spacing: 0) {
            settingsTopBar

            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    infoSection
                    aboutSection
                    Spacer().frame(height: 20)
                    saveButton
                    Spacer().frame(height: 12)
                    logoutButton
                    Spacer().frame(height: 40)
                }
                .padding(.top, 24)
            }
        }
        .background(Color(hex: 0xF4F4F4))
        .navigationBarHidden(true)
        .onAppear {
            editingName = displayName
            editingBio = bio
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            Task { await uploadAvatar(item) }
        }
    }

    // MARK: - Top Bar

    private var settingsTopBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(.wikiSecondary)
            }
            Spacer()
            Text("设置")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.wikiText)
            Spacer()
            Color.clear.frame(width: 40)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.wikiBg)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(.wikiDivider),
            alignment: .bottom
        )
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if isUploading {
                        Circle().fill(Color.wikiBgSecondary)
                            .frame(width: 88, height: 88)
                            .overlay(ProgressView())
                    } else {
                        AsyncImage(url: Secrets.avatarURL(for: myId)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Circle().fill(Color.wikiBgSecondary)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.wikiTertiary)
                                    )
                            }
                        }
                        .id(avatarRefreshId)
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                    }

                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.wikiBlue)
                        .background(Circle().fill(Color.wikiBg).frame(width: 24, height: 24))
                }
            }

            Text("点击更换头像")
                .font(.system(size: 12))
                .foregroundColor(.wikiTertiary)
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false; selectedPhoto = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let jpegData: Data
        if let uiImage = UIImage(data: data), let compressed = uiImage.jpegData(compressionQuality: 0.85) {
            jpegData = compressed
        } else {
            jpegData = data
        }

        do {
            _ = try await SupabaseService.shared.uploadImage(jpegData, fileName: "../avatars/\(myId).jpg")
            await MainActor.run { avatarRefreshId = UUID() }
        } catch {
            print("[Settings] avatar upload failed: \(error)")
        }
    }

    // MARK: - Info Card

    private var infoSection: some View {
        VStack(spacing: 0) {
            settingsField(label: "昵称", placeholder: "你的昵称", text: $editingName, field: .name)

            Rectangle()
                .fill(Color.wikiDivider)
                .frame(height: 0.5)
                .padding(.leading, 76)

            settingsField(label: "签名", placeholder: "一句话介绍自己", text: $editingBio, field: .bio, isMultiline: true)
        }
        .background(Color.wikiBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func settingsField(label: String, placeholder: String, text: Binding<String>, field: Field, isMultiline: Bool = false) -> some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.wikiSecondary)
                .frame(width: 52, alignment: .leading)

            if isMultiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 15))
                    .focused($focusedField, equals: field)
                    .lineLimit(1...4)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 15))
                    .focused($focusedField, equals: field)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - About Card

    private var aboutSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("版本")
                    .font(.system(size: 15))
                    .foregroundColor(.wikiText)
                Spacer()
                Text("1.0.0 beta")
                    .font(.system(size: 15))
                    .foregroundColor(.wikiTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.wikiBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            AuthService.shared.logout()
            dismiss()
        } label: {
            Text("退出登录")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.wikiBg)
                )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            displayName = editingName.trimmingCharacters(in: .whitespaces).isEmpty
                ? "我" : editingName.trimmingCharacters(in: .whitespaces)
            bio = editingBio.trimmingCharacters(in: .whitespaces).isEmpty
                ? "用百科的方式，记录我的人生" : editingBio.trimmingCharacters(in: .whitespaces)
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(Color.wikiBlue))
        }
        .padding(.horizontal, 16)
    }
}
