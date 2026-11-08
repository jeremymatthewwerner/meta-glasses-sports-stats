import Foundation

/// Spoken cues for the wearer, played in the glasses' open-ear speakers:
/// a play-clock countdown, the situation after each play, score changes,
/// and the wearer's own running stats in player mode.

// MARK: Settings

public struct CueSettings: Codable, Sendable, Equatable {
    /// Which play-clock lengths to use.
    public enum ClockRule: String, Codable, Sendable, CaseIterable, Identifiable {
        /// 40 s from the end of a play; 25 s after administrative stops
        /// (scores, kicks, changes of possession, penalties, new quarter).
        /// NFHS, NCAA and NFL all work this way.
        case fortyTwentyFive
        /// Always 25 s from the ready-for-play (many youth leagues).
        case twentyFive

        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .fortyTwentyFive: "40 / 25 (HS, college, NFL)"
            case .twentyFive: "25 always (youth)"
            }
        }
    }

    public var playClockVoice = true
    /// Start the play clock by itself when a play is called, backdated to
    /// when the call began (about when the ball was whistled dead).
    public var autoStartClock = true
    public var clockRule: ClockRule = .fortyTwentyFive
    /// Seconds left at which the countdown is spoken; 0 is spoken as "time".
    public var countdownMarks: [Int] = [20, 10, 5, 4, 3, 2, 1, 0]
    public var announceSituation = true
    public var announceScore = true
    /// Player mode: the wearer's jersey, for "your stats" callouts.
    public var me: PlayerKey?
    public var announceMyStats = true
    /// Speaking rate, 0.3–0.65 (AVSpeechUtterance scale; 0.5 is normal).
    public var voiceRate: Double = 0.52

    public init() {}
}

// MARK: Play clock

public struct PlayClock: Codable, Sendable, Equatable {
    public private(set) var startedAt: Date?
    public private(set) var length: TimeInterval = 40

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public mutating func start(_ seconds: TimeInterval, at date: Date) {
        startedAt = date
        length = seconds
    }

    public mutating func stop() { startedAt = nil }

    /// Seconds left (never below 0), or nil when stopped.
    public func remaining(at now: Date) -> TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, length - now.timeIntervalSince(startedAt))
    }

    /// Whole seconds shown on a clock face: 17.2 s left shows 18, like a stadium clock.
    public func display(at now: Date) -> Int? {
        remaining(at: now).map { Int($0.rounded(.up)) }
    }

    /// The clock for the Display lens, in coarse steps ("40", "under 30",
    /// … "under 5", "TIME"). Each lens update is a full re-send that resets
    /// the Neural Band's button focus, so the lens changes only ~6 times per
    /// play; the exact countdown is spoken and shown on the phone.
    public func lensText(at now: Date) -> String? {
        guard let left = remaining(at: now) else { return nil }
        if left <= 0 { return "TIME" }
        for step in [5.0, 10, 20, 30] where left <= step && step < length { return "under \(Int(step))" }
        return "\(Int(length))"
    }

    /// Countdown marks crossed between two ticks (largest first). A mark is
    /// crossed when the remaining time drops to or below it.
    public func marksCrossed(_ marks: [Int], from previous: Date, to now: Date) -> [Int] {
        guard let before = remaining(at: previous), let after = remaining(at: now) else { return [] }
        return marks.filter { Double($0) < before && Double($0) >= after - 0.000_1 }.sorted(by: >)
    }

    /// The length after `event`, given the states before and after it.
    public static func length(after event: FootballEvent, before: FootballGameState, after: FootballGameState,
                              rule: CueSettings.ClockRule) -> TimeInterval {
        if rule == .twentyFive { return 25 }
        // 25 s: administrative stops and changes of possession.
        guard let play = event.play else { return 25 }                        // quarter change / correction
        if before.score != after.score { return 25 }                          // any score, including the try
        if before.possession != after.possession { return 25 }                // turnover, punt, kick, downs
        if before.quarter != after.quarter { return 25 }
        switch play.kind {
        case .kickoff, .punt, .fieldGoal, .extraPoint, .twoPoint, .penalty: return 25
        default: break
        }
        if play.penalty != nil { return 25 }
        return 40
    }
}

// MARK: Spoken text

