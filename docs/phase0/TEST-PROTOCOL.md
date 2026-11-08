# Phase 0 hardware test protocol

**Devices:** Ray-Ban Meta Gen 3 and Meta Ray-Ban Display, plus an iPhone running **Sideline Probe** ([apps/ios/SidelineProbe](../../apps/ios/SidelineProbe/README.md)).
**Goal:** answer the capture questions in [PLAN.md](../PLAN.md) §14 with real numbers before building product.

Each run produces a folder: `summary.json`, `samples.csv`, `events.csv` and, for HEVC runs, `video.mov`. Copy every folder into `data/phase0/runs/`. That directory is git-ignored. Afterwards, record the key numbers in the results table at the bottom of this file.

## Before every run

- [ ] Glasses charged to 100% and out of the case for 5 minutes, so they start at ambient temperature
- [ ] Phone charged to at least 90%; Low Power Mode off; Wi-Fi state noted
- [ ] Glasses firmware and Meta AI app versions written in the run label or a note
- [ ] Outdoors where possible, since sun and heat are the real game conditions; note the temperature

## T1. Confirm DAT on Gen 3 and Display (about 10 min)

Meta has said Gen 3 works with DAT 1.0 (Gen 3 support was confirmed 2026-11-07: Meta replies in [dat-ios#323](https://github.com/meta/meta-wearables-dat-ios/discussions/323), [dat-android#185](https://github.com/meta/meta-wearables-dat-android/discussions/185) and [#221](https://github.com/meta/meta-wearables-dat-android/discussions/221), plus a hands-on report; the official FAQ device list lags). This test verifies it on our hardware.

1. Pair Gen 3 in Meta AI and turn on Developer Mode.
   - **Display (and likely Gen 3):** also open Meta AI → App Info → Developer Mode → your glasses, and tap **Install/Update** for the on-glasses DAT app. Without it, sessions end immediately with "Device session stopped before it started".
2. In the probe app, check that it appears under Glasses. Write down **Type**, **Compatibility** and **Link**.
3. Start a 2-minute run at `medium / 15 fps / HEVC`.
4. **Pass** if the stream reaches `streaming`, shows FPS above 10, and `video.mov` plays back.
5. Repeat on Display.

Expect Gen 3's **Type** to show *Ray-Ban Meta* or *Ray-Ban Meta Optics*; either is fine. If it fails anyway, record the error from the event log and post it in the DAT discussions. The fallback is that Display handles the live stream and Gen 3 records native clips.

## T2. Stream endurance matrix (≈ 1–2 h per run)

Run until the stream stops by itself. The summary records **stop reason**, **longest continuous streaming**, **drain/hour** and **first thermal warning**.

| Run | Glasses | Config | Wear pattern |
|---|---|---|---|
| E1 | Gen 3 | medium / 15 / HEVC | worn, looking at a field or street (motion similar to a game) |
| E2 | Gen 3 | low / 7 / HEVC | same |
| E3 | Gen 3 | high / 30 / HEVC | same (expected worst case) |
| E4 | Display | medium / 15 / HEVC | same |
| E5 | Gen 3 | best of E1–E3 | **game simulation**: 2 × 25 min halves; at halftime tap "Glasses into case", charge 15 min, tap "Glasses out of case" (see T3 for whether the run survives the case) |

## T3. Case recharge and hand-off

1. During a run, put the glasses in the case. Note whether the session goes to `paused` or `stopped`, using the event log.
2. Take them out after 15 minutes and record the battery gained.
3. Is a new run needed? (Hinge close → `stopped` is expected, per the DAT docs.)
4. **Two-pair hand-off:** stop the Gen 3 run, start Display. Record the gap in seconds, which is how much game time would be lost.

## T4. Native clips and Autocapture

1. While a probe run streams, take a native video clip with the capture button. Does the stream pause? Does the clip still save?
2. On Gen 3, try "Hey Meta, start autocapture" for 10 minutes, if it's available. Note availability, how many clips it made, and their length.
3. Import the clips to the phone through the Meta AI app. Record their resolution and frame rate, and whether the timestamps match wall-clock time to within 1 second.

## T6. Phone in pocket (screen locked)

On the sideline the phone lives in a pocket, so the stream has to survive the app going to the background and the screen locking. DAT's changelog says **HEVC** streaming continues in the background and **raw** pauses, so run this test with HEVC.

1. Start a `medium / 15 / HEVC` run and confirm FPS is above 10.
2. Lock the phone and put it in your pocket for 10 minutes while wearing the glasses.
3. Unlock it. The event log should show "app backgrounded" / "screen locked" entries. Check `samples.csv` to see whether `frames_total` kept rising and the FPS held while locked.
4. Repeat with the **Scorebook** mic: start listening, lock the phone, speak a play, then unlock it and check that the play was captured.

**Pass:** no stall longer than 5 s while locked, and `video.mov` covers the whole locked period.

If it fails, the fallbacks in order are:
- keep the screen on and dimmed in a chest or armband mount;
- Picture-in-Picture or VoIP-style background modes. These were suggested for iPhone-camera apps and are only worth trying if the DAT stream itself gets suspended.

## T7. Call plays through the glasses (Display, phone in pocket)

Hands-free scoring: the wearer picks **Call play** on the lens with the Neural Band, says the play, and stops talking. Recognition runs on the glasses (`MWDATSpeech`, experimental in DAT 1.0), so no phone audio is involved.

1. Probe tab → **Request mic permission** (approve in Meta AI). Check "Glasses mic permission: granted".
2. Scorebook → **Show on glasses**. Under the lens status the app should say "glasses mic: ready". If it says "unavailable", note the reason; Call play will fall back to the phone mic.
3. Call 10 plays from the lens with the phone in hand, then 10 with the phone in a pocket and the screen locked. For each, note whether it was heard, whether the parse was right, and how long until the play appeared on the lens.
4. Watch for the known DAT speech bugs: the recognizer never starting ([dat-ios#336](https://github.com/meta/meta-wearables-dat-ios/issues/336)) or stopping after a few minutes ([#360](https://github.com/meta/meta-wearables-dat-ios/issues/360)).
5. Pass: ≥ 9/10 heard and parsed correctly in each condition; works for 15+ minutes.

## T8. Game mode dry run (practice or scrimmage, ~20 min)

Scorebook → **Connect glasses** → **Record game video**, then call every play from the lens (Call play) with the phone in a pocket.

1. After ~20 min tap **Stop video**. Each called play should show **▶ Clip m:ss–m:ss**; open five and check the play is inside the clip (each clip runs 15 s before the call to 2 s after).
2. Note how many seconds after the whistle you usually start the call, so we can tune the clip window.
3. Note battery start/end and any "glasses mic" or recording errors. Files are in Files → On My iPhone → Sideline Probe → games → (game id).
4. Pass: ≥ 90% of clips contain their play; recording survives the pocket for the full run.

## T5. First real game

Record one real youth football game in **game mode** (lens + glasses mic + video in one session).

- Display (or Gen 3) in game mode; recharge in the case at halftime and start a new video file after.
- A tripod phone recording the whole game as the backbone, if possible.
- Every play called from the lens, so every play is stamped into the video.

This becomes eval game #1: the voice calls are the play labels, the clips are the play segments. Correct any wrong calls afterwards; that corrected log is the ground truth for the CV work.

## Results

| Run | Date | Glasses (type reported) | Config | Longest continuous | Stop reason | Drain/h | 1st thermal warning | Notes |
|---|---|---|---|---|---|---|---|---|
| T1-gen3 | | | medium/15/HEVC | | | | | |
| T1-display | 2026-11-07 | Meta Ray-Ban Display | medium/15/HEVC | ~2 min (1752 frames, 15.2 fps, 7.3 MB ≈ 0.5 Mbit/s) | user stop | 35% → 31% in ~2 min (≈2%/min ≈ 120%/h; started at low charge, rough) | none | Session first failed ("stopped before it started") until the on-glasses DAT app was installed: Meta AI → App Info → Developer Mode → glasses → Install. No stalls reported. |
| E1 | | | | | | | | |
| E2 | | | | | | | | |
| E3 | | | | | | | | |
| E4 | | | | | | | | |
| E5 | | | | | | | | |

## Phase 0 exit questions

- Can either device stream at least one 25-minute half with a case recharge between halves?
- Which config gives the best FPS-to-battery trade-off?
- Does Gen 3 work with DAT, and does Autocapture work on it?
- What is the clip-import path, and how accurate are its timestamps?
