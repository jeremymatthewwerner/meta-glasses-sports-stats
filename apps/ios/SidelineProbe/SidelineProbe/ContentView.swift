import MWDATMockDevice
import SidelineCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(WearablesModel.self) private var wearables
    @Environment(ProbeRunner.self) private var runner

    @State private var config = ProbeRunConfig(label: "", resolution: .medium, frameRate: 15, codec: .hevc, recordToFile: true)
    @State private var showLive = false
    @State private var mockModel: GlassesModel = .rayBanMeta
    @State private var pickingMockVideo = false

    var body: some View {
        @Bindable var wearables = wearables
        NavigationStack {
            Form {
                Section("Meta AI") {
                    LabeledContent("Registration", value: wearables.registrationLabel)
                    if wearables.registration == .registered {
                        Button("Unregister", role: .destructive) { wearables.unregister() }
                    } else {
                        Button("Register with Meta AI") { wearables.register() }
                            .disabled(wearables.registration == .registering)
                    }
                    LabeledContent("Glasses camera permission", value: wearables.cameraPermission)
                    if wearables.registration != .registered {
                        Text("Register first; camera permission is granted per registered app in Meta AI.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if wearables.cameraPermission != "granted" {
                        Button {
                            wearables.requestCameraPermission()
                        } label: {
                            Label("Request camera permission", systemImage: "camera")
                        }
                    }
                    Button("Re-check permission") { wearables.checkCameraPermission() }
                }
                .onChange(of: wearables.registration) { _, state in
                    if state == .registered { wearables.checkCameraPermission(quiet: true) }
                }

                Section {
                    if wearables.glasses.isEmpty {
                        Text("No glasses yet. Turn them on, open the hinges, and make sure Developer Mode is on in the Meta AI app.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker("Glasses", selection: $wearables.selectedID) {
                        ForEach(wearables.glasses) { g in
                            Text(g.name).tag(Optional(g.id))
                        }
                    }
                    if let g = wearables.selectedGlasses {
                        LabeledContent("Type", value: g.type)
                        LabeledContent("Compatibility", value: g.compatibility)
                        LabeledContent("Link", value: g.link)
                        LabeledContent("Battery", value: g.battery.map { "\($0)%" } ?? "–")
                        LabeledContent("Thermal", value: g.thermal)
                        LabeledContent("Has display", value: g.supportsDisplay ? "yes" : "no")
                    }
                } header: {
                    Text("Glasses")
                } footer: {
                    Text("Gen 3 may report its Type as Ray-Ban Meta or Ray-Ban Meta Optics. Note which, and whether a stream starts.")
                }

                Section("Run") {
                    TextField("Label (e.g. gen3-15fps-medium)", text: $config.label)
                        .textInputAutocapitalization(.never)
                    Picker("Resolution", selection: $config.resolution) {
                        ForEach(ProbeRunConfig.Resolution.allCases, id: \.self) { r in
                            Text("\(r.rawValue) \(r.size.width)×\(r.size.height)").tag(r)
                        }
                    }
                    Picker("Frame rate", selection: $config.frameRate) {
                        ForEach(ProbeRunConfig.validFrameRates, id: \.self) { Text("\($0) fps").tag($0) }
                    }
                    Picker("Codec", selection: $config.codec) {
                        Text("HEVC (records to file)").tag(ProbeRunConfig.Codec.hevc)
                        Text("Raw (live preview)").tag(ProbeRunConfig.Codec.raw)
                    }
                    if config.codec == .hevc {
                        Toggle("Save video.mov", isOn: $config.recordToFile)
                    }
                    Button {
                        guard let id = wearables.selectedID else { return }
                        if config.label.isEmpty { config.label = defaultLabel }
                        showLive = true
                        Task { await runner.start(config: config, deviceID: id) }
                    } label: {
                        Label("Start endurance run", systemImage: "record.circle")
                    }
                    .disabled(wearables.selectedID == nil || runner.isRunning)
                    if runner.isRunning {
                        Button("Return to live run") { showLive = true }
                    }
                }

                Section {
                    Picker("Model", selection: $mockModel) {
                        ForEach(GlassesModel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Button("Pair mock (sample field video)") {
                        wearables.enableMock(model: mockModel, feedURL: Bundle.main.url(forResource: "mock-feed", withExtension: "mp4"))
                    }
                    Button("Pair mock (phone back camera)") { wearables.enableMock(model: mockModel, feedURL: nil) }
                    Button("Pair mock (video file)…") { pickingMockVideo = true }
                    if wearables.mockEnabled {
                        Button("Disable mock devices", role: .destructive) { wearables.disableMock() }
                    }
                } header: {
                    Text("Mock glasses (no hardware)")
                } footer: {
                    Text("For trying the app in the simulator or without glasses. Mock runs don't measure real battery or thermal behavior.")
                }

                Section {
                    NavigationLink("Past runs") { RunsView() }
                }
            }
            .navigationTitle("Sideline Probe")
            .navigationDestination(isPresented: $showLive) { LiveRunView() }
            .fileImporter(isPresented: $pickingMockVideo, allowedContentTypes: [.movie]) { result in
                guard case .success(let url) = result, let local = copyToTemp(url) else { return }
                wearables.enableMock(model: mockModel, feedURL: local)
            }
            .alert("Error", isPresented: .constant(wearables.lastError != nil)) {
                Button("OK") { wearables.clearError() }
            } message: {
                Text(wearables.lastError ?? "")
            }
        }
    }

    private var defaultLabel: String {
        let type = wearables.selectedGlasses?.type ?? "glasses"
        return "\(type)-\(config.frameRate)fps-\(config.resolution.rawValue)-\(config.codec.rawValue)"
    }

    /// Security-scoped picker URLs don't outlive the callback; copy first.
    private func copyToTemp(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
