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
        /// Set for a video imported from another camera (Veo, phone on a
        /// tripod): how it was lined up with the game. `startedAt` is its
        /// synced first frame.
        public var sync: VideoSync?

        public var id: String { file }
        public var isImported: Bool { sync != nil }

        public init(file: String, startedAt: Date, endedAt: Date? = nil, frames: Int = 0, source: String,
                    sync: VideoSync? = nil) {
            self.file = file
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.frames = frames
            self.source = source
            self.sync = sync
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
        String(format: "glasses-%02d.mov", segments.filter { !$0.isImported }.count + 1)
    }

    /// Next name for an imported video ("camera-01.mp4", …), keeping its extension.
    public func nextImportName(extension ext: String) -> String {
        String(format: "camera-%02d.%@", segments.filter(\.isImported).count + 1, ext.isEmpty ? "mp4" : ext.lowercased())
    }

    /// Re-times an imported video (after a manual nudge or a new sync).
    public mutating func setSync(_ sync: VideoSync, for file: String) {
        guard let i = segments.firstIndex(where: { $0.file == file }), let d = segments[i].duration else { return }
        segments[i].sync = sync
        segments[i].startedAt = sync.videoStart
        segments[i].endedAt = sync.videoStart.addingTimeInterval(d)
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
