import AVKit
import MWDATMockDevice
import SidelineCore
import SwiftUI

struct ScorebookView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(WearablesModel.self) private var wearables
    @State private var typed = ""
    @State private var playingClip: PlayingClip?
    @State private var mockSay = "22 run for 7, tackle by 54"
    @State private var showBox = false
    @State private var showNewGame = false
    @State private var showHelp = false
    @State private var showRosters = false
    @State private var importingCV = false
    @State private var showSummary = false
    @FocusState private var typing: Bool

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                Scoreboard(game: model.game, state: model.state)
                    .padding(.horizontal)
                    .padding(.top, 4)

                hudBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                PlayClockBar()
                    .padding(.horizontal)
                    .padding(.top, 6)

                inputArea
                    .padding()

                List {
                    if let parse = model.lastParse, parse.isEmpty, parse.command == nil {
                        Section {
                            Label("Didn't catch a play in “\(parse.raw)”", systemImage: "questionmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                    Section("Plays (newest first)") {
                        if model.game.events.isEmpty {
                            Text("Tap the mic and call a play, e.g. “22 run for 7, tackle by 54”.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.game.events.reversed()) { event in
                            EventRow(event: event, clipReady: event.videoRefs.first.map(model.clipIsReady) ?? false) { ref in
                                playingClip = PlayingClip(url: model.clipURL(ref), ref: ref, title: event.summary)
                            }
                                .swipeActions(edge: .leading) {
                                    Button { model.confirm(event.id) } label: { Label("Confirm", systemImage: "checkmark") }
                                        .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { model.reject(event.id) } label: { Label("Reject", systemImage: "xmark") }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Scorebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New game…") { showNewGame = true }
                        Button("Rosters…") { showRosters = true }
                        Button("Import CV results…") { importingCV = true }
                        Button("Game summary") { showSummary = true }
                        Button(model.game.isOver ? "Reopen game" : "End game") { model.setEnded(!model.game.isOver) }
                        Button("Confirm all proposed") { model.confirmAll() }
                        Toggle("Auto-confirm confident plays", isOn: $model.autoConfirm)
                        Picker("Stat rules", selection: Binding(get: { model.game.ruleSet }, set: { model.setRuleSet($0) })) {
                            ForEach(FootballRuleSet.all, id: \.self) { Text($0.name).tag($0) }
                        }
                        ShareLink("Share game files", items: [model.gameFile, model.utterancesFile])
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.undoLast() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndo)
                        .accessibilityLabel("Undo last play")
                    Button { model.redoLast() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(model.redoTarget == nil)
                        .accessibilityLabel("Redo")
                    Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                    Button("Box score") { showBox = true }
                }
            }
            .sheet(isPresented: $showBox) { BoxScoreView(game: model.game) }
            .sheet(isPresented: $showNewGame) { NewGameView() }
            .sheet(isPresented: $showHelp) { PhraseHelpView() }
            .sheet(item: $playingClip) { ClipPlayerView(clip: $0) }
            .sheet(isPresented: $showRosters) { RosterEditorView() }
            .sheet(isPresented: $showSummary) {
                NavigationStack {
                    GameSummaryView(game: model.game)
                        .toolbar { Button("Done") { showSummary = false } }
                }
            }
            .fileImporter(isPresented: $importingCV, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { model.importCV(from: url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                model.importDroppedCVReport()
            }
        }
    }

    /// Show the scorebook on the Display lens; in mock mode, preview it here.
    @ViewBuilder private var hudBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "eyeglasses")
                Text("Lens: \(model.hud.statusText)")
                    .font(.footnote)
                    .foregroundStyle(hudFailed ? .red : .secondary)
                    .lineLimit(2)
                Spacer()
                Button(model.hud.isActive ? "Disconnect" : "Connect glasses") {
                    // Prefer a pair with a display (lens HUD); any pair can record and listen.
                    let pick = wearables.glasses.first(where: \.supportsDisplay) ?? wearables.glasses.first
                    model.toggleHUD(deviceID: pick?.id)
                }
                    .font(.footnote.bold())
                    .disabled(model.hud.status == .connecting)
            }
            if model.hud.isOn {
                HStack {
                    Button {
                        model.toggleRecording()
                    } label: {
                        Label(model.hud.isRecording ? "Stop video" : "Record game video",
                              systemImage: model.hud.isRecording ? "stop.circle.fill" : "record.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(model.hud.isRecording ? .red : .accentColor)
                    .font(.footnote.bold())
                    .accessibilityIdentifier("recordButton")
                    if let r = model.hud.recording {
                        Text("● \(Self.clock(r.seconds)) · \(String(format: "%.0f", r.fps)) fps · \(r.frames) frames")
                            .font(.caption.monospacedDigit()).foregroundStyle(.red)
                    } else if !model.recording.segments.isEmpty {
                        Text("\(model.recording.segments.count) video file(s) for this game")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let err = model.hud.recording?.error ?? model.recordingError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }
            if model.hud.isActive {
                Text(model.hud.glassesMicText).font(.caption2).foregroundStyle(.secondary)
            }
            if model.hud.isActive, wearables.mockModel == .metaRayBanDisplay, let mock = wearables.mockGlasses {
                MockLensPreview(glasses: mock)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("mockLensPreview")
                Text("Mock lens: tap a button once to focus it, again to press it (like the Neural Band).")
                    .font(.caption2).foregroundStyle(.secondary)
                // Mock glasses mic: feeds MockSpeechKit as if the wearer spoke.
                HStack {
                    TextField("Mock: say a play into the glasses", text: $mockSay)
                        .textFieldStyle(.roundedBorder).font(.caption)
                        .accessibilityIdentifier("mockSay")
                    Button("Say") {
                        let words = mockSay.split(separator: " ")
                        for i in 1..<max(words.count, 1) {
                            mock.services.speech.simulateTranscription(
                                text: words.prefix(i).joined(separator: " "), isFinal: false, confidence: 0.8)
                        }
                        mock.services.speech.simulateTranscription(text: mockSay, isFinal: true, confidence: 0.9)
                    }
                    .font(.caption).disabled(mockSay.isEmpty)
                }
            }
        }
    }

    static func clock(_ s: TimeInterval) -> String {
        let t = Int(s.rounded(.down))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%d:%02d", t / 60, t % 60)
    }

    private var hudFailed: Bool {
        if case .failed = model.hud.status { true } else { false }
    }

    private var inputArea: some View {
        VStack(spacing: 10) {
            Button {
                typing = false
                model.toggleListening()
            } label: {
                HStack {
                    Image(systemName: model.speech.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 34))
                    Text(model.speech.isStarting ? "Starting microphone…" : model.speech.isListening ? "Listening… tap when done" : "Tap and call the play")
                        .font(.headline)
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(model.speech.isListening ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.speech.isListening ? .red : .accentColor)

            if model.speech.isListening || !model.speech.partial.isEmpty {
                Text(model.speech.partial.isEmpty ? "…" : model.speech.partial)
                    .font(.callout.italic())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = model.speech.error {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
            if let cv = model.cvStatus {
                Label(cv, systemImage: "eye")
                    .font(.footnote).foregroundStyle(cv.contains("failed") ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !model.lastNotes.isEmpty {
                Text("Assumed: " + model.lastNotes.joined(separator: "; "))
                    .font(.footnote).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                TextField("…or type a play", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityIdentifier("playInput")
                Button("Add", action: send).disabled(typed.isEmpty)
            }
        }
    }

    private func send() {
        model.submit(typed, source: .typed)
        typed = ""
        typing = true   // keep the keyboard up for rapid entry
    }
}

struct Scoreboard: View {
    let game: FootballGame
    let state: FootballGameState

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                team(.away)
                Spacer()
                VStack {
                    Text(game.isOver ? "FINAL" : state.quarter >= 5 ? "OT" : "Q\(state.quarter)").font(.caption.bold())
                    Text(game.ruleSet.name).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                team(.home)
            }
            Text(state.situationText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func team(_ side: TeamSide) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if state.possession == side { Image(systemName: "football.fill").font(.caption) }
                if let hex = game.team(side).jerseyColor, let color = Color(hex: hex) {
                    Circle().fill(color).overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                        .frame(width: 10, height: 10)
                        .accessibilityLabel("jersey color")
                }
                Text(game.team(side).name).font(.caption).lineLimit(1)
            }
            Text("\(state.points(side))").font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        }
        .frame(minWidth: 90)
    }
}

struct EventRow: View {
    let event: FootballEvent
    var clipReady = false
    var onPlayClip: (VideoRef) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                statusIcon
                Text(event.summary.isEmpty ? "(empty)" : event.summary)
                    .strikethrough(event.status == .rejected)
                    .foregroundStyle(event.status == .rejected ? .secondary : .primary)
            }
            if let t = event.transcript {
                Text("“\(t)”").font(.caption).foregroundStyle(.secondary)
            }
            if event.confidence < 0.9, event.status == .proposed {
                Text("confidence \(Int(event.confidence * 100))% · swipe right to confirm, left to reject")
                    .font(.caption2).foregroundStyle(.orange)
            }
            if let cv = event.cv {
                let text = cv.summary.isEmpty ? "CV: no called players to check" : "CV: " + cv.summary
                Label(text + (cv.trimmed ? " · clip trimmed to the play" : ""), systemImage: "eye")
                    .font(.caption2)
                    .foregroundStyle(cv.seen.contains(where: \.teamConflict) ? .orange : .secondary)
            }
            if let ref = event.videoRefs.first {
                if clipReady {
                    Button {
                        onPlayClip(ref)
                    } label: {
                        Label("Clip \(ScorebookView.clock(ref.start))–\(ScorebookView.clock(ref.end))", systemImage: "play.rectangle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Label("Clip \(ScorebookView.clock(ref.start))–\(ScorebookView.clock(ref.end)) · ready when video stops",
                          systemImage: "film").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch event.status {
        case .confirmed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .proposed: Image(systemName: "circle.dashed").foregroundStyle(.orange)
        case .rejected: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }
}

struct NewGameView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var home = ""
    @State private var away = ""
    @State private var kickoff: TeamSide = .away
    @State private var rules: FootballRuleSet = .nfhs

    var body: some View {
        NavigationStack {
            Form {
                TextField("Home team", text: $home)
                TextField("Away team", text: $away)
                Picker("Opening kickoff by", selection: $kickoff) {
                    Text("Home").tag(TeamSide.home)
                    Text("Away").tag(TeamSide.away)
                }
                Picker("Stat rules", selection: $rules) {
                    ForEach(FootballRuleSet.all, id: \.self) { Text($0.name).tag($0) }
                }
            }
            .navigationTitle("New game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        model.newGame(home: home, away: away, openingKickoff: kickoff, ruleSet: rules)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PhraseHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let examples: [(String, [String])] = [
        ("Runs", ["22 run for 7, tackle by 54", "22 for no gain", "5 keeper for a loss of 3, tackled by 90 and 44"]),
        ("Passes", ["11 to 80 for 15", "11 incomplete to 80", "interception by 24, returned for 30", "11 to 80 for 40, touchdown"]),
        ("Sacks & fumbles", ["sack by 90 and 55 for a loss of 8", "22 fumbles, forced by 40, recovered by 55"]),
        ("Kicks", ["kickoff by 3, returned by 22 for 25", "kickoff touchback", "punt by 4 for 38, returned by 10 for 6",
                   "field goal is good from 32", "extra point good", "two point conversion good, 11 to 80"]),
        ("Penalties", ["holding on 72, 10 yards", "false start", "22 run for 4, flag, offside defense"]),
        ("Situation", ["home ball, first and 10, ball on our 40", "third and 4", "ball on their 35", "start of the second quarter"]),
        ("Fix mistakes", ["scratch that", "undo", "redo (puts back the last undone play)"]),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Numbers are jerseys. Offense numbers belong to the team with the ball; tacklers, sackers and interceptors to the defense. If you don't say the passer, the last passer is assumed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(examples, id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1, id: \.self) { Text("“\($0)”") }
                    }
                }
            }
            .navigationTitle("What to say")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

/// Meta's local rendering of what a mock Ray-Ban Display would show.
struct MockLensPreview: UIViewRepresentable {
    let glasses: any MockGlasses

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        let preview = glasses.services.display.createPreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            preview.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            preview.heightAnchor.constraint(equalTo: container.heightAnchor),
            preview.widthAnchor.constraint(equalTo: container.heightAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct PlayingClip: Identifiable {
    let url: URL
    let ref: VideoRef
    let title: String
    var id: String { "\(url.lastPathComponent)@\(ref.start)" }
}

/// Plays one play's clip: the stretch of game video before and after the call.
struct ClipPlayerView: View {
    let clip: PlayingClip
    @Environment(\.dismiss) private var dismiss
    @State private var player = AVPlayer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VideoPlayer(player: player)
                    .aspectRatio(504.0 / 896.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("\(clip.ref.assetID) · \(ScorebookView.clock(clip.ref.start))–\(ScorebookView.clock(clip.ref.end))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button("Replay", systemImage: "arrow.counterclockwise") { play() }
            }
            .padding()
            .navigationTitle(clip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onAppear {
                player.replaceCurrentItem(with: AVPlayerItem(url: clip.url))
                play()
            }
            .onDisappear { player.pause() }
        }
    }

    private func play() {
        guard let item = player.currentItem else { return }
        item.forwardPlaybackEndTime = CMTime(seconds: clip.ref.end, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: clip.ref.start, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            Task { @MainActor in player.play() }
        }
    }
}

extension Color {
    /// "#rrggbb" → Color.
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}
