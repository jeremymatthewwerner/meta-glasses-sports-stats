import Foundation
import MWDATCore
import MWDATMockDevice
import Observation

/// Registration, permissions, and the list of linked glasses.
@MainActor
@Observable
final class WearablesModel {
    struct GlassesRow: Identifiable, Equatable {
        let id: DeviceIdentifier
        var name: String
        var type: String           // DeviceType raw value, e.g. "rayBanMeta", "metaRayBanDisplay"
        var compatibility: String
        var link: String
        var battery: Int?
        var thermal: String
        var supportsDisplay: Bool
    }

    private(set) var registration: RegistrationState = .unavailable
    private(set) var glasses: [GlassesRow] = []
    var selectedID: DeviceIdentifier?
    private(set) var cameraPermission: String = "unknown"
    private(set) var lastError: String?
    private(set) var mockEnabled = false

    private var started = false
    private var refreshTimer: Timer?

    func start() {
        guard !started else { return }
        started = true
        let wearables = Wearables.shared
        registration = wearables.registrationState

        Task { [weak self] in
            for await state in wearables.registrationStateStream() {
                self?.registration = state
            }
        }
        Task { [weak self] in
            for await ids in wearables.devicesStream() {
                self?.refresh(ids: ids)
            }
        }
        // Battery/thermal on the device list; the probe run samples at 1 Hz itself.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(ids: Wearables.shared.devices) }
        }
    }

    var registrationLabel: String {
        switch registration {
        case .unavailable: "Unavailable"
        case .available: "Not registered"
        case .registering: "Registering…"
        case .registered: "Registered"
        @unknown default: "Unknown"
        }
    }

    var selectedGlasses: GlassesRow? {
        glasses.first { $0.id == selectedID }
    }

    // MARK: Registration & permissions

    func register() {
        Task {
            do { try await Wearables.shared.startRegistration() } catch { report(error) }
        }
    }

    func unregister() {
        Task {
            do { try await Wearables.shared.startUnregistration() } catch { report(error) }
        }
    }

    func handle(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
        else { return }
        Task {
            do { _ = try await Wearables.shared.handleUrl(url) } catch { report(error) }
        }
    }

    func checkCameraPermission() {
        Task {
            do {
                let status = try await Wearables.shared.checkPermissionStatus(.camera)
                cameraPermission = status == .granted ? "granted" : "denied"
            } catch { report(error) }
        }
    }

    func requestCameraPermission() {
        Task {
            do {
                let status = try await Wearables.shared.requestPermission(.camera)
                cameraPermission = status == .granted ? "granted" : "denied"
            } catch { report(error) }
        }
    }

    // MARK: Mock glasses (no hardware)

    /// Pairs a simulated pair of glasses. On a real phone, `feedURL == nil`
    /// streams the phone's back camera; in the simulator pass a video file.
    func enableMock(model: GlassesModel, feedURL: URL?) {
        do {
            let kit = MockDeviceKit.shared
            if !kit.isEnabled { kit.enable() }
            let mock = try kit.pairGlasses(model: model)
            mock.powerOn()
            mock.unfold()
            mock.don()
            mock.setBatteryLevel(100)
            if let feedURL {
                mock.services.camera.setCameraFeed(fileURL: feedURL)
            } else {
                mock.services.camera.setCameraFeed(cameraFacing: .back)
            }
            mockEnabled = true
        } catch {
            report(error)
        }
    }

    func disableMock() {
        MockDeviceKit.shared.disable()
        mockEnabled = false
    }

    // MARK: Helpers

    func clearError() { lastError = nil }

    private func refresh(ids: [DeviceIdentifier]) {
        glasses = ids.compactMap { id in
            guard let d = Wearables.shared.deviceForIdentifier(id) else { return nil }
            return GlassesRow(
                id: id,
                name: d.nameOrId(),
                type: d.deviceType().rawValue,
                compatibility: d.compatibility().displayString,
                link: "\(d.linkState)",
                battery: d.batteryLevel,
                thermal: "\(d.thermalLevel)",
                supportsDisplay: d.supportsDisplay()
            )
        }
        if selectedID == nil || !glasses.contains(where: { $0.id == selectedID }) {
            selectedID = glasses.first?.id
        }
    }

    private func report(_ error: Error) {
        lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }
}
