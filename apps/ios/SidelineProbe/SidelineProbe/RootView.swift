import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScorebookView()
                .tabItem { Label("Scorebook", systemImage: "list.clipboard") }
            GalleryView()
                .tabItem { Label("Gallery", systemImage: "square.grid.2x2") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            ContentView()
                .tabItem { Label("Glasses probe", systemImage: "eyeglasses") }
        }
    }
}
