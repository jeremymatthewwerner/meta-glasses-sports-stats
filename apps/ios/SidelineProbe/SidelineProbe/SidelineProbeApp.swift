import MWDATCore
import MWDATMockDevice
import SwiftUI

@main
struct SidelineProbeApp: App {
    // Models must not touch `Wearables.shared` until `configure()` has run,
    // so they only start observing SDK state in `.task` below.
    @State private var wearables = WearablesModel()
    @State private var runner = ProbeRunner()
    @State private var scorebook: ScorebookModel
    @State private var soccer: SoccerScorebookModel

    init() {
        do {
            try Wearables.configure()
        } catch {
            print("[SidelineProbe] Wearables.configure() failed: \(error)")
        }
        // Both scorebooks share the speech recognizer and the glasses lens.
        let football = ScorebookModel()
        _scorebook = State(initialValue: football)
        _soccer = State(initialValue: SoccerScorebookModel(hud: football.hud, speech: football.speech))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wearables)
                .environment(runner)
                .environment(scorebook)
                .environment(soccer)
                .task {
                    wearables.start()
                    #if DEBUG
                    // `-importVideo /path/to/game.mp4` imports a camera video into the open game (testing).
                    if let path = UserDefaults.standard.string(forKey: "importVideo") {
                        let url = URL(fileURLWithPath: path)
                        if UserDefaults.standard.string(forKey: "sport") == Sport.soccer.rawValue {
                            await soccer.importVideo(from: url)
                        } else {
                            await scorebook.importVideo(from: url)
                        }
                    }
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
