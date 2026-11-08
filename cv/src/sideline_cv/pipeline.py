"""CV v0: for every called play with video, sample the clip, detect people
(RF-DETR, COCO), track them (ByteTrack), and save per-play outputs:

    out/<game>/<NN>-<slug>/annotated.mp4   boxes + track ids, at the sample rate
    out/<game>/<NN>-<slug>/crops/track-<id>.jpg   best crop per track (for jersey reading)
    out/<game>/<NN>-<slug>/tracks.json
    out/<game>/report.json, report.md      one row per play

The voice call says who was involved ("22 run for 7, tackle by 54"); the
next stage reads jersey numbers from the crops and matches them to those
calls.
"""

from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
import supervision as sv

from .game import Clip, Game, Play
from .tracks import TrackBook
from .video import frames, probe

PERSON_COCO_ID = 1


class PersonDetector:
    """RF-DETR (Apache-2.0) restricted to the COCO "person" class."""

    SIZES = ("nano", "small", "medium", "base", "large")

    def __init__(self, size: str = "medium", threshold: float = 0.25):
        import rfdetr  # heavy import; keep CLI help fast

        cls = {
            "nano": rfdetr.RFDETRNano, "small": rfdetr.RFDETRSmall, "medium": rfdetr.RFDETRMedium,
            "base": rfdetr.RFDETRBase, "large": rfdetr.RFDETRLarge,
        }[size]
        self.model = cls()
        self.threshold = threshold
        self.size = size

    def __call__(self, frame_bgr: np.ndarray) -> sv.Detections:
        dets = self.model.predict(frame_bgr[:, :, ::-1].copy(), threshold=self.threshold)
        if isinstance(dets, list):
            dets = dets[0]
        if len(dets) == 0 or dets.class_id is None:
            return dets
        return dets[dets.class_id == PERSON_COCO_ID]


@dataclass
class PlayResult:
    play: Play
    folder: Path
    sampled_frames: int
    mean_people: float
    tracks: list[dict]
    seconds: float

    def to_json(self) -> dict:
        p = self.play
        return {
            "play_id": p.id, "index": p.index, "transcript": p.transcript, "kind": p.kind,
            "status": p.status, "clip": {"asset": p.clip.asset, "start": round(p.clip.start, 3),
                                         "end": round(p.clip.end, 3)} if p.clip else None,
            "called_players": [{"team": c.team, "jersey": c.jersey, "role": c.role} for c in p.players],
            "sampled_frames": self.sampled_frames, "mean_people_per_frame": round(self.mean_people, 2),
            "tracks": self.tracks, "folder": self.folder.name, "processing_seconds": round(self.seconds, 2),
        }


def slug(text: str, limit: int = 40) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return (s[:limit].rstrip("-")) or "play"


