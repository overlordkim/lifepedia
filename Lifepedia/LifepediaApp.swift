//
//  LifepediaApp.swift
//  Lifepedia
//
//  Created by kashorin on 2026/4/7.
//

import SwiftUI
import SwiftData

@main
struct LifepediaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Entry.self)
    }
}
