import json
import os
import stat
from pathlib import Path

import numpy as np
import pytest

from sideline_cv.faces import (ConsentError, FaceID, FaceStore, check_consent, distance2bbox, distance2kps, nms,
                               source_of)
from sideline_cv.game import CalledPlayer
from sideline_cv.jersey import match_play

CONSENT = {"name": "Sam Rivera", "consent_by": "Alex Rivera", "relationship": "guardian", "minor": True,
           "date": "2026-11-08", "scope": "Eagles 11U"}


def unit(v):
    v = np.asarray(v, np.float32)
    return v / np.linalg.norm(v)


def near(v, rng, noise=0.35):
    return unit(v + rng.normal(0, noise / np.sqrt(len(v)), len(v)))


def test_consent_is_required_and_minors_need_a_guardian():
    assert check_consent(dict(CONSENT))
    with pytest.raises(ConsentError, match="consent_by"):
        check_consent(CONSENT | {"consent_by": ""})
    with pytest.raises(ConsentError, match="guardian"):
        check_consent(CONSENT | {"relationship": "self"})          # a minor can't self-consent
    with pytest.raises(ConsentError):
        check_consent(CONSENT | {"relationship": "friend"})
    assert check_consent(CONSENT | {"minor": False, "relationship": "self"})


def test_store_enrolls_only_in_scope_and_forgets(tmp_path):
    rng = np.random.default_rng(0)
    store = FaceStore("Eagles 11U")
    sam = unit(rng.normal(size=512))
    p = store.enroll(dict(CONSENT), [near(sam, rng) for _ in range(4)], jersey=22)
    assert p.id == "sam-rivera" and p.jersey == 22 and len(p.embeddings) == 4
    with pytest.raises(ConsentError, match="Hawks"):
        store.enroll(CONSENT | {"scope": "Hawks 11U"}, [sam])        # consent is per team or group
    with pytest.raises(ValueError):
        store.enroll(dict(CONSENT), [])                              # no usable face
    path = tmp_path / "eagles.faces.json"
    store.save(path)
    assert stat.S_IMODE(os.stat(path).st_mode) == 0o600               # face data is private to the owner
    again = FaceStore.load(path)
    assert [x.name for x in again.people] == ["Sam Rivera"] and again.people[0].consent["consent_by"] == "Alex Rivera"
    assert again.forget("sam-rivera") and not again.people
    assert not again.forget("nobody")


def test_match_is_closed_set_with_a_margin():
    rng = np.random.default_rng(1)
    store = FaceStore("Eagles 11U")
    a, b = unit(rng.normal(size=512)), unit(rng.normal(size=512))
    store.enroll(CONSENT, [near(a, rng) for _ in range(5)], jersey=22)
    store.enroll(CONSENT | {"name": "Jo Park"}, [near(b, rng) for _ in range(5)], jersey=54)
    m = store.match([near(a, rng) for _ in range(3)])
    assert m["person"] == "sam-rivera" and m["jersey"] == 22 and m["similarity"] > 0.4
    # A stranger matches nobody: there is no "closest enrolled person" answer.
    assert store.match([unit(rng.normal(size=512)) for _ in range(3)]) is None
    # Halfway between two enrolled people is too close to call.
    assert store.match([unit(a + b)]) is None
    assert store.match([]) is None


def test_face_jersey_fills_in_and_confirms_numbers():
    called = [CalledPlayer("home", 22, "ballCarrier"), CalledPlayer("away", 54, "tacklers")]
    tracks = [
        {"track_id": 1, "frames": 30, "jersey": {"number": None, "confidence": 0.0},
         "face": {"person": "sam-rivera", "jersey": 22, "similarity": 0.61, "faces": 3}},
        {"track_id": 2, "frames": 30, "jersey": {"number": 54, "confidence": 0.9},
         "face": {"person": "jo-park", "jersey": 54, "similarity": 0.55, "faces": 2}},
        {"track_id": 3, "frames": 30, "jersey": {"number": None, "confidence": 0.0}, "face": {"person": None, "faces": 2}},
    ]
    m = {x["jersey"]: x for x in match_play(called, tracks)["matched"]}
    assert m[22]["track_id"] == 1 and m[22]["via"] == "face" and m[22]["person"] == "sam-rivera"
    assert m[54]["track_id"] == 2 and m[54]["face_confirmed"] and "via" not in m[54]


