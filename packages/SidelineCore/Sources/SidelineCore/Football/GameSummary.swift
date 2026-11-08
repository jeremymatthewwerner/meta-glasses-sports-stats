import Foundation

/// Everything the game page shows: score by quarter, scoring summary,
/// leaders, key plays and a short written recap. Derived from the event
/// log, so it is always consistent with the scorebook.
public struct GameSummary: Sendable {
    public struct ScoringPlay: Sendable, Equatable, Identifiable {
        public var id: UUID           // the event
        public var quarter: Int
        public var team: TeamSide
        public var points: Int
        public var description: String
        public var away: Int          // score after the play
        public var home: Int
    }

    public struct Leader: Sendable, Equatable, Identifiable {
        public var category: String   // "Passing", "Rushing", "Receiving", "Tackles"
        public var player: PlayerKey
        public var name: String       // "#22 Jane Smith"
        public var line: String       // "12 car, 88 yds, 1 TD"
        public var value: Double
        public var stats: FootballPlayerStats
        public var id: String { "\(category)-\(player.team.rawValue)-\(player.jersey)" }
    }

    public var away: String
    public var home: String
    public var score: [TeamSide: Int]
    /// Points per quarter (index 0 = Q1; a 5th entry is overtime).
    public var byQuarter: [TeamSide: [Int]]
    public var scoring: [ScoringPlay]
    public var leaders: [Leader]
    public var keyPlays: [FootballEvent]
    public var recap: String
    public var isOver: Bool

    public init(game: FootballGame, maxKeyPlays: Int = 8) {
        away = game.away.name
        home = game.home.name
        isOver = game.isOver

        var state = FootballGameState(possession: game.openingKickoff)
        var quarters: [TeamSide: [Int]] = [.home: [0, 0, 0, 0], .away: [0, 0, 0, 0]]
        var scoring: [ScoringPlay] = []
        for event in game.events where event.status != .rejected {
            let before = state
            FootballGame.apply(event, to: &state)
            let q = max(1, min(before.quarter, 5))
            for side in [TeamSide.away, .home] {
                let delta = state.points(side) - before.points(side)
                guard delta > 0 else { continue }
                while quarters[side]!.count < q { quarters[side]!.append(0) }
                quarters[side]![q - 1] += delta
                scoring.append(ScoringPlay(id: event.id, quarter: q, team: side, points: delta,
                                           description: event.summary, away: state.points(.away), home: state.points(.home)))
            }
        }
        let width = max(quarters[.home]!.count, quarters[.away]!.count)
        for side in [TeamSide.home, .away] { while quarters[side]!.count < width { quarters[side]!.append(0) } }
        score = [.home: state.points(.home), .away: state.points(.away)]
        byQuarter = quarters
        self.scoring = scoring

        let box = game.boxScore()
        leaders = Self.leaders(box: box, game: game)
        keyPlays = Array(game.events.filter { $0.status != .rejected }
            .filter { !$0.tags.intersection([.touchdown, .turnover, .bigPlay]).isEmpty }
            .prefix(maxKeyPlays))
        recap = ""
        recap = Self.recap(self, game: game, box: box)
    }

    // MARK: Leaders

    static func leaders(box: FootballBoxScore, game: FootballGame) -> [Leader] {
        var out: [Leader] = []
        func best(_ category: String, value: (FootballPlayerStats) -> Double, line: (FootballPlayerStats) -> String) {
            for side in [TeamSide.away, .home] {
                let candidates = box.players.filter { $0.key.team == side && value($0.value) > 0 }
                guard let top = candidates.max(by: { (value($0.value), -$0.key.jersey) < (value($1.value), -$1.key.jersey) })
                else { continue }
                out.append(Leader(category: category, player: top.key, name: game.displayName(top.key),
                                  line: line(top.value), value: value(top.value), stats: top.value))
            }
        }
        best("Passing", value: { Double($0.passYards) + 0.01 * Double($0.passAttempts) }) {
            "\($0.passCompletions)/\($0.passAttempts), \($0.passYards) yds" + td($0.passTouchdowns) + int($0.interceptionsThrown)
        }
        best("Rushing", value: { Double($0.rushYards) + 0.01 * Double($0.rushAttempts) }) {
            "\($0.rushAttempts) car, \($0.rushYards) yds" + td($0.rushTouchdowns)
        }
        best("Receiving", value: { Double($0.receivingYards) + 0.01 * Double($0.receptions) }) {
            "\($0.receptions) rec, \($0.receivingYards) yds" + td($0.receivingTouchdowns)
        }
        best("Tackles", value: { Double($0.totalTackles) + $0.sacks }) {
            "\($0.totalTackles) tkl" + ($0.sacks > 0 ? ", \(fmt($0.sacks)) sk" : "") + ($0.interceptions > 0 ? ", \($0.interceptions) int" : "")
        }
        return out
    }

