"""Face ID, opt-in and enrolled-only.

Matching runs only against a store of people someone enrolled with consent
(a player themself, or a guardian for a minor), scoped to one team or group.
It never names anyone who isn't enrolled: faces that match nobody get no
label, and no face data from a game is written anywhere (only the enrolled
person's id and the match score).

Models: InsightFace buffalo_l (SCRFD-10GF detector, ArcFace ResNet-50 on
WebFace600K), run directly with onnxruntime. InsightFace's models are for
**non-commercial research only**; they download on first use to
~/.insightface/models/buffalo_l and are never committed.

Faces are a seeding and confirmation signal: helmets hide most faces during
play, and recognition gets unreliable below ~30 px faces. They help on the
bench, in huddles, before and after games, and in pickup games without jerseys.
"""

from __future__ import annotations

import json
import os
import zipfile
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import cv2
import numpy as np

MODEL_DIR = Path(os.environ.get("SIDELINE_FACE_MODELS", "~/.insightface/models/buffalo_l")).expanduser()
MODEL_URL = "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip"
DETECTOR, EMBEDDER = "det_10g.onnx", "w600k_r50.onnx"

MIN_FACE_PX = 24            # face width in the original frame; smaller faces don't embed reliably
MIN_DET_SCORE = 0.6
# ArcFace cosine similarity. Provisional (no labeled game faces yet): typical
# same-person scores for this model are 0.4–0.8, different people under 0.3.
MATCH_MIN = 0.40
MATCH_MARGIN = 0.08         # best enrolled person must beat the runner-up by this much

# 112×112 ArcFace landmark template: eyes, nose, mouth corners.
ARCFACE_DST = np.array([[38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366],
                        [41.5493, 92.3655], [70.7299, 92.2041]], np.float32)


# MARK: Models

def ensure_models(log=print) -> Path:
    """Downloads buffalo_l (~280 MB zip) once and keeps only the two models used."""
    if (MODEL_DIR / DETECTOR).exists() and (MODEL_DIR / EMBEDDER).exists():
        return MODEL_DIR
    import urllib.request

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    zpath = MODEL_DIR / "buffalo_l.zip"
    log(f"downloading InsightFace buffalo_l (~280 MB, non-commercial license) to {MODEL_DIR}…")
    urllib.request.urlretrieve(MODEL_URL, zpath)
    with zipfile.ZipFile(zpath) as z:
        for name in (DETECTOR, EMBEDDER):
            member = next(m for m in z.namelist() if m.endswith(name))
            (MODEL_DIR / name).write_bytes(z.read(member))
    zpath.unlink()
    return MODEL_DIR


@dataclass(frozen=True)
class Face:
    box: tuple[float, float, float, float]     # in the image given to detect()
    score: float
    kps: np.ndarray                             # 5×2 landmarks

    @property
    def width(self) -> float:
        return self.box[2] - self.box[0]


def distance2bbox(centers: np.ndarray, d: np.ndarray) -> np.ndarray:
    return np.stack([centers[:, 0] - d[:, 0], centers[:, 1] - d[:, 1],
                     centers[:, 0] + d[:, 2], centers[:, 1] + d[:, 3]], axis=-1)


def distance2kps(centers: np.ndarray, d: np.ndarray) -> np.ndarray:
    xs = centers[:, 0:1] + d[:, 0::2]
    ys = centers[:, 1:2] + d[:, 1::2]
    return np.stack([xs, ys], axis=-1)


def nms(boxes: np.ndarray, scores: np.ndarray, iou: float = 0.4) -> list[int]:
    order = scores.argsort()[::-1]
    keep = []
    while order.size:
        i = order[0]
        keep.append(int(i))
        xx1 = np.maximum(boxes[i, 0], boxes[order[1:], 0])
        yy1 = np.maximum(boxes[i, 1], boxes[order[1:], 1])
        xx2 = np.minimum(boxes[i, 2], boxes[order[1:], 2])
        yy2 = np.minimum(boxes[i, 3], boxes[order[1:], 3])
        inter = np.clip(xx2 - xx1, 0, None) * np.clip(yy2 - yy1, 0, None)
        area = lambda b: (b[..., 2] - b[..., 0]) * (b[..., 3] - b[..., 1])
        order = order[1:][inter / (area(boxes[i]) + area(boxes[order[1:]]) - inter + 1e-9) <= iou]
    return keep


def align(image_bgr: np.ndarray, kps: np.ndarray) -> np.ndarray:
    """112×112 face crop with eyes, nose and mouth on the ArcFace template."""
    m, _ = cv2.estimateAffinePartial2D(kps.astype(np.float32), ARCFACE_DST, method=cv2.LMEDS)
    return cv2.warpAffine(image_bgr, m, (112, 112), borderValue=0.0)