def test_scrfd_decoding_helpers():
    centers = np.array([[16.0, 16.0]])
    assert distance2bbox(centers, np.array([[4.0, 5.0, 6.0, 7.0]])).tolist() == [[12.0, 11.0, 22.0, 23.0]]
    k = distance2kps(centers, np.array([[1.0, 2.0] * 5]))
    assert k.shape == (1, 5, 2) and k[0, 0].tolist() == [17.0, 18.0]
    boxes = np.array([[0, 0, 10, 10], [1, 1, 11, 11], [50, 50, 60, 60]], float)
    assert nms(boxes, np.array([0.9, 0.8, 0.7])) == [0, 2]


def test_source_switch():
    assert source_of("glasses-03.mov") == "glasses" and source_of("phone-1.mov") == "phone"
    assert source_of("veo-match.mp4") == "other"
    fid = FaceID.__new__(FaceID)               # no models needed for the switch
    fid.skip_sources, fid._warned, notes = {"phone"}, False, []
    fid.log = notes.append
    assert not fid.allowed("phone")
    assert fid.allowed("glasses") and fid.allowed("glasses") and len(notes) == 1   # warns once
    assert "Meta" in notes[0]


SAMPLE = Path(__file__).resolve().parents[1] / "samples" / "football" / "sweethome-vets-11u-a.mp4"


@pytest.mark.skipif(not os.environ.get("SIDELINE_CV_MODELS") or not SAMPLE.exists(),
                    reason="needs InsightFace weights and the local football sample")
def test_detector_finds_faces_in_helmets():
    """Detection only (no embeddings): kids' faces inside helmets in a real frame."""
    import cv2

    from sideline_cv.faces import FaceModel

    cap = cv2.VideoCapture(str(SAMPLE))
    cap.set(cv2.CAP_PROP_POS_MSEC, 20_000)
    ok, frame = cap.read()
    assert ok
    faces = FaceModel(detect_only=True).detect(frame, size=640, threshold=0.4)
    assert len(faces) >= 2 and all(f.kps.shape == (5, 2) for f in faces)


def test_pipeline_records_matches_but_no_face_data(tmp_path):
    import cv2
    import supervision as sv

    from sideline_cv.game import Clip
    from sideline_cv.pipeline import process_clip
    from test_teams import RED, player

    video = tmp_path / "phone-01.mov"
    out = cv2.VideoWriter(str(video), cv2.VideoWriter_fourcc(*"mp4v"), 30, (320, 240))
    for i in range(60):
        f = np.zeros((240, 320, 3), np.uint8)
        f[:] = (70, 140, 70)
        f[40:200, 40 + i:90 + i] = player(RED, 50, 160)
        out.write(f)
    out.release()

    class Detector:
        def __call__(self, frame):
            ys, xs = np.nonzero(np.abs(frame.astype(int) - RED).sum(axis=2) < 40)
            return sv.Detections(xyxy=np.array([[xs.min() - 4, ys.min() - 20, xs.max() + 4, ys.max() + 60]], float),
                                 confidence=np.array([0.9]), class_id=np.array([1]))

    class Faces:
        def __init__(self, skip):
            self.skip = skip

        def allowed(self, source):
            return source not in self.skip

        def identify(self, crops):
            return {"person": "sam-rivera", "name": "Sam Rivera", "jersey": 22, "similarity": 0.6, "margin": 0.3,
                    "faces": len(crops)}

    _, _, tracks = process_clip(video, Clip(video.name, 0, 2), tmp_path / "a", Detector(), 5,
                                faces=Faces(set()), source="phone")
    assert tracks and tracks[0]["face"]["person"] == "sam-rivera"
    saved = (tmp_path / "a" / "tracks.json").read_text()
    assert "embedding" not in saved                       # only who and how sure, never face vectors
    _, _, tracks = process_clip(video, Clip(video.name, 0, 2), tmp_path / "b", Detector(), 5,
                                faces=Faces({"phone"}), source="phone")
    assert "face" not in tracks[0]                         # switched off for this source
