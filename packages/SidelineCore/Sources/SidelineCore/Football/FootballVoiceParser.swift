import Foundation

/// The result of parsing one spoken (or typed) play call.
public struct ParsedUtterance: Sendable, Equatable {
    public enum Command: String, Sendable, Equatable { case undo, redo }

    public var raw: String
    public var normalized: String
    public var play: FootballPlay?
    public var situation: SituationUpdate?
    public var command: Command?
    /// 0–1. Lowered whenever the parser had to assume something.
    public var confidence: Double
    /// Human-readable notes on assumptions ("assumed rush", "fumble assumed lost").
    public var notes: [String]

    public var isEmpty: Bool { play == nil && (situation?.isEmpty ?? true) && command == nil }
}

/// Deterministic grammar for football play calls, as a stat-keeper says them:
///
///     "22 run for 7, tackle by 54"
///     "11 to 80 for 15, touchdown"
///     "incomplete to 80"              "sack by 90 and 55 for a loss of 8"
///     "interception by 24 returned for 30"
///     "field goal is good from 32"    "extra point good"
///     "punt by 4 for 38 returned by 10 for 6"
///     "holding on 72, 10 yards"       "second and 7"   "ball on their 35"
///     "undo" / "scratch that"
///
/// Jersey numbers on offense belong to the team in possession and on
/// defense to the other team; the caller supplies possession. Anything the
/// grammar can't place is left for review (and later an LLM fallback).
public enum FootballVoiceParser {

