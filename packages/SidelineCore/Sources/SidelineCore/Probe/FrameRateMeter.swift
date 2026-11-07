import Foundation

/// Counts frames, measures trailing-window FPS, and detects stalls
/// (gaps with no frames longer than `stallThreshold`).
///
/// Not thread-safe; callers serialize access (the app drives it from one actor).
public struct FrameRateMeter: Sendable {
    public let window: TimeInterval
    public let stallThreshold: TimeInterval

    public private(set) var totalFrames = 0
    public private(set) var stallCount = 0
    public private(set) var longestGap: TimeInterval = 0
    public private(set) var isStalled = false

    private var recent: [TimeInterval] = []   // timestamps within the window
    private var lastFrameAt: TimeInterval?
    private var firstFrameAt: TimeInterval?

    public init(window: TimeInterval = 5, stallThreshold: TimeInterval = 2) {
        self.window = window
        self.stallThreshold = stallThreshold
    }

    /// Record a frame at time `t` (seconds, monotonic). Returns true if this
    /// frame ended a stall.
    @discardableResult
    public mutating func recordFrame(at t: TimeInterval) -> Bool {
        var recovered = false
        if let last = lastFrameAt {
            let gap = t - last
            longestGap = max(longestGap, gap)
            if isStalled {
                isStalled = false
                recovered = true
            }
        }
        if firstFrameAt == nil { firstFrameAt = t }
        lastFrameAt = t
        totalFrames += 1
        recent.append(t)
        trim(now: t)
        return recovered
    }

    /// Check for a stall at time `t`. Returns true exactly once when a new
    /// stall begins. Only meaningful after the first frame has arrived.
    public mutating func checkStall(at t: TimeInterval) -> Bool {
        guard let last = lastFrameAt, !isStalled else { return false }
        if t - last > stallThreshold {
            isStalled = true
            stallCount += 1
            longestGap = max(longestGap, t - last)
            return true
        }
        return false
    }

    /// Frames per second over the trailing window ending at `t`.
    public mutating func fps(at t: TimeInterval) -> Double {
        trim(now: t)
        guard let first = firstFrameAt else { return 0 }
        // Before a full window has elapsed, divide by the time actually covered.
        let span = min(window, t - first)
        guard span > 0 else { return 0 }
        return Double(recent.count) / span
    }

    private mutating func trim(now t: TimeInterval) {
        let cutoff = t - window
        if let idx = recent.firstIndex(where: { $0 > cutoff }) {
            if idx > 0 { recent.removeFirst(idx) }
        } else {
            recent.removeAll()
        }
    }
}
