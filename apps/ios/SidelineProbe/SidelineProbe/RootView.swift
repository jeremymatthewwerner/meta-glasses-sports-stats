import SwiftUI

struct RootView: View {
    @AppStorage("sport") private var sport = Sport.football

    var body: some View {
        TabView {
            Group {
                switch sport {
                case .football: ScorebookView()
                case .soccer: SoccerScorebookView()
                }
            }
            .tabItem { Label("Scorebook", systemImage: sport == .soccer ? "soccerball" : "list.clipboard") }
            GalleryView()
                .tabItem { Label("Gallery", systemImage: "square.grid.2x2") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            ContentView()
                .tabItem { Label("Glasses probe", systemImage: "eyeglasses") }
        }
    }
}
