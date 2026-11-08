"""Where the play is inside a called play's clip.

A clip runs from 15 s before the call to 2 s after it, because plays are
called after they happen. Most of that is pre-snap standing. Two signals
rise when the play is live:

- **Player motion:** how fast tracked people move across the frame,
  in body heights per second (so near and far players count alike).
- **Camera motion:** median optical-flow magnitude, i.e. the wearer's head
  turning to follow the ball.

The activity curve is their normalized sum; the play is the longest
stretch above an adaptive threshold (short dips merged). The clip is then
trimmed to that stretch plus a little padding.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

import cv2
import numpy as np

FLOW_WIDTH = 160      # px; optical flow on a small copy is plenty for "is the head moving"


class MotionMeter:
    """Fed one sampled frame at a time; produces per-frame motion values."""

    def __init__(self) -> None:
        self.prev_gray: np.ndarray | None = None
        self.prev_t: float | None = None
        self.prev_centers: dict[int, tuple[float, float, float]] = {}
        self.samples: list[dict] = []

    def update(self, t: float, frame_bgr: np.ndarray, boxes: np.ndarray, track_ids: np.ndarray) -> None:
        h, w = frame_bgr.shape[:2]
        small = cv2.resize(frame_bgr, (FLOW_WIDTH, max(8, int(h * FLOW_WIDTH / w))), interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        centers = {}
        for box, tid in zip(boxes, track_ids):
            if tid < 0:
                continue
            x0, y0, x1, y1 = (float(v) for v in box)
            centers[int(tid)] = ((x0 + x1) / 2, (y0 + y1) / 2, max(1.0, y1 - y0))
        camera = players = 0.0
        moving = 0
        if self.prev_gray is not None and self.prev_t is not None and t > self.prev_t:
            dt = t - self.prev_t
            flow = cv2.calcOpticalFlowFarneback(self.prev_gray, gray, None, 0.5, 2, 9, 2, 5, 1.1, 0)
            # Pixels of the small frame per second, as a fraction of its width.
            camera = float(np.median(np.linalg.norm(flow, axis=2))) / FLOW_WIDTH / dt
            speeds = []
            for tid, (cx, cy, ch) in centers.items():
                if tid in self.prev_centers:
                    px, py, ph = self.prev_centers[tid]
                    speeds.append(np.hypot(cx - px, cy - py) / ((ch + ph) / 2) / dt)
            if speeds:
                players = float(np.mean(speeds))
                moving = int(sum(s > 0.5 for s in speeds))
        self.samples.append({"t": round(t, 3), "players": round(players, 4), "camera": round(camera, 4),
                             "people": len(centers), "moving": moving})
        self.prev_gray, self.prev_t, self.prev_centers = gray, t, centers


@dataclass
class ActionSegment:
    start: float
    end: float
    peak_t: float
    confidence: float      # how far the segment stands above the rest of the clip, 0–1
    threshold: float

    @property
    def duration(self) -> float:
        return self.end - self.start

    def to_json(self) -> dict:
        return {k: round(v, 3) for k, v in asdict(self).items()} | {"duration": round(self.duration, 3)}


def activity_curve(samples: list[dict], camera_weight: float = 1.0) -> np.ndarray:
    """Player and camera motion, each scaled by its own spread, summed and smoothed."""
    if not samples:
        return np.zeros(0)
    p = np.array([s["players"] for s in samples], float)
    c = np.array([s["camera"] for s in samples], float)

    def scale(x: np.ndarray) -> np.ndarray:
        hi = np.percentile(x, 90)
        return x / hi if hi > 1e-6 else np.zeros_like(x)

    a = scale(p) + camera_weight * scale(c)
    if len(a) >= 3:
        a = np.convolve(np.pad(a, 1, mode="edge"), np.ones(3) / 3, mode="valid")
    return a


def find_action(samples: list[dict], min_duration: float = 1.0, merge_gap: float = 1.0) -> ActionSegment | None:
    """The longest high-activity stretch in a clip, or None when the clip is
    uniformly quiet or uniformly busy (no contrast to find a play in)."""
    if len(samples) < 4:
        return None
    t = np.array([s["t"] for s in samples], float)
    a = activity_curve(samples)
    low, high = np.percentile(a, 20), np.percentile(a, 90)
    if high - low < 0.25:                 # nothing stands out
        return None
    thr = low + 0.4 * (high - low)
    above = a > thr
    # Runs of consecutive samples above the threshold.
    runs: list[list[int]] = []
    for i, on in enumerate(above):
        if on:
            if runs and i - runs[-1][1] <= 1:
                runs[-1][1] = i
            else:
                runs.append([i, i])
    if not runs:
        return None
    merged = [runs[0]]
    for r in runs[1:]:
        if t[r[0]] - t[merged[-1][1]] <= merge_gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    best = max(merged, key=lambda r: (a[r[0]:r[1] + 1].sum(), t[r[1]] - t[r[0]]))
    step = float(np.median(np.diff(t))) if len(t) > 1 else 0.2
    start, end = float(t[best[0]]), float(t[best[1]]) + step
    if end - start < min_duration:
        return None
    inside = a[best[0]:best[1] + 1].mean()
    rest = np.delete(a, np.arange(best[0], best[1] + 1))
    outside = rest.mean() if rest.size else low
    confidence = float(np.clip((inside - outside) / (inside + 1e-6), 0, 1))
    peak = float(t[best[0] + int(np.argmax(a[best[0]:best[1] + 1]))])
    return ActionSegment(start, end, peak, confidence, float(thr))


def refined_window(segment: ActionSegment | None, clip_start: float, clip_end: float,
                   before: float = 1.5, after: float = 2.0, min_confidence: float = 0.3) -> tuple[float, float] | None:
    """The clip trimmed to the action (with padding), or None to keep the full clip."""
    if segment is None or segment.confidence < min_confidence:
        return None
    s = max(clip_start, segment.start - before)
    e = min(clip_end, segment.end + after)
    return (round(s, 3), round(e, 3)) if e - s >= 1.0 else None
