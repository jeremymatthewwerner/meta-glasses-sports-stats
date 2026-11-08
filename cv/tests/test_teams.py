import numpy as np

from sideline_cv.game import CalledPlayer
from sideline_cv.jersey import match_play
from sideline_cv.teams import TeamModel, cluster_two, dominant_color, lab_to_hex, map_sides, track_color

RED, BLUE, WHITE = (40, 40, 210), (190, 90, 30), (245, 245, 245)     # BGR


def player(shirt, w=80, h=200, bg=(70, 140, 70), skin=(140, 170, 220)):
    """Background, a head (skin), a shirt and dark shorts."""
    img = np.zeros((h, w, 3), np.uint8)
    img[:] = bg
    img[: int(h * 0.12), int(w * 0.3):int(w * 0.7)] = skin
    img[int(h * 0.12):int(h * 0.62), int(w * 0.1):int(w * 0.9)] = shirt
    img[int(h * 0.62):, int(w * 0.2):int(w * 0.8)] = (30, 30, 30)
    return img


def test_dominant_color_is_the_shirt():
    lab = dominant_color(player(RED))
    assert lab is not None and lab[1] > 30            # strongly red (a* high)
    assert lab_to_hex(lab).startswith("#d") or lab_to_hex(lab)[1:3] > "b0"
    white = dominant_color(player(WHITE))
    assert white[0] > 90 and abs(white[1]) < 5 and abs(white[2]) < 5
    assert dominant_color(np.zeros((6, 4, 3), np.uint8)) is None


def test_track_color_is_robust_to_an_odd_crop():
    crops = [player(BLUE)] * 4 + [player(RED)]       # one crop dominated by an opponent
    lab = track_color(crops)
    assert lab[2] < -20                               # still blue (b* low)


def test_cluster_two_and_assign():
    rng = np.random.default_rng(0)
    reds = [dominant_color(player(RED)) + rng.normal(0, 2, 3) for _ in range(6)]
    blues = [dominant_color(player(BLUE)) + rng.normal(0, 2, 3) for _ in range(5)]
    centers = cluster_two(reds + blues)
    assert set(centers) == {"A", "B"}
    model = TeamModel(centers, {}, {})
    ra, ba = {model.assign(c)["cluster"] for c in reds}, {model.assign(c)["cluster"] for c in blues}
    assert len(ra) == 1 and len(ba) == 1 and ra != ba
    assert cluster_two([reds[0], reds[1]]).keys() == {"A"}   # one color on screen → one cluster


def test_map_sides_from_number_matches():
    red, blue = dominant_color(player(RED)), dominant_color(player(BLUE))
    centers = cluster_two([red, red, blue, blue])
    sides, evidence = map_sides(centers, [(red, "home"), (red, "home"), (blue, "away")])
    red_cluster = TeamModel(centers, {}, {}).assign(red)["cluster"]
    assert sides[red_cluster] == "home" and set(sides.values()) == {"home", "away"}
    only_one, _ = map_sides(centers, [(blue, "away")])        # the other cluster is inferred
    assert set(only_one.values()) == {"home", "away"}
    contradictory, _ = map_sides(centers, [(red, "home"), (blue, "home")])
    assert contradictory == {}


def test_team_aware_matching_splits_same_number():
    called = [CalledPlayer("home", 22, "ballCarrier"), CalledPlayer("away", 22, "tacklers")]
    tracks = [
        {"track_id": 1, "frames": 30, "jersey": {"number": 22, "confidence": 0.9}, "team": {"team": "away", "unsure": False}},
        {"track_id": 2, "frames": 20, "jersey": {"number": 22, "confidence": 0.7}, "team": {"team": "home", "unsure": False}},
    ]
    m = {x["team"]: x for x in match_play(called, tracks)["matched"]}
    assert m["home"]["track_id"] == 2 and m["away"]["track_id"] == 1
    assert not m["home"]["team_conflict"] and not m["home"]["ambiguous"]


