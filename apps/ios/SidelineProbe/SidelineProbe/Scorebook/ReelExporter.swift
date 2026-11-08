import AVFoundation
import Foundation

/// Stitches play clips (stretches of the game video files) into one
/// highlight reel, in order, without re-encoding.
enum ReelExporter {
    struct Piece: Sendable {
        let url: URL
        let start: TimeInterval
        let end: TimeInterval
    }

    enum Failure: LocalizedError {
        case nothingToExport
        case noVideoTrack(String)
        case exportFailed(String)
        var errorDescription: String? {
            switch self {
            case .nothingToExport: "No finished clips to put in a reel."
            case .noVideoTrack(let file): "\(file) has no video track (is it still recording?)."
            case .exportFailed(let why): "Export failed: \(why)"
            }
        }
    }

    /// Writes the reel to `output` (.mov) and returns its duration in seconds.
    static func export(_ pieces: [Piece], to output: URL) async throws -> TimeInterval {
        guard !pieces.isEmpty else { throw Failure.nothingToExport }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.exportFailed("couldn't create a video track")
        }
        var cursor = CMTime.zero
        var assets: [URL: (AVURLAsset, AVAssetTrack, CMTime)] = [:]
        for piece in pieces {
            let (asset, source, duration): (AVURLAsset, AVAssetTrack, CMTime)
            if let cached = assets[piece.url] {
                (asset, source, duration) = cached
            } else {
                let a = AVURLAsset(url: piece.url)
                guard let t = try await a.loadTracks(withMediaType: .video).first else {
                    throw Failure.noVideoTrack(piece.url.lastPathComponent)
                }
                let d = try await a.load(.duration)
                (asset, source, duration) = (a, t, d)
                assets[piece.url] = (a, t, d)
                if cursor == .zero { track.preferredTransform = try await t.load(.preferredTransform) }
            }
            _ = asset
            let start = CMTime(seconds: max(0, piece.start), preferredTimescale: 600)
            let end = CMTimeMinimum(CMTime(seconds: piece.end, preferredTimescale: 600), duration)
            guard end > start else { continue }
            let range = CMTimeRange(start: start, end: end)
            try track.insertTimeRange(range, of: source, at: cursor)
            cursor = CMTimeAdd(cursor, range.duration)
        }
        guard cursor > .zero else { throw Failure.nothingToExport }

        try? FileManager.default.removeItem(at: output)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw Failure.exportFailed("no export session")
        }
        if #available(iOS 18, *) {
            try await session.export(to: output, as: .mov)
        } else {
            session.outputURL = output
            session.outputFileType = .mov
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                session.exportAsynchronously { cont.resume() }
            }
            if session.status != .completed {
                throw Failure.exportFailed(session.error?.localizedDescription ?? "status \(session.status.rawValue)")
            }
        }
        return CMTimeGetSeconds(cursor)
    }
}