    // MARK: Recap

    static func recap(_ s: GameSummary, game: FootballGame, box: FootballBoxScore) -> String {
        let h = s.score[.home] ?? 0, a = s.score[.away] ?? 0
        var sentences: [String] = []
        let (lead, trail, hi, lo) = h >= a ? (s.home, s.away, h, a) : (s.away, s.home, a, h)
        if s.isOver {
            sentences.append(h == a ? "\(s.home) and \(s.away) tied \(h)–\(a)." : "\(lead) beat \(trail) \(hi)–\(lo).")
        } else if game.events.isEmpty {
            return "No plays yet."
        } else {
            let q = game.state.quarter >= 5 ? "overtime" : "the \(FootballGameState.ordinal(game.state.quarter)) quarter"
            sentences.append(h == a ? "\(s.home) and \(s.away) are tied \(h)–\(a) in \(q)."
                                    : "\(lead) lead \(trail) \(hi)–\(lo) in \(q).")
        }
        // Top two individual performances by yards.
        let performances: [(Int, String)] = s.leaders.compactMap { l in
            let st = l.stats
            switch l.category {
            case "Passing":
                return (st.passYards, "\(l.name) threw for \(count(st.passYards, "yard"))" + touchdowns(st.passTouchdowns))
            case "Rushing":
                return (st.rushYards, "\(l.name) ran for \(count(st.rushYards, "yard")) on \(count(st.rushAttempts, "carry", "carries"))"
                    + touchdowns(st.rushTouchdowns))
            case "Receiving":
                return (st.receivingYards, "\(l.name) had \(count(st.receptions, "catch", "catches")) for \(count(st.receivingYards, "yard"))"
                    + touchdowns(st.receivingTouchdowns))
            default: return nil
            }
        }.sorted { $0.0 > $1.0 }
        let top = performances.prefix(2).map(\.1)
        if !top.isEmpty { sentences.append(top.joined(separator: "; ") + ".") }
        // Biggest play.
        if let big = game.events.filter({ $0.status != .rejected && $0.play != nil })
            .max(by: { gain($0) < gain($1) }), gain(big) >= PlayTag.bigGain {
            sentences.append("Biggest play: \(big.summary).")
        }
        let to = (box.team(.home).turnovers, box.team(.away).turnovers)
        if to.0 + to.1 > 0 {
            sentences.append("Turnovers: \(s.home) \(to.0), \(s.away) \(to.1).")
        }
        return sentences.joined(separator: " ")
    }
}

private func count(_ n: Int, _ one: String, _ many: String? = nil) -> String {
    "\(n) " + (n == 1 ? one : (many ?? one + "s"))
}

private func touchdowns(_ n: Int) -> String {
    n == 0 ? "" : n == 1 ? " and a touchdown" : " and \(n) touchdowns"
}

private func gain(_ e: FootballEvent) -> Int {
    guard let p = e.play else { return 0 }
    return max(p.isScrimmage ? (p.yards ?? 0) : 0, p.returnYards ?? 0)
}

private func td(_ n: Int) -> String { n > 0 ? ", \(n) TD" : "" }
private func int(_ n: Int) -> String { n > 0 ? ", \(n) INT" : "" }
private func fmt(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x) }

// MARK: - Season

