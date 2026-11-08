import Foundation

// Sport-neutral pieces shared by every sport pack (PLAN.md §10).

public enum TeamSide: String, Codable, Sendable, CaseIterable, Hashable {
    case home, away

    public var opponent: TeamSide { self == .home ? .away : .home }
}

/// Where an event came from. Stats are always derived from events, so the
/// source is kept for auditing and accuracy measurement.
public enum EventSource: String, Codable, Sendable {
    case voice     // spoken by the wearer, parsed by the grammar/LLM
    case typed     // typed into the app
    case vision    // proposed by the CV/VLM pipeline
    case human     // entered or edited in the review UI
}

/// Proposed events count toward live state (so the scoreboard keeps up) but
/// are visually flagged until confirmed. Rejected events are ignored.
public enum EventStatus: String, Codable, Sendable {
    case proposed, confirmed, rejected
}

/// Pointer into a media asset (glasses stream, native clip, phone, Veo MP4).
public struct VideoRef: Codable, Sendable, Equatable, Hashable {
    public var assetID: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(assetID: String, start: TimeInterval, end: TimeInterval) {
        self.assetID = assetID
        self.start = start
        self.end = end
    }
}

public struct TeamInfo: Codable, Sendable, Equatable {
    public var name: String
    public var shortName: String
    /// Optional; older saved games have none.
    public var roster: Roster?
    /// Jersey color found by computer vision, "#rrggbb".
    public var jerseyColor: String?

    public init(name: String, shortName: String? = nil, roster: Roster? = nil) {
        self.name = name
        self.shortName = shortName ?? String(name.prefix(4)).uppercased()
        self.roster = roster
    }
}
