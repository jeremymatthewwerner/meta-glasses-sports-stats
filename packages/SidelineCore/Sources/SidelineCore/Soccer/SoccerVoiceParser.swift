import Foundation

/// One parsed soccer call.
public struct ParsedSoccerCall: Sendable, Equatable {
    public enum Command: String, Sendable { case undo, redo }

    public var raw: String
    public var normalized: String
    public var action: SoccerAction?
    public var command: Command?
    public var confidence: Double
    public var notes: [String]

    public var isEmpty: Bool { action == nil && command == nil }
}

/// Deterministic grammar for soccer calls, as a sideline parent or coach says them:
///
///     "goal 9, assist 7"        "7 to 9, goal"         "Hawks goal, 10"
///     "penalty goal 10"         "own goal by their 4"  "header goal 5 from 11"
///     "shot 10 saved by 1"      "9 shoots wide"        "shot blocked"   "off the post, 8"
///     "save 1"                  "corner us"            "corner Hawks"
///     "foul by 14 on 6"         "free kick for us"     "yellow card 4 away"   "red card their 5"
///     "12 on for 7"             "sub 12 for 7"         "offside 9"
///     "kickoff" "half time" "start of the second half" "full time"
///     "undo" / "scratch that"   "redo"
///
/// A call that names no team means the game's focus team (the wearer's
/// own); "we/us/our" is the focus team and "they/them/their" the other.
public enum SoccerVoiceParser {

