import json
import shutil
from pathlib import Path

import cv2
import numpy as np
import supervision as sv

from sideline_cv.game import Clip, called_players, find_game, load_game
from sideline_cv.pipeline import process_clip, render_markdown, slug
from sideline_cv.tracks import TrackBook, crop_score
from sideline_cv.video import frames, probe, sample_times

FIXTURE = Path(__file__).parent / "fixtures" / "game.json"


def test_load_game_reads_plays_clips_and_called_players():
    game = load_game(FIXTURE)
    assert game.home == "Eagles" and game.away == "Hawks"
    with_clip = [p for p in game.plays if p.clip]
    assert with_clip, "fixture has a play with a clip"
    p = with_clip[0]
    assert p.clip.asset.endswith(".mov") and p.clip.end > p.clip.start
    assert game.clip_path(p.clip) == FIXTURE.parent / game.id / p.clip.asset
    assert all(pl.status != "rejected" for pl in game.plays_with_clips)


def test_called_players_sides_and_roles():
    play = {"kind": "kickoff", "kicker": 3, "returner": 22, "tacklers": [54, 21]}
    got = called_players(play, offense="away")
    assert ("away", 3, "kicker") in [(c.team, c.jersey, c.role) for c in got]
    assert ("home", 22, "returner") in [(c.team, c.jersey, c.role) for c in got]
    assert {c.jersey for c in got if c.role == "tacklers"} == {54, 21}
    fumble = called_players({"kind": "rush", "ballCarrier": 22, "fumbledBy": 22, "fumbleRecoveredBy": 55,
                             "fumbleLost": True}, offense="home")
    assert ("away", 55, "fumbleRecoveredBy") in [(c.team, c.jersey, c.role) for c in fumble]
    assert len([c for c in fumble if c.jersey == 22]) == 2      # carrier and fumbler are separate roles


def test_find_game_latest_and_prefix(tmp_path):
    a = tmp_path / "AAAA-1.json"; a.write_text("{}")
    b = tmp_path / "BBBB-2.json"; b.write_text("{}")
    (tmp_path / "BBBB-2-utterances.json").write_text("[]")
    assert find_game(tmp_path, "aaaa") == a
    assert find_game(tmp_path, "latest") in (a, b)


def test_sample_times():
    assert sample_times(0, 1, 0.25) == [0, 0.25, 0.5, 0.75]
    assert sample_times(2, 2, 0.2) == []
    assert sample_times(1.0, 1.1, 0.5) == [1.0]


def make_video(path: Path, seconds=4, fps=30, w=320, h=240):
    """A white box walking left to right on green: a stand-in "player"."""
    out = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for i in range(seconds * fps):
        frame = np.zeros((h, w, 3), np.uint8)
        frame[:] = (40, 140, 40)
        x = 20 + i * 2
        frame[80:200, x:x + 40] = 255
        out.write(frame)
    out.release()


class FakeDetector:
    """Finds the white box: lets us test tracking without model weights."""
    size = "fake"

    def __call__(self, frame):
        mask = (frame > 200).all(axis=2)
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            return sv.Detections.empty()
        box = np.array([[xs.min(), ys.min(), xs.max() + 1, ys.max() + 1]], float)
        return sv.Detections(xyxy=box, confidence=np.array([0.9]), class_id=np.array([1]))


def test_frames_sample_the_requested_range(tmp_path):
    v = tmp_path / "walk.mp4"
    make_video(v)
    info = probe(v)
    assert info.frames == 120 and abs(info.fps - 30) < 0.5
    ts = [t for t, _ in frames(v, 1.0, 3.0, sample_fps=5)]
    assert len(ts) == 10
    assert abs(ts[0] - 1.0) < 0.05 and ts[-1] < 3.0


def test_process_clip_tracks_one_walker(tmp_path):
    v = tmp_path / "walk.mp4"
    make_video(v)
    n, mean_people, tracks = process_clip(v, Clip("walk.mp4", 0, 4), tmp_path / "out", FakeDetector(), 5)
    assert n == 20 and mean_people == 1
    assert len(tracks) == 1                       # one person, one track id throughout
    t = tracks[0]
    assert t["frames"] >= 18 and t["duration"] > 3
    assert (tmp_path / "out" / t["crop"]).exists()
    assert (tmp_path / "out" / "annotated.mp4").stat().st_size > 0
    assert json.loads((tmp_path / "out" / "tracks.json").read_text())[0]["track_id"] == t["track_id"]


def test_trackbook_prefers_big_unclipped_crops():
    book = TrackBook()
    book.update(0.0, np.array([[0, 0, 50, 100]], float), np.array([7]), np.array([0.9]), 640, 480)   # clipped at edge
    book.update(0.2, np.array([[100, 50, 140, 130]], float), np.array([7]), np.array([0.9]), 640, 480)
    s = book.tracks[7]
    assert s.frames == 2 and s.best_t == 0.2
    assert crop_score((0, 0, 50, 100), 0.9, 640, 480) < crop_score((100, 50, 150, 150), 0.9, 640, 480)
    book.update(0.4, np.array([[1, 1, 2, 2]], float), np.array([-1]), None, 640, 480)            # untracked: ignored
    assert set(book.tracks) == {7}


def test_slug_and_markdown():
    assert slug("22 run for 7, tackle by 54") == "22-run-for-7-tackle-by-54"
    md = render_markdown({"home": "Eagles", "away": "Hawks", "detector": "rf-detr-x", "sample_fps": 5, "plays": [
        {"index": 3, "transcript": "22 run for 7", "kind": "rush", "clip": {"asset": "glasses-01.mov", "start": 1, "end": 18},
         "sampled_frames": 85, "mean_people_per_frame": 6.2, "tracks": [{}, {}],
         "called_players": [{"team": "home", "jersey": 22, "role": "ballCarrier"}]}]})
    assert "| 3 | 22 run for 7 | glasses-01.mov 1.0–18.0s | 85 | 6.2 | 2 | home #22 (ballCarrier) |" in md
