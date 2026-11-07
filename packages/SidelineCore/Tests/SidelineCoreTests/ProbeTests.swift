import Foundation
import Testing
@testable import SidelineCore

@Suite struct FrameRateMeterTests {
    @Test func steadyFifteenFps() {
        var m = FrameRateMeter(window: 5, stallThreshold: 2)
        for i in 0..<150 { m.recordFrame(at: Double(i) / 15) }   // 10 s at 15 fps
        let fps = m.fps(at: 10)
        #expect(abs(fps - 15) < 0.5)
        #expect(m.totalFrames == 150)
        #expect(m.stallCount == 0)
    }

    @Test func partialWindowUsesElapsedSpan() {
        var m = FrameRateMeter(window: 5)
        for i in 0..<30 { m.recordFrame(at: Double(i) / 30) }    // 1 s at 30 fps
        #expect(abs(m.fps(at: 1) - 30) < 1)
    }

    @Test func detectsStallOnceAndRecovery() {
        var m = FrameRateMeter(window: 5, stallThreshold: 2)
        m.recordFrame(at: 0)
        m.recordFrame(at: 0.1)
        #expect(m.checkStall(at: 1.0) == false)
        #expect(m.checkStall(at: 2.5) == true)
        #expect(m.checkStall(at: 3.0) == false)    // same stall, reported once
        #expect(m.recordFrame(at: 4.0) == true)    // recovered
        #expect(m.stallCount == 1)
        #expect(m.longestGap >= 3.8)
    }

    @Test func noStallBeforeFirstFrame() {
        var m = FrameRateMeter()
        #expect(m.checkStall(at: 100) == false)
        #expect(m.fps(at: 100) == 0)
    }
}

@Suite struct ProbeRunTests {
    func sample(_ t: Double, battery: Int?, stream: String = "streaming", thermal: String = "none", frames: Int = 0) -> ProbeSample {
        ProbeSample(
            elapsed: t, glassesBattery: battery, glassesCharging: "notCharging", glassesThermal: thermal,
            donState: "donned", hingeState: "open", linkState: "connected", sessionState: "started",
            streamState: stream, framesTotal: frames, measuredFps: stream == "streaming" ? 15 : 0,
            bytesWritten: Int64(frames * 1000), phoneBattery: 0.9, phoneThermal: "nominal")
    }

    @Test func summaryComputesEnduranceAndDrain() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var run = ProbeRun(startedAt: start, config: ProbeRunConfig(label: "Gen3 15fps"))
        // 30 min streaming, battery 100 -> 70; thermal goes moderate at 20 min.
        for t in 0..<1800 {
            let battery = 100 - t / 60
            run.add(sample(Double(t), battery: battery, thermal: t >= 1200 ? "moderate" : "none", frames: t * 15))
        }
        // Then 60 s stopped.
        for t in 1800..<1860 { run.add(sample(Double(t), battery: 70, stream: "stopped", thermal: "severe", frames: 27000)) }
        run.add(ProbeEvent(elapsed: 1800, kind: .streamError, detail: "thermalHot"))
        run.stop(at: start.addingTimeInterval(1860), reason: "user")

        let s = run.summary
        #expect(s.durationSeconds == 1860)
        #expect(s.streamingSeconds == 1800)
        #expect(s.longestContinuousStreamingSeconds == 1800)
        #expect(s.glassesBatteryStart == 100)
        #expect(s.glassesBatteryEnd == 70)
        #expect(abs((s.glassesBatteryDrainPerHour ?? 0) - 60) < 0.01)   // 30 pts / 0.5 h
        #expect(s.firstThermalWarningSeconds == 1200)
        #expect(s.maxThermal == "severe")
        #expect(s.errorCount == 1)
        #expect(s.stopReason == "user")
        #expect(abs(s.meanFpsWhileStreaming - 15) < 0.01)
        #expect(s.totalFrames == 27000)
    }

    @Test func drainNotReportedForShortRuns() {
        var run = ProbeRun(config: ProbeRunConfig())
        for t in 0..<60 { run.add(sample(Double(t), battery: 100 - t / 30)) }
        #expect(run.summary.glassesBatteryDrainPerHour == nil)
    }

    @Test func longestContinuousResetsOnPause() {
        var run = ProbeRun(config: ProbeRunConfig())
        for t in 0..<10 { run.add(sample(Double(t), battery: 90)) }
        for t in 10..<15 { run.add(sample(Double(t), battery: 90, stream: "paused")) }
        for t in 15..<40 { run.add(sample(Double(t), battery: 90)) }
        #expect(run.summary.longestContinuousStreamingSeconds == 25)
        #expect(run.summary.streamingSeconds == 35)
    }

    @Test func csvHasHeaderRowPerSampleAndEscapes() {
        var run = ProbeRun(config: ProbeRunConfig())
        run.add(sample(0, battery: nil))
        run.add(sample(1, battery: 88))
        run.add(ProbeEvent(elapsed: 1, kind: .note, detail: "case at half, \"quick\""))
        let rows = run.samplesCSV().split(separator: "\n")
        #expect(rows.count == 3)
        #expect(rows[0] == Substring(ProbeRun.samplesCSVHeader))
        #expect(rows[1].hasPrefix("0.0,,notCharging"))
        #expect(run.eventsCSV().contains("\"case at half, \"\"quick\"\"\""))
    }

    @Test func writesRunFolder() throws {
        var run = ProbeRun(config: ProbeRunConfig(label: "Display / 7fps"))
        run.add(sample(0, battery: 50))
        run.stop(reason: "user")
        #expect(run.folderName.hasSuffix("_display-7fps"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try run.write(to: dir)
        for f in ["samples.csv", "events.csv", "summary.json"] {
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(f).path))
        }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("summary.json"))) as? [String: Any]
        #expect((json?["summary"] as? [String: Any])?["stopReason"] as? String == "user")
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func configValidatesFrameRate() {
        #expect(ProbeRunConfig(frameRate: 15).isValid)
        #expect(!ProbeRunConfig(frameRate: 20).isValid)
    }
}