class FaceModel:
    """SCRFD detection + ArcFace embedding (InsightFace buffalo_l)."""

    STRIDES = (8, 16, 32)
    ANCHORS = 2

    def __init__(self, model_dir: Path | None = None, detect_only: bool = False):
        import onnxruntime as ort

        d = model_dir or ensure_models()
        providers = ["CPUExecutionProvider"]
        opts = ort.SessionOptions()
        opts.log_severity_level = 3      # the detector runs at other sizes than its 640 px metadata; skip those notes
        self.det = ort.InferenceSession(str(d / DETECTOR), opts, providers=providers)
        self.emb = None if detect_only else ort.InferenceSession(str(d / EMBEDDER), opts, providers=providers)
        self._centers: dict[tuple[int, int, int], np.ndarray] = {}

    def detect(self, image_bgr: np.ndarray, size: int = 320, threshold: float = 0.5) -> list[Face]:
        """Faces in an image, letterboxed into a size×size detector input
        (small images are scaled up, which helps distant faces)."""
        h, w = image_bgr.shape[:2]
        scale = size / max(h, w)
        resized = cv2.resize(image_bgr, (max(1, int(round(w * scale))), max(1, int(round(h * scale)))))
        canvas = np.zeros((size, size, 3), np.uint8)
        canvas[:resized.shape[0], :resized.shape[1]] = resized
        blob = cv2.dnn.blobFromImage(canvas, 1.0 / 128, (size, size), (127.5, 127.5, 127.5), swapRB=True)
        outs = self.det.run(None, {self.det.get_inputs()[0].name: blob})
        boxes, scores, kpss = [], [], []
        n = len(self.STRIDES)
        for k, stride in enumerate(self.STRIDES):
            s, b, p = outs[k].ravel(), outs[k + n] * stride, outs[k + 2 * n] * stride
            gh, gw = size // stride, size // stride
            key = (gh, gw, stride)
            if key not in self._centers:
                c = np.stack(np.mgrid[:gh, :gw][::-1], axis=-1).astype(np.float32).reshape(-1, 2) * stride
                self._centers[key] = np.repeat(c, self.ANCHORS, axis=0)
            centers = self._centers[key]
            keep = np.where(s >= threshold)[0]
            boxes.append(distance2bbox(centers[keep], b[keep]))
            scores.append(s[keep])
            kpss.append(distance2kps(centers[keep], p[keep]))
        boxes, scores, kpss = np.concatenate(boxes), np.concatenate(scores), np.concatenate(kpss)
        if not len(scores):
            return []
        return [Face(tuple(float(v) for v in boxes[i] / scale), float(scores[i]), kpss[i] / scale)
                for i in nms(boxes, scores)]

    def embed(self, image_bgr: np.ndarray, face: Face) -> np.ndarray:
        blob = cv2.dnn.blobFromImage(align(image_bgr, face.kps), 1.0 / 127.5, (112, 112), (127.5, 127.5, 127.5),
                                     swapRB=True)
        v = self.emb.run(None, {self.emb.get_inputs()[0].name: blob})[0][0]
        return v / np.linalg.norm(v)


def head_region(person_bgr: np.ndarray) -> tuple[np.ndarray, int, int]:
    """Top of a person box, where the face is (plus margin): (image, x0, y0)."""
    h, w = person_bgr.shape[:2]
    y1, x0, x1 = int(h * 0.4), int(w * 0.05), int(w * 0.95)
    return person_bgr[:y1, x0:x1], x0, 0


def person_face(model: FaceModel, person_bgr: np.ndarray) -> Face | None:
    """The person's own face in their box: the most confident one in the
    head region that is big enough to identify."""
    head, x0, y0 = head_region(person_bgr)
    if head.shape[0] < 12 or head.shape[1] < 12:
        return None
    faces = [f for f in model.detect(head) if f.score >= MIN_DET_SCORE and f.width >= MIN_FACE_PX]
    if not faces:
        return None
    f = max(faces, key=lambda f: f.score * f.width)
    shift = np.array([x0, y0], np.float32)
    b = f.box
    return Face((b[0] + x0, b[1] + y0, b[2] + x0, b[3] + y0), f.score, f.kps + shift)


# MARK: Enrollment store (consented people only)

CONSENT_FIELDS = ("name", "consent_by", "relationship", "date", "scope")


class ConsentError(ValueError):
    pass


def check_consent(c: dict) -> dict:
    """A person may be enrolled only with a consent record: who agreed, as
    themself or as a guardian, when, and for which team or group."""
    missing = [k for k in CONSENT_FIELDS if not str(c.get(k, "")).strip()]
    if missing:
        raise ConsentError(f"consent record is missing {', '.join(missing)}")
    if c["relationship"] not in ("self", "guardian"):
        raise ConsentError("relationship must be 'self' or 'guardian'")
    if c.get("minor") and c["relationship"] != "guardian":
        raise ConsentError("a minor must be enrolled by a guardian")
    return c


@dataclass
class Person:
    id: str
    name: str
    consent: dict
    embeddings: list[list[float]]
    jersey: int | None = None
    team: str | None = None

    def to_json(self) -> dict:
        return {"id": self.id, "name": self.name, "jersey": self.jersey, "team": self.team,
                "consent": self.consent, "embeddings": self.embeddings}


