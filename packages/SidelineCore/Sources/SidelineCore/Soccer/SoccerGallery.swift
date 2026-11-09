import Foundation

/// Who took part in a soccer event, and how. The basis for the per-player gallery.
public struct SoccerInvolvement: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case goal, assist, ownGoal, shot, save, foul, fouled, card, subOn, subOff, offside, corner

        public var label: String {
            switch self {
            case .goal: "Goal"
            case .assist: "Assist"
            case .ownGoal: "Own goal"
            case .shot: "Shot"
            case .save: "Save"
            case .foul: "Foul"
            case .fouled: "Fouled"
            case .card: "Card"
            case .subOn: "Sub on"
            case .subOff: "Sub off"
            case .offside: "Offside"
            case .corner: "Corner"
            }
        }

        /// "1 goal", "2 assists", "3 times fouled".
        public func counted(_ n: Int) -> String {
            switch self {
            case .fouled: return n == 1 ? "fouled once" : "fouled \(n)×"
            case .subOn, .subOff, .offside: return "\(label.lowercased()) \(n)×"
            default: return "\(n) \(label.lowercased())\(n == 1 ? "" : "s")"
            }
        }
    }

    public var player: PlayerKey
    public var role: Role

    public init(player: PlayerKey, role: Role) {
        self.player = player
        self.role = role
    }
}

/// Event categories for the soccer gallery ("all goals", "all saves", …).
public enum SoccerTag: String, Codable, Sendable, CaseIterable, Identifiable {
    case goal, chance, save, card, foul, corner

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .goal: "Goals"
        case .chance: "Chances (goals and shots)"
        case .save: "Saves"
        case .card: "Cards"
        case .foul: "Fouls and offsides"
        case .corner: "Corners"
        }
    }
}

extension SoccerEvent {
    /// Every player named in the event, with their side and role.
    public var involvements: [SoccerInvolvement] {
        let a = action, us = a.team, them = a.team.opponent
        var out: [SoccerInvolvement] = []
        func add(_ side: TeamSide, _ number: Int?, _ role: SoccerInvolvement.Role) {
            guard let number else { return }
            let item = SoccerInvolvement(player: PlayerKey(team: side, jersey: number), role: role)
            if !out.contains(item) { out.append(item) }
        }
        switch a.kind {
        case .goal:
            if a.ownGoal { add(them, a.player, .ownGoal) } else { add(us, a.player, .goal) }
            add(us, a.assist, .assist)
        case .shot:
            add(us, a.player, .shot)
            add(them, a.savedBy, .save)
        case .save: add(us, a.player, .save)
        case .foul:
            add(us, a.player, .foul)
            add(them, a.fouled, .fouled)
        case .card: add(us, a.player, .card)
        case .substitution:
            add(us, a.player, .subOn)
            add(us, a.playerOff, .subOff)
        case .offside: add(us, a.player, .offside)
        case .corner: add(us, a.player, .corner)
        case .periodStart, .periodEnd: break
        }
        return out
    }

    /// Gallery categories this event belongs to.
    public var tags: [SoccerTag] {
        let a = action
        switch a.kind {
        case .goal: return [.goal, .chance]
        case .shot: return a.shotResult?.isOnTarget == true || a.savedBy != nil ? [.chance, .save] : [.chance]
        case .save: return [.save]
        case .card: return [.card]
        case .foul, .offside: return [.foul]
        case .corner: return [.corner]
        case .substitution, .periodStart, .periodEnd: return []
        }
    }

}

extension SoccerAction {
    /// Whether this gets a clip from the glasses video (not the period markers).
    public var wantsClip: Bool { kind != .periodStart && kind != .periodEnd }
}

/// A soccer match's events by player and by category, for the gallery.
public struct SoccerGallery: Sendable {
    public struct PlayerEntry: Sendable, Identifiable, Equatable {
        public var player: PlayerKey
        public var name: String?
        public var events: [SoccerEvent]
        public var roles: [SoccerInvolvement.Role: Int]
        public var id: PlayerKey { player }
        public var clipCount: Int { events.filter { !$0.videoRefs.isEmpty }.count }

        /// "2 goals · 1 assist · 3 shots".
        public var roleSummary: String {
            SoccerInvolvement.Role.allCases.compactMap { r in roles[r].map { r.counted($0) } }.joined(separator: " · ")
        }
    }

    public let players: [PlayerEntry]
    public let byTag: [SoccerTag: [SoccerEvent]]

    public init(game: SoccerGame) {
        var map: [PlayerKey: PlayerEntry] = [:]
        var tags: [SoccerTag: [SoccerEvent]] = [:]
        for event in game.activeEvents {
            for inv in event.involvements {
                var entry = map[inv.player] ?? PlayerEntry(
                    player: inv.player, name: game.team(inv.player.team).roster?.name(for: inv.player.jersey),
                    events: [], roles: [:])
                if entry.events.last?.id != event.id { entry.events.append(event) }
                entry.roles[inv.role, default: 0] += 1
                map[inv.player] = entry
            }
            for tag in event.tags { tags[tag, default: []].append(event) }
        }
        players = map.values.sorted { $0.player < $1.player }
        byTag = tags
    }
}
