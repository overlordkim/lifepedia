import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.18)

                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.wikiText)

                        Text("人间词条")
                            .font(.custom("Baskerville-Bold", size: 32))
                            .foregroundColor(.wikiText)

                        Text("Lifepedia")
                            .font(.custom("Baskerville-Italic", size: 16))
                            .foregroundColor(.wikiTertiary)
                    }
                    .padding(.bottom, 48)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("用户名")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.wikiSecondary)
                            TextField("输入用户名", text: $username)
                                .font(.system(size: 16))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.wikiBgSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.wikiBorder, lineWidth: 0.5)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.wikiSecondary)
                            SecureField("输入密码", text: $password)
                                .font(.system(size: 16))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.wikiBgSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.wikiBorder, lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 32)
                    .offset(x: shakeOffset)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }

                    Button {
                        performLogin()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("登录")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canLogin ? Color.wikiBlue : Color.wikiTertiary.opacity(0.4))
                        )
                    }
                    .disabled(!canLogin || isLoading)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.wikiBg.ignoresSafeArea())
    }

    private var canLogin: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func performLogin() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await AuthService.shared.login(
                    username: username.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                        shakeOffset = 8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        shakeOffset = 0
                    }
                }
            }
        }
    }
}
