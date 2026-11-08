"""Frame sampling from game video (HEVC .mov from the glasses, or any file
OpenCV/FFmpeg can read)."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np


@dataclass(frozen=True)
class VideoInfo:
    fps: float
    frames: int
    width: int
    height: int

    @property
    def duration(self) -> float:
        return self.frames / self.fps if self.fps else 0.0


def probe(path: Path) -> VideoInfo:
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise OSError(f"can't open video {path}")
    try:
        return VideoInfo(
            fps=cap.get(cv2.CAP_PROP_FPS) or 0.0,
            frames=int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0),
            width=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 0),
            height=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0),
        )
    finally:
        cap.release()


def sample_times(start: float, end: float, every: float) -> list[float]:
    """Timestamps from start (inclusive) to end (exclusive), `every` seconds apart."""
    if every <= 0 or end <= start:
        return []
    n = int((end - start) / every + 1e-9)
    times = [round(start + i * every, 6) for i in range(n + 1)]
    return [t for t in times if t < end - 1e-9] or [start]


def frames(path: Path, start: float, end: float, sample_fps: float) -> Iterator[tuple[float, np.ndarray]]:
    """Yields (seconds into the file, BGR frame) at about `sample_fps`.

    Decodes sequentially from one seek (seeking per frame is slow and
    inexact on HEVC), keeping the frame nearest each sample time.
    """
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise OSError(f"can't open video {path}")
    try:
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        wanted = sample_times(start, end, 1.0 / sample_fps)
        if not wanted:
            return
        cap.set(cv2.CAP_PROP_POS_MSEC, max(0.0, start) * 1000.0)
        i = 0
        half = 0.5 / fps
        while i < len(wanted):
            ok, frame = cap.read()
            if not ok:
                break
            t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0 - 1.0 / fps   # time of the frame just read
            if t > end:
                break
            if t + half >= wanted[i]:
                yield t, frame
                while i < len(wanted) and wanted[i] <= t + half:
                    i += 1
    finally:
        cap.release()
