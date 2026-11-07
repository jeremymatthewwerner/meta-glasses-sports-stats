import Foundation

/// Everything recorded during one probe run, plus derived summary and
/// CSV/JSON serialization. Value type; the app owns one per run.
public struct ProbeRun: Codable, Sendable {
    public let id: String
    public let startedAt: Date
    public var config: ProbeRunConfig
    public var device: ProbeDeviceInfo?
    public private(set) var samples: [ProbeSample] = []
    public private(set) var events: [ProbeEvent] = []
    public private(set) var stoppedAt: Date?

    public init(id: String = UUID().uuidString, startedAt: Date = Date(), config: ProbeRunConfig) {
        self.id = id
        self.startedAt = startedAt
        self.config = config
    }

    public mutating func add(_ sample: ProbeSample) {
        samples.append(sample)
    }

    public mutating func add(_ event: ProbeEvent) {
        events.append(event)
    }

    public mutating func stop(at date: Date = Date(), reason: String) {
        guard stoppedAt == nil else { return }
        stoppedAt = date
        events.append(ProbeEvent(elapsed: date.timeIntervalSince(startedAt), kind: .runStopped, detail: reason))
    }

    public var summary: ProbeSummary { ProbeSummary(run: self) }

    /// Folder-safe name, e.g. "2026-11-08T14-03-22_gen3-15fps-medium".
    public var folderName: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let stamp = f.string(from: startedAt).replacingOccurrences(of: ":", with: "-")
        let label = config.label
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let slug = String(label).split(separator: "-").joined(separator: "-")
        return slug.isEmpty ? stamp : "\(stamp)_\(slug)"
    }
}

// MARK: - Summary

/// The numbers Phase 0 needs per run: how long did streaming survive, what
/// killed it, and how fast did the battery drain.
public struct ProbeSummary: Codable, Sendable, Equatable {
    public var durationSeconds: TimeInterval
    public var streamingSeconds: TimeInterval
    public var longestContinuousStreamingSeconds: TimeInterval
    public var meanFpsWhileStreaming: Double
    public var totalFrames: Int
    public var stallCount: Int
    public var pauseCount: Int
    public var errorCount: Int
    public var glassesBatteryStart: Int?
    public var glassesBatteryEnd: Int?
    /// Percentage points per hour of streaming, if measurable.
    public var glassesBatteryDrainPerHour: Double?
    public var firstThermalWarningSeconds: TimeInterval?
    public var maxThermal: String
    public var stopReason: String?
    public var bytesWritten: Int64

    /// Thermal levels at or above this count as a "warning" for the summary.
    static let thermalOrder = ["unknown", "none", "light", "moderate", "severe", "critical", "emergency", "shutdown"]
    static let thermalWarningLevel = "moderate"

    public init(run: ProbeRun) {
        let s = run.samples
        let interval = Self.sampleInterval(s)

        durationSeconds = (run.stoppedAt ?? run.startedAt.addingTimeInterval(s.last?.elapsed ?? 0))
            .timeIntervalSince(run.startedAt)
        streamingSeconds = Double(s.filter { $0.streamState == "streaming" }.count) * interval

        var longest = 0.0, current = 0.0
        for sample in s {
            if sample.streamState == "streaming" { current += interval } else { current = 0 }
            longest = max(longest, current)
        }
        longestContinuousStreamingSeconds = longest

        let streamingFps = s.filter { $0.streamState == "streaming" }.map(\.measuredFps)
        meanFpsWhileStreaming = streamingFps.isEmpty ? 0 : streamingFps.reduce(0, +) / Double(streamingFps.count)
        totalFrames = s.last?.framesTotal ?? 0
        bytesWritten = s.last?.bytesWritten ?? 0

        stallCount = run.events.filter { $0.kind == .stall }.count
        pauseCount = run.events.filter { $0.kind == .streamState && $0.detail == "paused" }.count
        errorCount = run.events.filter { $0.kind == .sessionError || $0.kind == .streamError }.count

        let batteries = s.compactMap(\.glassesBattery)
        glassesBatteryStart = batteries.first
        glassesBatteryEnd = batteries.last
        if let a = batteries.first, let b = batteries.last, streamingSeconds >= 300, a > b {
            glassesBatteryDrainPerHour = Double(a - b) / (streamingSeconds / 3600)
        } else {
            glassesBatteryDrainPerHour = nil
        }

        let warnIdx = Self.thermalOrder.firstIndex(of: Self.thermalWarningLevel)!
        firstThermalWarningSeconds = s.first {
            (Self.thermalOrder.firstIndex(of: $0.glassesThermal) ?? 0) >= warnIdx
        }?.elapsed
        maxThermal = s.map(\.glassesThermal)
            .max { (Self.thermalOrder.firstIndex(of: $0) ?? 0) < (Self.thermalOrder.firstIndex(of: $1) ?? 0) }
            ?? "unknown"

        stopReason = run.events.last { $0.kind == .runStopped }?.detail
    }

    /// Median spacing between samples (defaults to 1 s).
    static func sampleInterval(_ s: [ProbeSample]) -> TimeInterval {
        guard s.count >= 2 else { return 1 }
        let gaps = zip(s.dropFirst(), s).map { $0.elapsed - $1.elapsed }.sorted()
        return gaps[gaps.count / 2]
    }
}

// MARK: - Serialization

extension ProbeRun {
    public static let samplesCSVHeader =
        "elapsed_s,glasses_battery,glasses_charging,glasses_thermal,don,hinge,link,session_state,stream_state,frames_total,fps,bytes_written,phone_battery,phone_thermal"

    public func samplesCSV() -> String {
        var lines = [Self.samplesCSVHeader]
        for s in samples {
            lines.append([
                String(format: "%.1f", s.elapsed),
                s.glassesBattery.map(String.init) ?? "",
                s.glassesCharging, s.glassesThermal, s.donState, s.hingeState, s.linkState,
                s.sessionState, s.streamState,
                String(s.framesTotal),
                String(format: "%.2f", s.measuredFps),
                String(s.bytesWritten),
                s.phoneBattery.map { String(format: "%.2f", $0) } ?? "",
                s.phoneThermal,
            ].map(Self.csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public func eventsCSV() -> String {
        var lines = ["elapsed_s,kind,detail"]
        for e in events {
            lines.append([String(format: "%.1f", e.elapsed), e.kind.rawValue, e.detail]
                .map(Self.csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public func summaryJSON() throws -> Data {
        struct Envelope: Encodable {
            let id: String
            let startedAt: Date
            let config: ProbeRunConfig
            let device: ProbeDeviceInfo?
            let summary: ProbeSummary
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(Envelope(id: id, startedAt: startedAt, config: config, device: device, summary: summary))
    }

    /// Writes samples.csv, events.csv and summary.json into `directory`.
    public func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try samplesCSV().write(to: directory.appendingPathComponent("samples.csv"), atomically: true, encoding: .utf8)
        try eventsCSV().write(to: directory.appendingPathComponent("events.csv"), atomically: true, encoding: .utf8)
        try summaryJSON().write(to: directory.appendingPathComponent("summary.json"), options: .atomic)
    }

    static func csvField(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
