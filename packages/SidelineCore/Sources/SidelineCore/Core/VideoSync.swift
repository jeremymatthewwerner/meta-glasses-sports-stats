import Accelerate
import Foundation

// Lining up a video from another camera (a Veo download, a phone on a
// tripod) with the game log. Glasses recordings carry no audio, so the
// imported video can't be matched to them sound-to-sound. Instead the
// referee's whistles in the imported audio are matched to the wall-clock
// times of logged events: a football play's call comes a few seconds after
// the whistle that ended it, and a soccer kickoff tap lands on the kickoff
// whistle.

// MARK: - Whistle detection

/// Finds referee-whistle blasts in mono audio: a strong, narrow tone between
/// ~2 and ~4.8 kHz that stands out from crowd noise and speech. Feed it
/// samples in chunks (an hour of audio doesn't fit in memory at once).
public struct WhistleDetector {
    public struct Blast: Sendable, Equatable {
        public var start: TimeInterval
        public var duration: TimeInterval
        /// Mean tonality of the blast's frames (0–1).
        public var strength: Double
    }

    public let sampleRate: Double
    public var band: ClosedRange<Double> = 2000...4800
    /// Share of the frame's energy (300 Hz–Nyquist) within ±300 Hz of the band's peak.
    public var minTonality: Double = 0.45
    /// Band peak must be this many times the running noise floor.
    public var minAboveFloor: Double = 6
    public var minDuration: TimeInterval = 0.12
    public var maxGap: TimeInterval = 0.12

    static let frame = 1024
    static let hop = 512

    private var buffer: [Float] = []
    private var consumed = 0                     // samples dropped from the front of `buffer`
    private var floor: Double = 0                // running median-ish noise floor of band peak power
    private var open: (start: TimeInterval, end: TimeInterval, tonality: [Double])?
    private var blasts: [Blast] = []
    private let dft: vDSP.DFT<Float>?
    private let window: [Float]

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        dft = vDSP.DFT(count: Self.frame, direction: .forward, transformType: .complexComplex, ofType: Float.self)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.frame, isHalfWindow: false)
    }

    public mutating func feed(_ samples: [Float]) {
        buffer.append(contentsOf: samples)
        var offset = 0
        while offset + Self.frame <= buffer.count {
            analyze(Array(buffer[offset..<offset + Self.frame]),
                    at: Double(consumed + offset) / sampleRate)
            offset += Self.hop
        }
        buffer.removeFirst(offset)
        consumed += offset
    }

    /// All blasts found so far (closes one still sounding).
    public mutating func finish() -> [Blast] {
        close()
        return blasts
    }

    private mutating func analyze(_ frame: [Float], at t: TimeInterval) {
        guard let dft else { return }
        let x = vDSP.multiply(frame, window)
        let (re, im) = dft.transform(inputReal: x, inputImaginary: [Float](repeating: 0, count: Self.frame))
        let half = Self.frame / 2
        var power = [Float](repeating: 0, count: half)
        for k in 0..<half { power[k] = re[k] * re[k] + im[k] * im[k] }
        let binHz = sampleRate / Double(Self.frame)
        let lo = max(1, Int(300 / binHz)), bLo = Int(band.lowerBound / binHz), bHi = min(half - 2, Int(band.upperBound / binHz))
        guard bHi > bLo + 3 else { return }
        let total = Double(power[lo..<half].reduce(0, +)) + 1e-12
        var peakBin = bLo
        for k in bLo...bHi where power[k] > power[peakBin] { peakBin = k }
        // A pea whistle warbles ±~150 Hz, so take the energy within ±300 Hz of the peak.
        let spread = Int(300 / binHz)
        let peak3 = Double(power[max(lo, peakBin - spread)...min(half - 1, peakBin + spread)].reduce(0, +))
        let tonality = peak3 / total
        // Noise floor: tracks the band peak slowly upward, quickly downward.
        floor = floor == 0 ? peak3 : (peak3 < floor ? floor * 0.9 + peak3 * 0.1 : floor * 0.995 + peak3 * 0.005)
        let loud = peak3 > minAboveFloor * floor
        let isWhistle = tonality >= minTonality && loud
        let frameEnd = t + Double(Self.frame) / sampleRate
        if isWhistle {
            if var o = open, t - o.end <= maxGap {
                o.end = frameEnd
                o.tonality.append(tonality)
                open = o
            } else {
                close()
                open = (t, frameEnd, [tonality])
            }
        } else if let o = open, t - o.end > maxGap {
            _ = o
            close()
        }
    }

    private mutating func close() {
        guard let o = open else { return }
        open = nil
        // Frames overlap by half; the blast's sound spans start…end minus the trailing half frame.
        let duration = o.end - o.start - Double(Self.frame - Self.hop) / sampleRate
        guard duration >= minDuration else { return }
        blasts.append(Blast(start: o.start, duration: duration, strength: o.tonality.reduce(0, +) / Double(o.tonality.count)))
    }
}

