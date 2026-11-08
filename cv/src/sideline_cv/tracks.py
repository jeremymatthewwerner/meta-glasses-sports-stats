"""Per-track bookkeeping: who was on screen, for how long, and the best
crop of each person (the input to jersey reading and "who is this?")."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

import numpy as np


@dataclass
class TrackSummary:
    track_id: int
    first_t: float
    last_t: float
    frames: int = 0
    mean_confidence: float = 0.0
    max_box_height: float = 0.0          # pixels; tall = close = readable jersey
    best_t: float = 0.0
    best_box: tuple[float, float, float, float] = (0, 0, 0, 0)
    best_score: float = -1.0
    _conf_sum: float = field(default=0.0, repr=False)

    @property
    def duration(self) -> float:
        return self.last_t - self.first_t

    def to_json(self) -> dict:
        d = asdict(self)
        d.pop("_conf_sum")
        d["duration"] = round(self.duration, 3)
        d["best_box"] = [round(v, 1) for v in self.best_box]
        for k in ("first_t", "last_t", "best_t", "mean_confidence", "max_box_height", "best_score"):
            d[k] = round(d[k], 3)
        return d


def crop_score(box: tuple[float, float, float, float], confidence: float, frame_w: int, frame_h: int) -> float:
    """How good a crop is for reading a jersey: big, confident, not cut off
    by the frame edge."""
    x0, y0, x1, y1 = box
    h = max(0.0, y1 - y0)
    w = max(0.0, x1 - x0)
    margin = 4
    clipped = x0 <= margin or y0 <= margin or x1 >= frame_w - margin or y1 >= frame_h - margin
    return h * w * confidence * (0.5 if clipped else 1.0)


class TrackBook:
    """Accumulates tracker output frame by frame."""

    def __init__(self) -> None:
        self.tracks: dict[int, TrackSummary] = {}

    def update(self, t: float, boxes: np.ndarray, track_ids: np.ndarray, confidences: np.ndarray | None,
               frame_w: int, frame_h: int) -> list[int]:
        """Records one frame; returns the track ids whose best crop improved."""
        improved: list[int] = []
        for i, tid in enumerate(track_ids):
            tid = int(tid)
            if tid < 0:
                continue      # detection not (yet) part of a confirmed track
            box = tuple(float(v) for v in boxes[i])
            conf = float(confidences[i]) if confidences is not None else 1.0
            s = self.tracks.get(tid)
            if s is None:
                s = self.tracks[tid] = TrackSummary(track_id=tid, first_t=t, last_t=t)
            s.last_t = max(s.last_t, t)
            s.first_t = min(s.first_t, t)
            s.frames += 1
            s._conf_sum += conf
            s.mean_confidence = s._conf_sum / s.frames
            s.max_box_height = max(s.max_box_height, box[3] - box[1])
            score = crop_score(box, conf, frame_w, frame_h)
            if score > s.best_score:
                s.best_score, s.best_box, s.best_t = score, box, t
                improved.append(tid)
        return improved

    def summaries(self, min_frames: int = 2) -> list[TrackSummary]:
        """Tracks seen at least `min_frames` times, longest first."""
        keep = [s for s in self.tracks.values() if s.frames >= min_frames]
        return sorted(keep, key=lambda s: (-s.frames, s.track_id))
