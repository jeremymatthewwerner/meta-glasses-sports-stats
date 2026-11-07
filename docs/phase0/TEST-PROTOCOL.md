# Phase 0 hardware test protocol

**Devices:** Ray-Ban Meta Gen 3 and Meta Ray-Ban Display, plus an iPhone running **Sideline Probe** ([apps/ios/SidelineProbe](../../apps/ios/SidelineProbe/README.md)).
**Goal:** answer the capture questions in [PLAN.md](../PLAN.md) §14 with real numbers before building product.

Each run produces a folder: `summary.json`, `samples.csv`, `events.csv` and, for HEVC runs, `video.mov`. Copy every folder into `data/phase0/runs/`. That directory is git-ignored. Afterwards, record the key numbers in the results table at the bottom of this file.

## Before every run

- [ ] Glasses charged to 100% and out of the case for 5 minutes, so they start at ambient temperature
- [ ] Phone charged to at least 90%; Low Power Mode off; Wi-Fi state noted
- [ ] Glasses firmware and Meta AI app versions written in the run label or a note
- [ ] Outdoors where possible, since sun and heat are the real game conditions; note the temperature

## T1. Does DAT work on Gen 3? (about 10 min, blocks the rest)

1. Pair Gen 3 in Meta AI and turn on Developer Mode.
2. In the probe app, check that it appears under Glasses. Write down **Type**, **Compatibility** and **Link**.
3. Start a 2-minute run at `medium / 15 fps / HEVC`.
4. **Pass** if the stream reaches `streaming`, shows FPS above 10, and `video.mov` plays back.
5. Repeat on Display.

If Gen 3 fails, record the error from the event log and follow the fallback in PLAN §16: Display handles the live stream and Gen 3 records native clips.

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

## T5. First real game

Record one real youth football game.

- Gen 3 streaming with the best config.
- A tripod phone recording the whole game as the backbone.
- Notes at each quarter break.
- Native clips of key plays.

This becomes eval game #1. Hand-label plays and events afterwards (labeling tool comes later; a spreadsheet with timestamps is fine).

## Results

| Run | Date | Glasses (type reported) | Config | Longest continuous | Stop reason | Drain/h | 1st thermal warning | Notes |
|---|---|---|---|---|---|---|---|---|
| T1-gen3 | | | medium/15/HEVC | | | | | |
| T1-display | | | medium/15/HEVC | | | | | |
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
