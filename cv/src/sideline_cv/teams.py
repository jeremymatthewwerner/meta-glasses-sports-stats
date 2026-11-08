"""Team assignment from jersey colors.

1. Each track gets a jersey color: the dominant color (largest k-means
   cluster) of the central torso in each of its kept crops, median across
   crops. Working in CIE Lab makes distances roughly perceptual.
2. All tracks of a game are clustered into two colors (A and B).
3. Clusters become home/away using the jersey numbers already matched to
   the voice calls: if the track read as #22 is in A and the caller said
   "home #22", A is home. Without evidence, clusters stay A/B.

Officials and sideline people end up in whichever cluster is nearer;
tracks far from both centers, or about equally near, are marked unsure.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

import cv2
import numpy as np

from .jersey import torso


def dominant_color(crop_bgr: np.ndarray, k: int = 3) -> np.ndarray | None:
    """Lab color (L 0–100, a/b about −128..127) of the biggest color region in
    the central torso, or None for crops too small to judge."""
    t = torso(crop_bgr)
    h, w = t.shape[:2]
    t = t[:, int(w * 0.2):int(w * 0.8)]          # stay off arms and background
    if t.shape[0] < 6 or t.shape[1] < 6:
        return None
    small = cv2.resize(t, (24, 32), interpolation=cv2.INTER_AREA)
    lab = cv2.cvtColor(small, cv2.COLOR_BGR2LAB).reshape(-1, 3).astype(np.float32)
    k = min(k, len(np.unique(lab, axis=0)))
    if k < 2:
        center = lab[0]
    else:
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 0.5)
        _, labels, centers = cv2.kmeans(lab, k, None, criteria, 3, cv2.KMEANS_PP_CENTERS)
        center = centers[np.bincount(labels.ravel()).argmax()]
    return opencv_lab_to_cie(center)


def opencv_lab_to_cie(lab8: np.ndarray) -> np.ndarray:
    """OpenCV 8-bit Lab (L*255/100, a+128, b+128) → CIE Lab."""
    L, a, b = (float(v) for v in lab8)
    return np.array([L * 100.0 / 255.0, a - 128.0, b - 128.0])


def track_color(crops_bgr: list[np.ndarray]) -> np.ndarray | None:
    colors = [c for c in (dominant_color(x) for x in crops_bgr) if c is not None]
    if not colors:
        return None
    return np.median(np.stack(colors), axis=0)


def lab_to_hex(lab: np.ndarray) -> str:
    L, a, b = lab
    px = np.uint8([[[np.clip(L * 255 / 100, 0, 255), np.clip(a + 128, 0, 255), np.clip(b + 128, 0, 255)]]])
    bgr = cv2.cvtColor(px, cv2.COLOR_LAB2BGR)[0, 0]
    return "#{:02x}{:02x}{:02x}".format(int(bgr[2]), int(bgr[1]), int(bgr[0]))


@dataclass
class TeamModel:
    centers: dict[str, np.ndarray]          # "A"/"B" → Lab
    sides: dict[str, str]                   # "A"/"B" → "home"/"away" (when known)
    evidence: dict[str, Counter]            # cluster → Counter of called sides it matched

    def assign(self, lab: np.ndarray | None, max_distance: float = 45.0, margin: float = 0.75) -> dict:
        """Cluster, side and confidence for one track color."""
        if lab is None or not self.centers:
            return {"cluster": None, "team": None, "unsure": True}
        d = {k: float(np.linalg.norm(lab - c)) for k, c in self.centers.items()}
        best, other = sorted(d, key=d.get)[:2] if len(d) > 1 else (next(iter(d)), None)
        unsure = d[best] > max_distance or (other is not None and d[best] > margin * d[other])
        return {"cluster": best, "team": self.sides.get(best), "distance": round(d[best], 1), "unsure": unsure}

    def to_json(self) -> dict:
        return {k: {"color": lab_to_hex(c), "lab": [round(float(v), 1) for v in c], "team": self.sides.get(k),
                    "evidence": dict(self.evidence.get(k, {}))} for k, c in self.centers.items()}


def cluster_two(colors: list[np.ndarray], weights: list[float] | None = None) -> dict[str, np.ndarray]:
    """Two team colors from many track colors (weighted by track length)."""
    if len(colors) < 2:
        return {"A": colors[0]} if colors else {}
    X = np.stack(colors).astype(np.float32)
    w = np.asarray(weights if weights is not None else [1.0] * len(colors), np.float32)
    # Weighted k-means by repeating rows in proportion to weight (bounded).
    reps = np.clip(np.round(w / w.max() * 5), 1, 5).astype(int)
    Xr = np.repeat(X, reps, axis=0)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.1)
    _, _, centers = cv2.kmeans(Xr, 2, None, criteria, 8, cv2.KMEANS_PP_CENTERS)
    a, b = centers
    if np.linalg.norm(a - b) < 12:          # basically one color on screen
        return {"A": (a + b) / 2}
    # Stable naming: A is the lighter jersey.
    return {"A": a, "B": b} if a[0] >= b[0] else {"A": b, "B": a}


def map_sides(centers: dict[str, np.ndarray], number_matches: list[tuple[np.ndarray | None, str]]
              ) -> tuple[dict[str, str], dict[str, Counter]]:
    """number_matches: (track color, called side) for tracks whose read
    number matched a called player. Majority vote per cluster; the other
    cluster gets the other side when only one cluster has evidence."""
    model = TeamModel(centers, {}, {})
    evidence: dict[str, Counter] = {k: Counter() for k in centers}
    for lab, side in number_matches:
        a = model.assign(lab)
        if a["cluster"] is not None and not a["unsure"]:
            evidence[a["cluster"]][side] += 1
    sides: dict[str, str] = {}
    for k, c in evidence.items():
        if c:
            top, n = c.most_common(1)[0]
            if n > sum(c.values()) - n:
                sides[k] = top
    if len(centers) == 2 and len(sides) == 1:
        (k, side), = sides.items()
        other = "B" if k == "A" else "A"
        sides[other] = "away" if side == "home" else "home"
    if len(set(sides.values())) < len(sides):  # both clusters voted the same side: don't trust it
        sides = {}
    return sides, evidence