public enum CueComposer {
    /// "Eagles ball. Second and 7 at the Hawks 35." Uses team names and
    /// words that read well aloud.
    public static func situation(_ game: FootballGame) -> String {
        let s = game.state
        let offense = game.team(s.possession).name
        let defense = game.team(s.possession.opponent).name
        switch s.phase {
        case .kickoff: return "\(offense) kicking off."
        case .tryAfterTD: return "\(offense) try after touchdown."
        case .scrimmage:
            guard let down = s.down else { return "\(offense) ball." }
            let d = ordinalWord(down)
            let dist = s.goalToGo ? "goal" : s.distance.map(String.init) ?? "unknown"
            var text = "\(offense) ball. \(d) and \(dist)"
            if let spot = s.ballOn {
                if spot == 50 { text += " at midfield" }
                else if spot < 50 { text += " at the \(offense) \(spot)" }
                else { text += " at the \(defense) \(100 - spot)" }
            }
            return text + "."
        }
    }

    /// "Touchdown Eagles. Eagles 14, Hawks 7." when the score changed.
    public static func scoreChange(_ game: FootballGame, before: FootballGameState, event: FootballEvent? = nil) -> String? {
        let after = game.state
        guard after.score != before.score else { return nil }
        let scorer = TeamSide.allCases.max { (after.points($0) - before.points($0)) < (after.points($1) - before.points($1)) }!
        let delta = after.points(scorer) - before.points(scorer)
        let what: String
        switch delta {
        case 6: what = "Touchdown"
        case 3: what = "Field goal"
        case 2: what = event?.play?.safety == true ? "Safety" : "Two-point conversion"
        case 1: what = "Extra point"
        default: what = "\(delta) points"
        }
        let home = game.home.name, away = game.away.name
        let h = after.points(.home), a = after.points(.away)
        let line = h == a ? "Tied at \(h)." : (h > a ? "\(home) \(h), \(away) \(a)." : "\(away) \(a), \(home) \(h).")
        return "\(what) \(game.team(scorer).name). \(line)"
    }

    /// The wearer's running totals when they were in the play:
    /// "You: 3 catches, 52 yards." Nil when they weren't involved.
    public static func myStats(_ game: FootballGame, event: FootballEvent, me: PlayerKey) -> String? {
        let roles = Set(event.involvements.filter { $0.player == me }.map(\.role))
        guard !roles.isEmpty, let st = game.boxScore().players[me] else { return nil }
        var parts: [String] = []
        if roles.contains(.passer) {
            parts.append("\(st.passCompletions) of \(st.passAttempts), \(count(st.passYards, "yard"))"
                         + (st.passTouchdowns > 0 ? ", \(count(st.passTouchdowns, "touchdown"))" : ""))
        }
        if roles.contains(.carrier) {
            parts.append("\(count(st.rushAttempts, "carry", "carries")), \(count(st.rushYards, "yard"))"
                         + (st.rushTouchdowns > 0 ? ", \(count(st.rushTouchdowns, "touchdown"))" : ""))
        }
        if roles.contains(.receiver) && st.receptions > 0 {
            parts.append("\(count(st.receptions, "catch", "catches")), \(count(st.receivingYards, "yard"))"
                         + (st.receivingTouchdowns > 0 ? ", \(count(st.receivingTouchdowns, "touchdown"))" : ""))
        }
        if roles.contains(.tackler) { parts.append(count(st.totalTackles, "tackle")) }
        if roles.contains(.sacker) {
            let s = st.sacks == st.sacks.rounded() ? String(Int(st.sacks)) : String(format: "%.1f", st.sacks)
            parts.append(st.sacks == 1 ? "1 sack" : "\(s) sacks")
        }
        if roles.contains(.interceptor) { parts.append(count(st.interceptions, "interception")) }
        guard !parts.isEmpty else { return nil }
        return "You: " + parts.joined(separator: ". ") + "."
    }

    /// Everything to say after a play was added, in priority order.
    public static func afterEvent(_ event: FootballEvent, game: FootballGame, before: FootballGameState,
                                  settings: CueSettings) -> String? {
        var lines: [String] = []
        if settings.announceScore, let s = scoreChange(game, before: before, event: event) { lines.append(s) }
        if settings.announceMyStats, let me = settings.me, let s = myStats(game, event: event, me: me) { lines.append(s) }
        if settings.announceSituation, !game.isOver { lines.append(situation(game)) }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    /// "Ten", "5"… spoken countdown; 0 is "Time".
    public static func countdown(_ mark: Int) -> String { mark == 0 ? "Time!" : "\(mark)" }

    static func ordinalWord(_ n: Int) -> String {
        switch n {
        case 1: "First"
        case 2: "Second"
        case 3: "Third"
        case 4: "Fourth"
        default: "Down \(n)"
        }
    }

    static func count(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        n == 1 ? "1 \(one)" : "\(n) \(many ?? one + "s")"
    }
}
