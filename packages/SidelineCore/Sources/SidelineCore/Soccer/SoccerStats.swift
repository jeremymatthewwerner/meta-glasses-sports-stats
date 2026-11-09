import Foundation

public struct SoccerPlayerStats: Codable, Sendable, Equatable {
    public var goals = 0
    public var penaltyGoals = 0
    public var headedGoals = 0
    public var assists = 0
    public var shots = 0             // includes goals
    public var shotsOnTarget = 0     // includes goals
    public var saves = 0
    public var foulsCommitted = 0
    public var foulsDrawn = 0
    public var yellowCards = 0
    public var redCards = 0
    public var offsides = 0
    public var ownGoals = 0
    public var subbedOn = 0
    public var subbedOff = 0

    public init() {}

    /// Anything worth a box-score line.
    public var isEmpty: Bool { self == SoccerPlayerStats() }

    /// "2 G, 1 A, 4 SH (3 on)" / "5 saves" / "1 YC".
    public var line: String {
        var parts: [String] = []
        if goals > 0 { parts.append("\(goals) G") }
        if assists > 0 { parts.append("\(assists) A") }
        if shots > 0 { parts.append("\(shots) SH (\(shotsOnTarget) on)") }
        if saves > 0 { parts.append("\(saves) \(saves == 1 ? "save" : "saves")") }
        if foulsCommitted > 0 { parts.append("\(foulsCommitted) F") }
        if yellowCards > 0 { parts.append("\(yellowCards) YC") }
        if redCards > 0 { parts.append("\(redCards) RC") }
        if offsides > 0 { parts.append("\(offsides) OFF") }
        if ownGoals > 0 { parts.append("\(ownGoals) OG") }
        return parts.isEmpty ? "–" : parts.joined(separator: ", ")
    }
}

public struct SoccerTeamStats: Codable, Sendable, Equatable {
    public var goals = 0
    public var shots = 0
    public var shotsOnTarget = 0
    public var corners = 0
    public var fouls = 0
    public var yellowCards = 0
    public var redCards = 0
    public var offsides = 0
    public var saves = 0

    public init() {}
}

public struct SoccerBoxScore: Sendable, Equatable {
    public var players: [PlayerKey: SoccerPlayerStats] = [:]
    public var teams: [TeamSide: SoccerTeamStats] = [.home: SoccerTeamStats(), .away: SoccerTeamStats()]

    public func team(_ side: TeamSide) -> SoccerTeamStats { teams[side] ?? SoccerTeamStats() }

    /// Players of a team with any stat, by jersey.
    public func roster(_ side: TeamSide) -> [(PlayerKey, SoccerPlayerStats)] {
        players.filter { $0.key.team == side && !$0.value.isEmpty }.sorted { $0.key.jersey < $1.key.jersey }
    }
}

