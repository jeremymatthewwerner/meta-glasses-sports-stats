import Foundation

/// What the offline CV pipeline (`cv/`, sideline-cv) found for one play.
public struct CVPlayNote: Codable, Sendable, Equatable {
    public struct Player: Codable, Sendable, Equatable {
        public var team: TeamSide
        public var jersey: Int
        public var role: String
        public var confidence: Double
        public var teamConflict: Bool

        public init(team: TeamSide, jersey: Int, role: String, confidence: Double, teamConflict: Bool) {
            self.team = team
            self.jersey = jersey
            self.role = role
            self.confidence = confidence
            self.teamConflict = teamConflict
        }
    }

    /// Called players whose number CV read on screen.
    public var seen: [Player]
    /// Called players CV never read.
    public var notSeen: [Player]
    /// Where the play is inside the clip, when CV found it.
    public var actionStart: Double?
    public var actionEnd: Double?
    public var actionConfidence: Double?
    /// True when the clip was trimmed to the action.
    public var trimmed: Bool

    public init(seen: [Player] = [], notSeen: [Player] = [], actionStart: Double? = nil, actionEnd: Double? = nil,
                actionConfidence: Double? = nil, trimmed: Bool = false) {
        self.seen = seen
        self.notSeen = notSeen
        self.actionStart = actionStart
        self.actionEnd = actionEnd
        self.actionConfidence = actionConfidence
        self.trimmed = trimmed
    }

    /// "#22 ✓ · #54 not seen · ⚠ #11 other team's colors"
    public var summary: String {
        var parts = seen.map { $0.teamConflict ? "⚠ #\($0.jersey) in other team's colors" : "#\($0.jersey) ✓" }
        parts += notSeen.map { "#\($0.jersey) not seen" }
        return parts.joined(separator: " · ")
    }
}

/// The parts of sideline-cv's report.json the app uses (format version 1).
public struct CVReport: Decodable, Sendable {
    public struct Team: Decodable, Sendable { public var color: String; public var team: String? }
    public struct Segment: Decodable, Sendable { public var start: Double; public var end: Double; public var confidence: Double }
    public struct Window: Decodable, Sendable { public var start: Double; public var end: Double }
    public struct Action: Decodable, Sendable { public var segment: Segment?; public var refinedClip: Window? }
    public struct Matched: Decodable, Sendable {
        public var team: String; public var jersey: Int; public var role: String
        public var confidence: Double; public var teamConflict: Bool?
    }
    public struct Missing: Decodable, Sendable { public var team: String; public var jersey: Int; public var role: String }
    public struct Matches: Decodable, Sendable { public var matched: [Matched]; public var missing: [Missing] }
    public struct Clip: Decodable, Sendable { public var asset: String; public var start: Double; public var end: Double }
    public struct Play: Decodable, Sendable {
        public var playId: String
        public var clip: Clip?
        public var action: Action?
        public var matches: Matches?
    }

    public var format: String?
    public var version: Int?
    public var gameId: String
    public var teams: [String: Team]?
    public var plays: [Play]

    public static func decode(_ data: Data) throws -> CVReport {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(CVReport.self, from: data)
    }
}

/// What an import changed.
public struct CVImportSummary: Equatable, Sendable {
    public var playsUpdated = 0
    public var clipsTrimmed = 0
    public var playersSeen = 0
    public var playersNotSeen = 0
    public var teamColorsSet = 0
    public var unknownPlays = 0

    public var text: String {
        "\(playsUpdated) play(s) updated, \(clipsTrimmed) clip(s) trimmed to the action, "
            + "\(playersSeen) called player(s) seen, \(playersNotSeen) not seen"
            + (teamColorsSet > 0 ? ", team colors set" : "")
            + (unknownPlays > 0 ? " (\(unknownPlays) play(s) not in this game)" : "")
    }
}

public enum CVImportError: Error, LocalizedError, Equatable {
    case wrongGame(report: String, game: String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .wrongGame(let r, let g): "This CV report is for game \(r.prefix(8)), not \(g.prefix(8))."
        case .unsupported(let why): "Unsupported CV report: \(why)"
        }
    }
}

extension FootballGame {
    /// Applies a CV report: per play, a note of who CV saw and, when CV
    /// found the action confidently, the clip trimmed to it. The original
    /// clip stays as the second video reference, and importing again is
    /// idempotent (trimming always starts from the original).
    @discardableResult
    public mutating func applyCV(_ report: CVReport) throws -> CVImportSummary {
        guard report.gameId.caseInsensitiveCompare(id.uuidString) == .orderedSame else {
            throw CVImportError.wrongGame(report: report.gameId, game: id.uuidString)
        }
        if let f = report.format, f != "sideline-cv-report" { throw CVImportError.unsupported("format \(f)") }
        if let v = report.version, v > 1 { throw CVImportError.unsupported("version \(v)") }

        var summary = CVImportSummary()
        for p in report.plays {
            guard let idx = events.firstIndex(where: { $0.id.uuidString.caseInsensitiveCompare(p.playId) == .orderedSame }) else {
                summary.unknownPlays += 1
                continue
            }
            var note = CVPlayNote()
            for m in p.matches?.matched ?? [] {
                guard let side = TeamSide(rawValue: m.team) else { continue }
                note.seen.append(.init(team: side, jersey: m.jersey, role: m.role, confidence: m.confidence,
                                       teamConflict: m.teamConflict ?? false))
            }
            for m in p.matches?.missing ?? [] {
                guard let side = TeamSide(rawValue: m.team) else { continue }
                note.notSeen.append(.init(team: side, jersey: m.jersey, role: m.role, confidence: 0, teamConflict: false))
            }
            if let seg = p.action?.segment {
                note.actionStart = seg.start
                note.actionEnd = seg.end
                note.actionConfidence = seg.confidence
            }
            // The original (voice-anchored) clip: an earlier import keeps it second.
            var refs = events[idx].videoRefs
            if refs.count >= 2, let original = refs.last, refs.first?.assetID == original.assetID,
               events[idx].cv?.trimmed == true {
                refs = [original]
            }
            if let window = p.action?.refinedClip, let original = refs.first,
               original.assetID == (p.clip?.asset ?? original.assetID) {
                refs = [VideoRef(assetID: original.assetID, start: window.start, end: window.end), original]
                note.trimmed = true
                summary.clipsTrimmed += 1
            }
            events[idx].videoRefs = refs
            events[idx].cv = note
            summary.playsUpdated += 1
            summary.playersSeen += note.seen.count
            summary.playersNotSeen += note.notSeen.count
        }
        for (_, t) in report.teams ?? [:] {
            switch t.team {
            case "home": home.jerseyColor = t.color; summary.teamColorsSet += 1
            case "away": away.jerseyColor = t.color; summary.teamColorsSet += 1
            default: break
            }
        }
        return summary
    }
}
