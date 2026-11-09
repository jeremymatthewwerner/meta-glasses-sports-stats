import MWDATMockDevice
import SidelineCore
import SwiftUI

/// Soccer scorebook: scoreboard with the match minute, a period button,
/// quick taps, voice/typed calls, and the event log.
struct SoccerScorebookView: View {
    @Environment(SoccerScorebookModel.self) private var model
    @Environment(WearablesModel.self) private var wearables
    @AppStorage("sport") private var sport = Sport.football
    @State private var typed = ""
    @State private var mockSay = "goal 9, assist 7"
    @State private var sheet: Sheet?
    @FocusState private var typing: Bool

    @State private var playing: PlayingClip?

    enum Sheet: String, Identifiable {
        case newGame, box, summary, help, rosters, videos
        var id: String { rawValue }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                SoccerScoreboard(game: model.game)
                    .padding(.horizontal)
                    .padding(.top, 4)
                lensBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                quickBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                inputArea
                    .padding()
                List {
                    if let p = model.lastParse, p.isEmpty, p.command == nil {
                        Section {
                            Label("Didn't catch a call in “\(p.raw)”", systemImage: "questionmark.circle")
                                .foregroundStyle(.orange)
                            if let note = p.notes.first { Text(note).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Section("Events (newest first)") {
                        if model.game.events.isEmpty {
                            Text("Tap Kickoff, then call what happens: “goal 9, assist 7”, “shot 10 saved”, “corner them”.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.game.events.reversed()) { e in
                            SoccerEventRow(game: model.game, event: e, glassesReady: e.videoRefs.first.map(model.clipIsReady) ?? false,
                                           camera: model.cameraClip(at: e.wallTime)) { ref in
                                playing = PlayingClip(url: model.videoURL(ref), ref: ref, title: model.game.summary(e))
                            }
                                .swipeActions(edge: .leading) {
                                    Button { model.confirm(e.id) } label: { Label("Confirm", systemImage: "checkmark") }
                                        .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { model.reject(e.id) } label: { Label("Reject", systemImage: "xmark") }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Soccer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Switch to football", systemImage: "football") {
                            model.releaseLens()
                            sport = .football
                        }
                        Divider()
                        Button("New game…") { sheet = .newGame }
                        Button("Rosters…") { sheet = .rosters }
                        Button("Game videos…") { sheet = .videos }
                        Button("Game summary") { sheet = .summary }
                        Button(model.game.isOver ? "Reopen game" : "End game") { model.setEnded(!model.game.isOver) }
                        Button("Confirm all proposed") { model.confirmAll() }
                        Toggle("Auto-confirm confident calls", isOn: $model.autoConfirm)
                        Picker("Calls with no team mean", selection: Binding(get: { model.game.focus }, set: { model.setFocus($0) })) {
                            Text(model.game.home.name).tag(TeamSide.home)
                            Text(model.game.away.name).tag(TeamSide.away)
                        }
                        ShareLink("Share game file", item: model.gameFile)
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.undoLast() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndo)
                        .accessibilityLabel("Undo last event")
                    Button { model.redoLast() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(model.redoTarget == nil)
                        .accessibilityLabel("Redo")
                    Button { sheet = .help } label: { Image(systemName: "questionmark.circle") }
                    Button("Stats") { sheet = .box }
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .newGame: SoccerNewGameView()
                case .box: SoccerBoxScoreView(game: model.game)
                case .summary: SoccerSummaryView(game: model.game)
                case .help: SoccerHelpView()
                case .rosters: SoccerRosterView()
                case .videos: GameVideosView(host: model)
                }
            }
            .sheet(item: $playing) { ClipPlayerView(clip: $0) }
            .task {
                // The lens shows the match minute; refresh it as the minute turns.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    model.tickLens()
                }
            }
        }
    }

    // MARK: Lens

    @ViewBuilder private var lensBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "eyeglasses")
                Text("Lens: \(model.hud.statusText)")
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button(model.hud.isActive ? "Disconnect" : "Connect glasses") {
                    let pick = wearables.glasses.first(where: \.supportsDisplay) ?? wearables.glasses.first
                    model.toggleHUD(deviceID: pick?.id)
                }
                .font(.footnote.bold())
                .disabled(model.hud.status == .connecting)
            }
            if model.drivesLens, model.hud.isOn {
                HStack {
                    Button {
                        model.toggleRecording()
                    } label: {
                        Label(model.isRecording ? "Stop video" : "Record match video",
                              systemImage: model.isRecording ? "stop.circle.fill" : "record.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(model.isRecording ? .red : .accentColor)
                    .font(.footnote.bold())
                    .accessibilityIdentifier("soccerRecordButton")
                    if let r = model.hud.recording {
                        Text("● \(ScorebookView.clock(r.seconds)) · \(String(format: "%.0f", r.fps)) fps · \(r.frames) frames")
                            .font(.caption.monospacedDigit()).foregroundStyle(.red)
                    } else if !model.recording.segments.isEmpty {
                        Text("\(model.recording.segments.count) video file(s) for this match")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let err = model.hud.recording?.error ?? model.recordingError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }
            if model.hud.isActive, wearables.mockModel == .metaRayBanDisplay, let mock = wearables.mockGlasses {
                MockLensPreview(glasses: mock)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    TextField("Mock: say a call into the glasses", text: $mockSay)
                        .textFieldStyle(.roundedBorder).font(.caption)
                    Button("Say") {
                        mock.services.speech.simulateTranscription(text: mockSay, isFinal: true, confidence: 0.9)
                    }
                    .font(.caption).disabled(mockSay.isEmpty)
                }
            }
        }
    }

    // MARK: Quick taps

    private var quickBar: some View {
        let us = model.game.focus, them = model.game.focus.opponent
        func name(_ s: TeamSide) -> String { model.game.team(s).shortName }
        return VStack(spacing: 6) {
            if let next = model.nextPeriodAction {
                Button {
                    model.advancePeriod()
                } label: {
                    Label(next.label, systemImage: next.action.kind == .periodStart ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("periodButton")
            }
            HStack(spacing: 6) {
                quick("Goal \(name(us))", .goal, us)
                quick("Shot \(name(us))", .shot, us)
                quick("Corner \(name(us))", .corner, us)
            }
            HStack(spacing: 6) {
                quick("Goal \(name(them))", .goal, them)
                quick("Shot \(name(them))", .shot, them)
                quick("Corner \(name(them))", .corner, them)
            }
        }
        .font(.footnote.bold())
    }

    private func quick(_ label: String, _ kind: SoccerAction.Kind, _ side: TeamSide) -> some View {
        Button {
            model.quick(SoccerAction(kind: kind, team: side))
        } label: {
            Text(label).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(side == model.game.focus ? .accentColor : .orange)
    }

    // MARK: Calls

    private var inputArea: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("Type a call, e.g. goal 9 assist 7", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .accessibilityIdentifier("soccerInput")
                Button {
                    model.toggleListening()
                } label: {
                    Image(systemName: model.speech.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(model.speech.isListening ? .red : .accentColor)
                }
                .accessibilityLabel(model.speech.isListening ? "Stop listening" : "Call by voice")
            }
            if model.speech.isListening {
                Text(model.speech.partial.isEmpty ? "Listening…" : model.speech.partial)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            } else if let p = model.lastParse, !p.notes.isEmpty, !p.isEmpty {
                Text(p.notes.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func send() {
        model.submit(typed, source: .typed)
        typed = ""
        typing = true          // keep the keyboard up for the next call
    }
}

// MARK: - Pieces

struct SoccerScoreboard: View {
    let game: SoccerGame

    var body: some View {
        let s = game.state
        VStack(spacing: 4) {
            HStack {
                team(.home, s)
                Spacer()
                VStack(spacing: 2) {
                    TimelineView(.periodic(from: .now, by: 10)) { ctx in
                        Text(clock(s, now: ctx.date)).font(.caption.bold().monospacedDigit())
                    }
                    Text(game.format.label).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                team(.away, s)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func clock(_ s: SoccerGameState, now: Date) -> String {
        if game.isOver { return "FULL TIME" }
        if s.period == 0 { return "Kickoff soon" }
        if let m = game.currentMinute(at: now) { return "\(game.format.periodName(s.period)) · \(m)′" }
        return game.format.periods == 2 && s.period == 1 ? "HALF TIME" : "After \(game.format.periodName(s.period))"
    }

    private func team(_ side: TeamSide, _ s: SoccerGameState) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if game.focus == side { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
                Text(game.team(side).name).font(.caption).lineLimit(1)
            }
            Text("\(s.goals(side))").font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            if let off = s.sentOff[side], !off.isEmpty {
                Text("🟥 " + off.sorted().map { "#\($0)" }.joined(separator: " ")).font(.caption2)
            }
        }
        .frame(minWidth: 90)
    }
}

struct SoccerEventRow: View {
    let game: SoccerGame
    let event: SoccerEvent
    /// The glasses clip (event.videoRefs) has finished recording.
    var glassesReady = false
    /// Clip from an imported camera video, when one covers this moment.
    var camera: VideoRef? = nil
    var onPlay: (VideoRef) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                icon
                if let m = game.minute(of: event) {
                    Text("\(m)′").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(game.summary(event))
                    .strikethrough(event.status == .rejected)
                    .foregroundStyle(event.status == .rejected ? .secondary : .primary)
                    .fontWeight(event.action.kind == .goal ? .semibold : .regular)
            }
            if let t = event.transcript {
                Text("“\(t)”").font(.caption).foregroundStyle(.secondary)
            }
            if event.confidence < 0.9, event.status == .proposed {
                Text("confidence \(Int(event.confidence * 100))% · swipe right to confirm, left to reject")
                    .font(.caption2).foregroundStyle(.orange)
            }
            HStack(spacing: 14) {
                if let ref = event.videoRefs.first {
                    if glassesReady {
                        Button {
                            onPlay(ref)
                        } label: {
                            Label("Glasses \(ScorebookView.clock(ref.start))–\(ScorebookView.clock(ref.end))", systemImage: "eyeglasses")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Label("Glasses clip ready when video stops", systemImage: "film")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let camera {
                    Button {
                        onPlay(camera)
                    } label: {
                        Label("Camera \(ScorebookView.clock(camera.start))–\(ScorebookView.clock(camera.end))", systemImage: "video")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder private var icon: some View {
        switch event.status {
        case .confirmed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .proposed: Image(systemName: "circle.dashed").foregroundStyle(.orange)
        case .rejected: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        }
    }
}

struct SoccerNewGameView: View {
    @Environment(SoccerScorebookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var home = ""
    @State private var away = ""
    @State private var format = SoccerFormat.nineASide
    @State private var focus: TeamSide = .home

    var body: some View {
        NavigationStack {
            Form {
                TextField("Home team", text: $home)
                TextField("Away team", text: $away)
                Picker("Format", selection: $format) {
                    ForEach(SoccerFormat.presets, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("My team", selection: $focus) {
                    Text(home.isEmpty ? "Home" : home).tag(TeamSide.home)
                    Text(away.isEmpty ? "Away" : away).tag(TeamSide.away)
                }
                Section {
                } footer: {
                    Text("Calls that name no team (“goal 9”) count for your team; say “they” or the other team's name for theirs.")
                }
            }
            .navigationTitle("New soccer game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        model.newGame(home: home, away: away, format: format, focus: focus)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SoccerBoxScoreView: View {
    let game: SoccerGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let box = game.boxScore()
        NavigationStack {
            List {
                Section("Team") {
                    row("", game.home.shortName, game.away.shortName, bold: true)
                    let h = box.team(.home), a = box.team(.away)
                    row("Goals", h.goals, a.goals)
                    row("Shots", h.shots, a.shots)
                    row("On target", h.shotsOnTarget, a.shotsOnTarget)
                    row("Saves", h.saves, a.saves)
                    row("Corners", h.corners, a.corners)
                    row("Fouls", h.fouls, a.fouls)
                    row("Offsides", h.offsides, a.offsides)
                    row("Yellow / red", "\(h.yellowCards) / \(h.redCards)", "\(a.yellowCards) / \(a.redCards)")
                }
                ForEach([TeamSide.home, .away], id: \.self) { side in
                    Section(game.team(side).name) {
                        let players = box.roster(side)
                        if players.isEmpty { Text("No player stats yet").foregroundStyle(.secondary) }
                        ForEach(players, id: \.0) { key, st in
                            LabeledContent(game.displayName(side, key.jersey), value: st.line)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func row(_ label: String, _ h: some CustomStringConvertible, _ a: some CustomStringConvertible, bold: Bool = false) -> some View {
        HStack {
            Text(label).frame(maxWidth: .infinity, alignment: .leading)
            Text(h.description).frame(width: 70).monospacedDigit()
            Text(a.description).frame(width: 70).monospacedDigit()
        }
        .fontWeight(bold ? .semibold : .regular)
    }
}

struct SoccerSummaryView: View {
    let game: SoccerGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SoccerGameDetail(game: game)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}

/// A game's page: recap, goals with minutes, team stats.
struct SoccerGameDetail: View {
    let game: SoccerGame

    var body: some View {
        let box = game.boxScore()
        List {
            Section { Text(game.recap()) }
            Section("Goals") {
                let goals = game.goalLog()
                if goals.isEmpty { Text("No goals").foregroundStyle(.secondary) }
                ForEach(Array(goals.enumerated()), id: \.offset) { _, line in Text(line) }
            }
            Section("Team stats (\(game.home.shortName) – \(game.away.shortName))") {
                let h = box.team(.home), a = box.team(.away)
                LabeledContent("Shots (on target)", value: "\(h.shots) (\(h.shotsOnTarget)) – \(a.shots) (\(a.shotsOnTarget))")
                LabeledContent("Corners", value: "\(h.corners) – \(a.corners)")
                LabeledContent("Fouls", value: "\(h.fouls) – \(a.fouls)")
                LabeledContent("Cards", value: "\(h.yellowCards)🟨 \(h.redCards)🟥 – \(a.yellowCards)🟨 \(a.redCards)🟥")
            }
            Section {
                ShareLink("Share recap", item: game.recap() + "\n\n" + game.goalLog().joined(separator: "\n"))
            }
        }
        .navigationTitle("\(game.home.name) vs \(game.away.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SoccerRosterView: View {
    @Environment(SoccerScorebookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var side: TeamSide = .home
    @State private var text = ""
    @State private var problems: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Picker("Team", selection: $side) {
                    Text(model.game.home.name).tag(TeamSide.home)
                    Text(model.game.away.name).tag(TeamSide.away)
                }
                .pickerStyle(.segmented)
                Section {
                    TextEditor(text: $text).frame(minHeight: 180).font(.body.monospaced())
                } header: {
                    Text("One player per line")
                } footer: {
                    Text("“9, Ava Lee” or “#9 Ava Lee”. Names then appear in events and stats.")
                }
                ForEach(problems, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
            }
            .navigationTitle("Rosters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { problems = model.setRoster(side, text: text); if problems.isEmpty { dismiss() } }
                }
            }
            .onAppear { load() }
            .onChange(of: side) { load() }
        }
    }

    private func load() { text = model.game.team(side).roster?.csv ?? ""; problems = [] }
}

struct SoccerHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let examples: [(String, [String])] = [
        ("Goals", ["goal 9, assist 7", "7 to 9, goal", "penalty goal 10", "header goal 5 from 11", "they scored, 14", "own goal by their 4"]),
        ("Shots & saves", ["shot 10 saved by 1", "9 shoots wide", "shot blocked", "off the post, 8", "great save 1"]),
        ("Set pieces & fouls", ["corner us", "corner Hawks", "foul by 14 on 6", "free kick for us", "offside 9"]),
        ("Cards & subs", ["yellow card 4 away", "red card their 5", "second yellow 5", "12 on for 7", "sub 12 for 7"]),
        ("Clock", ["kickoff", "half time", "start of the second half", "full time"]),
        ("Fixes", ["undo / scratch that", "redo"]),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("A call with no team counts for your team (★). Say “they”, “them”, “away”, “home” or a team's name for the other side.")
                        .font(.footnote)
                }
                ForEach(examples, id: \.0) { title, lines in
                    Section(title) { ForEach(lines, id: \.self) { Text("“\($0)”") } }
                }
            }
            .navigationTitle("What to say")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
