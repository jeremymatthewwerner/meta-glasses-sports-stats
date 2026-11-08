"""Training data for the jersey-number reader, labeled by the voice calls.

A track whose read number matched a called player (same team colors, no
conflict) is very likely that player: the caller said "22 run for 7" and
the screen showed a 22 in home colors. Its crops become labeled examples.
Over a season this is thousands of in-domain crops for fine-tuning PARSeq,
with no hand labeling.

Output: <out>/images/<game8>-<play>-t<track>-<k>.jpg and <out>/labels.csv
(path, number, team, role, game, play, confidence).
"""

from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path


def export_labeled_crops(report_dirs: list[Path], out: Path, min_confidence: float = 0.5) -> int:
    images = out / "images"
    images.mkdir(parents=True, exist_ok=True)
    labels_path = out / "labels.csv"
    new = not labels_path.exists()
    count = 0
    with labels_path.open("a", newline="") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["path", "number", "team", "role", "game", "play", "confidence"])
        for rd in report_dirs:
            report = json.loads((rd / "report.json").read_text())
            for p in report["plays"]:
                tracks = {t["track_id"]: t for t in p["tracks"]}
                for m in (p.get("matches") or {}).get("matched", []):
                    if m.get("team_conflict") or m.get("ambiguous") or m["confidence"] < min_confidence:
                        continue
                    t = tracks.get(m["track_id"])
                    if not t:
                        continue
                    for k, rel in enumerate(t.get("views") or [t.get("crop")]):
                        src = rd / p["folder"] / rel
                        if not src.exists():
                            continue
                        name = f"{report['game_id'][:8]}-{p['index']:03d}-t{m['track_id']}-{k}.jpg"
                        shutil.copyfile(src, images / name)
                        w.writerow([f"images/{name}", m["jersey"], m["team"], m["role"], report["game_id"],
                                    p["play_id"], m["confidence"]])
                        count += 1
    return count