// MARK: - Sync

/// A logged moment that should have a whistle near it: the whistle is
/// expected within `window` seconds of `date` (negative = before).
public struct SyncAnchor: Sendable, Equatable {
    public var date: Date
    public var window: ClosedRange<TimeInterval>
    /// The most likely offset inside the window (a call typically comes ~3.5 s after the whistle).
    public var typical: TimeInterval

    public init(date: Date, window: ClosedRange<TimeInterval>, typical: TimeInterval? = nil) {
        self.date = date
        self.window = window
        self.typical = typical ?? (window.lowerBound + window.upperBound) / 2
    }
}

/// Where an imported video sits on the game's clock.
public struct VideoSync: Codable, Sendable, Equatable {
    public enum Method: String, Codable, Sendable {
        case whistles        // whistles matched to logged events
        case recordingTime   // the file's creation time
        case manual          // set or nudged by hand
        case none            // nothing to go on: video start = first event
    }

    /// Wall-clock time of the video's first frame.
    public var videoStart: Date
    public var method: Method
    /// Anchors that found a whistle, out of anchors that fall inside the video.
    public var matched: Int
    public var anchors: Int

    public init(videoStart: Date, method: Method, matched: Int = 0, anchors: Int = 0) {
        self.videoStart = videoStart
        self.method = method
        self.matched = matched
        self.anchors = anchors
    }

    /// "Synced by whistles: 14 of 18 events line up".
    public var summary: String {
        switch method {
        case .whistles: "Synced by whistles: \(matched) of \(anchors) events line up"
        case .recordingTime: "Synced by the video's recording time" + (anchors > 0 ? " (whistles matched \(matched) of \(anchors))" : "")
        case .manual: "Synced by hand"
        case .none: "Not synced: video start assumed at the first event"
        }
    }

    /// Video time (seconds) of a wall-clock moment.
    public func videoTime(of date: Date) -> TimeInterval { date.timeIntervalSince(videoStart) }
}

public enum VideoSyncSolver {
    /// Finds the video start that lines up the most anchors with a whistle.
    ///
    /// - blasts: whistle times in video seconds.
    /// - guess: a prior video start (the file's creation time), searched
    ///   within `radius`; nil searches every offset the data allows.
    /// - Returns nil when fewer than `minMatched` anchors line up or the
    ///   best offset isn't clearly better than the next-best distinct one.
    public static func solve(blasts: [TimeInterval], anchors: [SyncAnchor], videoDuration: TimeInterval,
                             guess: Date? = nil, radius: TimeInterval = 600, minMatched: Int = 3) -> VideoSync? {
        guard !blasts.isEmpty, !anchors.isEmpty else { return nil }
        let ref = anchors.map(\.date).min()!
        // Each (anchor, blast) pair allows the video start to lie in an interval.
        struct Edge { var at: Double; var open: Bool; var anchor: Int }
        var edges: [Edge] = []
        for (i, a) in anchors.enumerated() {
            let t = a.date.timeIntervalSince(ref)
            for b in blasts {
                // whistle wall time = start + b ∈ [t + w.lo, t + w.hi]  ⇒  start ∈ [t + w.lo − b, t + w.hi − b]
                var lo = t + a.window.lowerBound - b, hi = t + a.window.upperBound - b
                if let guess {
                    let g = guess.timeIntervalSince(ref)
                    lo = max(lo, g - radius); hi = min(hi, g + radius)
                    if lo > hi { continue }
                }
                edges.append(Edge(at: lo, open: true, anchor: i))
                edges.append(Edge(at: hi, open: false, anchor: i))
            }
        }
        guard !edges.isEmpty else { return nil }
        edges.sort { $0.at != $1.at ? $0.at < $1.at : ($0.open && !$1.open) }
        var cover = [Int](repeating: 0, count: anchors.count)
        var distinct = 0
        var best = (count: 0, from: 0.0, to: 0.0)
        var inBest = false                    // still inside the best region found so far
        var runner = (count: 0, at: 0.0)
        for e in edges {
            if e.open {
                cover[e.anchor] += 1
                if cover[e.anchor] == 1 { distinct += 1 }
                if distinct > best.count {
                    if best.count > 0, abs(best.from - e.at) > 5 { runner = (best.count, best.from) }
                    best = (distinct, e.at, e.at)
                    inBest = true
                } else if distinct > runner.count, abs(e.at - best.from) > 5 {
                    runner = (distinct, e.at)
                }
            } else {
                cover[e.anchor] -= 1
                if cover[e.anchor] == 0 {
                    distinct -= 1
                    if inBest, distinct < best.count { best.to = e.at; inBest = false }
                }
            }
        }
        guard best.count >= minMatched else { return nil }
        // Ambiguous: another offset (≥ 5 s away) matches nearly as many.
        if runner.count > 0, Double(runner.count) > Double(best.count) * 0.8, best.count - runner.count < 3 { return nil }
        // Matching only bounds the start to a window as wide as the anchors'
        // windows; settle it with each matched anchor's typical offset.
        let coarse = (best.from + best.to) / 2
        var estimates: [Double] = []
        for a in anchors {
            let t = a.date.timeIntervalSince(ref)
            let candidates = blasts.filter { b in a.window.contains(coarse + b - t) }
            if let b = candidates.min(by: { abs(coarse + $0 - t - a.typical) < abs(coarse + $1 - t - a.typical) }) {
                estimates.append(t + a.typical - b)
            }
        }
        estimates.sort()
        var startOffset = estimates.isEmpty ? coarse : estimates[estimates.count / 2]
        startOffset = min(max(startOffset, best.from), best.to)
        let start = ref.addingTimeInterval(startOffset)
        let inside = anchors.filter { let t = $0.date.timeIntervalSince(start); return t >= 0 && t <= videoDuration }.count
        return VideoSync(videoStart: start, method: .whistles, matched: best.count, anchors: max(inside, best.count))
    }

