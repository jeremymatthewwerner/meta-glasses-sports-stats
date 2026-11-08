"""Reads what the iOS app saves for a game: the scorebook JSON (plays, with
clip references into the game video) and the game folder (video files).

On the phone (Files → On My iPhone → Sideline Probe → games):

    games/<game-id>.json               the scorebook (FootballGame, Swift Codable)
    games/<game-id>/recording.json     the video files of the game
    games/<game-id>/glasses-01.mov     HEVC 504x896 @15 from the glasses
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

# Play fields that name a player, and which side they belong to relative to
# the offense (the team in possession at the snap; the kicking team on kicks).
_OFFENSE_FIELDS = ("ballCarrier", "passer", "receiver", "fumbledBy", "kicker")
_DEFENSE_FIELDS = ("interceptedBy", "forcedFumbleBy", "returner")
_DEFENSE_LISTS = ("tacklers", "sackers")


@dataclass(frozen=True)
class Clip:
    asset: str          # file name inside the game folder, e.g. "glasses-01.mov"
    start: float        # seconds into that file
    end: float

    @property
    def duration(self) -> float:
        return max(0.0, self.end - self.start)


@dataclass(frozen=True)
class CalledPlayer:
    team: str           # "home" / "away"
    jersey: int
    role: str           # the play field it came from, e.g. "ballCarrier"


@dataclass
class Play:
    id: str
    index: int          # position in the game's event log
    kind: str | None
    transcript: str | None
    status: str         # proposed / confirmed / rejected
    offense: str
    clip: Clip | None
    players: list[CalledPlayer] = field(default_factory=list)

    @property
    def label(self) -> str:
        return self.transcript or self.kind or self.id


@dataclass
class Game:
    id: str
    home: str
    away: str
    plays: list[Play]
    folder: Path        # games/<id>/

    def clip_path(self, clip: Clip) -> Path:
        return self.folder / clip.asset

    @property
    def plays_with_clips(self) -> list[Play]:
        """Plays that still count and have video."""
        return [p for p in self.plays if p.clip and p.status != "rejected"]


def _opponent(side: str) -> str:
    return "away" if side == "home" else "home"


def called_players(play: dict, offense: str) -> list[CalledPlayer]:
    """Every jersey number the caller named, with its team."""
    out: list[CalledPlayer] = []
    defense = _opponent(offense)

    def add(team: str, number, role: str) -> None:
        if isinstance(number, int):
            item = CalledPlayer(team, number, role)
            if item not in out:
                out.append(item)

    for f in _OFFENSE_FIELDS:
        add(offense, play.get(f), f)
    for f in _DEFENSE_FIELDS:
        add(defense, play.get(f), f)
    for f in _DEFENSE_LISTS:
        for n in play.get(f) or []:
            add(defense, n, f)
    if (rec := play.get("fumbleRecoveredBy")) is not None:
        add(defense if play.get("fumbleLost") else offense, rec, "fumbleRecoveredBy")
    if (pen := play.get("penalty")) and pen.get("player") is not None:
        add(offense if pen.get("on") == "offense" else defense, pen["player"], "penalty")
    return out


def load_game(game_json: Path) -> Game:
    data = json.loads(game_json.read_text())
    game_id = data["id"]
    plays: list[Play] = []
    for i, e in enumerate(data.get("events", [])):
        raw = e.get("play")
        if raw is None:
            continue          # situation corrections ("third and 4") have no video
        refs = e.get("videoRefs") or []
        clip = Clip(refs[0]["assetID"], float(refs[0]["start"]), float(refs[0]["end"])) if refs else None
        offense = e.get("offense", "home")
        plays.append(Play(
            id=e["id"], index=i, kind=raw.get("kind"), transcript=e.get("transcript"),
            status=e.get("status", "proposed"), offense=offense, clip=clip,
            players=called_players(raw, offense),
        ))
    return Game(
        id=game_id,
        home=data.get("home", {}).get("name", "Home"),
        away=data.get("away", {}).get("name", "Away"),
        plays=plays,
        folder=game_json.parent / game_id,
    )


def find_game(games_dir: Path, game: str = "latest") -> Path:
    """The scorebook JSON for `game` (an id or id prefix), or the newest one."""
    candidates = [p for p in games_dir.glob("*.json") if not p.name.endswith("-utterances.json")]
    if not candidates:
        raise FileNotFoundError(f"no game JSON in {games_dir}")
    if game == "latest":
        return max(candidates, key=lambda p: p.stat().st_mtime)
    matches = [p for p in candidates if p.stem.lower().startswith(game.lower())]
    if len(matches) != 1:
        raise FileNotFoundError(f"{len(matches)} games match {game!r} in {games_dir}")
    return matches[0]
