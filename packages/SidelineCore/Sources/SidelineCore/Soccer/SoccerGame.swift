import Foundation

/// Match format: players a side and how the clock is split. Youth soccer
/// varies a lot (7v7 in 2×25, 9v9 in 2×30, 4 quarters at the youngest ages).
public struct SoccerFormat: Codable, Sendable, Equatable, Hashable {
    public var playersPerSide: Int
    public var periods: Int
    public var periodMinutes: Int

    public init(playersPerSide: Int, periods: Int, periodMinutes: Int) {
        self.playersPerSide = playersPerSide
        self.periods = periods
        self.periodMinutes = periodMinutes
    }

    public static let full = SoccerFormat(playersPerSide: 11, periods: 2, periodMinutes: 45)
    public static let highSchool = SoccerFormat(playersPerSide: 11, periods: 2, periodMinutes: 40)
    public static let youth11 = SoccerFormat(playersPerSide: 11, periods: 2, periodMinutes: 35)
    public static let nineASide = SoccerFormat(playersPerSide: 9, periods: 2, periodMinutes: 30)
    public static let sevenASide = SoccerFormat(playersPerSide: 7, periods: 2, periodMinutes: 25)
    public static let quarters = SoccerFormat(playersPerSide: 4, periods: 4, periodMinutes: 10)

    public static let presets: [SoccerFormat] = [.full, .highSchool, .youth11, .nineASide, .sevenASide, .quarters]

    public var label: String {
        "\(playersPerSide)v\(playersPerSide), \(periods == 2 ? "2 halves" : "\(periods) quarters") of \(periodMinutes)′"
    }

    /// "1st half", "2nd half", "Q3", "ET 1".
    public func periodName(_ p: Int) -> String {
        if p > periods { return "ET \(p - periods)" }
        if periods == 2 { return p == 1 ? "1st half" : "2nd half" }
        return "Q\(p)"
    }
}

/// One soccer event, raw facts only: stats are derived (`SoccerStats`).
/// `team` is the team the action belongs to: the scorer's team for a goal
/// (for an own goal, the team that gets the goal), the shooter's team, the
/// goalkeeper's team for a save, the fouling team, the carded player's team,
/// the team making a substitution, the team caught offside, the team taking
/// a corner.
public struct SoccerAction: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case goal, shot, save, corner, foul, card, substitution, offside
        case periodStart, periodEnd
    }

    public enum ShotResult: String, Codable, Sendable {
        case saved, wide, blocked, woodwork
        /// "On target" without saying what happened: counted as saved.
        case onTarget
        public var isOnTarget: Bool { self == .saved || self == .onTarget }
    }

    public enum Card: String, Codable, Sendable { case yellow, secondYellow, red }

    public var kind: Kind
    public var team: TeamSide
    /// Scorer, shooter, goalkeeper, fouling player, carded player, player
    /// coming on, or player offside. For an own goal: the defender who put
    /// it in (on `team.opponent`).
    public var player: Int?
    public var assist: Int?
    public var ownGoal = false
    public var penalty = false
    public var header = false
    public var shotResult: ShotResult?
    /// The opposing goalkeeper on a saved shot.
    public var savedBy: Int?
    /// The opposing player fouled.
    public var fouled: Int?
    public var card: Card?
    /// Player going off in a substitution.
    public var playerOff: Int?
    /// Period number for periodStart / periodEnd (1-based).
    public var period: Int?

    public init(kind: Kind, team: TeamSide, player: Int? = nil) {
        self.kind = kind
        self.team = team
        self.player = player
    }

    public var isScoring: Bool { kind == .goal }
}

/// A logged soccer event with provenance and video, like `FootballEvent`.
public struct SoccerEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var action: SoccerAction
    public var source: EventSource
    public var status: EventStatus
    public var confidence: Double
    public var transcript: String?
    public var wallTime: Date
    public var videoRefs: [VideoRef]
    public var cv: CVPlayNote?

    public init(id: UUID = UUID(), action: SoccerAction, source: EventSource, status: EventStatus = .proposed,
                confidence: Double = 1, transcript: String? = nil, wallTime: Date = Date(), videoRefs: [VideoRef] = []) {
        self.id = id
        self.action = action
        self.source = source
        self.status = status
        self.confidence = confidence
        self.transcript = transcript
        self.wallTime = wallTime
        self.videoRefs = videoRefs
    }
}

