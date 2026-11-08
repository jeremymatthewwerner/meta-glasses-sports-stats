import Foundation

/// The video files recorded during one game (game mode), and the rule for
/// cutting a clip around each called play.
///
/// A play is called *after* it happens: the wearer watches the snap, the
/// run and the tackle, then says "22 run for 7, tackle by 54". So the clip
/// for a call reaches back `lead` seconds before the moment the call
/// started, and a little past it.
public struct GameRecording: Codable, Sendable, Equatable {
    public struct Segment: Codable, Sendable, Equatable, Identifiable {
        /// File name inside the game's folder, e.g. "glasses-01.mov". Also
        /// the `VideoRef.assetID` used by plays in this segment.
        public var file: String
        public var startedAt: Date
        public var endedAt: Date?
        public var frames: Int
        public var source: String          // e.g. "Meta Ray-Ban Display, HEVC 504x896 @15"

        public var id: String { file }

        public init(file: String, startedAt: Date, endedAt: Date? = nil, frames: Int = 0, source: String) {
            self.file = file
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.frames = frames
            self.source = source
        }

        public var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }
    }

    public var gameID: UUID
    public var segments: [Segment]

    public init(gameID: UUID, segments: [Segment] = []) {
        self.gameID = gameID
        self.segments = segments
    }

    /// Next unused segment file name ("glasses-01.mov", "glasses-02.mov", …).
    public var nextFileName: String {
        String(format: "glasses-%02d.mov", segments.count + 1)
    }
}

/// How much video to keep around a called play.
public struct ClipPolicy: Codable, Sendable, Equatable {
    /// Seconds before the call started (the play itself).
    public var lead: TimeInterval
    /// Seconds after the call started.
    public var tail: TimeInterval

    public init(lead: TimeInterval, tail: TimeInterval) {
        self.lead = lead
        self.tail = tail
    }

    /// Football: a play runs ~4–10 s and the call usually starts a few
    /// seconds after the whistle.
    public static let football = ClipPolicy(lead: 15, tail: 2)

    /// The clip for a call that started at `anchor` seconds into a video that
    /// is currently `available` seconds long (nil = unknown / still growing).
    public func clip(assetID: String, anchor: TimeInterval, available: TimeInterval? = nil) -> VideoRef {
        let start = max(0, anchor - lead)
        var end = max(start, anchor + tail)
        if let available { end = min(end, max(start, available)) }
        return VideoRef(assetID: assetID, start: start, end: end)
    }
}
