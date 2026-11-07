import MWDATCore
import SwiftUI

@main
struct SidelineProbeApp: App {
    // Models must not touch `Wearables.shared` until `configure()` has run,
    // so they only start observing SDK state in `.task` below.
    @State private var wearables = WearablesModel()
    @State private var runner = ProbeRunner()

    init() {
        do {
            try Wearables.configure()
        } catch {
            print("[SidelineProbe] Wearables.configure() failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(wearables)
                .environment(runner)
                .task { wearables.start() }
                .onOpenURL { url in wearables.handle(url: url) }
        }
    }
}
