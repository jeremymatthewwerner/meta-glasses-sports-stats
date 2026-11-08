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
    var outcome: String   // "added", "undo", "redo", "not understood"
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
    /// Undo/redo of play calls (session only; not saved with the game).
    private(set) var history = UndoHistory()
    /// Hands-free play calls started from the lens.
    @ObservationIgnored private lazy var lensCall = LensCallController(hud: hud, phone: speech) { [weak self] text, startedAt in
        self?.submitFromLens(text, startedAt: startedAt)
    }
    /// Game mode: the video files recorded for this game.
    private(set) var recording: GameRecording
    /// When the phone mic button was pressed (clip anchor for phone calls).
    @ObservationIgnored private var phoneListenStartedAt = Date()

    init() {
        let loadedGame: FootballGame
        if let saved = Self.loadLatest() {
            loadedGame = saved.game
            log = saved.log
        } else {
            loadedGame = FootballGame(home: TeamInfo(name: "Home"), away: TeamInfo(name: "Away"))
        }
        game = loadedGame
        recording = Self.loadRecording(for: loadedGame.id)
        importDroppedCVReport()
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
            speech.onPartial = nil
            phoneListenStartedAt = Date()
            Task { await speech.start { [weak self] text in
                guard let self else { return }
                self.submit(text, source: .voice, anchor: self.phoneListenStartedAt)
            } }
        }
    }

    /// `anchor`: when the wearer started calling the play (for its video clip).
    func submit(_ text: String, source: EventSource, anchor: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsed = FootballVoiceParser.parse(trimmed)
        lastParse = parsed
        var notes = parsed.notes
        var entry = UtteranceLogEntry(
            text: trimmed, source: source, normalized: parsed.normalized, summary: "",
            confidence: parsed.confidence, notes: [], eventID: nil, outcome: "not understood")

        if parsed.command == .undo {
            let undone = history.undo(in: &game)
            entry.outcome = "undo"
            entry.summary = undone.map { "undid: \($0.summary)" } ?? "nothing to undo"
        } else if parsed.command == .redo {
            let redone = history.redo(in: &game)
            entry.outcome = "redo"
            entry.summary = redone.map { "redid: \($0.summary)" } ?? "nothing to redo"
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
            var event = FootballEvent(
                offense: offense, play: play, situation: parsed.situation, source: source,
                status: status, confidence: parsed.confidence, transcript: trimmed, wallTime: anchor)
            if play != nil, let file = hud.recordingFile, let t = hud.videoTime(at: anchor) {
                event.videoRefs = [ClipPolicy.football.clip(assetID: file, anchor: t)]
            }
            game.append(event)
            history.clearRedo()
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
        history.undo(in: &game)
        save()
    }

    /// Puts back the most recently undone play (lens "Redo" button).
    func redoLast() {
        history.redo(in: &game)
        save()
    }

    var redoTarget: FootballEvent? { history.redoTarget(in: game) }
    var canUndo: Bool { game.events.contains { $0.status != .rejected } }

    // MARK: Glasses HUD

    var hudContent: FootballHUD { FootballHUD(game: game, redo: redoTarget) }

    var isCallingFromLens: Bool { lensCall.isListening }

    func callPlayFromLens() {
        if speech.isListening { speech.stop() }
        Task { await lensCall.start() }
    }

    private func submitFromLens(_ text: String, startedAt: Date) {
        submit(text, source: .voice, anchor: startedAt)
        if let parse = lastParse, parse.isEmpty, parse.command == nil {
            hud.setVoice(.note("Didn't catch a play in “\(text)”"))
        }
    }

    func toggleHUD(deviceID: DeviceIdentifier?) {
        if hud.isActive {
            lensCall.cancel()
            hud.disconnect()
        } else {
            hud.onConfirm = { [weak self] id in self?.confirm(id) }
            hud.onUndo = { [weak self] in self?.undoLast() }
            hud.onRedo = { [weak self] in self?.redoLast() }
            hud.onCallPlay = { [weak self] in self?.callPlayFromLens() }
            hud.onDoneListening = { [weak self] in self?.lensCall.finish() }
            hud.onCancelListening = { [weak self] in self?.lensCall.cancel() }
            hud.onRecordingFinished = { [weak self] file, frames, error in
                self?.recordingFinished(file: file, frames: frames, error: error)
            }
            Task { await hud.connect(deviceID: deviceID, initial: hudContent) }
        }
    }
    func reject(_ id: UUID) { game.setStatus(.rejected, for: id); save() }

    func confirmAll() {
        for e in game.events where e.status == .proposed { game.setStatus(.confirmed, for: e.id) }
        save()
    }

    func newGame(home: String, away: String, openingKickoff: TeamSide, ruleSet: FootballRuleSet) {
        if hud.isRecording { hud.stopRecording() }
        save()
        game = FootballGame(
            home: TeamInfo(name: home.isEmpty ? "Home" : home),
            away: TeamInfo(name: away.isEmpty ? "Away" : away),
            ruleSet: ruleSet, openingKickoff: openingKickoff)
        log = []
        history = UndoHistory()
        recording = GameRecording(gameID: game.id)
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

    // MARK: Game video

    /// Folder for this game's video files and recording.json.
    var gameFolder: URL { Self.gamesDirectory.appendingPathComponent(game.id.uuidString, isDirectory: true) }

    func clipURL(_ ref: VideoRef) -> URL { gameFolder.appendingPathComponent(ref.assetID) }

    /// A clip can play once its file is finalized (recording stopped).
    func clipIsReady(_ ref: VideoRef) -> Bool {
        hud.recordingFile != ref.assetID && FileManager.default.fileExists(atPath: clipURL(ref).path)
    }

    var recordingError: String?

    func toggleRecording() {
        if hud.isRecording {
            hud.stopRecording()
            return
        }
        recordingError = nil
        do {
            try FileManager.default.createDirectory(at: gameFolder, withIntermediateDirectories: true)
            let file = recording.nextFileName
            try hud.startRecording(to: gameFolder.appendingPathComponent(file))
            recording.segments.append(.init(file: file, startedAt: Date(),
                                            source: "\(hud.statusText), HEVC 504x896 @15"))
            saveRecording()
        } catch {
            recordingError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func recordingFinished(file: String, frames: Int, error: String?) {
        if let i = recording.segments.firstIndex(where: { $0.file == file }) {
            recording.segments[i].endedAt = Date()
            recording.segments[i].frames = frames
        }
        if let error, frames == 0 { recordingError = "Recording failed: \(error)" }
        saveRecording()
    }

    private func saveRecording() {
        do {
            try FileManager.default.createDirectory(at: gameFolder, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(recording).write(to: gameFolder.appendingPathComponent("recording.json"), options: .atomic)
        } catch {
            print("[Scorebook] recording save failed: \(error)")
        }
    }

    private static func loadRecording(for gameID: UUID) -> GameRecording {
        let url = gamesDirectory.appendingPathComponent(gameID.uuidString).appendingPathComponent("recording.json")
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (try? Data(contentsOf: url)).flatMap { try? dec.decode(GameRecording.self, from: $0) }
            ?? GameRecording(gameID: gameID)
    }

    // MARK: CV results (from the Mac pipeline, cv/)

    /// Last import result, shown on the scorebook.
    var cvStatus: String?

    /// Applies a sideline-cv report.json to this game.
    @discardableResult
    func importCV(from url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let report = try CVReport.decode(Data(contentsOf: url))
            let summary = try game.applyCV(report)
            cvStatus = "CV imported: " + summary.text
            save()
            return true
        } catch {
            cvStatus = "CV import failed: " + ((error as? LocalizedError)?.errorDescription ?? "\(error)")
            return false
        }
    }

    /// Picks up games/<id>/cv-report.json (copied in with Files or Finder) when it's newer than the last import.
    func importDroppedCVReport() {
        let url = gameFolder.appendingPathComponent("cv-report.json")
        guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return }
        let key = "cvImported-\(game.id.uuidString)"
        let last = UserDefaults.standard.object(forKey: key) as? Date
        guard last == nil || modified > last! else { return }
        if importCV(from: url) { UserDefaults.standard.set(modified, forKey: key) }
    }

    // MARK: Gallery, rosters, reels

    var gallery: FootballGallery { FootballGallery(game: game) }

    /// Replaces a team's roster from pasted/imported text; returns lines it couldn't read.
    @discardableResult
    func setRoster(_ side: TeamSide, text: String) -> [String] {
        let (roster, problems) = Roster.parse(text)
        if side == .home { game.home.roster = roster.isEmpty ? nil : roster }
        else { game.away.roster = roster.isEmpty ? nil : roster }
        save()
        return problems
    }

    /// Stitches the finished clips of `events` into one reel; returns its file.
    func makeReel(title: String, events: [FootballEvent]) async throws -> URL {
        let pieces = events.compactMap { e -> ReelExporter.Piece? in
            guard let ref = e.videoRefs.first, clipIsReady(ref) else { return nil }
            return ReelExporter.Piece(url: clipURL(ref), start: ref.start, end: ref.end)
        }
        let slug = title.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .joined(separator: "-")
        let stamp = Int(Date().timeIntervalSince1970)
        let url = gameFolder.appendingPathComponent("reels", isDirectory: true)
            .appendingPathComponent("reel-\(slug.isEmpty ? "plays" : slug)-\(stamp).mov")
        _ = try await ReelExporter.export(pieces, to: url)
        return url
    }

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
