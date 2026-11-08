import AVFoundation
import Foundation
import MWDATCamera

/// Writes compressed `hvc1` frames from the glasses stream straight to a
/// .mov file (passthrough, no re-encode). All work happens on a private
/// serial queue, so `append` is safe to call from the SDK callback thread.
final class HEVCFileWriter: @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "sideline.hevc-writer")
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var sessionStarted = false
    private var finished = false
    private(set) var droppedFrames = 0   // queue-confined
    private(set) var failure: String?    // queue-confined
    // Wall clock ↔ file time mapping, refreshed on every frame (queue-confined).
    private var firstPTS: CMTime?
    private var lastPTS: CMTime?
    private var lastWall: Date?
    private var written = 0

    init(url: URL) {
        self.url = url
    }

    func append(_ frame: VideoFrame) {
        queue.async { [self] in
            guard !finished, failure == nil else { return }
            let buffer = frame.sampleBuffer
            if writer == nil { setUp(formatHint: CMSampleBufferGetFormatDescription(buffer)) }
            guard let writer, let input else { return }
            if !sessionStarted {
                guard writer.startWriting() else {
                    failure = writer.error?.localizedDescription ?? "startWriting failed"
                    return
                }
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
                sessionStarted = true
            }
            if input.isReadyForMoreMediaData {
                if input.append(buffer) {
                    let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                    if firstPTS == nil { firstPTS = pts }
                    lastPTS = pts
                    lastWall = Date()
                    written += 1
                } else {
                    failure = writer.error?.localizedDescription ?? "append failed"
                }
            } else {
                droppedFrames += 1
            }
        }
    }

    /// Seconds into the file that correspond to wall-clock `date`, using the
    /// most recent frame as the reference (so stream gaps don't skew it).
    /// Nil until the first frame is written.
    func videoTime(at date: Date) -> TimeInterval? {
        queue.sync {
            guard let firstPTS, let lastPTS, let lastWall else { return nil }
            let fileNow = CMTimeGetSeconds(CMTimeSubtract(lastPTS, firstPTS))
            return max(0, fileNow + date.timeIntervalSince(lastWall))
        }
    }

    /// Seconds of video written so far, and frame count.
    var progress: (seconds: TimeInterval, frames: Int) {
        queue.sync {
            guard let firstPTS, let lastPTS else { return (0, written) }
            return (CMTimeGetSeconds(CMTimeSubtract(lastPTS, firstPTS)), written)
        }
    }

    /// Finalizes the file. `completion` runs on an arbitrary queue.
    func finish(completion: @escaping @Sendable (_ error: String?) -> Void) {
        queue.async { [self] in
            guard !finished else { completion(failure); return }
            finished = true
            guard let writer, sessionStarted else { completion(failure ?? "no frames written"); return }
            input?.markAsFinished()
            writer.finishWriting { [self] in
                completion(writer.status == .completed ? failure : (writer.error?.localizedDescription ?? "finish failed"))
            }
        }
    }

    private func setUp(formatHint: CMFormatDescription?) {
        do {
            try? FileManager.default.removeItem(at: url)
            let w = try AVAssetWriter(outputURL: url, fileType: .mov)
            let i = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
            i.expectsMediaDataInRealTime = true
            guard w.canAdd(i) else {
                failure = "cannot add passthrough video input"
                return
            }
            w.add(i)
            writer = w
            input = i
        } catch {
            failure = error.localizedDescription
        }
    }
}