    /// Whistle sync if it works, else the recording time, else the first event.
    public static func sync(blasts: [TimeInterval], anchors: [SyncAnchor], videoDuration: TimeInterval,
                            recordingTime: Date?, firstEvent: Date?) -> VideoSync {
        if let s = solve(blasts: blasts, anchors: anchors, videoDuration: videoDuration, guess: recordingTime) { return s }
        if recordingTime != nil, let s = solve(blasts: blasts, anchors: anchors, videoDuration: videoDuration) { return s }
        if let recordingTime {
            let inside = anchors.filter { let t = $0.date.timeIntervalSince(recordingTime); return t >= 0 && t <= videoDuration }
            let hits = inside.filter { a in
                blasts.contains { b in a.window.contains(recordingTime.addingTimeInterval(b).timeIntervalSince(a.date)) }
            }.count
            return VideoSync(videoStart: recordingTime, method: .recordingTime, matched: hits, anchors: inside.count)
        }
        return VideoSync(videoStart: firstEvent ?? Date(), method: .none)
    }
}

// MARK: - Anchors and clips per sport

extension ClipPolicy {
    /// Soccer: a call comes a few seconds after the goal, foul or save.
    public static let soccer = ClipPolicy(lead: 20, tail: 4)
}

extension FootballGame {
    /// Each play's call follows the whistle that ended the play by a few seconds.
    public var syncAnchors: [SyncAnchor] {
        activeEvents.compactMap { e in
            guard let p = e.play, p.kind != .penalty else { return nil }
            return SyncAnchor(date: e.wallTime, window: -12 ... -0.5, typical: -3.5)
        }
    }
}

extension SoccerGame {
    /// Kickoff/period taps land on the whistle; fouls, offsides and cards are
    /// called after the whistle that stopped play.
    public var syncAnchors: [SyncAnchor] {
        activeEvents.compactMap { e in
            switch e.action.kind {
            case .periodStart, .periodEnd: SyncAnchor(date: e.wallTime, window: -4...4, typical: 0)
            case .foul, .offside, .card: SyncAnchor(date: e.wallTime, window: -25 ... -0.5, typical: -5)
            default: nil
            }
        }
    }
}

extension GameRecording.Segment {
    /// The clip around a moment, if this segment's video covers it.
    public func clip(at date: Date, policy: ClipPolicy) -> VideoRef? {
        let anchor = date.timeIntervalSince(startedAt)
        guard let duration, anchor >= 0, anchor <= duration + policy.tail else { return nil }
        return policy.clip(assetID: file, anchor: anchor, available: duration)
    }
}

extension GameRecording {
    /// The clip from an imported camera video around a moment (newest import first).
    /// Computed on demand, so a re-sync or nudge moves every clip with it.
    public func importedClip(at date: Date, policy: ClipPolicy) -> VideoRef? {
        for s in segments.reversed() where s.isImported {
            if let ref = s.clip(at: date, policy: policy) { return ref }
        }
        return nil
    }

    public var importedSegments: [Segment] { segments.filter(\.isImported) }
}
