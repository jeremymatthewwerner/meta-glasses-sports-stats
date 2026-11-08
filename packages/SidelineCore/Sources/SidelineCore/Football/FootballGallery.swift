import Foundation

/// Who took part in a play, and how. The basis for the per-player gallery.
public struct PlayInvolvement: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case carrier, passer, receiver, tackler, sacker, interceptor
        case fumbled, forcedFumble, recovered, kicker, returner, penalized

        public var label: String {
            switch self {
            case .carrier: "Run"
            case .passer: "Pass"
            case .receiver: "Target"
            case .tackler: "Tackle"
            case .sacker: "Sack"
            case .interceptor: "Interception"
            case .fumbled: "Fumble"
            case .forcedFumble: "Forced fumble"
            case .recovered: "Recovery"
            case .kicker: "Kick"
            case .returner: "Return"
            case .penalized: "Penalty"
            }
        }

        /// "1 run", "2 passes", "3 recoveries".
        public func counted(_ n: Int) -> String {
            let word = label.lowercased()
            guard n != 1 else { return "1 \(word)" }
            let plural: String
            if word.hasSuffix("ss") { plural = word + "es" }
            else if word.hasSuffix("y") { plural = String(word.dropLast()) + "ies" }
            else { plural = word + "s" }
            return "\(n) \(plural)"
        }
    }

    public var player: PlayerKey
    public var role: Role

    public init(player: PlayerKey, role: Role) {
        self.player = player
        self.role = role
    }
}

/// Event categories for the gallery ("all touchdowns", "all turnovers", …).
public enum PlayTag: String, Codable, Sendable, CaseIterable, Identifiable {
    case touchdown, turnover, bigPlay, sack, kick, penalty

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .touchdown: "Touchdowns"
        case .turnover: "Turnovers"
        case .bigPlay: "Big plays"
        case .sack: "Sacks"
        case .kick: "Kicks"
        case .penalty: "Penalties"
        }
    }

    /// Scrimmage gain or return length that counts as a big play.
    public static let bigGain = 15
    public static let bigReturn = 20
}

extension FootballEvent {
    /// Every player named in the play, with their side and role.
    /// `offense` is the team in possession at the snap (the kicking team on kicks).
    public var involvements: [PlayInvolvement] {
        guard let p = play else { return [] }
        let off = offense, def = offense.opponent
        var out: [PlayInvolvement] = []
        func add(_ side: TeamSide, _ number: Int?, _ role: PlayInvolvement.Role) {
            guard let number else { return }
            let item = PlayInvolvement(player: PlayerKey(team: side, jersey: number), role: role)
            if !out.contains(item) { out.append(item) }
        }
        add(off, p.ballCarrier, .carrier)
        add(off, p.passer, .passer)
        add(off, p.receiver, .receiver)
        for t in p.tacklers { add(def, t, .tackler) }
        for s in p.sackers { add(def, s, .sacker) }
        add(def, p.interceptedBy, .interceptor)
        add(off, p.fumbledBy, .fumbled)
        add(def, p.forcedFumbleBy, .forcedFumble)
        add(p.fumbleLost ? def : off, p.fumbleRecoveredBy, .recovered)
        add(off, p.kicker, .kicker)
        add(def, p.returner, .returner)
        if let pen = p.penalty { add(pen.on == .offense ? off : def, pen.player, .penalized) }
        return out
    }

    public var tags: Set<PlayTag> {
        guard let p = play else { return [] }
        var t: Set<PlayTag> = []
        if p.touchdown { t.insert(.touchdown) }
        if p.isTurnover { t.insert(.turnover) }
        if p.kind == .sack || !p.sackers.isEmpty { t.insert(.sack) }
        if [.kickoff, .punt, .fieldGoal, .extraPoint].contains(p.kind) { t.insert(.kick) }
        if p.penalty != nil { t.insert(.penalty) }
        if p.isScrimmage, let y = p.yards, y >= PlayTag.bigGain { t.insert(.bigPlay) }
        if let r = p.returnYards, r >= PlayTag.bigReturn { t.insert(.bigPlay) }
        return t
    }
}

/// The game's plays organized for browsing: by player and by event type.
/// Rejected plays are left out; order is game order.
public struct FootballGallery: Sendable {
    public struct PlayerEntry: Sendable, Identifiable, Equatable {
        public var player: PlayerKey
        public var name: String?
        public var plays: [FootballEvent]
        public var roles: [PlayInvolvement.Role: Int]
        public var id: PlayerKey { player }
        public var clipCount: Int { plays.filter { !$0.videoRefs.isEmpty }.count }
    }

    public let players: [PlayerEntry]
    public let byTag: [PlayTag: [FootballEvent]]

    public init(game: FootballGame) {
        var map: [PlayerKey: PlayerEntry] = [:]
        var tags: [PlayTag: [FootballEvent]] = [:]
        for event in game.events where event.status != .rejected {
            for inv in event.involvements {
                var entry = map[inv.player] ?? PlayerEntry(
                    player: inv.player, name: game.team(inv.player.team).roster?.name(for: inv.player.jersey),
                    plays: [], roles: [:])
                if entry.plays.last?.id != event.id { entry.plays.append(event) }
                entry.roles[inv.role, default: 0] += 1
                map[inv.player] = entry
            }
            for tag in event.tags { tags[tag, default: []].append(event) }
        }
        players = map.values.sorted { $0.player < $1.player }
        byTag = tags
    }

    public func entry(for player: PlayerKey) -> PlayerEntry? { players.first { $0.player == player } }
}
