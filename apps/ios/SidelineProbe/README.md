# Sideline Probe (Phase 0)

The app has two tabs:
- **Scorebook (Phase 0a):** tap the mic and call plays ("22 run for 7, tackle by 54"), or type them. It keeps a live score, down and distance, the play log with confirm (swipe right) / reject (swipe left), and a box score. Each utterance is saved with its parse to `Documents/games/<id>-utterances.json` so parse accuracy can be measured. Tap **?** for the phrases it understands. The mic uses Bluetooth headset input when one is connected (AirPods, or the glasses as a headset).
- **Glasses probe (Phase 0b):** the hardware endurance tests described below.

A minimal iOS app for the Phase 0 hardware tests in [docs/PLAN.md](../../../docs/PLAN.md) §14. It answers three questions on real glasses:

1. **Does DAT 1.0.1 work on our Ray-Ban Meta Gen 3?** Meta says yes (see the DAT discussions). Gen 3 may report its `DeviceType` as `rayBanMetaOptics`. The device list shows the reported type and `Compatibility`; then start a stream.
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

## Scorebook on the Display lens

On the Scorebook tab, **Show on glasses** opens a DAT session on the linked Meta Ray-Ban Display and draws the score, the situation, the last play and **Confirm / Undo** buttons on the lens. Every change in the scorebook redraws the lens. Pressing a lens button (Neural Band pinch, or the touchpad) confirms the play, undoes the last one, or (right after an undo) redoes it. Redo restores the play with its earlier status and stays available until the next new play; the phone toolbar and the voice command "redo" do the same.

- **Call play on the lens** listens through the glasses' own recognizer (MWDATSpeech, experimental), so plays can be called with the phone in a pocket. It needs the glasses mic permission (probe tab → Request mic permission) and falls back to the phone mic otherwise. A call ends on a final transcript, 1.6 s of silence, 12 s, or Done / Cancel.
- The phone's own mic button still works while the lens is up, but uses the **phone mic**. Using the glasses as a Bluetooth headset mic ends Display sessions ([dat-ios#342](https://github.com/meta/meta-wearables-dat-ios/issues/342)).
- DAT allows one session per device, so the HUD and a probe run can't run at the same time yet.
- In the simulator, launch with `-mockGlasses metaRayBanDisplay` to pair a mock Display automatically. The phone then shows MockDeviceKit's lens preview. Tap a lens button once to focus it and again to press it. The "Mock: say a play" field feeds MockSpeechKit as if the wearer spoke. (`MockDisplayKit.sendClick(identifier:)` returns `true` but doesn't reach the buttons, so the app doesn't use it.)

## Game mode (video + play clips)

**Connect glasses**, then **Record game video**. The same DAT session runs the lens, the glasses mic and the camera (HEVC 504×896 @ 15 fps, the T1 config, written in passthrough to `Documents/games/<game id>/glasses-01.mov`, `-02`, …, with `recording.json` listing the files and their start/end times).

Every play called while recording gets a clip reference: from 15 s before the moment the call started (Call play pressed, or the phone mic tapped) to 2 s after, because plays are called after they happen. After **Stop video** each such play shows **▶ Clip m:ss–m:ss**, which plays just that stretch. Clips of the file being recorded aren't playable until it stops (the .mov isn't finalized yet).

In the simulator the mock camera plays the bundled field video at 30 fps, so recordings there show 30 fps; real glasses deliver the requested 15.

## Gallery, rosters and highlight reels

- **Gallery tab:** every player named in a play, grouped by team, with what they did ("3 runs · 1 return") and how many clips they have; or plays by event type (touchdowns, turnovers, big plays of 15+ yards or 20+ yard returns, sacks, kicks, penalties). Tap through to the plays and their clips.
- **Make highlight reel:** stitches the finished clips of any list (one player, all touchdowns, …) into one video without re-encoding, saved to `games/<id>/reels/`, then **Play** or **Share**.
- **Rosters (Scorebook ⋯ menu):** paste or import a CSV per team, one player per line: `22,Jane Smith,RB` (tabs, `#22 Jane Smith` and a header row also work). Names then appear in the gallery.

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
| `Scorebook/ScorebookModel.swift` · `ScorebookView.swift` | Voice/typed play entry, play log, box score |
| `Scorebook/GlassesHUD.swift` | Display session + lens layout (MWDATDisplay); layout data comes from `SidelineCore.FootballHUD` |

Run models, CSV/JSON output and summary math live in [`packages/SidelineCore`](../../../packages/SidelineCore), which is tested on macOS with `scripts/test-core.sh`.

## Status

- **2026-11-07:** builds cleanly with Xcode 27.2 (iOS 27.2 simulator). It was verified end to end in the simulator with MockDeviceKit:
  - pairing → session `started` → stream `streaming` at ~30 fps;
  - HEVC `video.mov` written and playable;
  - `summary.json`, `samples.csv` and `events.csv` saved.
- **Not yet run on a real phone with real glasses.** Registration, permissions and real battery/thermal behavior are untested.
- **Mock quirks:**
  - MockDeviceKit only accepts **HEVC** feed videos. `Resources/mock-feed.mp4` is generated by `scripts/make-mock-feed.swift`.
  - The mock plays the file at its native 30 fps whatever frame rate is requested.
  - The mock reports thermal as `unknown`.