    public static func parse(_ raw: String, game: SoccerGame) -> ParsedSoccerCall {
        let text = normalize(raw)
        var out = ParsedSoccerCall(raw: raw, normalized: text, action: nil, command: nil, confidence: 1, notes: [])
        guard !text.isEmpty else { out.confidence = 0; return out }

        if m(text, #"^(redo|re do|put (it|that) back|bring (it|that) back|restore( that| it)?|undo (the |that )?undo)$"#) {
            out.command = .redo
            return out
        }
        if m(text, #"^(undo|scratch that|cancel|cancel that|delete( that| last)?|never ?mind|take that back)$"#) {
            out.command = .undo
            return out
        }
        if let a = period(text, game: game) {
            out.action = a
            return out
        }

        let (named, rest) = team(in: text, game: game)
        func resolve(_ fallback: TeamSide) -> TeamSide {
            if let named { return named }
            out.confidence = min(out.confidence, 0.9)
            out.notes.append("assumed \(game.team(fallback).name)")
            return fallback
        }

        let t = rest
        let scoring = m(t, #"\b(scores?|scored|nets|netted|finish(es|ed)?)\b"#)
            || (m(t, #"\bgoal\b"#) && !m(t, #"\bgoal ?kick\b|\bgoal ?keeper\b|\bgoalie\b|\bon goal\b|\bgoal ?line\b|\bno goal\b|\bdisallowed\b"#))
        if m(t, #"\bno goal\b|\bdisallowed\b"#) {
            out.notes.append("disallowed goal: say “undo” to remove a goal")
            out.confidence = 0
            return out
        }

        if m(t, #"\bown goal\b|\bown net\b"#) {
            // The team named is the player's own team; the goal goes to the other side.
            let playerTeam = named ?? game.focus.opponent
            if named == nil { out.notes.append("assumed own goal by \(game.team(playerTeam).name)"); out.confidence = 0.9 }
            var a = SoccerAction(kind: .goal, team: playerTeam.opponent, player: int(t, #"(\d+)"#))
            a.ownGoal = true
            out.action = a
            return out
        }

        if scoring {
            var scorer: Int?, assist: Int?
            if let g = groups(t, #"(\d+) (?:to|finds|feeds|sets up|crosses to|passes to|through to) (\d+)"#),
               let a1 = g[0].flatMap(Int.init), let s1 = g[1].flatMap(Int.init) {
                assist = a1; scorer = s1
            }
            scorer = scorer
                ?? int(t, #"\b(?:goal|scored)(?: by| for)? (\d+)"#)
                ?? int(t, #"(\d+) (?:scores|scored|nets|netted|goal|finishes|with the goal|puts it in)"#)
            assist = assist
                ?? int(t, #"\bassist(?:ed)?(?: by| from)? (\d+)"#)
                ?? int(t, #"(\d+) (?:with the )?assist"#)
                ?? int(t, #"\b(?:set up by|pass from|cross from|feed from|ball from) (\d+)"#)
            if scorer == nil { scorer = int(t, #"\bgoal from (\d+)"#) }
            if assist == nil, let s = scorer, let f = int(t, #"\bfrom (\d+)"#), f != s { assist = f }
            if scorer == nil, let only = numbers(t).first { scorer = only; out.confidence = min(out.confidence, 0.8) }
            if scorer == nil { out.notes.append("scorer not named") }
            var a = SoccerAction(kind: .goal, team: resolve(game.focus), player: scorer)
            a.assist = assist == scorer ? nil : assist
            a.penalty = m(t, #"\bpenalty\b|\bpk\b|\bspot kick\b"#)
            a.header = m(t, #"\bheader\b|\bheaded\b|\bheads? (it|in)\b"#)
            out.action = a
            return out
        }

        if m(t, #"\byellow\b|\bred\b|\bbooked\b|\bbooking\b|\bsent off\b|\bejected\b|\bcard\b"#) {
            var a = SoccerAction(kind: .card, team: resolve(game.focus), player: numbers(t).first)
            a.card = m(t, #"\bsecond yellow\b"#) ? .secondYellow : (m(t, #"\bred\b|\bsent off\b|\bejected\b"#) ? .red : .yellow)
            out.action = a
            return out
        }

        if m(t, #"\bsub\b|\bsubstitution\b|\bsubbing\b|\bcomes? on\b|\bcoming on\b|\b(on|in) for\b|\breplaces\b|\bin,? \d+ out\b|\bout,? \d+ in\b"#) {
            var on: Int?, off: Int?
            if let g = groups(t, #"(\d+) out,? (\d+) in"#) { off = g[0].flatMap(Int.init); on = g[1].flatMap(Int.init) }
            else if let g = groups(t, #"(\d+) (?:in|on|comes on|coming on|replaces|replacing)?,? ?(?:for )?(\d+)(?: out)?"#),
                    g[0] != nil, g[1] != nil {
                on = g[0].flatMap(Int.init); off = g[1].flatMap(Int.init)
            }
            if on == nil { on = numbers(t).first }
            var a = SoccerAction(kind: .substitution, team: resolve(game.focus), player: on)
            a.playerOff = off
            out.action = a
            return out
        }

        if m(t, #"\boffside\b|\boff side\b"#) {
            out.action = SoccerAction(kind: .offside, team: resolve(game.focus.opponent), player: numbers(t).first)
            return out
        }

        if m(t, #"\bcorner\b"#) {
            out.action = SoccerAction(kind: .corner, team: resolve(game.focus))
            return out
        }

        if m(t, #"\bfoul\b|\bfouls\b|\bfouled\b|\bfree kick\b|\btripped\b|\bhandball\b|\bhand ball\b"#) {
            var by: Int?, on: Int?
            if let g = groups(t, #"\bfoul on (\d+) by (\d+)"#) { on = g[0].flatMap(Int.init); by = g[1].flatMap(Int.init) }
            else if let g = groups(t, #"\bfoul by (\d+) on (\d+)"#) { by = g[0].flatMap(Int.init); on = g[1].flatMap(Int.init) }
            else if let g = groups(t, #"(\d+) (?:fouls|trips|tripped|takes down) (\d+)"#) { by = g[0].flatMap(Int.init); on = g[1].flatMap(Int.init) }
            else if let g = groups(t, #"(\d+) (?:fouled|tripped|taken down) by (\d+)"#) { on = g[0].flatMap(Int.init); by = g[1].flatMap(Int.init) }
            else if let n = int(t, #"\bfoul on (\d+)"#) { on = n }
            else { by = int(t, #"\b(?:foul|handball|hand ball)(?: by)? (\d+)"#) ?? int(t, #"(\d+) (?:foul|handball)"#) }
            // "free kick for us": the other team fouled. Otherwise the named team fouled.
            let freeKickFor = m(t, #"\bfree kick\b"#) && !m(t, #"\bfoul\b"#)
            let fouling: TeamSide
            if freeKickFor { fouling = (named ?? resolve(game.focus)).opponent }
            else if on != nil && by == nil { fouling = (named ?? resolve(game.focus)).opponent }   // "foul on our 7"
            else { fouling = resolve(game.focus.opponent) }
            var a = SoccerAction(kind: .foul, team: fouling, player: by)
            a.fouled = on
            out.action = a
            return out
        }

        let shotWords = #"\bshot\b|\bshoots\b|\bshooting\b|\beffort\b|\battempt\b|\bstrike\b|\bfires\b|\bheader\b|\bpenalty\b|\bpk\b|\bwide\b|\bover the bar\b|\bblocked\b|\bpost\b|\bcrossbar\b|\bwoodwork\b|\bon target\b|\bon goal\b"#
        if m(t, shotWords) {
            // A team named after "saved by" is the keeper's ("shot 10 saved by their 1"): the shot is the other side's.
            var shooter: TeamSide?
            if let r = text.range(of: #"\b(saved|save|stopped)\b"#, options: .regularExpression) {
                let head = team(in: String(text[..<r.lowerBound]), game: game).0
                let keeper = team(in: String(text[r.lowerBound...]), game: game).0
                shooter = head ?? keeper?.opponent
            }
            var a = SoccerAction(kind: .shot, team: shooter ?? resolve(game.focus))
            a.player = int(t, #"\b(?:shot|shoots|effort|attempt|strike|header|fires|penalty|pk)(?: by| from)? (\d+)"#)
                ?? int(t, #"(\d+) (?:shot|shoots|fires|strikes|heads|with a shot|with the header|header)"#)
            if m(t, #"\bsaved\b|\bsave\b|\bstopped\b|\bkept out\b"#) {
                a.shotResult = .saved
                a.savedBy = int(t, #"\b(?:saved|save|stopped)(?: by)? (\d+)"#)
            } else if m(t, #"\bwide\b|\bover\b|\bhigh\b|\boff target\b|\bmiss(es|ed)?\b|\bmissed\b"#) {
                a.shotResult = .wide
            } else if m(t, #"\bblocked\b"#) {
                a.shotResult = .blocked
            } else if m(t, #"\bpost\b|\bbar\b|\bcrossbar\b|\bwoodwork\b|\bupright\b"#) {
                a.shotResult = .woodwork
            } else if m(t, #"\bon target\b|\bon goal\b"#) {
                a.shotResult = .onTarget
            }
            a.penalty = m(t, #"\bpenalty\b|\bpk\b|\bspot kick\b"#)
            if a.player == nil, let n = numbers(t).first(where: { $0 != a.savedBy }) { a.player = n }
            out.action = a
            return out
        }

        if m(t, #"\bsave\b|\bsaves\b|\bsaved\b|\bstop\b"#) {
            out.action = SoccerAction(kind: .save, team: resolve(game.focus), player: numbers(t).first)
            return out
        }

        out.confidence = 0
        out.notes.append("not a soccer call I know")
        return out
    }

    // MARK: - Periods

    static func period(_ t: String, game: SoccerGame) -> SoccerAction? {
        let s = game.state
        let fmt = game.format
        func start(_ p: Int) -> SoccerAction { var a = SoccerAction(kind: .periodStart, team: .home); a.period = p; return a }
        func end(_ p: Int) -> SoccerAction { var a = SoccerAction(kind: .periodEnd, team: .home); a.period = p; return a }
        let ordinal = #"(first|1|second|2|third|3|fourth|4)"#
        func n(_ w: String) -> Int { ["first": 1, "1": 1, "second": 2, "2": 2, "third": 3, "3": 3, "fourth": 4, "4": 4][w] ?? 1 }

        if let g = groups(t, #"^(?:start|beginning|kick ?off)(?: of)?(?: the)? "# + ordinal + #" (?:half|quarter|period)$"#), let w = g[0] {
            return start(n(w))
        }
        if let g = groups(t, #"^"# + ordinal + #" (?:half|quarter|period) (?:kick ?off|underway|starts?|started|begins?)$"#), let w = g[0] {
            return start(n(w))
        }
        if let g = groups(t, #"^end(?: of)?(?: the)? "# + ordinal + #" (?:half|quarter|period)$"#), let w = g[0] {
            return end(n(w))
        }
        if m(t, #"^(full ?time|final whistle|end of (the )?(game|match)|game over|that's the game|final)$"#) {
            return end(max(s.period, fmt.periods))
        }
        if m(t, #"^half ?time$"#) {
            return end(fmt.periods == 2 ? 1 : max(1, s.period))
        }
        if m(t, #"^(start of )?extra time$"#) {
            return start(max(s.period, fmt.periods) + 1)
        }
        if m(t, #"^(kick ?off|we're underway|we are underway|(the )?(game|match) (is )?(underway|started|starts)|start(ing)?( of)?( the)? (game|match)|start the clock|restart|second half)$"#) {
            if s.period == 0 { return start(1) }
            return s.running ? nil : start(s.period + 1)
        }
        return nil
    }

    // MARK: - Teams

    /// Which team the call names, and the text with the team words removed.
    static func team(in t: String, game: SoccerGame) -> (TeamSide?, String) {
        var text = " \(t) "
        var found: TeamSide?
        func take(_ pattern: String, _ side: TeamSide) {
            if text.range(of: pattern, options: .regularExpression) != nil {
                if found == nil { found = side }
                text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
            }
        }
        for side in TeamSide.allCases {
            for name in Set([game.team(side).name, game.team(side).shortName]).map({ normalize($0) }) where name.count >= 2 {
                take(#"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\b"#, side)
            }
        }
        take(#"\bhome\b"#, .home)
        take(#"\b(away|visitors?|visiting)\b"#, .away)
        take(#"\b(we|us|our|ours|my team)\b"#, game.focus)
        take(#"\b(they|them|their|theirs|opponents?|other team)\b"#, game.focus.opponent)
        return (found, text.split(separator: " ").joined(separator: " "))
    }

    // MARK: - Text helpers

    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "’", with: "'")
        s = s.replacingOccurrences(of: "-", with: " ")
        s = String(s.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" ? $0 : " " })
        s = s.split(separator: " ").joined(separator: " ")
        s = NumberWords.digitize(s)
        for (p, r) in [(#"\bnumber (\d+)"#, "$1"), (#"\bno (\d+)\b"#, "$1"), (#"\bkeeper\b|\bgoalkeeper\b|\bgoalie\b"#, "keeper"),
                       (#"\bhalf time\b"#, "halftime"), (#"\bfull time\b"#, "fulltime")] {
            s = s.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        // Spelled-together forms back to the grammar's words.
        s = s.replacingOccurrences(of: "halftime", with: "half time").replacingOccurrences(of: "fulltime", with: "full time")
        return s
    }

    static func m(_ t: String, _ pattern: String) -> Bool { t.range(of: pattern, options: .regularExpression) != nil }

    static func groups(_ t: String, _ pattern: String) -> [String?]? { FootballVoiceParser.groups(t, pattern) }

    static func int(_ t: String, _ pattern: String) -> Int? { FootballVoiceParser.int(t, pattern) }

    /// Jersey-like numbers (0–99) in order.
    static func numbers(_ t: String) -> [Int] {
        t.split(separator: " ").compactMap { Int($0) }.filter { (0...99).contains($0) }
    }
}
