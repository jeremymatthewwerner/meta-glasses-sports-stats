import Foundation
import MWDATCore
import Observation
import SidelineCore

/// The soccer scorebook: voice/typed calls → events → score, minute and
/// stats. Shares the speech recognizer and the glasses display with the
/// football scorebook (only one sport drives the lens at a time).
@MainActor
@Observable
final class SoccerScorebookModel {
    private(set) var game: SoccerGame
    private(set) var log: [UtteranceLogEntry] = []
    private(set) var lastParse: ParsedSoccerCall?
    /// Confirm confident calls instead of leaving them proposed.
    var autoConfirm = false
    /// Events undone this session, newest last (for Redo).
    private(set) var redoStack: [UUID] = []
    /// Every saved soccer game, newest first.
    private(set) var library: [SoccerGame] = []

    let hud: GlassesHUD
    let speech: SpeechTranscriber
    @ObservationIgnored private lazy var lensCall = LensCallController(hud: hud, phone: speech) { [weak self] text, _ in
        self?.submitFromLens(text)
    }
    /// Whether this scorebook (not football's) currently drives the lens.
    private(set) var drivesLens = false

    init(hud: GlassesHUD, speech: SpeechTranscriber) {
        self.hud = hud
        self.speech = speech
        if let saved = Self.loadLatest() {
            game = saved.game
            log = saved.log
        } else {
            game = SoccerGame(home: TeamInfo(name: "Home"), away: TeamInfo(name: "Away"), format: .nineASide)
        }
        refreshLibrary()
    }

    var state: SoccerGameState { game.state }

    // MARK: Input

    func toggleListening() {
        if speech.isListening {
            speech.stop()
        } else {
            speech.allowBluetoothInput = !hud.isActive     // HFP mic ends Display sessions (dat-ios #342)
            speech.onPartial = nil
            Task { await speech.start { [weak self] text in self?.submit(text, source: .voice) } }
        }
    }

    func submit(_ text: String, source: EventSource, at date: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsed = SoccerVoiceParser.parse(trimmed, game: game)
        lastParse = parsed
        var entry = UtteranceLogEntry(text: trimmed, source: source, normalized: parsed.normalized, summary: "",
                                      confidence: parsed.confidence, notes: parsed.notes, eventID: nil,
                                      outcome: "not understood")
        switch parsed.command {
        case .undo?:
            entry.outcome = "undo"
            entry.summary = undoLast().map { "undid: \(game.summary($0))" } ?? "nothing to undo"
        case .redo?:
            entry.outcome = "redo"
            entry.summary = redoLast().map { "redid: \(game.summary($0))" } ?? "nothing to redo"
        case nil:
            if let action = parsed.action {
                let e = add(action, source: source, confidence: parsed.confidence, transcript: trimmed, at: date)
                entry.eventID = e.id
                entry.outcome = "added"
                entry.summary = game.summary(e)
            }
        }
        log.append(entry)
        save()
    }

    /// Quick buttons and lens actions (no transcript).
    func quick(_ action: SoccerAction) {
        lastParse = nil
        add(action, source: .human, confidence: 1, transcript: nil, at: Date())
        save()
    }

    @discardableResult
    private func add(_ action: SoccerAction, source: EventSource, confidence: Double, transcript: String?, at date: Date) -> SoccerEvent {
        // Period changes and taps are facts; calls wait for a confirm unless confident and auto-confirm is on.
        let sure = action.kind == .periodStart || action.kind == .periodEnd || source == .human
        let status: EventStatus = sure || (autoConfirm && confidence >= 0.9) ? .confirmed : .proposed
        let e = SoccerEvent(action: action, source: source, status: status, confidence: confidence,
                            transcript: transcript, wallTime: date)
        game.append(e)
        redoStack.removeAll()
        return e
    }

    /// The period button's next step: kickoff, half time, second half, full time…
    var nextPeriodAction: (label: String, action: SoccerAction)? {
        let s = state
        if game.isOver { return nil }
        var a: SoccerAction
        if s.running {
            a = SoccerAction(kind: .periodEnd, team: .home)
            a.period = s.period
            let last = s.period >= game.format.periods
            let label = last ? "Full time" : (game.format.periods == 2 ? "Half time" : "End \(game.format.periodName(s.period))")
            return (label, a)
        }
        a = SoccerAction(kind: .periodStart, team: .home)
        a.period = s.period + 1
        let label = s.period == 0 ? "Kickoff" : "Start \(game.format.periodName(s.period + 1))"
        return (label, a)
    }

    func advancePeriod() {
        guard let next = nextPeriodAction else { return }
        quick(next.action)
        if next.action.kind == .periodEnd, (next.action.period ?? 0) >= game.format.periods {
            game.ended = true
            save()
        }
    }

    // MARK: Review

