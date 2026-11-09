# sideline-cv — offline computer vision on game recordings

CV v0 for the plan's Phase 0a/1 bake-off: for every **called play that has video** (game mode on the glasses), sample the play's clip, **detect people** (RF-DETR, Apache-2.0), **track** them (ByteTrack from roboflow/trackers, Apache-2.0), and save, per play:

```
out/<game id>/<NNN>-<call>/annotated.mp4     boxes + track ids at the sample rate
out/<game id>/<NNN>-<call>/crops/track-N.jpg  best crop per track (input to jersey reading)
out/<game id>/<NNN>-<call>/tracks.json        per track: first/last seen, frames, box height, best crop
out/<game id>/report.md / report.json         one row per play, with the jerseys the caller named
```

The voice call is the label ("22 run for 7, tackle by 54" → home #22 ball carrier, away #54 tackler).

**Jersey numbers.** For each track the pipeline keeps its 6 best crops from different moments, reads four torso windows per crop with **PARSeq** (Apache-2.0, via torch.hub; ~91 MB on first use), takes the most confident digit reading per crop, and votes across crops (a number needs ≥ 2 agreeing frames and ≥ 0.5 summed confidence). Each play then gets a match against the call: `matched` (called #22 → track 3), `missing` (called but never read) and `unexpected` (read on screen, not called). The report's last column shows it. `--no-jerseys` skips this stage.

**Where the play is.** A clip runs 15 s before the call to 2 s after, mostly pre-snap standing. Per sampled frame the pipeline measures player motion (tracked people's speed in body heights per second) and camera motion (median optical flow: the wearer's head following the ball), sums them on a common scale, and takes the longest stretch above an adaptive threshold (dips under 1 s merged) as the play. With enough contrast (confidence ≥ 0.3) the clip is trimmed to the play plus 1.5 s before and 2 s after. The report shows it in the "Action" column; `activity.json` per play has the curve.

**Who's a player.** Each track gets a role, `player`, `official` or `sideline` (coach, spectator), from zero-shot CLIP (OpenAI ViT-B/32, MIT) comparing its crops with three short descriptions. Officials get no jersey number (stripes read as "1", "11", "0") and, like sideline people, stay out of the team colors. The report's Tracks column counts them. `--no-roles` skips this.

**Face ID (opt-in, enrolled-only).** Only people enrolled with consent can be recognized, and only within their own team's or group's store:

```bash
# cv/samples/faces/sam/ holds consent.json + 5–10 photos of Sam's face
.venv/bin/sideline-cv faces enroll --store ~/sideline/eagles.faces.json --scope "Eagles 11U" samples/faces/sam
.venv/bin/sideline-cv faces list   --store ~/sideline/eagles.faces.json
.venv/bin/sideline-cv faces forget --store ~/sideline/eagles.faces.json sam-rivera   # consent withdrawn / season over
.venv/bin/sideline-cv game --games ~/Downloads/games --faces ~/sideline/eagles.faces.json
```

`consent.json`: `{"name": "Sam Rivera", "jersey": 22, "team": "Eagles", "consent_by": "Alex Rivera", "relationship": "guardian", "minor": true, "date": "2026-11-08", "scope": "Eagles 11U"}`. Enrollment refuses a missing field, a self-consenting minor, or a scope that isn't the store's. The store is a private file (mode 600) of face vectors from the enrollment photos. Game processing writes only who matched and how sure (`face` in `tracks.json`), never face vectors, and faces that match nobody stay anonymous. A face match stands in for an unreadable jersey number in the play match (`via: face`) or confirms a read one (`face ✓`). Face ID runs on every source by default and prints a note for glasses footage, since Meta's Wearables policy requires Meta's approval for face identification from glasses. `--no-faces-on glasses` (or `phone`, `other`) switches it off per source; `video` takes `--source`. Models: InsightFace buffalo_l (SCRFD detector + ArcFace R50) through onnxruntime, ~280 MB downloaded on first use to `~/.insightface/models/buffalo_l`, **non-commercial research license**.

**Team colors.** Each track gets a jersey color (largest color cluster of the central torso, median over its crops, in CIE Lab). All tracks of a game are clustered into two colors, A (lighter) and B, and the clusters are named **home/away from the number-matched calls**: if the track read as #22 is in A and the caller said "home #22", A is home (one side's evidence is enough to name both). Every track is then labeled with its team (or *unsure* when far from both colors or between them), and matching runs again team-aware: a called "home #22" prefers a home-colored #22, a number worn by both teams is split correctly, and a number read on the other team's colors is flagged ⚠. The report starts with the two team colors and their evidence.

## Setup

```bash
cd cv
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -e ".[dev]"
.venv/bin/python -m pytest -q          # no model weights needed
```

The first real run downloads RF-DETR weights (~390 MB for `medium`) to `~/.roboflow/models/`, PARSeq (~91 MB) and CLIP ViT-B/32 (~600 MB, Hugging Face cache); `--faces` adds InsightFace (~280 MB). On Apple silicon it runs on the GPU (MPS); `medium` processes ~20 sampled frames/s on an M5 Max.

## Run

Copy the app's `games` folder off the phone (Files → On My iPhone → Sideline Probe → games, or Finder → iPhone → Files), then:

```bash
.venv/bin/sideline-cv game --games ~/Downloads/games            # newest game
.venv/bin/sideline-cv game --games ~/Downloads/games --game 1657  # by id prefix
.venv/bin/sideline-cv video some.mp4 --start 30 --end 60         # any video
.venv/bin/sideline-cv game --games "$(.venv/bin/sideline-cv sim-games)"   # the iOS Simulator's games
```

**Back to the app.** Copy `out/<game id>/report.json` into the phone's `games/<game id>/` folder as `cv-report.json` (Files or Finder), and the app imports it the next time it opens or comes to the foreground; or use Scorebook ⋯ → **Import CV results…**. Each play then shows what CV saw ("CV: #22 ✓ · #54 not seen", ⚠ for a number on the other team's colors), clips are trimmed to the detected action (the original window is kept, and re-importing is safe), and the scoreboard shows the team colors.

**Training data.** `sideline-cv export-crops out/<game id> [more games…] --out dataset` writes `dataset/images/*.jpg` + `labels.csv`: every kept crop of each track whose read number matched a called player on the same team's colors, labeled with that number and team. That is the fine-tuning set for the number reader, labeled by the voice calls instead of by hand.

Options: `--fps` (default 5 sampled frames per second), `--model nano|small|medium|base|large`, `--threshold` (default 0.25), `--no-jerseys`, `--no-roles`, `--faces store.json`, `--no-faces-on SOURCE`.

Tests: `.venv/bin/python -m pytest -q` (no weights). `SIDELINE_CV_MODELS=1` also runs PARSeq on synthetic jerseys.

## Status (2026-11-07)

- Verified end to end on a game recorded in the simulator with MockDeviceKit (HEVC 504×896 from the "glasses"; synthetic field video, so 0 people, as expected) and on Roboflow's `people-walking` sample: ~28 people/frame detected at threshold 0.25 (17 at 0.4), stable track ids across the 10 s clip.
- Not yet run on real glasses footage. Expect to retune `--fps`, the threshold and the tracker for fast, occluded football action.
- Jersey reading (same day) on Roboflow's `basketball-1` sample (close-up, 2 players): the white #2 is read correctly (2 of 6 frames, 0.53); a black tank with no number gets a false "7" at 0.49, just under the match bar; an occluded track abstains. Off-the-shelf PARSeq is a **baseline**: small chest numbers, doubled digits ("22" for "2") and shirt patterns are the failure modes. The fix the plan calls for is fine-tuning on our own crops, which the voice-labeled plays provide for free, with a VLM fallback.
- Team colors (same day): on `basketball-1` the white #2 (#92939b under indoor light) lands in team A and the black-tank player's tracks in team B; on a synthetic two-team game the clusters are named home/away from the call and #22/#54 match with the right teams. Officials and fans aren't modeled yet (they join the nearer team or are marked unsure).
- Play boundaries (same day): a synthetic still–run–still clip is found at 2–4 s; `basketball-1` (a shooting drill) gives 1.2–6.0 s at confidence 0.79; `people-walking` (uniform motion) gives confidence 0.19 and is correctly left untrimmed. Real football will need tuning: pre-snap motion (shifts, the wearer looking around) and the whistle-to-call delay.
- **First real football (2026-11-08).** Eight 90 s excerpts from four CC BY youth games on YouTube (720p; handheld on-field, bench-level sideline, raised sideline, stadium press box; credits in `samples/football/CREDITS.md`, not committed). Detection is solid: every player in frame is boxed, including kids cut off at the frame edge; officials and coaches are detected too. Tracking fragments heavily (110–230 track ids per 90 s for ~25–40 people) and sometimes swaps two players in a pile-up. Off-the-shelf number reading was poor: on 41 hand-checked tracks only 15 numbers were right, and 26 were wrong numbers, mostly a lone "1" read from shirt seams, coaches' jackets and refs (even at 0.8–0.9 confidence) and half of a two-digit number. Two credibility floors (a reading needs ≥ 0.5 confidence; a lone "1" needs ≥ 0.95) kept all 15 right and cut the wrong ones to 2. On held-out clips with the floors: **46 of 69 sampled numbered tracks correct (67%)**; per clip 58% (handheld on-field), 79% (raised sideline), 62% (stadium). Remaining errors: officials' stripes read as digits (5), track swaps (4), blur, 3↔8/30↔80 and 40→4. The activity detector finds one action span per clip, as designed for a play's window, so it is not a play splitter for long video.
- **Officials (same day).** On 184 hand-labeled tracks (every referee found plus the players most likely to be confused with one), CLIP flags 82 of 93 official tracks (88%) and 9 of 91 players (mostly blurry or partly covered). Across the eight clips it marks 116 of 1,351 tracks as officials. A hand-built stripe detector reached ~35% of refs and was dropped; a probe trained on these labels didn't carry over between games. In the held-out number sample it removed 4 of the 5 referee misreads and no correct number: **46 of 65 numbered tracks correct (71%)**. What's left is track swaps in pile-ups, blur and look-alike digits. A referee showing the number on his back can still pass as a player.
- **Face ID (same day).** Built and tested on synthetic data only (unit tests with fake face vectors; the detector checked on real frames, detection only). Nobody in the YouTube clips was enrolled, and no face data was computed from them. How often play footage even shows a usable face (≥ 24 px, detector confidence ≥ 0.6), per player track: Sweet Home (handheld on field) 12–25% at least one, 1–7% three or more; Pop Warner 9–20% / 0–6% (faces ~28–31 px); Calumet 3–22% / 0–3%. Helmets and distance make faces a bench/huddle/pickup signal, as the plan expected. The match threshold (cosine ≥ 0.40, margin 0.08) is provisional until enrolled photos and a recorded game exist.
- Next: test face ID with enrolled family photos, tracker tuning for pile-ups, a labeled crop export for fine-tuning the number reader, sending refined clip windows back to the app, and an officials/other cluster.
