import Foundation

extension FootballPlay {
    /// One-line, scorebook-style description: "#22 run for 7 (tkl #54)".
    public var summary: String {
        func n(_ x: Int?) -> String { x.map { "#\($0)" } ?? "?" }
        func list(_ xs: [Int]) -> String { xs.map { "#\($0)" }.joined(separator: ", ") }
        func gain(_ y: Int?) -> String {
            guard let y else { return "" }
            if y == 0 { return " for no gain" }
            return y < 0 ? " for a loss of \(-y)" : " for \(y)"
        }
        func result(_ r: KickResult?) -> String {
            switch r {
            case .good: "good"
            case .missed: "no good"
            case .blocked: "blocked"
            case nil: "?"
            }
        }

        var s: String
        switch kind {
        case .rush: s = "\(n(ballCarrier)) run" + gain(yards)
        case .kneel: s = "Kneel" + gain(yards)
        case .spike: s = "Spike"
        case .pass:
            switch passResult {
            case .complete: s = "\(n(passer)) pass to \(n(receiver))" + gain(yards)
            case .incomplete: s = "\(n(passer)) incomplete to \(n(receiver))"
            case .intercepted: s = "\(n(passer)) intercepted by \(n(interceptedBy))"
            case nil: s = "Pass"
            }
        case .sack:
            s = (passer.map { "#\($0) " } ?? "") + "sacked" + (sackers.isEmpty ? "" : " by \(list(sackers))") + gain(yards)
        case .fieldGoal: s = (kickDistance.map { "\($0)-yd " } ?? "") + "FG " + result(kickResult)
        case .extraPoint: s = "PAT " + result(kickResult)
        case .twoPoint: s = "2-pt try " + (kickResult == .good ? "good" : "failed")
        case .punt: s = "Punt" + (kicker.map { " by #\($0)" } ?? "") + (kickDistance.map { ", \($0) yds" } ?? "")
        case .kickoff: s = "Kickoff" + (kicker.map { " by #\($0)" } ?? "") + (kickDistance.map { ", \($0) yds" } ?? "")
        case .penalty: s = "Penalty"
        }

        if kind != .sack, !tacklers.isEmpty { s += " (tkl \(list(tacklers)))" }
        if returner != nil || returnYards != nil {
            s += ", return " + (returner.map { "#\($0) " } ?? "") + (returnYards.map { "\($0) yds" } ?? "")
        }
        if let f = fumbledBy {
            s += ", fumble by #\(f)" + (fumbleLost ? " LOST" : " (kept)")
            if let r = fumbleRecoveredBy { s += " rec #\(r)" }
        }
        if let p = penalty {
            s += ", " + (p.name ?? "penalty") + " on \(p.on.rawValue)" + (p.player.map { " #\($0)" } ?? "") + " \(p.yards) yds"
        }
        if touchdown { s += " — TOUCHDOWN" }
        if safety { s += " — SAFETY" }
        return s
    }
}

extension SituationUpdate {
    public var summary: String {
        var parts: [String] = []
        if let q = quarter { parts.append(q == 5 ? "Overtime" : "Quarter \(q)") }
        if let p = possession { parts.append("\(p.rawValue) ball") }
        if let d = down {
            let dist = goalToGo == true ? "Goal" : distance.map(String.init) ?? "?"
            parts.append("\(FootballGameState.ordinal(d)) & \(dist)")
        }
        if let b = ballOn { parts.append("ball on " + FootballGameState.spotText(b)) }
        return parts.joined(separator: ", ")
    }
}

extension FootballEvent {
    public var summary: String {
        [play?.summary, situation?.summary].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
