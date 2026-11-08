import MWDATCore
import MWDATMockDevice
import SwiftUI

@main
struct SidelineProbeApp: App {
    // Models must not touch `Wearables.shared` until `configure()` has run,
    // so they only start observing SDK state in `.task` below.
    @State private var wearables = WearablesModel()
    @State private var runner = ProbeRunner()
    @State private var scorebook = ScorebookModel()

    init() {
        do {
            try Wearables.configure()
        } catch {
            print("[SidelineProbe] Wearables.configure() failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wearables)
                .environment(runner)
                .environment(scorebook)
                .task {
                    wearables.start()
                    #if DEBUG
                    // `-mockGlasses metaRayBanDisplay` (launch argument) pairs a mock
                    // with the bundled field video, for simulator testing.
                    if let raw = UserDefaults.standard.string(forKey: "mockGlasses"),
                       let model = GlassesModel.allCases.first(where: { "\($0)" == raw || $0.rawValue == raw }) {
                        wearables.enableMock(model: model, feedURL: Bundle.main.url(forResource: "mock-feed", withExtension: "mp4"))
                    }
                    #endif
                }
                .onOpenURL { url in wearables.handle(url: url) }
        }
    }
}
