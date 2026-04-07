//
//  ContentView.swift
//  Lifepedia
//
//  Created by kashorin on 2026/4/7.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("发现")
                }
                .tag(0)
            
            EncyclopediaView()
                .tabItem {
                    Image(systemName: "book.closed")
                    Text("百科")
                }
                .tag(1)
            
            ComposeView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("编纂")
                }
                .tag(2)
            
            GraphView()
                .tabItem {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                    Text("图谱")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("我的")
                }
                .tag(4)
        }
        .tint(.wikiAccent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Entry.self, inMemory: true)
}
