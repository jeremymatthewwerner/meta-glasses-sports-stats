import Foundation
import Testing
@testable import SidelineCore

@Suite struct VideoSyncTests {
    let sr = 12_000.0

    /// Pea whistle: ~3.2 kHz with a fast warble.
    func whistle(_ seconds: Double, freq: Double = 3200, amp: Float = 0.35) -> [Float] {
        let n = Int(seconds * sr)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / sr
            let f = freq + 150 * sin(2 * .pi * 28 * t)
            phase += 2 * .pi * f / sr
            return amp * Float(sin(phase))
        }
    }

    /// Crowd-ish noise plus a few speech-band harmonics.
    func noise(_ seconds: Double, seed: UInt64, amp: Float = 0.08) -> [Float] {
        var rng = SplitMix(seed: seed)
        let n = Int(seconds * sr)
        return (0..<n).map { i in
            let t = Double(i) / sr
            let speech = 0.05 * sin(2 * .pi * 180 * t) + 0.03 * sin(2 * .pi * 540 * t) + 0.02 * sin(2 * .pi * 900 * t)
            return amp * Float(rng.nextGaussian()) + Float(speech)
        }
    }

    func mix(_ base: inout [Float], _ add: [Float], at seconds: Double) {
        let o = Int(seconds * sr)
        for i in 0..<add.count where o + i < base.count { base[o + i] += add[i] }
    }

    @Test func findsWhistlesInNoiseAndNothingElse() {
        var audio = noise(60, seed: 1)
        let times = [5.0, 12.3, 30.0, 47.8]
        for (k, t) in times.enumerated() { mix(&audio, whistle([0.4, 1.0, 0.25, 0.6][k]), at: t) }
        mix(&audio, (0..<Int(3 * sr)).map { Float(0.3 * sin(2 * .pi * 600 * Double($0) / sr)) }, at: 20)   // a hum
        var d = WhistleDetector(sampleRate: sr)
        for chunk in stride(from: 0, to: audio.count, by: 4096) { d.feed(Array(audio[chunk..<min(chunk + 4096, audio.count)])) }
        let blasts = d.finish()
        #expect(blasts.count == times.count, "\(blasts)")
        guard blasts.count == times.count else { return }
        for (b, t) in zip(blasts, times) { #expect(abs(b.start - t) < 0.12, "\(b.start) vs \(t)") }
        #expect(abs(blasts[1].duration - 1.0) < 0.15)
        var quiet = WhistleDetector(sampleRate: sr)
        quiet.feed(noise(30, seed: 2))
        #expect(quiet.finish().isEmpty)
    }

    @Test func solverRecoversTheVideoStartFromPlayCalls() {
        let videoStart = Date(timeIntervalSince1970: 5_000_000)
        var rng = SplitMix(seed: 7)
        var anchors: [SyncAnchor] = []
        var blasts: [TimeInterval] = []
        var t = 60.0
        for _ in 0..<25 {                                          // plays every 25–45 s
            t += 25 + Double(rng.next() % 20)
            let whistle = t
            let call = whistle + 2 + Double(rng.next() % 5)       // call 2–6 s after the whistle
            blasts.append(whistle)
            anchors.append(SyncAnchor(date: videoStart.addingTimeInterval(call), window: -12 ... -0.5, typical: -4))
        }
        for _ in 0..<30 { blasts.append(Double(rng.next() % 1200)) }   // other whistles, other fields
        blasts.sort()
        let s = VideoSyncSolver.solve(blasts: blasts, anchors: anchors, videoDuration: 1300)
        #expect(s != nil)
        #expect(abs(s!.videoStart.timeIntervalSince(videoStart)) < 1.5)
        #expect(s!.matched >= 23 && s!.method == .whistles)
        // A creation time 40 s off still lands on the right offset.
        let g = VideoSyncSolver.solve(blasts: blasts, anchors: anchors, videoDuration: 1300, guess: videoStart.addingTimeInterval(40))
        #expect(abs(g!.videoStart.timeIntervalSince(videoStart)) < 1.5)
    }

    @Test func soccerKickoffsAndFoulsSync() {
        let start = Date(timeIntervalSince1970: 6_000_000)
        var g = SoccerGame(home: TeamInfo(name: "Eagles"), away: TeamInfo(name: "Hawks"), format: .nineASide)
        func add(_ kind: SoccerAction.Kind, at video: Double, period: Int? = nil) {
            var a = SoccerAction(kind: kind, team: .away, player: 4)
            a.period = period
            g.append(SoccerEvent(action: a, source: .human, status: .confirmed, wallTime: start.addingTimeInterval(video)))
        }
        add(.periodStart, at: 120.5, period: 1)
        add(.foul, at: 400)
        add(.card, at: 900)
        add(.periodEnd, at: 1920, period: 1)
        add(.periodStart, at: 2520, period: 2)
        add(.goal, at: 3000)                                     // not an anchor
        let blasts = [120.0, 396.0, 893.0, 1919.0, 2521.0, 1500.0, 2800.0]
        let s = VideoSyncSolver.solve(blasts: blasts, anchors: g.syncAnchors, videoDuration: 4000)
        #expect(s != nil && abs(s!.videoStart.timeIntervalSince(start)) < 3)
        #expect(g.syncAnchors.count == 5)
    }

    @Test func fallsBackToRecordingTimeThenFirstEvent() {
        let rec = Date(timeIntervalSince1970: 7_000_000)
        let anchors = [SyncAnchor(date: rec.addingTimeInterval(100), window: -12 ... -0.5)]
        let s = VideoSyncSolver.sync(blasts: [95], anchors: anchors, videoDuration: 600, recordingTime: rec, firstEvent: nil)
        #expect(s.method == .recordingTime && s.videoStart == rec && s.matched == 1 && s.anchors == 1)
        let n = VideoSyncSolver.sync(blasts: [], anchors: [], videoDuration: 600, recordingTime: nil, firstEvent: rec)
        #expect(n.method == .none && n.videoStart == rec)
        #expect(s.summary.contains("recording time"))
    }

    @Test func importedSegmentsGiveClipsAndRetimeOnSync() {
        let start = Date(timeIntervalSince1970: 8_000_000)
        var rec = GameRecording(gameID: UUID())
        rec.segments.append(.init(file: "glasses-01.mov", startedAt: start, endedAt: start.addingTimeInterval(60), source: "glasses"))
        let name = rec.nextImportName(extension: "MP4")
        #expect(name == "camera-01.mp4" && rec.nextFileName == "glasses-02.mov")
        rec.segments.append(.init(file: name, startedAt: start, endedAt: start.addingTimeInterval(3600), source: "Veo",
                                  sync: VideoSync(videoStart: start, method: .none)))
        #expect(rec.nextFileName == "glasses-02.mov" && rec.nextImportName(extension: "mov") == "camera-02.mov")
        let cam = rec.segments[1]
        let ref = cam.clip(at: start.addingTimeInterval(600), policy: .soccer)
        #expect(ref == VideoRef(assetID: "camera-01.mp4", start: 580, end: 604))
        #expect(cam.clip(at: start.addingTimeInterval(-5), policy: .soccer) == nil)
        rec.setSync(VideoSync(videoStart: start.addingTimeInterval(-30), method: .manual), for: name)
        #expect(rec.segments[1].clip(at: start.addingTimeInterval(600), policy: .soccer)?.start == 610)
        #expect(rec.segments[1].duration == 3600)
    }
}

/// Deterministic RNG for test signals.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func nextGaussian() -> Double {
        let u1 = max(Double(next() % 1_000_000) / 1_000_000, 1e-9), u2 = Double(next() % 1_000_000) / 1_000_000
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

@Suite struct ImportedClipTests {
    @Test func importedClipIgnoresGlassesSegments() {
        let t0 = Date(timeIntervalSince1970: 9_000_000)
        var rec = GameRecording(gameID: UUID())
        rec.segments.append(.init(file: "glasses-01.mov", startedAt: t0, endedAt: t0.addingTimeInterval(600), source: "glasses"))
        #expect(rec.importedClip(at: t0.addingTimeInterval(100), policy: .football) == nil)
        rec.segments.append(.init(file: "camera-01.mp4", startedAt: t0.addingTimeInterval(-60), endedAt: t0.addingTimeInterval(3000),
                                  source: "Veo", sync: VideoSync(videoStart: t0.addingTimeInterval(-60), method: .whistles)))
        #expect(rec.importedClip(at: t0.addingTimeInterval(100), policy: .football) == VideoRef(assetID: "camera-01.mp4", start: 145, end: 162))
        #expect(rec.importedSegments.count == 1)
    }
}
