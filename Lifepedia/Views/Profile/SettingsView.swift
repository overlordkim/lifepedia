import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("user_display_name") private var displayName = "我"
    @AppStorage("user_bio") private var bio = "用百科的方式，记录我的人生"
    @AppStorage("user_avatar_seed") private var avatarSeed = 32

    @State private var editingName = ""
    @State private var editingBio = ""
    @State private var showAvatarPicker = false
    @FocusState private var focusedField: Field?

    enum Field { case name, bio }

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
        .overlay {
            if showAvatarPicker {
                avatarPickerOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showAvatarPicker)
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
            Button { showAvatarPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: "https://i.pravatar.cc/200?img=\(avatarSeed)")) { phase in
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
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())

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

    // MARK: - Avatar Picker Overlay

    private var avatarPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { showAvatarPicker = false }

            VStack(spacing: 0) {
                HStack {
                    Text("选择头像")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.wikiText)
                    Spacer()
                    Button { showAvatarPicker = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.wikiTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                        ForEach(1..<71, id: \.self) { seed in
                            Button {
                                avatarSeed = seed
                                showAvatarPicker = false
                            } label: {
                                AsyncImage(url: URL(string: "https://i.pravatar.cc/120?img=\(seed)")) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Circle().fill(Color.wikiBgSecondary)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(seed == avatarSeed ? Color.wikiBlue : Color.clear, lineWidth: 3)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxHeight: 460)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.wikiBg)
            )
            .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
            .padding(.horizontal, 24)
        }
    }
}
