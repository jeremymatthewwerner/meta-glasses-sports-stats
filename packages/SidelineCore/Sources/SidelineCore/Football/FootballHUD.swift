import Foundation

/// What the heads-up display on the glasses shows, derived from the game.
/// Kept SDK-free so it can be unit-tested; the app renders it with MWDATDisplay.
///
/// Layout on the lens (small, glanceable, ≤ 4 lines):
///
///     EAGLES 7  –  HAWKS 14          ← score (away first, like a scoreboard)
///     Q2 · HAWKS ball · 3rd & 4 at opp 35   ← situation
///     22 run for 7, tackle by 54     ← last play (or nothing yet)
///     [ ✓ Confirm ]  [ Undo ]        ← actions for the last play
public struct FootballHUD: Equatable, Sendable {
    public var scoreLine: String
    public var situationLine: String
    /// Summary of the latest play that still counts (not rejected).
    public var lastPlay: String?
    public var lastPlayID: UUID?
    /// True while the latest play is only proposed.
    public var lastPlayNeedsConfirm: Bool
    /// Plays still waiting for confirmation, across the whole game.
    public var pendingCount: Int

    public static let maxTeamName = 10
    public static let maxPlayLength = 48

    public init(game: FootballGame) {
        let state = game.state
        func side(_ s: TeamSide) -> String {
            "\(Self.shortName(game.team(s).name)) \(state.points(s))"
        }
        scoreLine = "\(side(.away))  –  \(side(.home))"
        let quarter = state.quarter >= 5 ? "OT" : "Q\(state.quarter)"
        let ball = Self.shortName(game.team(state.possession).name)
        let kicking = state.phase == .kickoff ? "kicking" : "ball"
        situationLine = "\(quarter) · \(ball) \(kicking) · \(state.situationText)"

        let last = game.events.last { $0.status != .rejected && !$0.summary.isEmpty }
        lastPlay = last.map { Self.truncate($0.summary, to: Self.maxPlayLength) }
        lastPlayID = last?.id
        lastPlayNeedsConfirm = last?.status == .proposed
        pendingCount = game.events.filter { $0.status == .proposed }.count
    }

    static func shortName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return truncate(trimmed.isEmpty ? "TEAM" : trimmed.uppercased(), to: maxTeamName)
    }

    static func truncate(_ s: String, to n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n - 1)) + "…"
    }
}
