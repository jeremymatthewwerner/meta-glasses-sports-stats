import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScorebookView()
                .tabItem { Label("Scorebook", systemImage: "list.clipboard") }
            ContentView()
                .tabItem { Label("Glasses probe", systemImage: "eyeglasses") }
        }
    }
}
