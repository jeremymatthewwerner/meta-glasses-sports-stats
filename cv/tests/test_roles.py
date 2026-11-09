import json
import os

import cv2
import numpy as np
import pytest
import supervision as sv

from sideline_cv.game import load_game
from sideline_cv.jersey import Vote
from sideline_cv.pipeline import process_game, track_count
from sideline_cv.roles import decide, is_player
from sideline_cv.teams import track_color
from test_teams import BLUE, RED, player

GRAY = (128, 128, 128)       # stands in for a referee's stripes


def test_decide_and_is_player():
    assert decide({"official": 0.62, "player": 0.30, "sideline": 0.08}) == "official"
    assert decide({"official": 0.45, "player": 0.50, "sideline": 0.05}) == "player"      # not sure enough
    assert decide({"official": 0.30, "player": 0.05, "sideline": 0.65}) == "official"    # surely not a player
    assert decide({"official": 0.02, "player": 0.08, "sideline": 0.90}) == "sideline"
    assert decide({"official": 0.10, "player": 0.20, "sideline": 0.70}) == "player"      # sideline needs ≥ 0.85
    assert is_player({}) and is_player({"role": {"role": "player"}})
    assert not is_player({"role": {"role": "official"}})


def test_track_count_names_officials_and_sideline():
    tracks = [{"role": {"role": "player"}}] * 3 + [{"role": {"role": "official"}}] * 2 + [{"role": {"role": "sideline"}}]
    assert track_count(tracks) == "6 (2 officials, 1 sideline)"
    assert track_count([{}, {}]) == "2"


def test_officials_get_no_number_and_stay_out_of_team_colors(tmp_path):
    """Red #22 and blue #54 play; a gray official walks between them. The
    reader would happily read "11" off the official's shirt."""
    games = tmp_path / "games"
    (games / "G1").mkdir(parents=True)
    fps, w, h = 30, 480, 270
    out = cv2.VideoWriter(str(games / "G1" / "glasses-01.mov"), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for i in range(4 * fps):
        f = np.zeros((h, w, 3), np.uint8)
        f[:] = (70, 140, 70)
        f[60:220, 20 + i * 2:70 + i * 2] = player(RED, 50, 160)
        f[60:220, 400 - i * 2:450 - i * 2] = player(BLUE, 50, 160)
        f[40:200, 215:265] = player(GRAY, 50, 160)
        out.write(f)
    out.release()
    (games / "G1.json").write_text(json.dumps({
        "id": "G1", "home": {"name": "Reds"}, "away": {"name": "Blues"}, "events": [{
            "id": "P1", "offense": "home", "status": "proposed", "transcript": "22 run for 7, tackle by 54",
            "play": {"kind": "rush", "ballCarrier": 22, "tacklers": [54], "yards": 7},
            "videoRefs": [{"assetID": "glasses-01.mov", "start": 0, "end": 4}]}]}))

    def mask_box(frame, bgr):
        ys, xs = np.nonzero(np.abs(frame.astype(int) - bgr).sum(axis=2) < 40)
        return [xs.min() - 4, ys.min() - 20, xs.max() + 4, ys.max() + 60] if len(xs) else None

    class Detector:
        size = "fake"

        def __call__(self, frame):
            boxes = [b for b in (mask_box(frame, c) for c in (RED, BLUE, GRAY)) if b]
            return sv.Detections(xyxy=np.array(boxes, float), confidence=np.full(len(boxes), 0.9),
                                 class_id=np.ones(len(boxes), int))

    def shirt(crops):
        lab = track_color(crops)
        return "red" if lab[1] > 20 else ("gray" if abs(lab[1]) < 5 and abs(lab[2]) < 5 else "blue")

    class Reader:
        def read_track(self, crops):
            return Vote({"red": 22, "blue": 54, "gray": 11}[shirt(crops)], 0.9, len(crops), len(crops)), []

    class Roles:
        def classify(self, crops):
            gray = shirt(crops) == "gray"
            p = {"official": 0.8 if gray else 0.05, "player": 0.15 if gray else 0.9, "sideline": 0.05}
            return {"role": decide(p), "p": p}

    report_dir = process_game(load_game(games / "G1.json"), tmp_path / "out", Detector(), 5,
                              log=lambda *_: None, reader=Reader(), roles=Roles())
    report = json.loads((report_dir / "report.json").read_text())
    tracks = report["plays"][0]["tracks"]
    officials = [t for t in tracks if t["role"]["role"] == "official"]
    assert officials and all(t["jersey"]["number"] is None and t["jersey"]["skipped"] == "official" for t in officials)
    assert all(t["team"]["team"] is None for t in officials)
    # The official's gray doesn't become a "team": red and blue are still the two teams.
    assert {v["team"] for v in report["teams"].values()} == {"home", "away"}
    assert not report["plays"][0]["matches"]["unexpected"]           # no "#11" on screen
    assert "official" in (report_dir / "report.md").read_text()


@pytest.mark.skipif(not os.environ.get("SIDELINE_CV_MODELS"), reason="needs CLIP weights (~600 MB)")
def test_clip_tells_a_striped_shirt_from_a_jersey():
    from sideline_cv.roles import RoleClassifier

    def person(shirt):
        img = player((60, 60, 60), 120, 300)
        img[36:186, 12:108] = shirt
        return img

    stripes = np.zeros((150, 96, 3), np.uint8)
    for x in range(0, 96, 12):
        stripes[:, x:x + 6] = 245
    jersey = np.zeros((150, 96, 3), np.uint8)
    jersey[:] = RED
    cv2.putText(jersey, "22", (14, 100), cv2.FONT_HERSHEY_SIMPLEX, 2.0, (255, 255, 255), 6)
    rc = RoleClassifier()
    ref, kid = rc.probs([person(stripes)]), rc.probs([person(jersey)])
    assert ref["official"] > kid["official"]