def process_clip(video: Path, clip: Clip, out: Path, detector, sample_fps: float = 5.0,
                 min_track_frames: int = 3) -> tuple[int, float, list[dict]]:
    """Detect + track people in one clip. Returns (frames, mean people/frame, tracks)."""
    from trackers import ByteTrackTracker

    info = probe(video)
    out.mkdir(parents=True, exist_ok=True)
    crops = out / "crops"
    crops.mkdir(exist_ok=True)
    tracker = ByteTrackTracker(frame_rate=sample_fps, lost_track_buffer=int(sample_fps * 2),
                               track_activation_threshold=0.35, minimum_consecutive_frames=2)
    book = TrackBook()
    box_annotator = sv.BoxAnnotator(thickness=2)
    label_annotator = sv.LabelAnnotator(text_scale=0.5, text_padding=3)
    writer = cv2.VideoWriter(str(out / "annotated.mp4"), cv2.VideoWriter_fourcc(*"mp4v"),
                             sample_fps, (info.width, info.height))
    n = 0
    people = 0
    try:
        for t, frame in frames(video, clip.start, clip.end, sample_fps):
            n += 1
            dets = detector(frame)
            people += len(dets)
            tracked = tracker.update(dets)
            ids = tracked.tracker_id if tracked.tracker_id is not None else np.full(len(tracked), -1)
            improved = book.update(t, tracked.xyxy, ids, tracked.confidence, info.width, info.height)
            for tid in improved:
                x0, y0, x1, y1 = (int(round(v)) for v in book.tracks[tid].best_box)
                crop = frame[max(0, y0):max(0, y1), max(0, x0):max(0, x1)]
                if crop.size:
                    cv2.imwrite(str(crops / f"track-{tid}.jpg"), crop)
            labels = [f"#{int(i)}" if i >= 0 else "" for i in ids]
            annotated = box_annotator.annotate(frame.copy(), tracked)
            annotated = label_annotator.annotate(annotated, tracked, labels=labels)
            cv2.putText(annotated, f"{t:6.2f}s", (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            writer.write(annotated)
    finally:
        writer.release()
    summaries = book.summaries(min_frames=min_track_frames)
    keep = {s.track_id for s in summaries}
    for f in crops.glob("track-*.jpg"):          # drop crops of tracks too short to matter
        if int(f.stem.split("-")[1]) not in keep:
            f.unlink()
    tracks = [s.to_json() | {"crop": f"crops/track-{s.track_id}.jpg"} for s in summaries]
    (out / "tracks.json").write_text(json.dumps(tracks, indent=2))
    return n, (people / n if n else 0.0), tracks


def process_game(game: Game, out_root: Path, detector, sample_fps: float = 5.0,
                 log=print) -> Path:
    out = out_root / game.id
    out.mkdir(parents=True, exist_ok=True)
    results: list[PlayResult] = []
    plays = game.plays_with_clips
    log(f"{game.away} at {game.home}: {len(plays)} play(s) with video")
    for k, play in enumerate(plays, 1):
        video = game.clip_path(play.clip)
        if not video.exists():
            log(f"  [{k}/{len(plays)}] skip, missing {video.name}")
            continue
        folder = out / f"{play.index:03d}-{slug(play.label)}"
        t0 = time.monotonic()
        n, mean_people, tracks = process_clip(video, play.clip, folder, detector, sample_fps)
        r = PlayResult(play, folder, n, mean_people, tracks, time.monotonic() - t0)
        results.append(r)
        log(f"  [{k}/{len(plays)}] {play.label!r}: {n} frames, {mean_people:.1f} people/frame, "
            f"{len(tracks)} track(s), {r.seconds:.1f}s")
    report = {
        "game_id": game.id, "home": game.home, "away": game.away, "sample_fps": sample_fps,
        "detector": f"rf-detr-{getattr(detector, 'size', '?')}", "plays": [r.to_json() for r in results],
    }
    (out / "report.json").write_text(json.dumps(report, indent=2))
    (out / "report.md").write_text(render_markdown(report))
    return out


def render_markdown(report: dict) -> str:
    lines = [
        f"# CV report: {report['away']} at {report['home']}",
        "",
        f"Detector {report['detector']}, sampled at {report['sample_fps']} fps. "
        "Tracks are people seen in at least 3 sampled frames.",
        "",
        "| # | Call | Clip | Frames | People/frame | Tracks | Called jerseys |",
        "|---|---|---|---|---|---|---|",
    ]
    for p in report["plays"]:
        c = p["clip"]
        called = ", ".join(f"{x['team']} #{x['jersey']} ({x['role']})" for x in p["called_players"]) or "–"
        lines.append(
            f"| {p['index']} | {p['transcript'] or p['kind']} | {c['asset']} {c['start']:.1f}–{c['end']:.1f}s "
            f"| {p['sampled_frames']} | {p['mean_people_per_frame']} | {len(p['tracks'])} | {called} |"
        )
    lines += ["", "Each play folder has `annotated.mp4`, `tracks.json` and `crops/` (best crop per track)."]
    return "\n".join(lines) + "\n"
