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
                if !input.append(buffer) {
                    failure = writer.error?.localizedDescription ?? "append failed"
                }
            } else {
                droppedFrames += 1
            }
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
