import CoreMedia
import Foundation
import MWDATCamera
import MWDATCore
import Observation
import SidelineCore
import UIKit

/// Runs one Phase 0 endurance probe: opens a device session on the chosen
/// glasses, streams with the chosen config, optionally records HEVC to disk,
/// and samples glasses/phone/stream health at 1 Hz until stopped.
///
/// Output per run (Documents/runs/<folder>/): samples.csv, events.csv,
/// summary.json and, for HEVC runs, video.mov.
@MainActor
@Observable
final class ProbeRunner {
    static let sdkVersion = "1.0.1"

    private(set) var isRunning = false
    private(set) var run: ProbeRun?
    private(set) var latest: ProbeSample?
    private(set) var preview: UIImage?
    private(set) var recentEvents: [ProbeEvent] = []
    private(set) var lastRunFolder: URL?
    private(set) var startError: String?

    private var session: DeviceSession?
    private var camera: Camera?
    private var tokens = ListenerTokenBag()
    private var tap = FrameTap()
    private var writer: HEVCFileWriter?
    private var sampler: Timer?
    private var lastThermal: String?
    private var runFolder: URL?

    // MARK: Start / stop

    func start(config: ProbeRunConfig, deviceID: DeviceIdentifier) async {
        guard !isRunning else { return }
        startError = nil
        recentEvents = []
        preview = nil
        latest = nil
        lastThermal = nil
        tap = FrameTap()
        tokens = ListenerTokenBag()

        var newRun = ProbeRun(config: config)
        let folder = Self.runsDirectory.appendingPathComponent(newRun.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runFolder = folder

        let wearables = Wearables.shared
        if let d = wearables.deviceForIdentifier(deviceID) {
            newRun.device = ProbeDeviceInfo(
                glassesName: d.nameOrId(),
                glassesType: d.deviceType().rawValue,
                compatibility: d.compatibility().displayString,
                sdkVersion: Self.sdkVersion,
                phoneModel: Self.phoneModel,
                phoneOS: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            )
        }
        run = newRun
        isRunning = true
        log(.runStarted, "\(config.resolution.rawValue) \(config.frameRate)fps \(config.codec.rawValue) on \(newRun.device?.glassesType ?? "?")")

        UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        startSampler()

        do {
            let session = try wearables.createSession(deviceSelector: SpecificDeviceSelector(device: deviceID))
            self.session = session

            // Subscribe before start() so no transition is missed.
            let states = session.stateStream()
            session.statePublisher.listen { [weak self] state in
                Task { @MainActor in self?.onSessionState(state) }
            }.store(in: tokens)
            session.errorPublisher.listen { [weak self] error in
                Task { @MainActor in self?.log(.sessionError, Self.describe(error)) }
            }.store(in: tokens)

            try session.start()
            for await state in states {
                if state == .started { break }
                if state == .stopped { throw ProbeError.sessionStoppedBeforeStart }
            }

            let streamConfig = StreamConfiguration(
                videoCodec: config.codec == .hevc ? .hvc1 : .raw,
                resolution: Self.resolution(config.resolution),
                frameRate: config.frameRate
            )
            guard let camera = try session.addCamera(config: streamConfig) else {
                throw ProbeError.cameraUnavailable
            }
            self.camera = camera
            attach(stream: camera.stream, config: config, folder: folder)
            camera.stream.start()
        } catch {
            startError = Self.describe(error)
            log(.sessionError, "start failed: \(startError!)")
            await finish(reason: "start failed: \(startError!)")
        }
    }

    func stop(reason: String = "user") async {
        guard isRunning else { return }
        await finish(reason: reason)
    }

    func addNote(_ text: String) {
        log(.note, text)
    }

    // MARK: Stream wiring

    private func attach(stream: MWDATCamera.Stream, config: ProbeRunConfig, folder: URL) {
        let tap = self.tap
        let writer: HEVCFileWriter? = (config.codec == .hevc && config.recordToFile)
            ? HEVCFileWriter(url: folder.appendingPathComponent("video.mov")) : nil
        self.writer = writer
        // Raw frames: preview ~4x/s. HEVC frames need decoding to preview, so skip.
        let previewEvery = config.codec == .raw ? max(1, Int(config.frameRate) / 4) : 0

        stream.statePublisher.listen { [weak self] state in
            Task { @MainActor in self?.log(.streamState, "\(state)") }
        }.store(in: tokens)

        stream.errorPublisher.listen { [weak self] error in
            Task { @MainActor in self?.log(.streamError, Self.describe(error)) }
        }.store(in: tokens)

        stream.videoFramePublisher.listen { [weak self] frame in
            let size = config.codec == .hevc ? CMSampleBufferGetTotalSampleSize(frame.sampleBuffer) : 0
            let result = tap.frame(bytes: size, previewEvery: previewEvery)
            writer?.append(frame)
            if result.recoveredFromStall {
                Task { @MainActor in self?.log(.stallRecovered, "frames resumed") }
            }
            if result.wantPreview, let image = frame.makeUIImage() {
                Task { @MainActor in self?.preview = image }
            }
        }.store(in: tokens)
    }

    // MARK: Sampling

    private func startSampler() {
        sampler?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.takeSample() }
        }
        RunLoop.main.add(timer, forMode: .common)   // keep sampling while the UI scrolls
        sampler = timer
    }

    private func takeSample() {
        guard isRunning, let startedAt = run?.startedAt else { return }
        let snap = tap.snapshot()
        let device = session?.device
        let thermal = device.map { "\($0.thermalLevel)" } ?? "unknown"
        let phoneBattery = UIDevice.current.batteryLevel

        let sample = ProbeSample(
            elapsed: Date().timeIntervalSince(startedAt),
            glassesBattery: device?.batteryLevel,
            glassesCharging: device.map { "\($0.chargingState)" } ?? "unknown",
            glassesThermal: thermal,
            donState: device.map { "\($0.donState)" } ?? "unknown",
            hingeState: device.map { "\($0.hingeState)" } ?? "unknown",
            linkState: device.map { "\($0.linkState)" } ?? "unknown",
            sessionState: session.map { "\($0.state)" } ?? "none",
            streamState: camera.map { "\($0.stream.state)" } ?? "none",
            framesTotal: snap.totalFrames,
            measuredFps: snap.fps,
            bytesWritten: snap.bytes,
            phoneBattery: phoneBattery >= 0 ? Double(phoneBattery) : nil,
            phoneThermal: Self.describe(ProcessInfo.processInfo.thermalState)
        )
        run?.add(sample)   // mutate in place; no copy of the growing arrays
        latest = sample

        if snap.newStall { log(.stall, "no frames for >2 s") }
        if thermal != lastThermal {
            if lastThermal != nil { log(.thermalChange, "\(lastThermal!) → \(thermal)") }
            lastThermal = thermal
        }
        // Checkpoint to disk every 30 s so a crash or dead phone loses little.
        if Int(sample.elapsed) % 30 == 0, let folder = runFolder, let current = run {
            try? current.write(to: folder)
        }
    }

    private func onSessionState(_ state: DeviceSessionState) {
        log(.sessionState, "\(state)")
        // A stopped session is terminal: that's the end-of-endurance moment.
        if state == .stopped, isRunning {
            let lastError = recentEvents.last { $0.kind == .sessionError || $0.kind == .streamError }?.detail
            Task { await finish(reason: "session stopped" + (lastError.map { " after \($0)" } ?? "")) }
        }
    }

    // MARK: Teardown

    private func finish(reason: String) async {
        guard isRunning else { return }
        isRunning = false
        sampler?.invalidate()
        sampler = nil
        takeSampleFinal()

        camera?.stop()            // cascades to the stream
        session?.stop()
        await tokens.cancelAll()
        camera = nil
        session = nil

        if let writer {
            let error: String? = await withCheckedContinuation { cont in
                writer.finish { cont.resume(returning: $0) }
            }
            if let error { log(.note, "video: \(error)") }
            self.writer = nil
        }

        if var current = run {
            current.stop(reason: reason)
            run = current
            if let folder = runFolder {
                do { try current.write(to: folder) } catch { startError = "save failed: \(error)" }
                lastRunFolder = folder
            }
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// One last sample so the summary reflects the final state.
    private func takeSampleFinal() {
        isRunning = true
        takeSample()
        isRunning = false
    }

    private func log(_ kind: ProbeEvent.Kind, _ detail: String) {
        guard let startedAt = run?.startedAt else { return }
        let event = ProbeEvent(elapsed: Date().timeIntervalSince(startedAt), kind: kind, detail: detail)
        run?.add(event)
        recentEvents.append(event)
        if recentEvents.count > 200 { recentEvents.removeFirst(recentEvents.count - 200) }
    }

    // MARK: Utilities

    enum ProbeError: LocalizedError {
        case sessionStoppedBeforeStart, cameraUnavailable
        var errorDescription: String? {
            switch self {
            case .sessionStoppedBeforeStart: "Device session stopped before it started"
            case .cameraUnavailable: "Could not add a camera (session not started?)"
            }
        }
    }

    static var runsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("runs", isDirectory: true)
    }

    static func resolution(_ r: ProbeRunConfig.Resolution) -> StreamingResolution {
        switch r {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }

    nonisolated static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    static func describe(_ t: ProcessInfo.ThermalState) -> String {
        switch t {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    static var phoneModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
