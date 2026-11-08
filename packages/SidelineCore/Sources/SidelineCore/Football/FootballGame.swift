import Foundation

/// Derived game situation. Never stored; always recomputed from the event
/// log, so editing or rejecting an event fixes everything downstream.
public struct FootballGameState: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable {
        case kickoff     // next snap is a free kick by `possession`
        case scrimmage   // normal downs
        case tryAfterTD  // PAT / two-point try by `possession`
    }

    public var score: [TeamSide: Int] = [.home: 0, .away: 0]
    public var possession: TeamSide
    public var phase: Phase = .kickoff
    public var quarter: Int = 1
    public var down: Int?          // nil when not in scrimmage or unknown
    public var distance: Int?
    public var goalToGo = false
    /// Yards from the possessing team's own goal (1–99), when known.
    public var ballOn: Int?

    public init(possession: TeamSide) {
        self.possession = possession
    }

    public func points(_ side: TeamSide) -> Int { score[side] ?? 0 }

    /// "2nd & 7 at own 35", "1st & Goal at opp 4", "Kickoff", "PAT".
    public var situationText: String {
        switch phase {
        case .kickoff: return "Kickoff"
        case .tryAfterTD: return "Try (PAT / 2-pt)"
        case .scrimmage:
            guard let down else { return "Scrimmage" }
            let dist = goalToGo ? "Goal" : distance.map(String.init) ?? "?"
            var text = "\(Self.ordinal(down)) & \(dist)"
            if let ballOn { text += " at " + Self.spotText(ballOn) }
            return text
        }
    }

    static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(n)th"
        }
    }

    static func spotText(_ ballOn: Int) -> String {
        if ballOn == 50 { return "50" }
        return ballOn < 50 ? "own \(ballOn)" : "opp \(100 - ballOn)"
    }
}