def test_team_conflict_flagged():
    called = [CalledPlayer("home", 54, "ballCarrier")]
    tracks = [{"track_id": 9, "frames": 30, "jersey": {"number": 54, "confidence": 0.8},
               "team": {"team": "away", "unsure": False}}]
    m = match_play(called, tracks)["matched"][0]
    assert m["track_id"] == 9 and m["team_conflict"]


def test_process_game_names_teams_from_called_numbers(tmp_path):
    import json

    import cv2
    import supervision as sv

    from sideline_cv.game import load_game
    from sideline_cv.jersey import Vote
    from sideline_cv.pipeline import process_game

    # Video: red #22 runs right, blue #54 runs left, on grass.
    games = tmp_path / "games"
    gid = "G1"
    (games / gid).mkdir(parents=True)
    fps, w, h = 30, 480, 270
    out = cv2.VideoWriter(str(games / gid / "glasses-01.mov"), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for i in range(4 * fps):
        f = np.zeros((h, w, 3), np.uint8)
        f[:] = (70, 140, 70)
        f[60:220, 20 + i * 2:20 + i * 2 + 50] = player(RED, 50, 160)
        f[60:220, 400 - i * 2:400 - i * 2 + 50] = player(BLUE, 50, 160)
        out.write(f)
    out.release()
    (games / f"{gid}.json").write_text(json.dumps({
        "id": gid, "home": {"name": "Reds"}, "away": {"name": "Blues"}, "events": [{
            "id": "P1", "offense": "home", "status": "proposed", "transcript": "22 run for 7, tackle by 54",
            "play": {"kind": "rush", "ballCarrier": 22, "tacklers": [54], "yards": 7},
            "videoRefs": [{"assetID": "glasses-01.mov", "start": 0, "end": 4}]}]}))

    class TwoColorDetector:
        size = "fake"

        def __call__(self, frame):
            boxes = []
            for bgr in (RED, BLUE):
                mask = (np.abs(frame.astype(int) - bgr).sum(axis=2) < 40)
                ys, xs = np.nonzero(mask)
                if len(xs):
                    boxes.append([xs.min() - 4, ys.min() - 20, xs.max() + 4, ys.max() + 60])
            if not boxes:
                return sv.Detections.empty()
            return sv.Detections(xyxy=np.array(boxes, float), confidence=np.full(len(boxes), 0.9),
                                 class_id=np.ones(len(boxes), int))

    class ColorReader:
        """Reads 22 on red shirts and 54 on blue ones."""

        def read_track(self, crops):
            lab = track_color(crops)
            return Vote(22 if lab[1] > 20 else 54, 0.9, len(crops), len(crops)), []

    game = load_game(games / f"{gid}.json")
    report_dir = process_game(game, tmp_path / "out", TwoColorDetector(), 5, log=lambda *_: None, reader=ColorReader())
    report = json.loads((report_dir / "report.json").read_text())
    sides = {v["team"] for v in report["teams"].values()}
    assert sides == {"home", "away"}
    matched = {m["jersey"]: m for m in report["plays"][0]["matches"]["matched"]}
    assert matched[22]["track_team"] == "home" and matched[54]["track_team"] == "away"
    assert not any(m["team_conflict"] for m in matched.values())
    assert "→ home" in (report_dir / "report.md").read_text()


def test_export_labeled_crops_from_a_processed_game(tmp_path):
    """Reuses the synthetic two-team game; every matched, conflict-free track's views become labeled crops."""
    import csv

    from sideline_cv.dataset import export_labeled_crops

    test_process_game_names_teams_from_called_numbers(tmp_path)
    report_dir = tmp_path / "out" / "G1"
    report = __import__("json").loads((report_dir / "report.json").read_text())
    assert report["format"] == "sideline-cv-report" and report["version"] == 1
    n = export_labeled_crops([report_dir], tmp_path / "dataset")
    rows = list(csv.DictReader((tmp_path / "dataset" / "labels.csv").open()))
    assert n == len(rows) and n >= 4
    assert {r["number"] for r in rows} == {"22", "54"}
    assert {(r["number"], r["team"]) for r in rows} == {("22", "home"), ("54", "away")}
    assert all((tmp_path / "dataset" / r["path"]).exists() for r in rows)
