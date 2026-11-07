# Sideline Probe (Phase 0)

A minimal iOS app for the Phase 0 hardware tests in [docs/PLAN.md](../../../docs/PLAN.md) §14. It answers three questions on real glasses:

1. **Does DAT 1.0.1 work on Ray-Ban Meta Gen 3?** The device list shows the `DeviceType` and `Compatibility` DAT reports. Then try to start a stream.
2. **How long does a live stream survive?** Endurance runs log glasses battery, thermal level, link/session/stream state, measured FPS, stalls and errors at 1 Hz until the stream dies or you stop it.
3. **Is the HEVC stream usable as a game proxy?** HEVC runs write the glasses stream to `video.mov` (passthrough, no re-encode).

Each run saves `summary.json`, `samples.csv`, `events.csv` and (optionally) `video.mov` to `Documents/runs/<timestamp>_<label>/`. You can open them in the Files app (On My iPhone → Sideline Probe) or share them from **Past runs**.

## Prerequisites

- **Xcode 26.4+** (DAT requires Swift 6.3 / iOS 17.2+). Install it from the App Store, then run:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  ```
- **XcodeGen** to generate the project file:
  ```bash
  brew install xcodegen
  ```
- An iPhone with the **Meta AI** app, your glasses paired, and **Developer Mode** turned on (Meta AI → Settings → your glasses → Developer Mode).
- A free or paid Apple developer account for on-device signing.

## Build & run

```bash
cd apps/ios/SidelineProbe
xcodegen generate
open SidelineProbe.xcodeproj
```

In Xcode: select the **SidelineProbe** target → Signing & Capabilities → pick your Team. (You can also set `DEVELOPMENT_TEAM` in `project.yml`.) Then run it on your iPhone.

In the app:

1. **Register with Meta AI.** This opens Meta AI; approve, and you're bounced back.
2. **Camera permission → Request.** Choose *Allow always* to avoid re-prompting between runs.
3. Pick the glasses, pick a run config, then **Start endurance run**.

`META_APP_ID` stays `0` for Developer Mode, so the SDK skips attestation. To share with testers through a Meta release channel, create a project in the [Wearables Developer Center](https://wearables.developer.meta.com/) and set `META_APP_ID` and `CLIENT_TOKEN` in `project.yml`.

## Without glasses

**Mock glasses** pairs a simulated device through MockDeviceKit. On a phone it can stream the back camera; in the simulator, choose a video file. Mock runs exercise the app flow only. They say nothing about battery or thermal behavior.

## Code map

| File | Role |
|---|---|
| `SidelineProbeApp.swift` | `Wearables.configure()`, Meta AI URL callback |
| `WearablesModel.swift` | Registration, camera permission, device list, mock pairing |
| `ProbeRunner.swift` | Device session → camera stream → 1 Hz sampler → run files |
| `FrameTap.swift` | Thread-safe FPS / stall meter fed from the frame callback |
| `HEVCFileWriter.swift` | Passthrough `hvc1` → `video.mov` |
| `ContentView` / `LiveRunView` / `RunsView` | UI |

Run models, CSV/JSON output and summary math live in [`packages/SidelineCore`](../../../packages/SidelineCore), which is tested on macOS with `scripts/test-core.sh`.

## Status

The `SidelineCore` package builds and its tests pass on macOS. **The iOS app has not been compiled yet.** It was written against the DAT 1.0.1 public Swift interfaces, but this Mac has no Xcode, so expect a few compile fixes on first build.