/// Derived match situation; never stored.
public struct SoccerGameState: Codable, Sendable, Equatable {
    public var score: [TeamSide: Int] = [.home: 0, .away: 0]
    /// Current or most recent period (0 before kickoff).
    public var period = 0
    public var running = false
    /// Wall-clock start of the running period, for the match minute.
    public var periodStartedAt: Date?
    /// Players sent off, by team.
    public var sentOff: [TeamSide: Set<Int>] = [.home: [], .away: []]
    /// Yellow cards so far, by team and jersey.
    public var yellows: [TeamSide: [Int: Int]] = [.home: [:], .away: [:]]

    public init() {}

    public func goals(_ side: TeamSide) -> Int { score[side] ?? 0 }
}

/// A soccer match: teams, format and the ordered event log.
public struct SoccerGame: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var home: TeamInfo
    public var away: TeamInfo
    public var format: SoccerFormat
    /// The team whose numbers a call means when it names no team ("goal 9"):
    /// usually the wearer's own team. "We/us" is this team, "they/them" the other.
    public var focus: TeamSide
    public var events: [SoccerEvent]
    public var ended: Bool?

    public var isOver: Bool { ended == true }

    public init(id: UUID = UUID(), date: Date = Date(), home: TeamInfo, away: TeamInfo, format: SoccerFormat = .full,
                focus: TeamSide = .home, events: [SoccerEvent] = []) {
        self.id = id
        self.date = date
        self.home = home
        self.away = away
        self.format = format
        self.focus = focus
        self.events = events
    }

    public func team(_ side: TeamSide) -> TeamInfo { side == .home ? home : away }

    public var activeEvents: [SoccerEvent] { events.filter { $0.status != .rejected } }

    public var state: SoccerGameState { state(after: events.count) }

    public func state(after count: Int) -> SoccerGameState {
        var s = SoccerGameState()
        for e in events.prefix(count) where e.status != .rejected { Self.apply(e, to: &s, format: format) }
        return s
    }

    @discardableResult
    public mutating func append(_ event: SoccerEvent) -> UUID {
        events.append(event)
        return event.id
    }

    @discardableResult
    public mutating func rejectLast() -> SoccerEvent? {
        guard let i = events.lastIndex(where: { $0.status != .rejected }) else { return nil }
        events[i].status = .rejected
        return events[i]
    }

    public mutating func setStatus(_ status: EventStatus, for id: UUID) {
        guard let i = events.firstIndex(where: { $0.id == id }) else { return }
        events[i].status = status
    }

    static func apply(_ e: SoccerEvent, to s: inout SoccerGameState, format: SoccerFormat) {
        let a = e.action
        switch a.kind {
        case .goal:
            s.score[a.team, default: 0] += 1
        case .periodStart:
            s.period = a.period ?? (s.period + 1)
            s.running = true
            s.periodStartedAt = e.wallTime
        case .periodEnd:
            if let p = a.period { s.period = p }
            s.running = false
            s.periodStartedAt = nil
        case .card:
            guard let n = a.player else { break }
            if a.card == .yellow || a.card == nil {        // a card of unknown colour counts as yellow
                s.yellows[a.team, default: [:]][n, default: 0] += 1
                if s.yellows[a.team]?[n] ?? 0 >= 2 { s.sentOff[a.team, default: []].insert(n) }
            } else {
                s.sentOff[a.team, default: []].insert(n)
            }
        default:
            break
        }
    }

    /// Match minute of an event, counted like a broadcast (1-based, each
    /// period starting where the previous ones' regulation time ended), or
    /// nil before kickoff.
    public func minute(of event: SoccerEvent) -> Int? {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return nil }
        let before = state(after: idx)
        guard before.running, let start = before.periodStartedAt else { return nil }
        let elapsed = max(0, event.wallTime.timeIntervalSince(start))
        return (before.period - 1) * format.periodMinutes + Int(elapsed / 60) + 1
    }

    /// The minute shown on a scoreboard right now (nil when the clock isn't running).
    public func currentMinute(at now: Date = Date()) -> Int? {
        let s = state
        guard s.running, let start = s.periodStartedAt else { return nil }
        return (s.period - 1) * format.periodMinutes + Int(max(0, now.timeIntervalSince(start)) / 60) + 1
    }

    /// "#9 Ava Lee" when the roster knows the number.
    public func displayName(_ team: TeamSide, _ jersey: Int) -> String {
        if let name = self.team(team).roster?.name(for: jersey) { return "#\(jersey) \(name)" }
        return "#\(jersey)"
    }
}
