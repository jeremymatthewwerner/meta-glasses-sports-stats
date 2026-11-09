"""Jersey numbers: read them from track crops (PARSeq, Apache-2.0), vote
across several crops per track, and match the result to the jerseys the
caller named for the play.

PARSeq is a general scene-text recognizer (SoccerNet's best jersey
pipelines use it fine-tuned). Off the shelf it reads clear numbers well;
fine-tuning on our own crops is the obvious upgrade once labeled games exist.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import asdict, dataclass

import numpy as np

from .game import CalledPlayer

MIN_CROP_HEIGHT = 48        # px; smaller people can't have a readable number


@dataclass(frozen=True)
class Reading:
    number: int | None      # 0–99, or None when nothing digit-like was read
    confidence: float       # 0–1
    raw: str                # what the recognizer actually returned


def torso(crop: np.ndarray) -> np.ndarray:
    """The part of a person box where a jersey number sits (front or back)."""
    h, w = crop.shape[:2]
    return crop[int(0.12 * h):int(0.62 * h), int(0.08 * w):int(0.92 * w)]


def torso_windows(crop: np.ndarray) -> list[np.ndarray]:
    """Where to look for a number: the whole torso, its left and right
    halves (chest numbers sit off-center) and its upper half. Each window
    is read separately so a small number fills the recognizer's input."""
    t = torso(crop)
    h, w = t.shape[:2]
    if h < 8 or w < 8:
        return []
    return [t, t[:, : int(w * 0.6)], t[:, int(w * 0.4):], t[: int(h * 0.6)]]


def to_reading(label: str, char_confs: list[float]) -> Reading:
    """Keeps the digits of a recognizer output. Non-digit characters cost
    confidence; more than two digits (not a jersey) or none gives no number."""
    digits = [(c, p) for c, p in zip(label, char_confs) if c.isdigit()]
    if not digits or len(digits) > 2:
        return Reading(None, 0.0, label)
    conf = float(np.prod([p for _, p in digits]))
    junk = len(label) - len(digits)
    conf *= 0.6 ** junk
    return Reading(int("".join(c for c, _ in digits)), round(conf, 4), label)


# Off-the-shelf PARSeq "finds" digits in shirt seams, logos and coaches'
# jackets, mostly at low confidence and above all a lone "1" (even at 0.8+).
# On hand-labeled youth-football tracks (2026-11-08) these two floors cut
# wrong numbers from 26 of 41 tracks to 2 without losing a correct one.
MIN_READ_CONFIDENCE = 0.5
MIN_LONE_ONE_CONFIDENCE = 0.95


def credible(r: Reading) -> bool:
    if r.number is None:
        return False
    floor = MIN_LONE_ONE_CONFIDENCE if r.number == 1 and r.raw.strip() in ("1", "#1") else MIN_READ_CONFIDENCE
    return r.confidence >= floor


def best_reading(readings: list[Reading]) -> Reading:
    """The most confident credible reading (or an empty one, keeping the raw
    text of the best reading for the record)."""
    numbered = [r for r in readings if credible(r)]
    if not numbered:
        raw = max(readings, key=lambda r: r.confidence).raw if readings else ""
        return Reading(None, 0.0, raw)
    return max(numbered, key=lambda r: r.confidence)


@dataclass(frozen=True)
class Vote:
    number: int | None
    confidence: float       # share of the total reading weight that agrees
    support: int            # readings that agree
    reads: int              # readings considered

    def to_json(self) -> dict:
        return asdict(self) | {"confidence": round(self.confidence, 3)}


def vote(readings: list[Reading], min_weight: float = 0.5, min_support: int = 1) -> Vote:
    """Confidence-weighted vote over a track's readings (one per frame). A
    number needs at least `min_weight` of summed confidence and
    `min_support` agreeing readings to win."""
    weights: dict[int, float] = defaultdict(float)
    counts: dict[int, int] = defaultdict(int)
    total = 0.0
    for r in readings:
        total += max(r.confidence, 0.05)          # an unreadable crop still counts as doubt
        if r.number is not None:
            weights[r.number] += r.confidence
            counts[r.number] += 1
    if not weights:
        return Vote(None, 0.0, 0, len(readings))
    best = max(weights, key=lambda n: (weights[n], counts[n]))
    if weights[best] < min_weight or counts[best] < min_support:
        return Vote(None, weights[best] / total if total else 0.0, counts[best], len(readings))
    return Vote(best, weights[best] / total, counts[best], len(readings))


