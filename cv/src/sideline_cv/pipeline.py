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
from .activity import MotionMeter, find_action, refined_window
from .jersey import match_play
from .teams import TeamModel, cluster_two, lab_to_hex, map_sides, track_color
from .tracks import CropKeeper, TrackBook, crop_score
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
    matches: dict | None = None
    action: dict | None = None

    def to_json(self) -> dict:
        p = self.play
        return {
            "play_id": p.id, "index": p.index, "transcript": p.transcript, "kind": p.kind,
            "status": p.status, "clip": {"asset": p.clip.asset, "start": round(p.clip.start, 3),
                                         "end": round(p.clip.end, 3)} if p.clip else None,
            "called_players": [{"team": c.team, "jersey": c.jersey, "role": c.role} for c in p.players],
            "sampled_frames": self.sampled_frames, "mean_people_per_frame": round(self.mean_people, 2),
            "tracks": self.tracks, "folder": self.folder.name, "processing_seconds": round(self.seconds, 2),
            "matches": self.matches, "action": self.action,
        }


def slug(text: str, limit: int = 40) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return (s[:limit].rstrip("-")) or "play"


def process_clip(video: Path, clip: Clip, out: Path, detector, sample_fps: float = 5.0,
                 min_track_frames: int = 3, reader=None, extra: dict | None = None) -> tuple[int, float, list[dict]]:
    """Detect + track people in one clip (and read jersey numbers when a
    `reader` is given). Returns (frames, mean people/frame, tracks); fills
    `extra` with the action segment and the refined clip window."""
    from trackers import ByteTrackTracker

    info = probe(video)
    out.mkdir(parents=True, exist_ok=True)
    crops = out / "crops"
    crops.mkdir(exist_ok=True)
    tracker = ByteTrackTracker(frame_rate=sample_fps, lost_track_buffer=int(sample_fps * 2),
                               track_activation_threshold=0.35, minimum_consecutive_frames=2)
    book = TrackBook()
    keeper = CropKeeper()
    meter = MotionMeter()
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
            meter.update(t, frame, tracked.xyxy, ids)
            if True:   # keep crops for jersey reading and team colors
                confs = tracked.confidence if tracked.confidence is not None else np.ones(len(tracked))
                for box, tid, conf in zip(tracked.xyxy, ids, confs):
                    if tid < 0:
                        continue
                    x0, y0, x1, y1 = (int(round(v)) for v in box)
                    keeper.offer(int(tid), crop_score(tuple(map(float, box)), float(conf), info.width, info.height),
                                 t, frame[max(0, y0):max(0, y1), max(0, x0):max(0, x1)])
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
    for t in tracks:
        crops_t = keeper.best(t["track_id"])
        # Every kept crop (different moments) for training data; best-scored first.
        views = crops / f"track-{t['track_id']}"
        views.mkdir(exist_ok=True)
        for k, c in enumerate(crops_t):
            cv2.imwrite(str(views / f"{k}.jpg"), c)
        t["views"] = [f"crops/track-{t['track_id']}/{k}.jpg" for k in range(len(crops_t))]
        lab = track_color(crops_t)
        t["color"] = None if lab is None else {"lab": [round(float(v), 1) for v in lab], "hex": lab_to_hex(lab)}
        if reader is not None:
            v, readings = reader.read_track(crops_t)
            t["jersey"] = v.to_json() | {"raw": [r.raw for r in readings][:12]}
    (out / "tracks.json").write_text(json.dumps(tracks, indent=2))
    segment = find_action(meter.samples)
    window = refined_window(segment, clip.start, clip.end)
    action = {"segment": segment.to_json() if segment else None,
              "refined_clip": {"start": window[0], "end": window[1]} if window else None}
    (out / "activity.json").write_text(json.dumps(action | {"samples": meter.samples}, indent=1))
    if extra is not None:
        extra.update(action)
    return n, (people / n if n else 0.0), tracks


