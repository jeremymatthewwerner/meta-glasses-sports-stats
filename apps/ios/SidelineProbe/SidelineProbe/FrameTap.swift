import Foundation
import os
import SidelineCore

/// Thread-safe frame counter fed from the SDK's frame callback thread and
/// read by the 1 Hz sampler on the main actor.
final class FrameTap: Sendable {
    private struct State: Sendable {
        var meter = FrameRateMeter(window: 5, stallThreshold: 2)
        var bytes: Int64 = 0
        var framesSincePreview = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let t0 = ContinuousClock.now

    /// Seconds since this tap was created (monotonic).
    func now() -> TimeInterval {
        let d = t0.duration(to: .now)
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    /// Records one frame. Returns whether it ended a stall and whether the
    /// caller should render a preview for it.
    func frame(bytes: Int, previewEvery: Int) -> (recoveredFromStall: Bool, wantPreview: Bool) {
        let t = now()
        return state.withLock { s in
            let recovered = s.meter.recordFrame(at: t)
            s.bytes += Int64(bytes)
            s.framesSincePreview += 1
            let want = previewEvery > 0 && s.framesSincePreview >= previewEvery
            if want { s.framesSincePreview = 0 }
            return (recovered, want)
        }
    }

    struct Snapshot: Sendable {
        var totalFrames: Int
        var fps: Double
        var bytes: Int64
        var newStall: Bool
        var stallCount: Int
    }

    func snapshot() -> Snapshot {
        let t = now()
        return state.withLock { s in
            let newStall = s.meter.checkStall(at: t)
            return Snapshot(
                totalFrames: s.meter.totalFrames,
                fps: s.meter.fps(at: t),
                bytes: s.bytes,
                newStall: newStall,
                stallCount: s.meter.stallCount
            )
        }
    }
}
