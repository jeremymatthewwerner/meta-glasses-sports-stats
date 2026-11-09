import AVFoundation
import Foundation
import SidelineCore

/// Imports a game video from another camera (a Veo download, a phone on a
/// tripod) into a game's folder and lines it up with the game log: whistles
/// in its audio are matched to logged events, falling back to the file's
/// recording time.
enum VideoImporter {
    struct Imported {
        var segment: GameRecording.Segment
        var whistles: [TimeInterval]
    }

    enum ImportError: LocalizedError {
        case unreadable
        var errorDescription: String? { "That file isn't a video this phone can read." }
    }

    static let sampleRate = 12_000.0

    /// Copies `url` into `folder` as `name`, finds whistles, and syncs.
    /// Runs off the main thread; `progress` gets short status lines.
    static func importVideo(from url: URL, into folder: URL, name: String, anchors: [SyncAnchor], firstEvent: Date?,
                            progress: @escaping @Sendable (String) -> Void) async throws -> Imported {
        try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let dest = folder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            progress("Copying \(url.lastPathComponent)…")
            try FileManager.default.copyItem(at: url, to: dest)

            let asset = AVURLAsset(url: dest)
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw ImportError.unreadable }
            let recorded = try? await asset.load(.creationDate)?.load(.dateValue)

            progress("Listening for whistles…")
            let whistles = (try? await Self.whistles(in: asset, duration: duration, progress: progress)) ?? []
            saveWhistles(whistles, for: dest)
            let sync = VideoSyncSolver.sync(blasts: whistles, anchors: anchors, videoDuration: duration,
                                            recordingTime: recorded, firstEvent: firstEvent)
            let segment = GameRecording.Segment(file: name, startedAt: sync.videoStart,
                                                endedAt: sync.videoStart.addingTimeInterval(duration),
                                                source: "Imported: \(url.lastPathComponent)", sync: sync)
            return Imported(segment: segment, whistles: whistles)
        }.value
    }

    /// Whistle onsets (seconds) in the video's first audio track.
    static func whistles(in asset: AVAsset, duration: TimeInterval, progress: @Sendable (String) -> Void) async throws -> [TimeInterval] {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1, AVSampleRateKey: sampleRate,
        ])
        reader.add(output)
        guard reader.startReading() else { return [] }
        var detector = WhistleDetector(sampleRate: sampleRate)
        var read = 0
        var lastReport = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let bytes = CMBlockBufferGetDataLength(block)
            var samples = [Float](repeating: 0, count: bytes / MemoryLayout<Float>.size)
            samples.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes, destination: raw.baseAddress!)
            }
            detector.feed(samples)
            read += samples.count
            let minutes = Int(Double(read) / sampleRate / 60)
            if minutes >= lastReport + 5 {
                lastReport = minutes
                progress("Listening for whistles… \(minutes) of \(Int(duration / 60)) min")
            }
        }
        return detector.finish().map(\.start)
    }

    // MARK: Saved whistles (for re-syncing after more events are logged)

    static func whistlesFile(for video: URL) -> URL { video.appendingPathExtension("whistles.json") }

    static func saveWhistles(_ w: [TimeInterval], for video: URL) {
        try? JSONEncoder().encode(w).write(to: whistlesFile(for: video), options: .atomic)
    }

    static func loadWhistles(for video: URL) -> [TimeInterval] {
        (try? Data(contentsOf: whistlesFile(for: video))).flatMap { try? JSONDecoder().decode([TimeInterval].self, from: $0) } ?? []
    }

    /// Re-solves a saved import against the current game log (nil when the
    /// whistles still don't line up; the current sync then stays).
    static func resync(_ segment: GameRecording.Segment, folder: URL, anchors: [SyncAnchor]) -> VideoSync? {
        let whistles = loadWhistles(for: folder.appendingPathComponent(segment.file))
        let d = segment.duration ?? 0
        return VideoSyncSolver.solve(blasts: whistles, anchors: anchors, videoDuration: d, guess: segment.startedAt, radius: 1800)
            ?? VideoSyncSolver.solve(blasts: whistles, anchors: anchors, videoDuration: d)
    }
}