    public static func parse(_ raw: String) -> ParsedUtterance {
        var notes: [String] = []
        var confidence = 1.0
        let text = normalize(raw)
        var result = ParsedUtterance(raw: raw, normalized: text, play: nil, situation: nil,
                                     command: nil, confidence: 1, notes: [])

        if text.isEmpty { result.confidence = 0; return result }

        // Commands
        if matches(text, #"^(redo|re do|put (it|that) back|bring (it|that) back|restore( that| it)?|undo (the |that )?undo)$"#) {
            result.command = .redo
            return result
        }
        if matches(text, #"^(undo|scratch that|cancel|cancel that|delete( that| last)?|never ?mind|take that back)$"#) {
            result.command = .undo
            return result
        }

        // Situation corrections (can accompany a play, but usually standalone).
        result.situation = parseSituation(text)

        // Strip clauses that would confuse yardage extraction.
        var rest = text
        let penalty = parsePenalty(&rest)
        let ret = parseReturn(&rest)

        let kind = detectKind(rest, hasPenalty: penalty != nil, notes: &notes, confidence: &confidence)
        guard var play = kind.map(FootballPlay.init(kind:)) else {
            // Situation-only or nothing.
            result.notes = notes
            result.confidence = (result.situation?.isEmpty ?? true) ? 0 : 0.9
            return result
        }
        play.penalty = penalty
        if let ret {
            play.returner = ret.returner
            play.returnYards = ret.yards
        }

        switch play.kind {
        case .rush, .kneel:
            play.ballCarrier = int(rest, #"(\d+) (?:runs?|rush(?:es)?|carr(?:y|ies)|keeper|scrambles?|kneels?|takes it)"#)
                ?? int(rest, #"(?:run|rush|carry|keeper|scramble) (?:by|for) (\d+)(?! yard)"#)
                ?? int(rest, #"^(\d+)\b(?! yard)"#)
                ?? int(rest, #"touchdown (?:by )?(\d+)"#)
            play.yards = scrimmageYards(rest)
            if play.yards == nil, play.kind == .rush { notes.append("yards not heard"); confidence -= 0.25 }

        case .pass:
            if let m = groups(rest, #"(\d+) (?:pass(?:es)?|throws?|hits|finds|completes?|to) (?:(?:complete|completed|a pass) )?(?:to )?(\d+)"#),
               let a = m[0], let b = m[1] {
                play.passer = Int(a)
                play.receiver = Int(b)
            } else {
                play.receiver = int(rest, #"(?:to|for|intended for|caught by|catch by|reception by) (\d+)(?! yard)"#)
                    ?? int(rest, #"(\d+) (?:catch(?:es)?|reception|grabs it|hauls it in)"#)
                play.passer = int(rest, #"(\d+) (?:pass(?:es)?|throws?|incomplete)"#)
            }
            if contains(rest, "interception") || contains(rest, "intercepted") {
                play.passResult = .intercepted
                play.interceptedBy = int(rest, #"intercept(?:ed|ion)(?: by)? (\d+)"#)
                    ?? int(rest, #"(\d+) (?:with the )?interception"#)
                if play.interceptedBy == nil { notes.append("interceptor not heard"); confidence -= 0.1 }
            } else if contains(rest, "incomplete") || contains(rest, "dropped") || contains(rest, "broken up") {
                play.passResult = .incomplete
                play.yards = 0
            } else {
                play.passResult = .complete
                play.yards = scrimmageYards(rest)
                if play.yards == nil { notes.append("yards not heard"); confidence -= 0.25 }
            }

        case .sack:
            play.sackers = numberList(after: #"(?:sack(?:ed)?|sacked) by"#, in: rest)
            if play.sackers.isEmpty, let s = int(rest, #"(\d+) (?:with the |gets the |for the )?sack"#) { play.sackers = [s] }
            play.passer = int(rest, #"(\d+) (?:is |was )?sacked"#)
            if let y = scrimmageYards(rest) { play.yards = -abs(y) } else { notes.append("sack yardage not heard"); confidence -= 0.2 }

        case .spike:
            play.passer = int(rest, #"(\d+) spikes?"#)

        case .fieldGoal:
            play.kicker = kickerNumber(rest)
            play.kickResult = kickResult(rest) ?? { notes.append("FG result not heard"); confidence -= 0.4; return nil }()
            play.kickDistance = int(rest, #"(\d+) (?:yard|yarder)"#) ?? int(rest, #"from (\d+)"#)

        case .extraPoint:
            play.kicker = kickerNumber(rest)
            play.kickResult = kickResult(rest) ?? { notes.append("PAT result not heard"); confidence -= 0.4; return nil }()

        case .twoPoint:
            play.kickResult = (contains(rest, "fail") || contains(rest, "no good") || contains(rest, "stopped") || contains(rest, "incomplete"))
                ? .missed : .good
            play.receiver = int(rest, #"to (\d+)"#)
            play.ballCarrier = play.receiver == nil ? int(rest, #"(\d+) (?:runs?|rush|carr)"#) : nil

        case .punt:
            play.kicker = kickerNumber(rest)
            play.kickDistance = int(rest, #"(?:punt|punts|punted)(?: by \d+)? (?:for )?(\d+)"#)
                ?? int(rest, #"(\d+) yard punt"#)

        case .kickoff:
            play.kicker = kickerNumber(rest)
            play.kickDistance = int(rest, #"kick ?off(?: by \d+)? (?:for )?(\d+)"#)
            if contains(rest, "touchback") { play.kickDistance = play.kickDistance ?? 60 }

        case .penalty:
            break
        }

        // Defense: tacklers (not for sacks, which use sackers).
        if play.kind != .sack {
            play.tacklers = numberList(after: #"(?:tackled? by|tackle by|tackles? (?:made )?by|stopped by|brought down by|pushed out by|made by)"#, in: rest)
            if play.tacklers.isEmpty, let t = int(rest, #"(\d+) (?:with the |on the |makes the )?(?:tackle|stop)"#) {
                play.tacklers = [t]
            }
        }

        // Fumbles
        if contains(rest, "fumble") {
            play.fumbledBy = int(rest, #"(\d+) fumbles?"#) ?? int(rest, #"fumbled? by (\d+)"#) ?? play.ballCarrier ?? play.receiver
            play.forcedFumbleBy = int(rest, #"forced by (\d+)"#) ?? int(rest, #"(\d+) forces?"#)
            play.fumbleRecoveredBy = int(rest, #"recover(?:ed|s|y)?(?: by)? (\d+)"#) ?? int(rest, #"(\d+) recovers"#)
            if matches(rest, #"(offense|we) (recover|keep|retain)|recovered by (the )?offense|still our ball|kept it"#) {
                play.fumbleLost = false
            } else if matches(rest, #"defense|they recover|turnover|lost|recovered by|recovers"#) {
                play.fumbleLost = true
                if !matches(rest, #"defense|they recover|turnover|lost"#) {
                    notes.append("fumble assumed lost"); confidence -= 0.15
                }
            } else {
                notes.append("fumble recovery not heard"); confidence -= 0.2
            }
        }

        // Scoring
        play.touchdown = matches(rest, #"\btouchdown\b|\bscores?\b|\binto the end ?zone\b|pick six"#)
        play.safety = contains(rest, "safety")

        result.play = play
        result.notes = notes
        result.confidence = max(0, min(1, confidence))
        return result
    }

    // MARK: - Normalization

    static func normalize(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "#", with: " ")
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: "’", with: "'")
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = String(s.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" ? $0 : " " })
        s = s.split(separator: " ").joined(separator: " ")
        s = NumberWords.digitize(s)

        let replacements: [(String, String)] = [
            (#"\bnumber (\d+)"#, "$1"),
            (#"\bno\.? (\d+)"#, "$1"),
            (#"\b(\d+)(?:st|nd|rd|th)\b"#, "$1"),
            (#"\btd\b"#, "touchdown"),
            (#"\bpicked off by\b"#, "intercepted by"),
            (#"\bpicked off\b"#, "intercepted"),
            (#"\bpick by\b"#, "interception by"),
            (#"\bpick\b(?! six)"#, "interception"),
            (#"\bincompletion\b"#, "incomplete"),
            (#"\bp ?a ?t\b|\bpoint after( attempt)?\b|\bextra point attempt\b|\bkick after\b"#, "extra point"),
            (#"\bf ?g\b"#, "field goal"),
            (#"\b(2|two) (point|pt)( conversion| try)?\b"#, "two point"),
            (#"\bkick off\b|\bkick off\b"#, "kickoff"),
            (#"\bit's good\b|\bit is good\b|\bis good\b"#, "good"),
            (#"\bno good\b|\bwide (left|right)\b|\bshort\b|\bdoinked\b"#, "missed"),
            (#"\bloses?\b"#, "loss of"),
            (#"\bnegative\b|\bminus\b"#, "loss of"),
            (#"\bthe (\d+) yard line\b"#, "the $1"),
            (#"\byards?\b"#, "yard"),
        ]
        for (pattern, template) in replacements {
            s = s.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return s.split(separator: " ").joined(separator: " ")
    }

    // MARK: - Clauses

    static func detectKind(_ t: String, hasPenalty: Bool, notes: inout [String], confidence: inout Double) -> FootballPlay.Kind? {
        if contains(t, "extra point") { return .extraPoint }
        if contains(t, "two point") { return .twoPoint }
        if contains(t, "field goal") { return .fieldGoal }
        if matches(t, #"\bpunts?\b|\bpunted\b"#) { return .punt }
        if contains(t, "kickoff") || contains(t, "touchback") { return .kickoff }
        if matches(t, #"\bsack"#) { return .sack }
        if matches(t, #"\bspikes?\b"#) { return .spike }
        if matches(t, #"\bkneels?\b|victory formation|takes a knee"#) { return .kneel }
        if matches(t, #"\bpass|complete|incomplete|intercept|\bthrows?\b|\bcatch|reception|\bhits \d+|\bfinds \d+|\d+ to \d+|^to \d+|\bto \d+ for\b|dropped|broken up"#) {
            return .pass
        }
        if matches(t, #"\bruns?\b|\brush|\bcarr(y|ies)|keeper|scramble|up the middle|sweep|draw|dive|off tackle"#) { return .rush }
        // "22 for 7", "22 for no gain", "22 loss of 3": a bare carrier + yardage is a rush.
        if matches(t, #"^\d+ (for|loss of)"#) || matches(t, #"\bfor no gain\b"#) {
            notes.append("assumed rush"); confidence -= 0.1
            return .rush
        }
        if matches(t, #"\b(touchdown|fumble|tackle)"#) {
            notes.append("play type not heard, assumed rush"); confidence -= 0.3
            return .rush
        }
        if hasPenalty { return .penalty }
        return nil
    }

    /// Net yards on a scrimmage play: "for 7", "for no gain", "for a loss of 3", "7 yard run".
    static func scrimmageYards(_ t: String) -> Int? {
        if contains(t, "no gain") { return 0 }
        if let n = int(t, #"loss of (\d+)"#) { return -n }
        if let n = int(t, #"\bfor (?:a )?(\d+)(?: yard)?(?! (?:and|&))"#) { return n }
        if let n = int(t, #"(\d+) yard (?:run|rush|gain|pass|completion|catch|reception|touchdown|carry|scramble|loss)"#) {
            return t.contains("\(n) yard loss") ? -n : n
        }
        if let n = int(t, #"gain(?:s|ed)? (?:of )?(\d+)"#) { return n }
        return nil
    }

    static func parseSituation(_ t: String) -> SituationUpdate? {
        var u = SituationUpdate()
        if let m = groups(t, #"\b(1|first|2|second|3|third|4|fourth) and (\d+|goal|inches)\b"#), let d = m[0], let dist = m[1] {
            u.down = ["1": 1, "first": 1, "2": 2, "second": 2, "3": 3, "third": 3, "4": 4, "fourth": 4][d]
            switch dist {
            case "goal": u.goalToGo = true
            case "inches": u.distance = 1
            default: u.distance = Int(dist)
            }
        }
        if let m = groups(t, #"ball (?:is )?(?:on|at) (?:the )?(own|our|their|opponent'?s?|opp|the)? ?(\d+)"#), let n = m[1].flatMap(Int.init) {
            switch m[0] {
            case "their", "opponent's", "opponents", "opponent", "opp": u.ballOn = 100 - n
            case "own", "our": u.ballOn = n
            default: u.ballOn = n == 50 ? 50 : n   // ambiguous; assume own side
            }
        } else if matches(t, #"\bmidfield\b"#) {
            u.ballOn = 50
        }
        if let m = groups(t, #"\b(?:start of |end of )?(?:the )?(1|first|2|second|3|third|4|fourth) quarter\b"#), let q = m[0] {
            u.quarter = ["1": 1, "first": 1, "2": 2, "second": 2, "3": 3, "third": 3, "4": 4, "fourth": 4][q]
        } else if contains(t, "halftime") || contains(t, "second half") {
            u.quarter = 3
        } else if contains(t, "overtime") {
            u.quarter = 5
        }
        if matches(t, #"\bhome (team )?ball\b"#) { u.possession = .home }
        if matches(t, #"\b(away|visitor'?s?|visiting) (team )?ball\b"#) { u.possession = .away }
        return u.isEmpty ? nil : u
    }

    static let foulDefaults: [(pattern: String, name: String, side: Penalty.Side, yards: Int, autoFirst: Bool)] = [
        (#"false start"#, "False start", .offense, 5, false),
        (#"delay of game"#, "Delay of game", .offense, 5, false),
        (#"illegal (procedure|formation|motion|shift)"#, "Illegal procedure", .offense, 5, false),
        (#"intentional grounding"#, "Intentional grounding", .offense, 5, false),
        (#"holding"#, "Holding", .offense, 10, false),
        (#"illegal block|block in the back|clipping|chop block"#, "Illegal block", .offense, 15, false),
        (#"offensive pass interference"#, "Offensive pass interference", .offense, 15, false),
        (#"offside|encroachment|neutral zone"#, "Offside", .defense, 5, false),
        (#"pass interference"#, "Pass interference", .defense, 15, true),
        (#"roughing( the)? (passer|kicker|snapper)"#, "Roughing", .defense, 15, true),
        (#"face ?mask"#, "Face mask", .defense, 15, false),
        (#"personal foul|late hit|unnecessary roughness|targeting|horse ?collar"#, "Personal foul", .defense, 15, false),
        (#"unsportsmanlike"#, "Unsportsmanlike conduct", .defense, 15, false),
    ]

    /// Extracts a penalty clause and removes it from `t`.
    static func parsePenalty(_ t: inout String) -> Penalty? {
        let foul = foulDefaults.first { matches(t, $0.pattern) }
        guard foul != nil || matches(t, #"\b(flag|penalty)\b"#) else { return nil }

        var side = foul?.side ?? .defense
        if matches(t, #"(on|against) (the )?offense"#) { side = .offense }
        if matches(t, #"(on|against) (the )?defense"#) { side = .defense }
        let yards = int(t, #"(\d+) yard(?: penalty)?"#).flatMap { matchesPenaltyYardage(t, $0) ? $0 : nil }
            ?? int(t, #"penalty (?:of )?(\d+)"#)
            ?? foul?.yards ?? 5
        let player = int(t, #"(?:on|against|by) (\d+)(?! yard)"#)

        // Drop everything from the foul words on, so "10 yard" isn't read as a gain.
        if let r = t.range(of: #"(flag|penalty|false start|delay of game|illegal|intentional grounding|holding|block in the back|clipping|chop block|pass interference|offside|encroachment|neutral zone|roughing|face ?mask|personal foul|late hit|unnecessary roughness|targeting|horse ?collar|unsportsmanlike).*$"#, options: .regularExpression) {
            t = String(t[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return Penalty(on: side, yards: yards, player: player, name: foul?.name, automaticFirstDown: foul?.autoFirst ?? false)
    }

    /// A "N yard" mention belongs to the penalty only if it appears after the foul words.
    static func matchesPenaltyYardage(_ t: String, _ n: Int) -> Bool {
        guard let foulPos = t.range(of: #"flag|penalty|false start|delay|illegal|grounding|holding|block|clipping|interference|offside|encroachment|neutral zone|roughing|face ?mask|personal|late hit|unnecessary|targeting|collar|unsportsmanlike"#, options: .regularExpression),
              let ydPos = t.range(of: "\(n) yard", range: foulPos.lowerBound..<t.endIndex)
        else { return false }
        return ydPos.lowerBound >= foulPos.lowerBound
    }

    /// Extracts "returned by 22 for 25" / "return of 30" and removes it from `t`.
    static func parseReturn(_ t: inout String) -> (returner: Int?, yards: Int?)? {
        let pattern = #"\b(?:returned|returns?|run back|brought back)(?: by (\d+))?(?: (?:for|of) (?:a )?(\d+)(?: yard)?)?"#
        guard let m = groups(t, pattern) else { return nil }
        let returner = m[0].flatMap(Int.init)
        let yards = m[1].flatMap(Int.init)
        if let r = t.range(of: pattern, options: .regularExpression) { t.removeSubrange(r) }
        t = t.split(separator: " ").joined(separator: " ")
        return (returner, yards)
    }

    static func kickerNumber(_ t: String) -> Int? {
        int(t, #"(\d+) (?:kicks?|punts?|boots?|nails?|makes?|misses?)"#)
            ?? int(t, #"(?:kick|kickoff|punt|field goal|extra point)(?: attempt)? by (\d+)"#)
            ?? int(t, #"\bby (\d+)\b(?! yard)"#)
    }

    static func kickResult(_ t: String) -> FootballPlay.KickResult? {
        if contains(t, "blocked") { return .blocked }
        if matches(t, #"\bmissed|\bmisses|\bfails?\b"#) { return .missed }
        if matches(t, #"\bgood\b|\bmakes?\b|\bmade\b|\bnails\b|\bconverted\b|\bthrough\b"#) { return .good }
        return nil
    }

    // MARK: - Regex helpers

    static func contains(_ t: String, _ s: String) -> Bool { t.contains(s) }

    static func matches(_ t: String, _ pattern: String) -> Bool {
        t.range(of: pattern, options: .regularExpression) != nil
    }

    /// Capture groups of the first match (nil entries for unmatched groups).
    static func groups(_ t: String, _ pattern: String) -> [String?]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t))
        else { return nil }
        return (1..<max(1, m.numberOfRanges)).map { i in
            Range(m.range(at: i), in: t).map { String(t[$0]) }
        }
    }

    static func int(_ t: String, _ pattern: String) -> Int? {
        groups(t, pattern)?.first.flatMap { $0 }.flatMap(Int.init)
    }

    /// Numbers following a keyword: "tackle by 54 and 32", "sacked by 90, 55".
    static func numberList(after keyword: String, in t: String) -> [Int] {
        guard let m = groups(t, keyword + #" ((?:\d+)(?:(?: and| &|,)? \d+)*)"#), let list = m.last.flatMap({ $0 }) else { return [] }
        return list.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
}
