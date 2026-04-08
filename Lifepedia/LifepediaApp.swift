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
            ContentView()
                .modelContainer(container)
                .onAppear {
                    seedIfNeeded()
                }
        }
    }

    private func seedIfNeeded() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
        if count == 0 {
            MockEntries.seedAll(in: context)
            try? context.save()
            return
        }
        // 补种其他用户的词条（可能旧版本没有）
        let otherUserPred = #Predicate<Entry> { $0.authorId != "self" }
        let otherCount = (try? context.fetchCount(FetchDescriptor<Entry>(predicate: otherUserPred))) ?? 0
        if otherCount == 0 {
            MockEntries.seedOtherUsers(in: context)
            try? context.save()
        }
    }
}
