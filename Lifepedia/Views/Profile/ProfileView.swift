import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("个人主页")
                .foregroundColor(.wikiGray)
                .navigationTitle("我的")
        }
    }
}
