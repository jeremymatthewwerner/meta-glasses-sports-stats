import Foundation

/// Configuration of one endurance/streaming probe run (Phase 0).
public struct ProbeRunConfig: Codable, Sendable, Equatable {
    public enum Resolution: String, Codable, Sendable, CaseIterable {
        case low     // 360x640
        case medium  // 504x896
        case high    // 720x1280

        public var size: (width: Int, height: Int) {
            switch self {
            case .low: (360, 640)
            case .medium: (504, 896)
            case .high: (720, 1280)
            }
        }
    }

    public enum Codec: String, Codable, Sendable, CaseIterable {
        case raw   // decoded frames; preview only, nothing written to disk
        case hevc  // compressed hvc1 frames; written to disk in passthrough
    }

    /// Frame rates DAT 1.0 accepts.
    public static let validFrameRates: [UInt] = [2, 7, 15, 24, 30]

    public var label: String
    public var resolution: Resolution
    public var frameRate: UInt
    public var codec: Codec
    public var recordToFile: Bool

    public init(
        label: String = "",
        resolution: Resolution = .medium,
        frameRate: UInt = 15,
        codec: Codec = .hevc,
        recordToFile: Bool = true
    ) {
        self.label = label
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.recordToFile = recordToFile
    }

    public var isValid: Bool { Self.validFrameRates.contains(frameRate) }
}

/// Static facts about the glasses and phone at the start of a run.
public struct ProbeDeviceInfo: Codable, Sendable, Equatable {
    public var glassesName: String
    public var glassesType: String        // DAT DeviceType raw value, e.g. "rayBanMeta"
    public var compatibility: String      // DAT Compatibility
    public var sdkVersion: String
    public var phoneModel: String
    public var phoneOS: String

    public init(
        glassesName: String, glassesType: String, compatibility: String,
        sdkVersion: String, phoneModel: String, phoneOS: String
    ) {
        self.glassesName = glassesName
        self.glassesType = glassesType
        self.compatibility = compatibility
        self.sdkVersion = sdkVersion
        self.phoneModel = phoneModel
        self.phoneOS = phoneOS
    }
}

/// One periodic (≈1 Hz) snapshot of glasses + phone + stream health.
/// States are plain strings so this package has no SDK dependency.
public struct ProbeSample: Codable, Sendable, Equatable {
    public var elapsed: TimeInterval          // seconds since run start
    public var glassesBattery: Int?           // 0–100
    public var glassesCharging: String
    public var glassesThermal: String         // none/light/moderate/severe/critical/emergency/shutdown/unknown
    public var donState: String
    public var hingeState: String
    public var linkState: String
    public var sessionState: String
    public var streamState: String
    public var framesTotal: Int
    public var measuredFps: Double            // over the trailing window
    public var bytesWritten: Int64
    public var phoneBattery: Double?          // 0.0–1.0
    public var phoneThermal: String           // nominal/fair/serious/critical

    public init(
        elapsed: TimeInterval, glassesBattery: Int?, glassesCharging: String,
        glassesThermal: String, donState: String, hingeState: String, linkState: String,
        sessionState: String, streamState: String, framesTotal: Int, measuredFps: Double,
        bytesWritten: Int64, phoneBattery: Double?, phoneThermal: String
    ) {
        self.elapsed = elapsed
        self.glassesBattery = glassesBattery
        self.glassesCharging = glassesCharging
        self.glassesThermal = glassesThermal
        self.donState = donState
        self.hingeState = hingeState
        self.linkState = linkState
        self.sessionState = sessionState
        self.streamState = streamState
        self.framesTotal = framesTotal
        self.measuredFps = measuredFps
        self.bytesWritten = bytesWritten
        self.phoneBattery = phoneBattery
        self.phoneThermal = phoneThermal
    }
}

/// A discrete thing that happened during a run.
public struct ProbeEvent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case runStarted
        case runStopped
        case sessionState
        case streamState
        case sessionError
        case streamError
        case stall           // no frames for longer than the stall threshold
        case stallRecovered
        case thermalChange
        case note            // free-form, e.g. "put in case at halftime"
    }

    public var elapsed: TimeInterval
    public var kind: Kind
    public var detail: String

    public init(elapsed: TimeInterval, kind: Kind, detail: String) {
        self.elapsed = elapsed
        self.kind = kind
        self.detail = detail
    }
}