extension SoccerGame {
    /// Stats from every event that counts (proposed and confirmed).
    public func boxScore() -> SoccerBoxScore {
        var box = SoccerBoxScore()
        func p(_ team: TeamSide, _ n: Int?, _ edit: (inout SoccerPlayerStats) -> Void) {
            guard let n else { return }
            edit(&box.players[PlayerKey(team: team, jersey: n), default: SoccerPlayerStats()])
        }
        func t(_ team: TeamSide, _ edit: (inout SoccerTeamStats) -> Void) {
            edit(&box.teams[team, default: SoccerTeamStats()])
        }
        for e in activeEvents {
            let a = e.action
            switch a.kind {
            case .goal:
                t(a.team) { $0.goals += 1 }
                if a.ownGoal {
                    p(a.team.opponent, a.player) { $0.ownGoals += 1 }
                } else {
                    t(a.team) { $0.shots += 1; $0.shotsOnTarget += 1 }
                    p(a.team, a.player) {
                        $0.goals += 1; $0.shots += 1; $0.shotsOnTarget += 1
                        if a.penalty { $0.penaltyGoals += 1 }
                        if a.header { $0.headedGoals += 1 }
                    }
                    p(a.team, a.assist) { $0.assists += 1 }
                }
            case .shot:
                let on = a.shotResult?.isOnTarget ?? false
                t(a.team) { $0.shots += 1; if on { $0.shotsOnTarget += 1 } }
                p(a.team, a.player) { $0.shots += 1; if on { $0.shotsOnTarget += 1 } }
                if on {
                    t(a.team.opponent) { $0.saves += 1 }
                    p(a.team.opponent, a.savedBy) { $0.saves += 1 }
                }
            case .save:
                // A save on its own implies an opposing shot on target.
                t(a.team) { $0.saves += 1 }
                p(a.team, a.player) { $0.saves += 1 }
                t(a.team.opponent) { $0.shots += 1; $0.shotsOnTarget += 1 }
            case .corner:
                t(a.team) { $0.corners += 1 }
            case .foul:
                t(a.team) { $0.fouls += 1 }
                p(a.team, a.player) { $0.foulsCommitted += 1 }
                p(a.team.opponent, a.fouled) { $0.foulsDrawn += 1 }
            case .card:
                let red = a.card == .red || a.card == .secondYellow
                t(a.team) { if red { $0.redCards += 1 } else { $0.yellowCards += 1 } }
                p(a.team, a.player) { if red { $0.redCards += 1 } else { $0.yellowCards += 1 } }
            case .offside:
                t(a.team) { $0.offsides += 1 }
                p(a.team, a.player) { $0.offsides += 1 }
            case .substitution:
                p(a.team, a.player) { $0.subbedOn += 1 }
                p(a.team, a.playerOff) { $0.subbedOff += 1 }
            case .periodStart, .periodEnd:
                break
            }
        }
        return box
    }
}

// MARK: - Text

extension SoccerGame {
    /// One line for an event: "Goal Eagles · #9 (assist #7)", "Shot #10, saved by #1".
    public func summary(_ e: SoccerEvent) -> String {
        let a = e.action
        let team = self.team(a.team).name
        func n(_ side: TeamSide, _ j: Int?) -> String { j.map { displayName(side, $0) } ?? "" }
        switch a.kind {
        case .goal:
            if a.ownGoal {
                return "Goal \(team) · own goal" + (a.player.map { " by \(displayName(a.team.opponent, $0))" } ?? "")
            }
            var s = "Goal \(team)"
            if a.player != nil { s += " · \(n(a.team, a.player))" }
            if a.penalty { s += " (penalty)" } else if a.header { s += " (header)" }
            if let as_ = a.assist { s += ", assist \(displayName(a.team, as_))" }
            return s
        case .shot:
            var s = (a.penalty ? "Penalty" : "Shot") + " \(team)" + (a.player != nil ? " \(n(a.team, a.player))" : "")
            switch a.shotResult {
            case .saved?: s += ", saved" + (a.savedBy.map { " by \(displayName(a.team.opponent, $0))" } ?? "")
            case .onTarget?: s += ", on target"
            case .wide?: s += ", wide"
            case .blocked?: s += ", blocked"
            case .woodwork?: s += ", off the woodwork"
            case nil: break
            }
            return s
        case .save:
            return "Save" + (a.player != nil ? " \(n(a.team, a.player))" : " \(team)")
        case .corner:
            return "Corner \(team)"
        case .foul:
            var s = "Foul" + (a.player != nil ? " by \(n(a.team, a.player))" : " \(team)")
            if let f = a.fouled { s += " on \(displayName(a.team.opponent, f))" }
            return s
        case .card:
            let c = a.card == .red ? "Red card" : (a.card == .secondYellow ? "Second yellow, red card" : "Yellow card")
            return "\(c) \(a.player != nil ? n(a.team, a.player) : team)" + (a.player != nil ? " (\(team))" : "")
        case .substitution:
            return "Sub \(team): \(n(a.team, a.player)) on" + (a.playerOff.map { " for \(displayName(a.team, $0))" } ?? "")
        case .offside:
            return "Offside" + (a.player != nil ? " \(n(a.team, a.player))" : " \(team)")
        case .periodStart:
            return "Start of \(format.periodName(a.period ?? 1))"
        case .periodEnd:
            let p = a.period ?? 1
            if p == format.periods { return "Full time" }
            return format.periods == 2 && p == 1 ? "Half time" : "End of \(format.periodName(p))"
        }
    }

