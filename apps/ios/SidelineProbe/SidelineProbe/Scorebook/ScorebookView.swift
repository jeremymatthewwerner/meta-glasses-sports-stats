import MWDATMockDevice
import SidelineCore
import SwiftUI

struct ScorebookView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(WearablesModel.self) private var wearables
    @State private var typed = ""
    @State private var showBox = false
    @State private var showNewGame = false
    @State private var showHelp = false
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
                            EventRow(event: event)
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
            }
            .navigationTitle("Scorebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New game…") { showNewGame = true }
                        Button("Confirm all proposed") { model.confirmAll() }
                        Toggle("Auto-confirm confident plays", isOn: $model.autoConfirm)
                        Picker("Stat rules", selection: Binding(get: { model.game.ruleSet }, set: { model.setRuleSet($0) })) {
                            ForEach(FootballRuleSet.all, id: \.self) { Text($0.name).tag($0) }
                        }
                        ShareLink("Share game files", items: [model.gameFile, model.utterancesFile])
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                    Button("Box score") { showBox = true }
                }
            }
            .sheet(isPresented: $showBox) { BoxScoreView(game: model.game) }
            .sheet(isPresented: $showNewGame) { NewGameView() }
            .sheet(isPresented: $showHelp) { PhraseHelpView() }
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
                Button(model.hud.isActive ? "Hide" : "Show on glasses") {
                    model.toggleHUD(deviceID: wearables.glasses.first(where: \.supportsDisplay)?.id)
                }
                    .font(.footnote.bold())
                    .disabled(model.hud.status == .connecting)
            }
            if model.hud.isActive, wearables.mockModel == .metaRayBanDisplay, let mock = wearables.mockGlasses {
                MockLensPreview(glasses: mock)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("mockLensPreview")
                Text("Mock lens: tap a button once to focus it, again to press it (like the Neural Band).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
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
                    Text(state.quarter >= 5 ? "OT" : "Q\(state.quarter)").font(.caption.bold())
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
                Text(game.team(side).name).font(.caption).lineLimit(1)
            }
            Text("\(state.points(side))").font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        }
        .frame(minWidth: 90)
    }
}

struct EventRow: View {
    let event: FootballEvent

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
        ("Fix mistakes", ["scratch that", "undo"]),
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
