"""Who is on screen: player, official (referee) or sideline (coach,
spectator). Officials and sideline people otherwise get jersey numbers read
off their stripes and jackets ("1", "11", "0"), pull a team's color, and
count as players.

Zero-shot CLIP (OpenAI ViT-B/32, MIT; ~600 MB from Hugging Face on first
use): each kept crop of a track is compared with three text prompts and the
probabilities are averaged over the crops.

Measured 2026-11-08 on 184 hand-labeled tracks from four youth games (the
hard cases: striped-looking players and every referee found): a track is
an official when the referee probability is ≥ 0.5, or ≥ 0.25 while the
player probability is ≤ 0.1 (gray-striped refs CLIP splits between
"referee" and "coach"). That caught 82 of 93 officials (88%) and flagged 9
of 91 players, mostly blurry or partly covered; a referee showing the
number on his back can still pass as a player. A hand-built stripe detector
reached ~35% of officials at a similar error rate, so it was dropped; a
linear probe on these labels didn't carry over between games. "Sideline"
is only trusted when sure (≥ 0.85): below that it's mostly players in odd
poses.
"""

from __future__ import annotations

import numpy as np

PROMPTS = {
    "official": "a photo of a referee wearing a black and white striped shirt",
    "player": "a photo of a football player wearing a helmet and a numbered jersey",
    "sideline": "a photo of a coach or spectator in regular clothes",
}
OFFICIAL_MIN = 0.5
OFFICIAL_MIN_IF_NOT_PLAYER = 0.25     # … when the player probability is at most:
NOT_PLAYER_MAX = 0.1
SIDELINE_MIN = 0.85
MODEL_ID = "openai/clip-vit-base-patch32"


def decide(probs: dict[str, float]) -> str:
    """A track's role from its averaged prompt probabilities."""
    official, player = probs.get("official", 0.0), probs.get("player", 1.0)
    if official >= OFFICIAL_MIN or (official >= OFFICIAL_MIN_IF_NOT_PLAYER and player <= NOT_PLAYER_MAX):
        return "official"
    if probs.get("sideline", 0.0) >= SIDELINE_MIN:
        return "sideline"
    return "player"


def is_player(track: dict) -> bool:
    """Tracks without a role (older outputs, or roles turned off) count as players."""
    return (track.get("role") or {}).get("role", "player") == "player"


class RoleClassifier:
    def __init__(self, device: str | None = None):
        import torch
        from transformers import CLIPModel, CLIPProcessor

        self.torch = torch
        self.device = device or ("mps" if torch.backends.mps.is_available() else "cpu")
        self.model = CLIPModel.from_pretrained(MODEL_ID, use_safetensors=True).eval().to(self.device)
        self.processor = CLIPProcessor.from_pretrained(MODEL_ID)
        self.labels = list(PROMPTS)
        with torch.no_grad():
            text = self.processor(text=list(PROMPTS.values()), return_tensors="pt", padding=True).to(self.device)
            self.text = self._unit(self.model.get_text_features(**text))

    @staticmethod
    def _unit(x):
        x = getattr(x, "pooler_output", x)        # transformers ≥ 5 returns an output object
        return x / x.norm(dim=-1, keepdim=True)

    def probs(self, crops_bgr: list[np.ndarray]) -> dict[str, float] | None:
        from PIL import Image

        ims = [Image.fromarray(np.ascontiguousarray(c[:, :, ::-1])) for c in crops_bgr
               if c is not None and c.size and min(c.shape[:2]) >= 8]
        if not ims:
            return None
        with self.torch.no_grad():
            feats = self._unit(self.model.get_image_features(**self.processor(images=ims, return_tensors="pt").to(self.device)))
            p = (100.0 * feats @ self.text.T).softmax(-1).mean(0).cpu().numpy()
        return {k: round(float(v), 3) for k, v in zip(self.labels, p)}

    def classify(self, crops_bgr: list[np.ndarray]) -> dict:
        p = self.probs(crops_bgr)
        return {"role": "player", "p": None} if p is None else {"role": decide(p), "p": p}