class JerseyReader:
    """PARSeq via torch.hub (downloads code + ~91 MB weights on first use)."""

    def __init__(self, device: str | None = None):
        import torch
        import torchvision.transforms as T

        self.torch = torch
        self.device = device or ("mps" if torch.backends.mps.is_available() else "cpu")
        self.model = torch.hub.load("baudm/parseq", "parseq", pretrained=True, trust_repo=True).eval().to(self.device)
        h, w = self.model.hparams.img_size
        self.transform = T.Compose([
            T.Resize((h, w), T.InterpolationMode.BICUBIC), T.ToTensor(), T.Normalize(0.5, 0.5)])

    def read(self, crops_bgr: list[np.ndarray]) -> list[Reading]:
        from PIL import Image

        usable = [(i, c) for i, c in enumerate(crops_bgr) if c is not None and c.size and c.shape[0] >= 8]
        out: list[Reading] = [Reading(None, 0.0, "") for _ in crops_bgr]
        if not usable:
            return out
        batch = self.torch.stack([self.transform(Image.fromarray(np.ascontiguousarray(c[:, :, ::-1])))
                                  for _, c in usable]).to(self.device)
        with self.torch.no_grad():
            probs = self.model(batch).softmax(-1)
        labels, confs = self.model.tokenizer.decode(probs)
        for (i, _), label, conf in zip(usable, labels, confs):
            # The last confidence is the end-of-sequence token; drop it.
            out[i] = to_reading(label, [float(c) for c in conf[: len(label)]])
        return out

    def read_track(self, person_crops: list[np.ndarray], min_support: int = 2) -> tuple[Vote, list[Reading]]:
        """One reading per crop (the most confident of its torso windows),
        then a vote across crops, which come from different moments."""
        crops = [c for c in person_crops if c is not None and c.shape[0] >= MIN_CROP_HEIGHT]
        if not crops:
            return Vote(None, 0.0, 0, 0), []
        windows = [torso_windows(c) for c in crops]
        flat = self.read([w for ws in windows for w in ws])
        readings, i = [], 0
        for ws in windows:
            group = flat[i:i + len(ws)]
            i += len(ws)
            readings.append(best_reading(group))
        return vote(readings, min_support=min(min_support, len(readings))), readings


def match_play(called: list[CalledPlayer], tracks: list[dict], min_confidence: float = 0.5) -> dict:
    """Links called jerseys to tracks whose read number matches.

    Returns {"matched": [...], "missing": [...], "unexpected": [...]}:
    matched = called player + the track that shows that number;
    missing = called but never read; unexpected = read on screen but not
    named in the call (teammates, opponents, or misreads).
    Team colors aren't used yet, so a number worn on both teams can match
    either; such matches are flagged `ambiguous`.
    """
    by_number: dict[int, list[dict]] = defaultdict(list)
    for t in tracks:
        j = t.get("jersey") or {}
        if j.get("number") is not None and j.get("confidence", 0) >= min_confidence:
            by_number[j["number"]].append(t)
    def track_team(t: dict) -> str | None:
        a = t.get("team") or {}
        return None if a.get("unsure", True) else a.get("team")

    # Enrolled faces carry a jersey: a track whose face matched a person
    # wearing #22 stands in for an unreadable number, and confirms a read one.
    by_face: dict[int, list[dict]] = defaultdict(list)
    for t in tracks:
        f = t.get("face") or {}
        if f.get("person") and f.get("jersey") is not None:
            by_face[int(f["jersey"])].append(t)

    called_numbers = [c.jersey for c in called]
    matched, missing = [], []
    for c in called:
        ts = by_number.get(c.jersey)
        if not ts and by_face.get(c.jersey):
            best = max(by_face[c.jersey], key=lambda t: (t["face"]["similarity"], t.get("frames", 0)))
            matched.append({
                "team": c.team, "jersey": c.jersey, "role": c.role, "track_id": best["track_id"],
                "confidence": best["face"]["similarity"], "crop": best.get("crop"), "track_team": track_team(best),
                "team_conflict": False, "ambiguous": False, "via": "face", "person": best["face"]["person"],
            })
            continue
        if not ts:
            missing.append({"team": c.team, "jersey": c.jersey, "role": c.role})
            continue
        # Prefer a track whose jersey color says it's on the called team;
        # then the more confident read; then the longer track.
        best = min(ts, key=lambda t: (track_team(t) not in (c.team, None), track_team(t) is None,
                                      -t["jersey"]["confidence"], -t.get("frames", 0)))
        tt = track_team(best)
        same_number_both_teams = len({x.team for x in called if x.jersey == c.jersey}) > 1
        matched.append({
            "team": c.team, "jersey": c.jersey, "role": c.role, "track_id": best["track_id"],
            "confidence": best["jersey"]["confidence"], "crop": best.get("crop"),
            "track_team": tt,
            "team_conflict": tt is not None and tt != c.team,
            "ambiguous": same_number_both_teams and tt is None,
            "face_confirmed": (best.get("face") or {}).get("jersey") == c.jersey,
        })
    unexpected = [
        {"track_id": t["track_id"], "jersey": n, "confidence": t["jersey"]["confidence"]}
        for n, ts in sorted(by_number.items()) if n not in called_numbers for t in ts
    ]
    return {"matched": matched, "missing": missing, "unexpected": unexpected}