/// A football game: teams, rule set and the ordered event log.
public struct FootballGame: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var home: TeamInfo
    public var away: TeamInfo
    public var ruleSet: FootballRuleSet
    /// Which team kicks off to start the game.
    public var openingKickoff: TeamSide
    public var events: [FootballEvent]
    /// Set when the scorer marks the game over (older saves: nil = in progress).
    public var ended: Bool?

    public var isOver: Bool { ended == true }

    public init(
        id: UUID = UUID(), date: Date = Date(), home: TeamInfo, away: TeamInfo,
        ruleSet: FootballRuleSet = .nfhs, openingKickoff: TeamSide = .away, events: [FootballEvent] = []
    ) {
        self.id = id
        self.date = date
        self.home = home
        self.away = away
        self.ruleSet = ruleSet
        self.openingKickoff = openingKickoff
        self.events = events
    }

    public func team(_ side: TeamSide) -> TeamInfo { side == .home ? home : away }

    /// Events that count: everything not rejected.
    public var activeEvents: [FootballEvent] { events.filter { $0.status != .rejected } }

    /// Current situation after replaying all active events.
    public var state: FootballGameState { state(after: events.count) }

    /// Situation after the first `count` events of the log.
    public func state(after count: Int) -> FootballGameState {
        var s = FootballGameState(possession: openingKickoff)
        for event in events.prefix(count) where event.status != .rejected {
            Self.apply(event, to: &s)
        }
        return s
    }

    /// Adds an event and returns its id.
    @discardableResult
    public mutating func append(_ event: FootballEvent) -> UUID {
        events.append(event)
        return event.id
    }

    /// Marks the most recent non-rejected event as rejected (voice "undo").
    @discardableResult
    public mutating func rejectLast() -> FootballEvent? {
        guard let idx = events.lastIndex(where: { $0.status != .rejected }) else { return nil }
        events[idx].status = .rejected
        return events[idx]
    }

    public mutating func setStatus(_ status: EventStatus, for id: UUID) {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { return }
        events[idx].status = status
    }

    // MARK: - State machine

    static func apply(_ event: FootballEvent, to s: inout FootballGameState) {
        if let play = event.play {
            applyPlay(play, offense: event.offense, to: &s)
        }
        if let u = event.situation {
            if let q = u.quarter { s.quarter = q }
            if let p = u.possession { s.possession = p }
            if u.down != nil || u.distance != nil || u.ballOn != nil { s.phase = .scrimmage }
            if let d = u.down { s.down = d }
            if let d = u.distance { s.distance = d; s.goalToGo = false }
            if let g = u.goalToGo { s.goalToGo = g }
            if let b = u.ballOn { s.ballOn = b }
            if s.goalToGo, let b = s.ballOn { s.distance = 100 - b }
        }
    }

    static func applyPlay(_ p: FootballPlay, offense: TeamSide, to s: inout FootballGameState) {
        let defense = offense.opponent

        // Scoring first; it decides what comes next.
        if p.touchdown {
            let scorer = p.isDefensiveTouchdown ? defense : offense
            s.score[scorer, default: 0] += 6
            setTry(by: scorer, &s)
            return
        }
        if p.safety {
            s.score[defense, default: 0] += 2
            setKickoff(by: offense, &s)   // free kick by the team that conceded
            return
        }

        switch p.kind {
        case .extraPoint:
            if p.kickResult == .good { s.score[offense, default: 0] += 1 }
            setKickoff(by: offense, &s)

        case .twoPoint:
            if p.kickResult == .good { s.score[offense, default: 0] += 2 }
            setKickoff(by: offense, &s)

        case .fieldGoal:
            if p.kickResult == .good {
                s.score[offense, default: 0] += 3
                setKickoff(by: offense, &s)
            } else {
                // Missed/blocked: defense takes over (spot not tracked here).
                let spot = s.ballOn.map { 100 - $0 }
                setFirstDown(for: defense, ballOn: spot, &s)
            }

        case .kickoff:
            // NFHS kickoffs are from the kicking team's 40, so the ball lands at
            // the receiver's (60 − distance); touchback to the 20 if no return.
            var spot: Int?
            if let d = p.kickDistance {
                spot = (d >= 60 && p.returnYards == nil) ? 20 : 60 - d + (p.returnYards ?? 0)
                spot = spot.map { max(1, min(99, $0)) }
            }
            setFirstDown(for: defense, ballOn: spot, &s)

        case .punt:
            var spot: Int?
            if let b = s.ballOn, let d = p.kickDistance {
                spot = 100 - (b + d) + (p.returnYards ?? 0)
                spot = spot.map { max(1, min(99, $0)) }
            }
            setFirstDown(for: defense, ballOn: spot, &s)

        case .penalty:
            applyPenalty(p.penalty, &s)

        case .rush, .pass, .sack, .kneel, .spike:
            if p.isTurnover {
                setFirstDown(for: defense, ballOn: nil, &s)
                return
            }
            s.phase = .scrimmage
            let gain = (p.passResult == .incomplete || p.kind == .spike) ? 0 : (p.yards ?? 0)
            if let b = s.ballOn { s.ballOn = max(1, min(99, b + gain)) }
            if let pen = p.penalty {
                applyPenalty(pen, &s)
                return
            }
            if let dist = s.distance {
                let remaining = dist - gain
                if remaining <= 0 {
                    setFirstDown(for: offense, ballOn: s.ballOn, &s)
                } else {
                    s.distance = remaining
                    advanceDown(offense: offense, &s)
                }
            } else {
                advanceDown(offense: offense, &s)
            }
        }
    }

    static func advanceDown(offense: TeamSide, _ s: inout FootballGameState) {
        let next = (s.down ?? 0) + 1
        if s.down != nil, next > 4 {
            // Turnover on downs.
            setFirstDown(for: offense.opponent, ballOn: s.ballOn.map { 100 - $0 }, &s)
        } else if s.down != nil {
            s.down = next
        }
    }

    static func applyPenalty(_ pen: Penalty?, _ s: inout FootballGameState) {
        guard let pen else { return }
        s.phase = .scrimmage
        let offenseGain = pen.on == .defense ? pen.yards : -pen.yards
        if let b = s.ballOn { s.ballOn = max(1, min(99, b + offenseGain)) }
        if pen.on == .defense, pen.automaticFirstDown {
            setFirstDown(for: s.possession, ballOn: s.ballOn, &s)
            return
        }
        if let d = s.distance {
            let remaining = d - offenseGain
            if remaining <= 0 {
                setFirstDown(for: s.possession, ballOn: s.ballOn, &s)
            } else {
                s.distance = remaining   // replay the down
            }
        }
    }

    static func setFirstDown(for team: TeamSide, ballOn: Int?, _ s: inout FootballGameState) {
        s.possession = team
        s.phase = .scrimmage
        s.down = 1
        s.ballOn = ballOn
        if let b = ballOn, 100 - b <= 10 {
            s.goalToGo = true
            s.distance = 100 - b
        } else {
            s.goalToGo = false
            s.distance = 10
        }
    }

    static func setTry(by team: TeamSide, _ s: inout FootballGameState) {
        s.possession = team
        s.phase = .tryAfterTD
        s.down = nil
        s.distance = nil
        s.goalToGo = false
        s.ballOn = 97   // NFHS try from the 3
    }

    static func setKickoff(by team: TeamSide, _ s: inout FootballGameState) {
        s.possession = team
        s.phase = .kickoff
        s.down = nil
        s.distance = nil
        s.goalToGo = false
        s.ballOn = nil
    }
}