    /// "Eagles 2, Hawks 1" (leader first) or "Tied 1–1".
    public func scoreText(_ s: SoccerGameState? = nil) -> String {
        let s = s ?? state
        let h = s.goals(.home), a = s.goals(.away)
        if h == a { return "Tied \(h)–\(a)" }
        return h > a ? "\(home.name) \(h), \(away.name) \(a)" : "\(away.name) \(a), \(home.name) \(h)"
    }

    /// Goals in order with minute and running score:
    /// "23′ Eagles #9 (assist #7) — 1–0".
    public func goalLog() -> [String] {
        var lines: [String] = []
        var h = 0, aw = 0
        for e in activeEvents where e.action.kind == .goal {
            if e.action.team == .home { h += 1 } else { aw += 1 }
            let minute = self.minute(of: e).map { "\($0)′ " } ?? ""
            lines.append("\(minute)\(summary(e).replacingOccurrences(of: "Goal ", with: "")) — \(h)–\(aw)")
        }
        return lines
    }

    /// Short written recap: result, scorers, and team stats.
    public func recap() -> String {
        let s = state
        let box = boxScore()
        var out = (isOver ? "Final: " : "So far: ") + scoreText(s) + "."
        let scorers = TeamSide.allCases.map { side -> String? in
            let g = box.roster(side).filter { $0.1.goals > 0 }
            guard !g.isEmpty else { return nil }
            return "\(team(side).name): " + g.map { "\(displayName(side, $0.0.jersey))\($0.1.goals > 1 ? " ×\($0.1.goals)" : "")" }
                .joined(separator: ", ")
        }.compactMap { $0 }
        if !scorers.isEmpty { out += " Scorers — " + scorers.joined(separator: "; ") + "." }
        let ht = box.team(.home), at = box.team(.away)
        if ht.shots + at.shots > 0 {
            out += " Shots \(home.name) \(ht.shots) (\(ht.shotsOnTarget) on target), \(away.name) \(at.shots) (\(at.shotsOnTarget))."
        }
        if ht.corners + at.corners > 0 { out += " Corners \(ht.corners)–\(at.corners)." }
        return out
    }
}

/// What the glasses' lens shows for soccer (same shape as `FootballHUD`).
///
///     HAWKS 1  –  EAGLES 2
///     2nd half · 63′
///     Goal Eagles · #9, assist #7
public struct SoccerHUD: Equatable, Sendable {
    public var scoreLine: String
    public var situationLine: String
    public var lastPlay: String?
    public var lastPlayID: UUID?
    public var lastPlayNeedsConfirm: Bool
    public var pendingCount: Int

    public init(game: SoccerGame, now: Date = Date()) {
        let s = game.state
        func side(_ t: TeamSide) -> String { "\(FootballHUD.shortName(game.team(t).name)) \(s.goals(t))" }
        scoreLine = "\(side(.away))  –  \(side(.home))"
        if s.period == 0 {
            situationLine = "Before kickoff"
        } else if let m = game.currentMinute(at: now) {
            situationLine = "\(game.format.periodName(s.period)) · \(m)′"
        } else {
            situationLine = game.isOver || s.period >= game.format.periods ? "Full time"
                : (game.format.periods == 2 && s.period == 1 ? "Half time" : "After \(game.format.periodName(s.period))")
        }
        let last = game.events.last { $0.status != .rejected && $0.action.kind != .periodStart }
        lastPlay = last.map { FootballHUD.truncate(game.summary($0), to: FootballHUD.maxPlayLength) }
        lastPlayID = last?.id
        lastPlayNeedsConfirm = last?.status == .proposed
        pendingCount = game.events.filter { $0.status == .proposed }.count
    }
}

extension SoccerHUD {
    /// The same content in the lens layout the glasses app renders.
    public func lens(redo: String? = nil) -> FootballHUD {
        FootballHUD(scoreLine: scoreLine, situationLine: situationLine, lastPlay: lastPlay, lastPlayID: lastPlayID,
                    lastPlayNeedsConfirm: lastPlayNeedsConfirm, pendingCount: pendingCount, redoPlay: redo)
    }
}