extension FootballPlayerStats {
    /// Adds another game's line (season totals). Long field goal is a max.
    public mutating func add(_ o: FootballPlayerStats) {
        passCompletions += o.passCompletions; passAttempts += o.passAttempts; passYards += o.passYards
        passTouchdowns += o.passTouchdowns; interceptionsThrown += o.interceptionsThrown
        timesSacked += o.timesSacked; sackYardsLost += o.sackYardsLost
        rushAttempts += o.rushAttempts; rushYards += o.rushYards; rushTouchdowns += o.rushTouchdowns
        targets += o.targets; receptions += o.receptions; receivingYards += o.receivingYards
        receivingTouchdowns += o.receivingTouchdowns
        soloTackles += o.soloTackles; assistedTackles += o.assistedTackles; sacks += o.sacks
        interceptions += o.interceptions; defensiveTouchdowns += o.defensiveTouchdowns
        forcedFumbles += o.forcedFumbles; fumbleRecoveries += o.fumbleRecoveries
        fumbles += o.fumbles; fumblesLost += o.fumblesLost
        fieldGoalsMade += o.fieldGoalsMade; fieldGoalsAttempted += o.fieldGoalsAttempted
        longFieldGoal = max(longFieldGoal, o.longFieldGoal)
        extraPointsMade += o.extraPointsMade; extraPointsAttempted += o.extraPointsAttempted
        twoPointConversions += o.twoPointConversions
        punts += o.punts; puntYards += o.puntYards; kickoffs += o.kickoffs
        kickReturns += o.kickReturns; kickReturnYards += o.kickReturnYards
        puntReturns += o.puntReturns; puntReturnYards += o.puntReturnYards
        penalties += o.penalties; penaltyYards += o.penaltyYards
    }
}

/// One team's season across saved games: record and per-player totals.
public struct SeasonStats: Sendable {
    public struct Player: Sendable, Identifiable, Equatable {
        public var jersey: Int
        public var name: String?
        public var games: Int
        public var stats: FootballPlayerStats
        public var id: Int { jersey }
        public var label: String { name.map { "#\(jersey) \($0)" } ?? "#\(jersey)" }
    }

    public var team: String
    public var games: Int
    public var wins = 0, losses = 0, ties = 0, inProgress = 0
    public var pointsFor = 0, pointsAgainst = 0
    public var players: [Player]

    public var record: String {
        "\(wins)–\(losses)" + (ties > 0 ? "–\(ties)" : "") + (inProgress > 0 ? " (\(inProgress) in progress)" : "")
    }

    /// Games whose home or away name matches `team` (case-insensitive).
    public init(team: String, games all: [FootballGame]) {
        self.team = team
        var totals: [Int: Player] = [:]
        var count = 0
        let key = team.trimmingCharacters(in: .whitespaces).lowercased()
        for g in all.sorted(by: { $0.date < $1.date }) {
            let side: TeamSide
            if g.home.name.lowercased() == key { side = .home }
            else if g.away.name.lowercased() == key { side = .away }
            else { continue }
            count += 1
            let s = g.state
            let us = s.points(side), them = s.points(side.opponent)
            pointsFor += us
            pointsAgainst += them
            if !g.isOver { inProgress += 1 }
            else if us > them { wins += 1 } else if us < them { losses += 1 } else { ties += 1 }
            for (jersey, stats) in g.boxScore().players(of: side) {
                var p = totals[jersey] ?? Player(jersey: jersey, name: nil, games: 0, stats: FootballPlayerStats())
                p.stats.add(stats)
                p.games += 1
                if let n = g.team(side).roster?.name(for: jersey) { p.name = n }
                totals[jersey] = p
            }
        }
        games = count
        players = totals.values.sorted { $0.jersey < $1.jersey }
    }

    /// Every real team name across games, most games first ("Home"/"Away"
    /// placeholders from unnamed games are left out).
    public static func teamNames(in games: [FootballGame]) -> [String] {
        var counts: [String: Int] = [:]
        for g in games {
            for name in [g.home.name, g.away.name] where !["home", "away", ""].contains(name.lowercased()) {
                counts[name, default: 0] += 1
            }
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }
}