def process_game(game: Game, out_root: Path, detector, sample_fps: float = 5.0,
                 log=print, reader=None) -> Path:
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
        extra: dict = {}
        n, mean_people, tracks = process_clip(video, play.clip, folder, detector, sample_fps, reader=reader,
                                              extra=extra)
        r = PlayResult(play, folder, n, mean_people, tracks, time.monotonic() - t0, action=extra)
        if reader is not None:
            r.matches = match_play(play.players, tracks)
        results.append(r)
        log(f"  [{k}/{len(plays)}] {play.label!r}: {n} frames, {mean_people:.1f} people/frame, "
            f"{len(tracks)} track(s), {r.seconds:.1f}s")
    teams = assign_teams(results)
    report = {
        "format": "sideline-cv-report", "version": 1,
        "game_id": game.id, "home": game.home, "away": game.away, "sample_fps": sample_fps,
        "detector": f"rf-detr-{getattr(detector, 'size', '?')}", "teams": teams.to_json() if teams else None,
        "plays": [r.to_json() for r in results],
    }
    (out / "report.json").write_text(json.dumps(report, indent=2))
    (out / "report.md").write_text(render_markdown(report))
    return out


def _lab(t: dict):
    c = t.get("color")
    return None if not c else np.array(c["lab"], float)


def assign_teams(results: list[PlayResult]) -> TeamModel | None:
    """Game-level team colors: cluster every track's jersey color into two,
    name the clusters home/away from number-matched calls, label each track,
    then redo the matching with teams known. Rewrites each play's tracks.json."""
    colored = [(t, _lab(t)) for r in results for t in r.tracks if _lab(t) is not None]
    if len(colored) < 2:
        return None
    centers = cluster_two([lab for _, lab in colored], [t.get("frames", 1) for t, _ in colored])
    by_id = {(r.folder, t["track_id"]): t for r in results for t in r.tracks}
    evidence_pairs = []
    for r in results:
        for m in (r.matches or {}).get("matched", []):
            t = by_id.get((r.folder, m["track_id"]))
            if t is not None:
                evidence_pairs.append((_lab(t), m["team"]))
    sides, evidence = map_sides(centers, evidence_pairs)
    model = TeamModel(centers, sides, evidence)
    for r in results:
        for t in r.tracks:
            t["team"] = model.assign(_lab(t))
        if r.matches is not None:
            r.matches = match_play(r.play.players, r.tracks)
        (r.folder / "tracks.json").write_text(json.dumps(r.tracks, indent=2))
    return model


def team_lines(teams: dict | None) -> list[str]:
    if not teams:
        return ["Team colors: not enough tracks to tell teams apart.", ""]
    parts = []
    for k, v in sorted(teams.items()):
        side = v["team"] or "unknown side"
        ev = ", ".join(f"{n}× {s}" for s, n in v["evidence"].items()) or "no matched numbers"
        parts.append(f"{k} {v['color']} → {side} ({ev})")
    return ["Team colors: " + "; ".join(parts) + ".", ""]


def render_markdown(report: dict) -> str:
    lines = [
        f"# CV report: {report['away']} at {report['home']}",
        "",
        f"Detector {report['detector']}, sampled at {report['sample_fps']} fps. "
        "Tracks are people seen in at least 3 sampled frames.",
        "",
        *team_lines(report.get("teams")),
        "| # | Call | Clip | Action (play) | Frames | People/frame | Tracks | Called jerseys | Found on screen |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for p in report["plays"]:
        c = p["clip"]
        called = ", ".join(f"{x['team']} #{x['jersey']} ({x['role']})" for x in p["called_players"]) or "–"
        m = p.get("matches")
        if m is None:
            found = "–"
        else:
            parts = [f"#{x['jersey']} → track {x['track_id']} ({x['confidence']:.2f})"
                     + (" ⚠ other team's colors" if x.get("team_conflict") else "") for x in m["matched"]]
            parts += [f"#{x['jersey']} not seen" for x in m["missing"]]
            found = "; ".join(parts) or "–"
        act = (p.get("action") or {}).get("segment")
        refined = (p.get("action") or {}).get("refined_clip")
        action = "–" if not act else (f"{act['start']:.1f}–{act['end']:.1f}s (conf {act['confidence']:.2f})"
                                       + (f" → clip {refined['start']:.1f}–{refined['end']:.1f}s" if refined else ""))
        lines.append(
            f"| {p['index']} | {p['transcript'] or p['kind']} | {c['asset']} {c['start']:.1f}–{c['end']:.1f}s "
            f"| {action} | {p['sampled_frames']} | {p['mean_people_per_frame']} | {len(p['tracks'])} | {called} | {found} |"
        )
    lines += ["", "Each play folder has `annotated.mp4`, `tracks.json` and `crops/` (best crop per track)."]
    return "\n".join(lines) + "\n"
