// No SwiftUI import here on purpose: MWDATDisplay's Text/Button/Image
// would clash with SwiftUI's (see the DAT 0.5 changelog note).
import Foundation
import MWDATCore
import MWDATDisplay
import Observation
import SidelineCore

/// Heads-up scorebook on Meta Ray-Ban Display: score, situation, the last
/// play and Confirm / Undo buttons (selectable with the Neural Band).
///
/// Owns its own DeviceSession with a Display capability. DAT allows one
/// session per device, so it can't run at the same time as a probe run yet.
@MainActor
@Observable
final class GlassesHUD {
    enum Status: Equatable {
        case off
        case connecting
        case on(glasses: String)
        case failed(String)
    }

    private(set) var status: Status = .off
    private(set) var sentCount = 0

    /// Called on the main actor when the wearer picks a button on the lens.
    var onConfirm: ((UUID) -> Void)?
    var onUndo: (() -> Void)?

    private var session: DeviceSession?
    private var display: Display?
    private var tokens = ListenerTokenBag()
    private var shown: FootballHUD?
    private var queued: FootballHUD?
    private var sending = false
    private var lastSessionError: DeviceSessionError?

    var isOn: Bool { if case .on = status { true } else { false } }
    var isActive: Bool { session != nil }

    var statusText: String {
        switch status {
        case .off: "Off"
        case .connecting: "Connecting…"
        case .on(let name): "On \(name)"
        case .failed(let why): "Failed: \(why)"
        }
    }

    // MARK: Connect / disconnect

    /// Opens a session on the given glasses (which must have a display).
    func connect(deviceID: DeviceIdentifier?, initial hud: FootballHUD) async {
        guard session == nil else { return }
        guard let deviceID else {
            status = .failed("No Meta Ray-Ban Display linked. Pair it in Meta AI (or a mock Display on the probe tab).")
            return
        }
        status = .connecting
        tokens = ListenerTokenBag()
        shown = nil
        do {
            let wearables = Wearables.shared
            let session = try wearables.createSession(deviceSelector: SpecificDeviceSelector(device: deviceID))
            self.session = session

            let states = session.stateStream()
            lastSessionError = nil
            session.errorPublisher.listen { [weak self] error in
                Task { @MainActor in self?.lastSessionError = error }
            }.store(in: tokens)

            try session.start()
            for await state in states {
                if state == .started { break }
                if state == .stopped {
                    try? await Task.sleep(for: .milliseconds(500))
                    throw HUDError.sessionEnded(lastSessionError.map { "\($0)" })
                }
            }

            // From here on, a stopped session means the HUD is gone.
            session.statePublisher.listen { [weak self] state in
                Task { @MainActor in
                    if state == .stopped { self?.ended("session ended") }
                }
            }.store(in: tokens)

            let display = try session.addDisplay()
            self.display = display
            let displayStates = AsyncStream<DisplayState> { cont in
                display.statePublisher.listen { cont.yield($0) }.store(in: self.tokens)
            }
            display.start()
            if display.state != .started {
                for await s in displayStates {
                    if s == .started { break }
                    if s == .stopped { throw HUDError.displayStopped }
                }
            }
            status = .on(glasses: session.device?.nameOrId() ?? "glasses")
            show(hud)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            teardown()
            status = .failed(message)
        }
    }

    func disconnect() {
        let display = self.display
        teardown()
        Task { try? await display?.clearDisplay() }
        status = .off
    }

    private func ended(_ why: String) {
        guard session != nil else { return }
        teardown()
        status = .failed(why)
    }

    private func teardown() {
        display?.stop()
        session?.stop()
        display = nil
        session = nil
        let old = tokens
        Task { await old.cancelAll() }
    }

    // MARK: Rendering

    /// Sends the HUD if it changed. Sends are serialized; if one is in
    /// flight, only the newest pending state is sent afterwards.
    func show(_ hud: FootballHUD) {
        guard isOn, hud != shown else { return }
        if sending { queued = hud; return }
        sending = true
        Task {
            var next: FootballHUD? = hud
            while let current = next, let display {
                do {
                    try await display.send(render(current))
                    shown = current
                    sentCount += 1
                } catch {
                    ended("send failed: \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
                }
                next = queued
                queued = nil
            }
            sending = false
        }
    }

    private func render(_ hud: FootballHUD) -> FlexBox {
        let playID = hud.lastPlayID
        let confirm: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in if let playID { self?.onConfirm?(playID) } }
        }
        let undo: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.onUndo?() }
        }
        return FlexBox(direction: .column, spacing: 6, alignment: .start, crossAlignment: .stretch,
                       padding: EdgeInsets(all: 12)) {
            Text(hud.scoreLine, style: .heading)
            Text(hud.situationLine, style: .body, color: .secondary)
            if let play = hud.lastPlay {
                FlexBox(direction: .column, spacing: 2, padding: EdgeInsets(all: 8)) {
                    Text(play, style: .body)
                    Text(hud.lastPlayNeedsConfirm ? "Proposed" : "Confirmed", style: .meta, color: .secondary)
                }
                .background(.card)
                ButtonGroup(alignment: .start) {
                    if hud.lastPlayNeedsConfirm {
                        Button(label: "Confirm", style: .primary, iconName: .checkmark, onClick: confirm)
                            .actionRole(.primary)
                    }
                    Button(label: "Undo", style: .secondary, onClick: undo)
                }
            } else {
                Text("Call a play on your phone", style: .meta, color: .secondary)
            }
            if hud.pendingCount > 1 {
                Text("\(hud.pendingCount) plays to confirm", style: .meta, color: .secondary)
            }
        }
    }

    enum HUDError: LocalizedError {
        case sessionEnded(String?)
        case displayStopped
        var errorDescription: String? {
            switch self {
            case .sessionEnded(let why): "The glasses ended the session" + (why.map { " (\($0))" } ?? "")
            case .displayStopped: "The display stopped before it started"
            }
        }
    }
}
