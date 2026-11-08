import Foundation

/// Stat-credit conventions differ by level (research: stat_data_models.md).
/// Raw plays are stored once; the box score is computed under a rule set,
/// so switching rule sets just recomputes.
public struct FootballRuleSet: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var name: String
    /// NCAA: a sack that causes a fumble gets no sack credit (the fumble
    /// is credited instead). NFL: credits the sack and the forced fumble.
    public var sackCausingFumbleCreditsSack: Bool
    /// NCAA: sack yardage counts as the passer's rushing (attempt + yards).
    /// NFL: sacks are charged against team passing, not rushing.
    public var sackYardsCountAsRushing: Bool

    public static let ncaa = FootballRuleSet(
        id: "ncaa", name: "NCAA", sackCausingFumbleCreditsSack: false, sackYardsCountAsRushing: true)
    /// High school stat crews generally follow NCAA statistics conventions
    /// (NFHS publishes playing rules, not a stats manual). Verify per state.
    public static let nfhs = FootballRuleSet(
        id: "nfhs", name: "High school (NFHS)", sackCausingFumbleCreditsSack: false, sackYardsCountAsRushing: true)
    public static let nfl = FootballRuleSet(
        id: "nfl", name: "NFL", sackCausingFumbleCreditsSack: true, sackYardsCountAsRushing: false)

    public static let all: [FootballRuleSet] = [.nfhs, .ncaa, .nfl]
}

public struct PlayerKey: Codable, Sendable, Hashable, Comparable {
    public var team: TeamSide
    public var jersey: Int

    public init(team: TeamSide, jersey: Int) {
        self.team = team
        self.jersey = jersey
    }

    public static func < (a: PlayerKey, b: PlayerKey) -> Bool {
        (a.team.rawValue, a.jersey) < (b.team.rawValue, b.jersey)
    }
}

public struct FootballPlayerStats: Codable, Sendable, Equatable {
    // Passing
    public var passCompletions = 0, passAttempts = 0, passYards = 0, passTouchdowns = 0, interceptionsThrown = 0
    public var timesSacked = 0, sackYardsLost = 0
    // Rushing
    public var rushAttempts = 0, rushYards = 0, rushTouchdowns = 0
    // Receiving
    public var targets = 0, receptions = 0, receivingYards = 0, receivingTouchdowns = 0
    // Defense
    public var soloTackles = 0, assistedTackles = 0
    public var sacks: Double = 0
    public var interceptions = 0, defensiveTouchdowns = 0
    public var forcedFumbles = 0, fumbleRecoveries = 0
    // Ball security
    public var fumbles = 0, fumblesLost = 0
    // Kicking / returns
    public var fieldGoalsMade = 0, fieldGoalsAttempted = 0, longFieldGoal = 0
    public var extraPointsMade = 0, extraPointsAttempted = 0
    public var twoPointConversions = 0
    public var punts = 0, puntYards = 0, kickoffs = 0
    public var kickReturns = 0, kickReturnYards = 0, puntReturns = 0, puntReturnYards = 0
    // Penalties charged to this player
    public var penalties = 0, penaltyYards = 0

    public init() {}

    public var totalTackles: Int { soloTackles + assistedTackles }
    public var points: Int {
        6 * (rushTouchdowns + receivingTouchdowns + defensiveTouchdowns)
            + 3 * fieldGoalsMade + extraPointsMade + 2 * twoPointConversions
    }
}

public struct FootballTeamTotals: Codable, Sendable, Equatable {
    public var points = 0
    public var plays = 0
    public var rushYards = 0, passYards = 0
    public var firstDowns = 0
    public var turnovers = 0
    public var penalties = 0, penaltyYards = 0
    public var thirdDownAttempts = 0, thirdDownConversions = 0

    public init() {}
    public var totalYards: Int { rushYards + passYards }
}

public struct FootballBoxScore: Codable, Sendable, Equatable {
    public var ruleSet: FootballRuleSet
    public var teams: [TeamSide: FootballTeamTotals]
    public var players: [PlayerKey: FootballPlayerStats]

    public func team(_ side: TeamSide) -> FootballTeamTotals { teams[side] ?? FootballTeamTotals() }

    /// Players of one side, sorted by jersey.
    public func players(of side: TeamSide) -> [(jersey: Int, stats: FootballPlayerStats)] {
        players.filter { $0.key.team == side }
            .sorted { $0.key.jersey < $1.key.jersey }
            .map { ($0.key.jersey, $0.value) }
    }
}

