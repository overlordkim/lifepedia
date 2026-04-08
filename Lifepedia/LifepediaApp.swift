import SwiftUI
import SwiftData

@main
struct LifepediaApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Entry.self)
        } catch {
            // schema 不兼容时，删除 Application Support 下所有 .store 文件后重试
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let fm = FileManager.default
                if let files = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in files where file.lastPathComponent.contains(".store") {
                        try? fm.removeItem(at: file)
                    }
                }
            }
            do {
                container = try ModelContainer(for: Entry.self)
            } catch {
                fatalError("ModelContainer creation failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}

struct RootView: View {
    @State private var auth = AuthService.shared

    var body: some View {
        Group {
            if auth.isLoggedIn {
                ContentView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isLoggedIn)
        .task {
            if auth.isLoggedIn {
                await FollowService.shared.syncFromRemote()
            }
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn {
                Task { await FollowService.shared.syncFromRemote() }
            }
        }
    }
}
