import os

import cv2
import numpy as np
import pytest

from sideline_cv.game import CalledPlayer, Clip
from sideline_cv.jersey import Reading, Vote, match_play, to_reading, torso, vote
from sideline_cv.pipeline import process_clip
from sideline_cv.tracks import CropKeeper

from test_cv import FakeDetector, make_video


def test_to_reading_keeps_digits_and_penalizes_junk():
    assert to_reading("22", [0.99, 0.98]) == Reading(22, round(0.99 * 0.98, 4), "22")
    r = to_reading("2a", [0.9, 0.9])
    assert r.number == 2 and r.confidence == pytest.approx(0.9 * 0.6, abs=1e-4)
    assert to_reading("ab", [0.9, 0.9]).number is None
    assert to_reading("1234", [1, 1, 1, 1]).number is None      # not a jersey number
    assert to_reading("07", [0.9, 0.9]).number == 7


def test_vote_weighs_confidence_and_needs_enough_weight():
    reads = [Reading(22, 0.9, "22"), Reading(22, 0.8, "22"), Reading(27, 0.95, "27"), Reading(None, 0, "x")]
    v = vote(reads)
    assert v.number == 22 and v.support == 2 and v.reads == 4
    assert 0.5 < v.confidence < 0.7
    assert vote([Reading(5, 0.3, "5")]).number is None             # too little evidence
    assert vote([]).number is None


def test_torso_is_upper_middle_of_box():
    crop = np.zeros((200, 100, 3), np.uint8)
    t = torso(crop)
    assert t.shape[0] == 100 and 80 <= t.shape[1] <= 85


def test_crop_keeper_keeps_best_spread_out():
    k = CropKeeper(k=2, min_gap=0.3)
    img = np.ones((10, 10, 3), np.uint8)
    k.offer(1, 5, 0.0, img * 1)
    k.offer(1, 9, 0.1, img * 2)      # same moment, better: replaces
    k.offer(1, 3, 1.0, img * 3)
    k.offer(1, 7, 2.0, img * 4)      # pushes out the weakest
    kept = k.best(1)
    assert [int(c[0, 0, 0]) for c in kept] == [2, 4]


def tracks_with(*items):
    return [{"track_id": tid, "frames": f, "crop": f"crops/track-{tid}.jpg",
             "jersey": {"number": n, "confidence": c, "support": 3, "reads": 4}} for tid, n, c, f in items]


def test_match_play_matched_missing_unexpected():
    called = [CalledPlayer("home", 22, "ballCarrier"), CalledPlayer("away", 54, "tacklers")]
    tracks = tracks_with((3, 22, 0.9, 40), (8, 22, 0.6, 10), (5, 11, 0.8, 30), (6, 54, 0.3, 20))
    m = match_play(called, tracks)
    assert m["matched"] == [{"team": "home", "jersey": 22, "role": "ballCarrier", "track_id": 3,
                             "confidence": 0.9, "crop": "crops/track-3.jpg", "track_team": None,
                             "team_conflict": False, "ambiguous": False, "face_confirmed": False}]
    assert m["missing"] == [{"team": "away", "jersey": 54, "role": "tacklers"}]   # 0.3 is below the bar
    assert [u["jersey"] for u in m["unexpected"]] == [11]


class FakeReader:
    """Pretends the walker's jersey says 22."""
    def read_track(self, crops):
        return (Vote(22, 0.9, len(crops), len(crops)) if crops else Vote(None, 0, 0, 0)), []


def test_process_clip_attaches_jersey_votes(tmp_path):
    v = tmp_path / "walk.mp4"
    make_video(v)
    _, _, tracks = process_clip(v, Clip("walk.mp4", 0, 4), tmp_path / "out", FakeDetector(), 5, reader=FakeReader())
    assert tracks[0]["jersey"]["number"] == 22
    m = match_play([CalledPlayer("home", 22, "ballCarrier")], tracks)
    assert m["matched"][0]["track_id"] == tracks[0]["track_id"]


def shirt(num, bg, fg, w=120, h=320):
    """A crude player: dark legs, a colored shirt with a number."""
    img = np.zeros((h, w, 3), np.uint8)
    img[:] = (60, 60, 60)
    img[int(h * 0.1):int(h * 0.62)] = bg
    cv2.putText(img, str(num), (12 if num > 9 else 35, int(h * 0.45)), cv2.FONT_HERSHEY_DUPLEX, 2.4, fg, 7)
    return img


@pytest.mark.skipif(os.environ.get("SIDELINE_CV_MODELS") != "1", reason="set SIDELINE_CV_MODELS=1 to run with PARSeq")
def test_parseq_reads_synthetic_jerseys():
    from sideline_cv.jersey import JerseyReader

    reader = JerseyReader()
    for num, bg, fg in [(22, (30, 30, 200), (255, 255, 255)), (54, (240, 240, 240), (20, 20, 20)), (7, (20, 90, 20), (250, 250, 250))]:
        crops = [shirt(num, bg, fg)] * 3
        v, _ = reader.read_track(crops)
        assert v.number == num, (num, v)


def test_torso_windows_and_best_reading():
    from sideline_cv.jersey import best_reading, torso_windows

    ws = torso_windows(np.zeros((200, 100, 3), np.uint8))
    assert len(ws) == 4 and ws[1].shape[1] < ws[0].shape[1] and ws[3].shape[0] < ws[0].shape[0]
    assert torso_windows(np.zeros((10, 5, 3), np.uint8)) == []
    r = best_reading([Reading(None, 0, "SPB"), Reading(2, 0.7, "2"), Reading(22, 0.4, "22")])
    assert r.number == 2
    assert best_reading([Reading(None, 0, "AD")]).number is None


def test_weak_reads_and_lone_ones_are_not_credible():
    from sideline_cv.jersey import best_reading

    # Seam/jacket noise: low-confidence digits, and the recognizer's favorite, a lone "1".
    assert best_reading([Reading(7, 0.45, "7"), Reading(None, 0, "THE")]).number is None
    assert best_reading([Reading(1, 0.89, "1"), Reading(None, 0, "S")]).number is None
    assert best_reading([Reading(1, 0.97, "1")]).number == 1        # a clear #1 still reads
    assert best_reading([Reading(1, 0.6, "#1"), Reading(10, 0.96, "10")]).number == 10
    assert best_reading([Reading(11, 0.7, "11")]).number == 11      # two digits use the normal floor


def test_vote_min_support_rejects_one_off_reads():
    reads = [Reading(7, 0.9, "7"), Reading(None, 0, "x"), Reading(None, 0, "y")]
    assert vote(reads, min_support=2).number is None
    assert vote(reads + [Reading(7, 0.8, "7")], min_support=2).number == 7
