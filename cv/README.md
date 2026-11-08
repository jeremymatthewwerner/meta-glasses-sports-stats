# sideline-cv — offline computer vision on game recordings

CV v0 for the plan's Phase 0a/1 bake-off: for every **called play that has video** (game mode on the glasses), sample the play's clip, **detect people** (RF-DETR, Apache-2.0), **track** them (ByteTrack from roboflow/trackers, Apache-2.0), and save, per play:

```
out/<game id>/<NNN>-<call>/annotated.mp4     boxes + track ids at the sample rate
out/<game id>/<NNN>-<call>/crops/track-N.jpg  best crop per track (input to jersey reading)
out/<game id>/<NNN>-<call>/tracks.json        per track: first/last seen, frames, box height, best crop
out/<game id>/report.md / report.json         one row per play, with the jerseys the caller named
```

The voice call is the label ("22 run for 7, tackle by 54" → home #22 ball carrier, away #54 tackler). The next stage reads jersey numbers from the crops and matches them to those calls; that is where identity per play comes from.

## Setup

```bash
cd cv
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -e ".[dev]"
.venv/bin/python -m pytest -q          # no model weights needed
```

The first real run downloads RF-DETR weights (~390 MB for `medium`) to `~/.roboflow/models/`. On Apple silicon it runs on the GPU (MPS); `medium` processes ~20 sampled frames/s on an M5 Max.

## Run

Copy the app's `games` folder off the phone (Files → On My iPhone → Sideline Probe → games, or Finder → iPhone → Files), then:

```bash
.venv/bin/sideline-cv game --games ~/Downloads/games            # newest game
.venv/bin/sideline-cv game --games ~/Downloads/games --game 1657  # by id prefix
.venv/bin/sideline-cv video some.mp4 --start 30 --end 60         # any video
.venv/bin/sideline-cv game --games "$(.venv/bin/sideline-cv sim-games)"   # the iOS Simulator's games
```

Options: `--fps` (default 5 sampled frames per second), `--model nano|small|medium|base|large`, `--threshold` (default 0.25).

## Status (2026-11-07)

- Verified end to end on a game recorded in the simulator with MockDeviceKit (HEVC 504×896 from the "glasses"; synthetic field video, so 0 people, as expected) and on Roboflow's `people-walking` sample: ~28 people/frame detected at threshold 0.25 (17 at 0.4), stable track ids across the 10 s clip.
- Not yet run on real glasses footage. Expect to retune `--fps`, the threshold and the tracker for fast, occluded football action.
- Next: jersey-number reading on the crops (PARSeq, Apache-2.0), then matching read numbers to the called jerseys, and play-boundary detection checked against the voice calls.
