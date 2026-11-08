import json

import cv2
import numpy as np

from sideline_cv.activity import ActionSegment, find_action, refined_window
from sideline_cv.game import Clip
from sideline_cv.pipeline import process_clip

from test_cv import FakeDetector


def samples(series, step=0.2, camera=None):
    return [{"t": round(i * step, 3), "players": v, "camera": (camera[i] if camera else 0.0), "people": 1, "moving": 0}
            for i, v in enumerate(series)]


def test_find_action_picks_the_busy_stretch():
    quiet, busy = [0.02] * 15, [1.5] * 10
    seg = find_action(samples(quiet + busy + quiet))      # 3 s still, 2 s play, 3 s still
    assert seg is not None
    assert abs(seg.start - 3.0) <= 0.4 and abs(seg.end - 5.0) <= 0.4
    assert seg.confidence > 0.7


def test_find_action_merges_short_dips_and_ignores_flat_clips():
    s = [0.0] * 10 + [1.2] * 5 + [0.1] * 3 + [1.2] * 5 + [0.0] * 10    # 0.6 s dip inside the play
    seg = find_action(samples(s))
    assert seg is not None and seg.duration > 2.0
    assert find_action(samples([0.5] * 30)) is None                      # uniformly busy: no contrast
    assert find_action(samples([0.0] * 30)) is None                      # uniformly quiet


def test_camera_motion_alone_counts():
    cam = [0.0] * 10 + [0.8] * 8 + [0.0] * 10
    seg = find_action(samples([0.0] * 28, camera=cam))
    assert seg is not None and abs(seg.start - 2.0) <= 0.4


def test_refined_window_pads_and_clamps():
    seg = ActionSegment(start=10.0, end=14.0, peak_t=12.0, confidence=0.8, threshold=0.5)
    assert refined_window(seg, 2.0, 19.0) == (8.5, 16.0)
    assert refined_window(seg, 9.0, 15.0) == (9.0, 15.0)
    assert refined_window(ActionSegment(10, 14, 12, 0.1, 0.5), 2, 19) is None    # not confident
    assert refined_window(None, 2, 19) is None


def make_still_run_still(path, fps=30, w=320, h=240):
    """A player stands for 2 s, runs for 2 s, stands for 2 s (camera fixed)."""
    out = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for i in range(6 * fps):
        t = i / fps
        x = 30 if t < 2 else (30 + int((t - 2) * 100) if t < 4 else 230)
        f = np.zeros((h, w, 3), np.uint8)
        f[:] = (40, 140, 40)
        f[60:200, x:x + 40] = 255
        out.write(f)
    out.release()


def test_process_clip_finds_the_run(tmp_path):
    v = tmp_path / "still-run-still.mp4"
    make_still_run_still(v)
    extra = {}
    process_clip(v, Clip(v.name, 0, 6), tmp_path / "out", FakeDetector(), 5, extra=extra)
    seg = extra["segment"]
    assert seg is not None
    assert 1.6 <= seg["start"] <= 2.4 and 3.6 <= seg["end"] <= 4.6
    assert extra["refined_clip"]["start"] <= seg["start"] and extra["refined_clip"]["end"] >= seg["end"]
    saved = json.loads((tmp_path / "out" / "activity.json").read_text())
    assert len(saved["samples"]) == 30
