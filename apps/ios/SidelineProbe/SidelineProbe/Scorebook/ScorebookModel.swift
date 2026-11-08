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

    // MARK: Player cues (state)

    /// What the wearer hears; saved across launches.
    var cues: CueSettings = ScorebookModel.loadCues() {
        didSet {
            speaker.rate = Float(cues.voiceRate)
            if let data = try? JSONEncoder().encode(cues) { UserDefaults.standard.set(data, forKey: Self.cuesKey) }
        }
    }
    @ObservationIgnored let speaker = CueSpeaker()
    private(set) var playClock = PlayClock()
    /// Whole seconds on the clock face, nil when stopped.
    private(set) var clockShown: Int?
    /// The last callout spoken after a play (shown under the clock).
    private(set) var lastCue: String?
    @ObservationIgnored private var clockTimer: Timer?
    @ObservationIgnored private var lastClockTick = Date()
    private static let cuesKey = "cueSettings"

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
        refreshLibrary()
        speaker.rate = Float(cues.voiceRate)
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

        let before = game.state
        if let clock = parsed.command, [.clock, .clock25, .clock40, .stopClock].contains(clock) {
            switch clock {
            case .clock25: startPlayClock(25)
            case .clock40: startPlayClock(40)
            case .stopClock: stopPlayClock()
            default: startPlayClock()
            }
            entry.outcome = "clock"
            entry.summary = clock == .stopClock ? "play clock stopped" : "play clock started"
        } else if parsed.command == .undo {
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
            cuesAfter(event, before: before, anchor: anchor)
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
            hud.onClock = { [weak self] in
                guard let self else { return }
                if self.playClock.isRunning { self.stopPlayClock() } else { self.startPlayClock() }
            }
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

    // MARK: Library (every saved game)

    struct SavedGame: Identifiable {
        var game: FootballGame
        var id: UUID { game.id }
    }

    /// All saved games, newest first.
    private(set) var library: [SavedGame] = []

    func refreshLibrary() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.gamesDirectory, includingPropertiesForKeys: nil)) ?? []
        var games = files
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix("-utterances.json") }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? dec.decode(FootballGame.self, from: $0) } }
        if !games.contains(where: { $0.id == game.id }) { games.append(game) }
        if let i = games.firstIndex(where: { $0.id == game.id }) { games[i] = game }   // in-memory is newest
        library = games.sorted { $0.date > $1.date }.map(SavedGame.init)
    }

    /// Switches the scorebook to another saved game.
    func openGame(_ id: UUID) {
        guard id != game.id, let target = library.first(where: { $0.id == id })?.game else { return }
        if hud.isRecording { hud.stopRecording() }
        save()
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        game = target
        log = (try? Data(contentsOf: utterancesFile)).flatMap { try? dec.decode([UtteranceLogEntry].self, from: $0) } ?? []
        recording = Self.loadRecording(for: target.id)
        history = UndoHistory()
        lastParse = nil
        lastNotes = []
        cvStatus = nil
        save()                       // marks it most recent, so it reopens next launch
        importDroppedCVReport()
    }

    /// Deletes a saved game and its videos. The open game can't be deleted.
    func deleteGame(_ id: UUID) {
        guard id != game.id else { return }
        let fm = FileManager.default
        let base = Self.gamesDirectory
        try? fm.removeItem(at: base.appendingPathComponent("\(id.uuidString).json"))
        try? fm.removeItem(at: base.appendingPathComponent("\(id.uuidString)-utterances.json"))
        try? fm.removeItem(at: base.appendingPathComponent(id.uuidString, isDirectory: true))
        UserDefaults.standard.removeObject(forKey: "cvImported-\(id.uuidString)")
        library.removeAll { $0.id == id }
    }

    func setEnded(_ ended: Bool) {
        game.ended = ended
        save()
    }

    func folder(for gameID: UUID) -> URL { Self.gamesDirectory.appendingPathComponent(gameID.uuidString, isDirectory: true) }

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

    // MARK: Player cues

    private static func loadCues() -> CueSettings {
        UserDefaults.standard.data(forKey: cuesKey).flatMap { try? JSONDecoder().decode(CueSettings.self, from: $0) } ?? CueSettings()
    }

    /// Muted while a play is being called, so the mic doesn't hear the cue.
    private var isListeningAnywhere: Bool { speech.isListening || lensCall.isListening }

    /// Starts (or restarts) the play clock. `seconds` nil uses the rule's
    /// usual length; `date` can be in the past (backdated to the whistle).
    func startPlayClock(_ seconds: TimeInterval? = nil, at date: Date = Date(), announce: Bool = true) {
        let length = seconds ?? (cues.clockRule == .twentyFive ? 25 : 40)
        playClock.start(length, at: date)
        lastClockTick = max(date, Date())     // backdated marks already passed aren't spoken
        if announce, cues.playClockVoice, !isListeningAnywhere { speaker.say("\(Int(length)) clock", urgent: true) }
        clockTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clockTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
        clockTick()
    }

    func stopPlayClock() {
        clockTimer?.invalidate()
        clockTimer = nil
        playClock.stop()
        clockShown = nil
        hud.setClock(nil)
    }

    private func clockTick() {
        let now = Date()
        if cues.playClockVoice, !isListeningAnywhere,
           let mark = playClock.marksCrossed(cues.countdownMarks, from: lastClockTick, to: now).last {
            speaker.say(CueComposer.countdown(mark), urgent: true)   // only the latest if ticks were late
        }
        lastClockTick = now
        clockShown = playClock.display(at: now)
        hud.setClock(playClock.lensText(at: now))
        // Leave "0" up briefly, then clear.
        if let left = playClock.remaining(at: now), left <= 0,
           let started = playClock.startedAt, now.timeIntervalSince(started) > playClock.length + 4 {
            stopPlayClock()
        }
    }

    /// After a play is added: maybe start the clock, then speak the callouts.
    private func cuesAfter(_ event: FootballEvent, before: FootballGameState, anchor: Date) {
        if cues.autoStartClock, !game.isOver {
            let length = PlayClock.length(after: event, before: before, after: game.state, rule: cues.clockRule)
            startPlayClock(length, at: anchor, announce: false)
        }
        if let text = CueComposer.afterEvent(event, game: game, before: before, settings: cues) {
            // The mic has stopped by the time a call is submitted; speak after a beat.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !self.isListeningAnywhere else { return }
                self.speaker.say(text)
                self.lastCue = text
            }
        }
    }

    // MARK: Web library

    /// Progress or result of the last web export, for the Library tab.
    var webExportStatus: String?
    var webExportRunning = false
    /// The zipped site, ready to share.
    var webExportZip: URL?

    static var documentsDirectory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var webDirectory: URL { documentsDirectory.appendingPathComponent("web", isDirectory: true) }

    /// Builds the static website of every saved game in Documents/web
    /// (visible in the Files app) with a clip per play, then zips it for sharing.
    func exportWebLibrary() async {
        guard !webExportRunning else { return }
        webExportRunning = true
        defer { webExportRunning = false }
        save()
        refreshLibrary()
        let games = library.map(\.game)
        let fm = FileManager.default
        let dir = Self.webDirectory
        webExportZip = nil
        do {
            try? fm.removeItem(at: dir)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            var exported = Set<UUID>()
            var skipped = 0
            let clips = WebLibrary.clipsToExport(games)
            for (i, clip) in clips.enumerated() {
                let source = folder(for: clip.gameID).appendingPathComponent(clip.source.assetID)
                let stillRecording = clip.gameID == game.id && hud.recordingFile == clip.source.assetID
                guard !stillRecording, fm.fileExists(atPath: source.path) else { skipped += 1; continue }
                webExportStatus = "Cutting clip \(i + 1) of \(clips.count)…"
                do {
                    _ = try await ReelExporter.export([.init(url: source, start: clip.source.start, end: clip.source.end)],
                                                      to: dir.appendingPathComponent(clip.path), fileType: .mp4)
                    exported.insert(clip.eventID)
                } catch {
                    skipped += 1
                }
            }

            webExportStatus = "Writing pages…"
            for file in WebLibrary(games: games, exportedClips: exported).files() {
                let url = dir.appendingPathComponent(file.path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(file.contents.utf8).write(to: url, options: .atomic)
            }

            webExportStatus = "Zipping…"
            let zip = try Self.zip(dir, named: "sideline-library-\(Self.stamp()).zip")
            webExportZip = zip
            var parts = ["\(games.count) game\(games.count == 1 ? "" : "s")", "\(exported.count) clip\(exported.count == 1 ? "" : "s")"]
            if skipped > 0 { parts.append("\(skipped) clip\(skipped == 1 ? "" : "s") unavailable") }
            webExportStatus = "Web library ready: " + parts.joined(separator: ", ") + "."
        } catch {
            webExportStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    /// Zips a folder with the system's built-in archiver (NSFileCoordinator
    /// `.forUploading`) into Documents/exports, replacing older exports.
    private static func zip(_ folder: URL, named name: String) throws -> URL {
        let fm = FileManager.default
        let exports = documentsDirectory.appendingPathComponent("exports", isDirectory: true)
        try? fm.removeItem(at: exports)
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        let dest = exports.appendingPathComponent(name)
        var coordError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordError) { zipped in
            do { try fm.copyItem(at: zipped, to: dest) } catch { copyError = error }
        }
        if let e = coordError ?? copyError { throw e }
        return dest
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }

    static var gamesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games", isDirectory: true)
    }

    var gameFile: URL { Self.gamesDirectory.appendingPathComponent("\(game.id.uuidString).json") }
    var utterancesFile: URL { Self.gamesDirectory.appendingPathComponent("\(game.id.uuidString)-utterances.json") }

    func save() {
        hud.show(hudContent)
        if let i = library.firstIndex(where: { $0.id == game.id }) { library[i].game = game }
        else if !library.isEmpty || !game.events.isEmpty { library.insert(SavedGame(game: game), at: 0) }
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
