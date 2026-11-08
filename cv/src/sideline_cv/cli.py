"""sideline-cv command line.

    sideline-cv game  --games ~/path/to/games [--game latest|<id>] [--out out]
    sideline-cv video file.mp4 [--start 0 --end 20] [--out out]
    sideline-cv sim-games          # prints the iOS Simulator's games folder
"""

from __future__ import annotations

import argparse
import glob
import os
import sys
from pathlib import Path


def _detector(args):
    from .pipeline import PersonDetector

    print(f"loading RF-DETR {args.model} (first run downloads weights)…", file=sys.stderr)
    return PersonDetector(size=args.model, threshold=args.threshold)


def cmd_game(args) -> int:
    from .game import find_game, load_game
    from .pipeline import process_game

    game = load_game(find_game(Path(args.games).expanduser(), args.game))
    out = process_game(game, Path(args.out), _detector(args), sample_fps=args.fps)
    print(f"report: {out / 'report.md'}")
    return 0


def cmd_video(args) -> int:
    from .game import Clip
    from .pipeline import process_clip, slug
    from .video import probe

    path = Path(args.file).expanduser()
    info = probe(path)
    end = args.end if args.end is not None else info.duration
    out = Path(args.out) / slug(path.stem)
    n, mean_people, tracks = process_clip(path, Clip(path.name, args.start, end), out, _detector(args), args.fps)
    print(f"{n} frames, {mean_people:.1f} people/frame, {len(tracks)} track(s) → {out}")
    return 0


def sim_games_dirs() -> list[str]:
    pattern = os.path.expanduser(
        "~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/games")
    return sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)


def cmd_sim_games(_args) -> int:
    dirs = sim_games_dirs()
    if not dirs:
        print("no simulator games folder found", file=sys.stderr)
        return 1
    print(dirs[0])
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="sideline-cv", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--out", default="out", help="output folder (default: ./out)")
        p.add_argument("--fps", type=float, default=5.0, help="frames sampled per second (default 5)")
        p.add_argument("--model", default="medium", choices=["nano", "small", "medium", "base", "large"])
        p.add_argument("--threshold", type=float, default=0.25, help="person detection threshold (default 0.25)")

    g = sub.add_parser("game", help="every called play with video in a game")
    g.add_argument("--games", required=True, help="the app's games folder (copied from the phone)")
    g.add_argument("--game", default="latest", help="game id (or prefix); default: newest")
    common(g)
    g.set_defaults(func=cmd_game)

    v = sub.add_parser("video", help="one video file (or a time range of it)")
    v.add_argument("file")
    v.add_argument("--start", type=float, default=0.0)
    v.add_argument("--end", type=float)
    common(v)
    v.set_defaults(func=cmd_video)

    s = sub.add_parser("sim-games", help="print the iOS Simulator's games folder")
    s.set_defaults(func=cmd_sim_games)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