extension FootballGame {
    /// Box score under the game's rule set (or an override).
    public func boxScore(ruleSet override: FootballRuleSet? = nil) -> FootballBoxScore {
        let rules = override ?? ruleSet
        var players: [PlayerKey: FootballPlayerStats] = [:]
        var teams: [TeamSide: FootballTeamTotals] = [.home: .init(), .away: .init()]

        func credit(_ side: TeamSide, _ jersey: Int?, _ update: (inout FootballPlayerStats) -> Void) {
            guard let jersey else { return }
            update(&players[PlayerKey(team: side, jersey: jersey), default: FootballPlayerStats()])
        }

        var stateBefore = FootballGameState(possession: openingKickoff)
        for event in events where event.status != .rejected {
            defer { FootballGame.apply(event, to: &stateBefore) }
            guard let p = event.play else { continue }
            let off = event.offense
            let def = off.opponent
            let ownTD = p.touchdown && !p.isDefensiveTouchdown

            if p.isScrimmage { teams[off]!.plays += 1 }
            if p.isScrimmage, stateBefore.down == 3 {
                teams[off]!.thirdDownAttempts += 1
                if let d = stateBefore.distance, let y = p.yards, !p.isTurnover,
                   p.passResult != .incomplete, y >= d || ownTD {
                    teams[off]!.thirdDownConversions += 1
                }
            }

            switch p.kind {
            case .rush, .kneel:
                let y = p.yards ?? 0
                credit(off, p.ballCarrier) {
                    $0.rushAttempts += 1
                    $0.rushYards += y
                    if ownTD { $0.rushTouchdowns += 1 }
                }
                teams[off]!.rushYards += y

            case .pass:
                credit(off, p.passer) { $0.passAttempts += 1 }
                credit(off, p.receiver) { $0.targets += 1 }
                switch p.passResult {
                case .complete:
                    let y = p.yards ?? 0
                    credit(off, p.passer) {
                        $0.passCompletions += 1
                        $0.passYards += y
                        if ownTD { $0.passTouchdowns += 1 }
                    }
                    credit(off, p.receiver) {
                        $0.receptions += 1
                        $0.receivingYards += y
                        if ownTD { $0.receivingTouchdowns += 1 }
                    }
                    teams[off]!.passYards += y
                case .intercepted:
                    credit(off, p.passer) { $0.interceptionsThrown += 1 }
                    credit(def, p.interceptedBy) {
                        $0.interceptions += 1
                        if p.touchdown { $0.defensiveTouchdowns += 1 }
                    }
                case .incomplete, .none:
                    break
                }

            case .sack:
                let loss = p.yards ?? 0
                let causedFumble = p.fumbledBy != nil
                let creditSack = !causedFumble || rules.sackCausingFumbleCreditsSack
                if creditSack, !p.sackers.isEmpty {
                    let share = 1.0 / Double(p.sackers.count)
                    for s in p.sackers { credit(def, s) { $0.sacks += share } }
                }
                credit(off, p.passer) {
                    $0.timesSacked += 1
                    $0.sackYardsLost += -min(0, loss)
                    if rules.sackYardsCountAsRushing {
                        $0.rushAttempts += 1
                        $0.rushYards += loss
                    }
                }
                if rules.sackYardsCountAsRushing { teams[off]!.rushYards += loss } else { teams[off]!.passYards += loss }

            case .spike:
                credit(off, p.passer) { $0.passAttempts += 1 }

            case .fieldGoal:
                let good = p.kickResult == .good
                credit(off, p.kicker) {
                    $0.fieldGoalsAttempted += 1
                    if good {
                        $0.fieldGoalsMade += 1
                        $0.longFieldGoal = max($0.longFieldGoal, p.kickDistance ?? 0)
                    }
                }

            case .extraPoint:
                credit(off, p.kicker) {
                    $0.extraPointsAttempted += 1
                    if p.kickResult == .good { $0.extraPointsMade += 1 }
                }

            case .twoPoint:
                if p.kickResult == .good {
                    credit(off, p.receiver ?? p.ballCarrier) { $0.twoPointConversions += 1 }
                }

            case .punt:
                credit(off, p.kicker) {
                    $0.punts += 1
                    $0.puntYards += p.kickDistance ?? 0
                }
                credit(def, p.returner) {
                    $0.puntReturns += 1
                    $0.puntReturnYards += p.returnYards ?? 0
                    if p.touchdown { $0.defensiveTouchdowns += 1 }
                }

            case .kickoff:
                credit(off, p.kicker) { $0.kickoffs += 1 }
                credit(def, p.returner) {
                    $0.kickReturns += 1
                    $0.kickReturnYards += p.returnYards ?? 0
                    if p.touchdown { $0.defensiveTouchdowns += 1 }
                }

            case .penalty:
                break
            }

            // Tackles (sacks are recorded through `sackers`, which also earn tackle credit).
            let tacklers = p.kind == .sack ? p.sackers : p.tacklers
            if tacklers.count == 1 {
                credit(def, tacklers[0]) { $0.soloTackles += 1 }
            } else {
                for t in tacklers { credit(def, t) { $0.assistedTackles += 1 } }
            }

            // Fumbles
            if let f = p.fumbledBy {
                credit(off, f) {
                    $0.fumbles += 1
                    if p.fumbleLost { $0.fumblesLost += 1 }
                }
                credit(def, p.forcedFumbleBy) { $0.forcedFumbles += 1 }
                credit(p.fumbleLost ? def : off, p.fumbleRecoveredBy) {
                    $0.fumbleRecoveries += 1
                    if p.fumbleLost, p.touchdown { $0.defensiveTouchdowns += 1 }
                }
            }
            if p.isTurnover { teams[off]!.turnovers += 1 }

            // Penalties
            if let pen = p.penalty {
                let side = pen.on == .offense ? off : def
                teams[side]!.penalties += 1
                teams[side]!.penaltyYards += pen.yards
                credit(side, pen.player) {
                    $0.penalties += 1
                    $0.penaltyYards += pen.yards
                }
            }

            // First downs: compare derived states around the play.
            var after = stateBefore
            FootballGame.apply(event, to: &after)
            let movedChains = p.kind != .kickoff && p.kind != .punt && !p.isTurnover
                && after.possession == off && after.phase == .scrimmage && after.down == 1
                && stateBefore.phase == .scrimmage && stateBefore.down != nil
            // A touchdown that reached the line to gain also counts as a first down.
            let tdPastLine = ownTD && p.isScrimmage && (stateBefore.distance.map { (p.yards ?? 0) >= $0 } ?? false)
            if movedChains || tdPastLine { teams[off]!.firstDowns += 1 }
        }

        let final = state
        teams[.home]!.points = final.points(.home)
        teams[.away]!.points = final.points(.away)
        return FootballBoxScore(ruleSet: rules, teams: teams, players: players)
    }
}