@dataclass
class FaceStore:
    """One team's or group's enrolled people. Matching never crosses stores."""
    scope: str
    people: list[Person] = field(default_factory=list)

    @classmethod
    def load(cls, path: Path) -> "FaceStore":
        d = json.loads(Path(path).read_text())
        if d.get("format") != "sideline-faces":
            raise ValueError(f"{path} is not a face store")
        return cls(d["scope"], [Person(**p) for p in d["people"]])

    def save(self, path: Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps({"format": "sideline-faces", "version": 1, "scope": self.scope,
                                   "people": [p.to_json() for p in self.people]}))
        os.chmod(tmp, 0o600)
        tmp.replace(path)

    def enroll(self, consent: dict, embeddings: list[np.ndarray], jersey: int | None = None,
               team: str | None = None) -> Person:
        check_consent(consent)
        if consent["scope"] != self.scope:
            raise ConsentError(f"consent is for '{consent['scope']}', this store is '{self.scope}'")
        if not embeddings:
            raise ValueError(f"no usable face found for {consent['name']}")
        pid = slug_id(consent["name"])
        self.forget(pid)
        p = Person(pid, consent["name"], consent, [[round(float(x), 5) for x in e] for e in embeddings], jersey, team)
        self.people.append(p)
        return p

    def forget(self, person: str) -> bool:
        """Deletes a person's face data (consent withdrawn, or the season ended)."""
        before = len(self.people)
        self.people = [p for p in self.people if p.id != person and p.name != person]
        return len(self.people) < before

    def match(self, embeddings: list[np.ndarray]) -> dict | None:
        """Best enrolled person for a track's faces, or None. Each face votes
        with its best similarity to each person's enrollment photos; the
        track's score for a person is the median over its faces."""
        if not embeddings or not self.people:
            return None
        E = np.stack(embeddings)
        scores = []
        for p in self.people:
            P = np.asarray(p.embeddings, np.float32)
            scores.append(float(np.median((E @ P.T).max(axis=1))))
        order = np.argsort(scores)[::-1]
        best = scores[order[0]]
        second = scores[order[1]] if len(order) > 1 else -1.0
        if best < MATCH_MIN or best - second < MATCH_MARGIN:
            return None
        p = self.people[order[0]]
        return {"person": p.id, "name": p.name, "jersey": p.jersey, "team": p.team,
                "similarity": round(best, 3), "margin": round(best - max(second, 0.0), 3)}


def slug_id(name: str) -> str:
    return "-".join("".join(ch.lower() if ch.isalnum() else " " for ch in name).split()) or "person"


def enroll_folder(store: FaceStore, folder: Path, model: FaceModel, log=print) -> Person:
    """folder/consent.json + photos. Each photo should show the person's face;
    the largest confident face in each photo is used."""
    consent = json.loads((folder / "consent.json").read_text())
    check_consent(consent)
    embs = []
    for img_path in sorted(folder.iterdir()):
        if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".heic"):
            continue
        img = cv2.imread(str(img_path))
        if img is None:
            log(f"  skip {img_path.name}: can't read")
            continue
        faces = [f for f in model.detect(img, size=640) if f.score >= MIN_DET_SCORE and f.width >= MIN_FACE_PX]
        if not faces:
            log(f"  skip {img_path.name}: no clear face")
            continue
        embs.append(model.embed(img, max(faces, key=lambda f: f.width)))
    consent = consent | {"enrolled": date.today().isoformat(), "photos": len(embs)}
    return store.enroll(consent, embs, consent.get("jersey"), consent.get("team"))


# MARK: Per-track identification

def identify_track(model: FaceModel, store: FaceStore, crops_bgr: list[np.ndarray]) -> dict:
    """Faces in a track's crops matched to the store. Returns the match (or
    person None) and how many usable faces were seen; face data is not kept."""
    embs = []
    for c in crops_bgr:
        if c is None or not c.size:
            continue
        f = person_face(model, c)
        if f is not None:
            embs.append(model.embed(c, f))
    m = store.match(embs) if embs else None
    return (m or {"person": None}) | {"faces": len(embs)}


class FaceID:
    """What the pipeline uses: a store plus the models, and the per-source
    switch (the plan requires face ID to be switchable per capture source)."""

    def __init__(self, store_path: Path, skip_sources: tuple[str, ...] = (), log=print):
        self.store = FaceStore.load(store_path)
        self.model = FaceModel()
        self.skip_sources = set(skip_sources)
        self.log = log
        self._warned = False

    def allowed(self, source: str) -> bool:
        if source in self.skip_sources:
            return False
        if source == "glasses" and not self._warned:
            self._warned = True
            self.log("note: matching faces in glasses footage; Meta's Wearables policy requires Meta's approval "
                     "for face identification from glasses (use --no-faces-on glasses to switch it off)")
        return True

    def identify(self, crops_bgr: list[np.ndarray]) -> dict:
        return identify_track(self.model, self.store, crops_bgr)


def source_of(asset: str) -> str:
    """Capture source from the app's asset names (glasses-NN.mov, phone-…)."""
    a = asset.lower()
    return "glasses" if a.startswith("glasses") else ("phone" if a.startswith("phone") else "other")
