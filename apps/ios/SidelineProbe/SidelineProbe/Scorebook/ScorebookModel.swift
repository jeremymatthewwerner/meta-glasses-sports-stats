import MWDATCore
import Foundation
import Observation
import SidelineCore

/// One spoken/typed line and what the parser made of it. Saved alongside
/// the game so Phase 0a can measure parse accuracy on real sideline speech.
struct UtteranceLogEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var text: String
    var source: EventSource
    var normalized: String
    var summary: String
    var confidence: Double
    var notes: [String]
    var eventID: UUID?
    var outcome: String   // "added", "undo", "not understood"
}

@MainActor
@Observable
final class ScorebookModel {
    private(set) var game: FootballGame
    private(set) var log: [UtteranceLogEntry] = []
    private(set) var lastParse: ParsedUtterance?
    private(set) var lastNotes: [String] = []
    /// Confirm high-confidence plays automatically instead of leaving them proposed.
    var autoConfirm = false

    let speech = SpeechTranscriber()
    /// Heads-up scorebook on Meta Ray-Ban Display.
    let hud = GlassesHUD()

    init() {
        if let saved = Self.loadLatest() {
            game = saved.game
            log = saved.log
        } else {
            game = FootballGame(home: TeamInfo(name: "Home"), away: TeamInfo(name: "Away"))
        }
    }

    var state: FootballGameState { game.state }
    var boxScore: FootballBoxScore { game.boxScore() }

    // MARK: Input

    func toggleListening() {
        if speech.isListening {
            speech.stop()
        } else {
            // On Ray-Ban Display, connecting the glasses as a Bluetooth (HFP)
            // mic ends the DAT session (dat-ios #342). Use the phone mic
            // while the HUD is up.
            speech.allowBluetoothInput = !hud.isActive
            Task { await speech.start { [weak self] text in self?.submit(text, source: .voice) } }
        }
    }

    func submit(_ text: String, source: EventSource) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsed = FootballVoiceParser.parse(trimmed)
        lastParse = parsed
        var notes = parsed.notes
        var entry = UtteranceLogEntry(
            text: trimmed, source: source, normalized: parsed.normalized, summary: "",
            confidence: parsed.confidence, notes: [], eventID: nil, outcome: "not understood")

        if parsed.command == .undo {
            let undone = game.rejectLast()
            entry.outcome = "undo"
            entry.summary = undone.map { "undid: \($0.summary)" } ?? "nothing to undo"
        } else if !parsed.isEmpty {
            let offense = parsed.situation?.possession ?? game.state.possession
            var play = parsed.play
            // Stat-keepers rarely repeat the QB's number; assume the last passer.
            if var p = play, p.kind == .pass || p.kind == .sack || p.kind == .spike, p.passer == nil,
               let qb = lastPasser(for: offense) {
                p.passer = qb
                play = p
                notes.append("passer assumed #\(qb)")
            }
            let status: EventStatus = (autoConfirm && parsed.confidence >= 0.9) ? .confirmed : .proposed
            let event = FootballEvent(
                offense: offense, play: play, situation: parsed.situation, source: source,
                status: status, confidence: parsed.confidence, transcript: trimmed)
            game.append(event)
            entry.eventID = event.id
            entry.outcome = "added"
            entry.summary = event.summary
        }
        entry.notes = notes
        lastNotes = notes
        log.append(entry)
        save()
    }

    // MARK: Review

    func confirm(_ id: UUID) { game.setStatus(.confirmed, for: id); save() }

    /// Rejects the newest play that still counts (lens "Undo" button).
    func undoLast() {
        _ = game.rejectLast()
        save()
    }

    // MARK: Glasses HUD

    var hudContent: FootballHUD { FootballHUD(game: game) }

    func toggleHUD(deviceID: DeviceIdentifier?) {
        if hud.isActive {
            hud.disconnect()
        } else {
            hud.onConfirm = { [weak self] id in self?.confirm(id) }
            hud.onUndo = { [weak self] in self?.undoLast() }
            Task { await hud.connect(deviceID: deviceID, initial: hudContent) }
        }
    }
    func reject(_ id: UUID) { game.setStatus(.rejected, for: id); save() }

    func confirmAll() {
        for e in game.events where e.status == .proposed { game.setStatus(.confirmed, for: e.id) }
        save()
    }

    func newGame(home: String, away: String, openingKickoff: TeamSide, ruleSet: FootballRuleSet) {
        save()
        game = FootballGame(
            home: TeamInfo(name: home.isEmpty ? "Home" : home),
            away: TeamInfo(name: away.isEmpty ? "Away" : away),
            ruleSet: ruleSet, openingKickoff: openingKickoff)
        log = []
        lastParse = nil
        lastNotes = []
        save()
    }

    func setRuleSet(_ rules: FootballRuleSet) {
        game.ruleSet = rules
        save()
    }

    private func lastPasser(for team: TeamSide) -> Int? {
        game.activeEvents.reversed().first { $0.offense == team && $0.play?.passer != nil }?.play?.passer
    }

    // MARK: Persistence (Documents/games/<id>.json + <id>-utterances.json)

    static var gamesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games", isDirectory: true)
    }

    var gameFile: URL { Self.gamesDirectory.appendingPathComponent("\(game.id.uuidString).json") }
    var utterancesFile: URL { Self.gamesDirectory.appendingPathComponent("\(game.id.uuidString)-utterances.json") }

    func save() {
        hud.show(hudContent)
        do {
            try FileManager.default.createDirectory(at: Self.gamesDirectory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(game).write(to: gameFile, options: .atomic)
            try enc.encode(log).write(to: utterancesFile, options: .atomic)
        } catch {
            print("[Scorebook] save failed: \(error)")
        }
    }

    private static func loadLatest() -> (game: FootballGame, log: [UtteranceLogEntry])? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: gamesDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        let games = files.filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix("-utterances.json") }
        let newest = games.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }
        guard let newest else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: newest), let game = try? dec.decode(FootballGame.self, from: data) else { return nil }
        let logURL = newest.deletingPathExtension().appendingPathExtension("json")
            .deletingLastPathComponent().appendingPathComponent("\(game.id.uuidString)-utterances.json")
        let log = (try? Data(contentsOf: logURL)).flatMap { try? dec.decode([UtteranceLogEntry].self, from: $0) } ?? []
        return (game, log)
    }
}
