import Foundation

/// One football play, described relative to the team in possession
/// (the "offense"; for kicks, the kicking team). Raw facts only: no stat
/// credit is stored here. `FootballStats` derives credit under a rule set.
///
/// Players are identified by jersey number within their side. Identity
/// resolution (jersey → roster person) happens elsewhere.
public struct FootballPlay: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case rush, pass, sack, kneel, spike
        case kickoff, punt, fieldGoal, extraPoint, twoPoint
        case penalty          // dead-ball / no-play penalty
    }

    public enum PassResult: String, Codable, Sendable { case complete, incomplete, intercepted }
    public enum KickResult: String, Codable, Sendable { case good, missed, blocked }

    public var kind: Kind

    // Offense
    public var ballCarrier: Int?        // rusher (rush / two-point run / kneel)
    public var passer: Int?
    public var receiver: Int?           // intended target; the catcher when complete
    public var passResult: PassResult?
    /// Net yards gained by the offense on the scrimmage play (negative = loss).
    public var yards: Int?

    // Defense
    public var tacklers: [Int] = []
    public var sackers: [Int] = []
    public var interceptedBy: Int?

    // Fumbles
    public var fumbledBy: Int?
    public var forcedFumbleBy: Int?
    public var fumbleRecoveredBy: Int?
    /// True when the defense recovered (a turnover).
    public var fumbleLost: Bool = false

    // Kicks
    public var kicker: Int?
    public var kickResult: KickResult?  // FG / XP / two-point (good = converted)
    public var kickDistance: Int?       // punt or kickoff distance, or FG distance
    public var returner: Int?
    public var returnYards: Int?

    // Outcomes
    public var touchdown: Bool = false
    public var safety: Bool = false
    public var penalty: Penalty?

    public init(kind: Kind) {
        self.kind = kind
    }

    /// Possession changed hands during the play (interception or lost fumble).
    public var isTurnover: Bool { interceptedBy != nil || passResult == .intercepted || fumbleLost }

    /// A touchdown scored by the team *not* in possession at the snap:
    /// pick-six, scoop-and-score, or a kickoff/punt return.
    public var isDefensiveTouchdown: Bool {
        touchdown && (isTurnover || kind == .kickoff || kind == .punt)
    }

    public var isScrimmage: Bool {
        switch kind {
        case .rush, .pass, .sack, .kneel, .spike: true
        default: false
        }
    }
}

public struct Penalty: Codable, Sendable, Equatable {
    public enum Side: String, Codable, Sendable { case offense, defense }

    public var on: Side
    public var yards: Int
    public var player: Int?
    public var name: String?
    public var automaticFirstDown: Bool

    public init(on: Side, yards: Int, player: Int? = nil, name: String? = nil, automaticFirstDown: Bool = false) {
        self.on = on
        self.yards = yards
        self.player = player
        self.name = name
        self.automaticFirstDown = automaticFirstDown
    }
}

/// An explicit correction to the game situation ("second and seven",
/// "ball on their 35", "third quarter"). Applied on top of derived state.
public struct SituationUpdate: Codable, Sendable, Equatable {
    public var down: Int?
    public var distance: Int?
    public var goalToGo: Bool?
    /// Yards from the offense's own goal line (1–99); 50 = midfield.
    public var ballOn: Int?
    public var possession: TeamSide?
    public var quarter: Int?

    public init(down: Int? = nil, distance: Int? = nil, goalToGo: Bool? = nil, ballOn: Int? = nil,
                possession: TeamSide? = nil, quarter: Int? = nil) {
        self.down = down
        self.distance = distance
        self.goalToGo = goalToGo
        self.ballOn = ballOn
        self.possession = possession
        self.quarter = quarter
    }

    public var isEmpty: Bool {
        down == nil && distance == nil && goalToGo == nil && ballOn == nil && possession == nil && quarter == nil
    }
}

/// One entry in the game log: a play and/or a situation correction, plus
/// provenance (source/status/confidence/transcript) and video pointers.
public struct FootballEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var offense: TeamSide
    public var play: FootballPlay?
    public var situation: SituationUpdate?
    public var source: EventSource
    public var status: EventStatus
    public var confidence: Double
    public var transcript: String?
    public var wallTime: Date
    public var videoRefs: [VideoRef]
    /// What computer vision found for this play (set by importing a CV report).
    public var cv: CVPlayNote?

    public init(
        id: UUID = UUID(), offense: TeamSide, play: FootballPlay? = nil, situation: SituationUpdate? = nil,
        source: EventSource, status: EventStatus = .proposed, confidence: Double = 1,
        transcript: String? = nil, wallTime: Date = Date(), videoRefs: [VideoRef] = []
    ) {
        self.id = id
        self.offense = offense
        self.play = play
        self.situation = situation
        self.source = source
        self.status = status
        self.confidence = confidence
        self.transcript = transcript
        self.wallTime = wallTime
        self.videoRefs = videoRefs
    }
}