    func confirm(_ id: UUID) { game.setStatus(.confirmed, for: id); save() }
    func reject(_ id: UUID) { game.setStatus(.rejected, for: id); save() }

    func confirmAll() {
        for e in game.events where e.status == .proposed { game.setStatus(.confirmed, for: e.id) }
        save()
    }

    @discardableResult
    func undoLast() -> SoccerEvent? {
        guard let e = game.rejectLast() else { return nil }
        redoStack.append(e.id)
        save()
        return e
    }

    @discardableResult
    func redoLast() -> SoccerEvent? {
        guard let id = redoStack.popLast(), let e = game.events.first(where: { $0.id == id }) else { return nil }
        game.setStatus(.proposed, for: id)
        save()
        return e
    }

    var canUndo: Bool { game.events.contains { $0.status != .rejected } }
    var redoTarget: SoccerEvent? { redoStack.last.flatMap { id in game.events.first { $0.id == id } } }

    // MARK: Games

    func newGame(home: String, away: String, format: SoccerFormat, focus: TeamSide) {
        save()
        game = SoccerGame(home: TeamInfo(name: home.isEmpty ? "Home" : home),
                          away: TeamInfo(name: away.isEmpty ? "Away" : away), format: format, focus: focus)
        log = []
        redoStack = []
        lastParse = nil
        save()
        refreshLibrary()
    }

    func setEnded(_ ended: Bool) {
        game.ended = ended
        save()
    }

    func setFocus(_ side: TeamSide) {
        game.focus = side
        save()
    }

    @discardableResult
    func setRoster(_ side: TeamSide, text: String) -> [String] {
        let (roster, problems) = Roster.parse(text)
        if side == .home { game.home.roster = roster.isEmpty ? nil : roster } else { game.away.roster = roster.isEmpty ? nil : roster }
        save()
        return problems
    }

    func refreshLibrary() {
        var games = GameFiles.all(SoccerGame.self).map(\.game)
        if let i = games.firstIndex(where: { $0.id == game.id }) { games[i] = game }
        else if !game.events.isEmpty { games.append(game) }
        library = games.sorted { $0.date > $1.date }
    }

    func openGame(_ id: UUID) {
        guard id != game.id, let target = library.first(where: { $0.id == id }) else { return }
        save()
        game = target
        log = GameFiles.utterances(for: id)
        redoStack = []
        lastParse = nil
        save()                       // most recent → reopens next launch
    }

    func deleteGame(_ id: UUID) {
        guard id != game.id else { return }
        GameFiles.delete(id)
        library.removeAll { $0.id == id }
    }

    // MARK: Glasses

    var hudContent: FootballHUD { SoccerHUD(game: game).lens(redo: redoTarget.map { game.summary($0) }) }

    func toggleHUD(deviceID: DeviceIdentifier?) {
        if hud.isActive {
            lensCall.cancel()
            hud.disconnect()
            drivesLens = false
        } else {
            hud.onConfirm = { [weak self] id in self?.confirm(id) }
            hud.onUndo = { [weak self] in self?.undoLast() }
            hud.onRedo = { [weak self] in self?.redoLast() }
            hud.onCallPlay = { [weak self] in self?.callFromLens() }
            hud.onClock = nil                 // no play clock in soccer
            hud.onDoneListening = { [weak self] in self?.lensCall.finish() }
            hud.onCancelListening = { [weak self] in self?.lensCall.cancel() }
            hud.onRecordingFinished = nil
            drivesLens = true
            Task { await hud.connect(deviceID: deviceID, initial: hudContent) }
        }
    }

    /// Lets go of the lens (switching to football).
    func releaseLens() {
        guard drivesLens else { return }
        lensCall.cancel()
        if hud.isActive { hud.disconnect() }
        drivesLens = false
    }

    func callFromLens() {
        if speech.isListening { speech.stop() }
        Task { await lensCall.start() }
    }

    private func submitFromLens(_ text: String) {
        submit(text, source: .voice)
        if let p = lastParse, p.isEmpty {
            hud.setVoice(.note("Didn't catch a call in “\(text)”"))
        }
    }

    /// The lens minute only changes once a minute; refresh it then.
    func tickLens() {
        if drivesLens, hud.isActive, state.running { hud.show(hudContent) }
    }

    // MARK: Files

    var gameFile: URL { GameFiles.file(for: game.id) }

    func save() {
        if drivesLens { hud.show(hudContent) }
        if let i = library.firstIndex(where: { $0.id == game.id }) { library[i] = game }
        else if !game.events.isEmpty { library.insert(game, at: 0) }
        GameFiles.save(game, id: game.id, log: log)
    }

    private static func loadLatest() -> (game: SoccerGame, log: [UtteranceLogEntry])? {
        guard let newest = GameFiles.all(SoccerGame.self).first else { return nil }
        return (newest.game, GameFiles.utterances(for: newest.game.id))
    }
}
