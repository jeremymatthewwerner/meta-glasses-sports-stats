"""sideline-cv command line.

    sideline-cv game  --games ~/path/to/games [--game latest|<id>] [--out out]
    sideline-cv video file.mp4 [--start 0 --end 20] [--out out]
    sideline-cv export-crops out/<game id> [...] --out dataset
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


def _reader(args):
    if args.no_jerseys:
        return None
    from .jersey import JerseyReader

    print("loading PARSeq jersey reader (first run downloads ~91 MB)…", file=sys.stderr)
    return JerseyReader()


def cmd_game(args) -> int:
    from .game import find_game, load_game
    from .pipeline import process_game

    game = load_game(find_game(Path(args.games).expanduser(), args.game))
    out = process_game(game, Path(args.out), _detector(args), sample_fps=args.fps, reader=_reader(args))
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
    extra: dict = {}
    n, mean_people, tracks = process_clip(path, Clip(path.name, args.start, end), out, _detector(args), args.fps,
                                          reader=_reader(args), extra=extra)
    seg = extra.get("segment")
    print("action:", "none found" if not seg else
          f"{seg['start']:.1f}–{seg['end']:.1f}s (confidence {seg['confidence']:.2f}), refined clip {extra.get('refined_clip')}")
    numbers = sorted({t["jersey"]["number"] for t in tracks if (t.get("jersey") or {}).get("number") is not None})
    print(f"{n} frames, {mean_people:.1f} people/frame, {len(tracks)} track(s), numbers read: {numbers or 'none'} → {out}")
    from .teams import TeamModel, cluster_two, lab_to_hex
    import numpy as np
    colored = [(t, np.array(t["color"]["lab"])) for t in tracks if t.get("color")]
    if len(colored) >= 2:
        model = TeamModel(cluster_two([c for _, c in colored], [t["frames"] for t, _ in colored]), {}, {})
        for t, lab in colored:
            a = model.assign(lab)
            num = (t.get("jersey") or {}).get("number")
            print(f"  track {t['track_id']:>3}: {t['color']['hex']} → team {a['cluster']}{' (unsure)' if a['unsure'] else ''}"
                  f"{f', #{num}' if num is not None else ''}")
        print("  team colors:", ", ".join(f"{k} {lab_to_hex(c)}" for k, c in model.centers.items()))
    return 0


def cmd_export(args) -> int:
    from .dataset import export_labeled_crops

    dirs = [Path(d) for d in args.reports]
    n = export_labeled_crops(dirs, Path(args.out), args.min_confidence)
    print(f"{n} labeled crop(s) → {Path(args.out) / 'labels.csv'}")
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
        p.add_argument("--no-jerseys", action="store_true", help="skip jersey-number reading")

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

    e = sub.add_parser("export-crops", help="voice-labeled jersey crops from processed games (training data)")
    e.add_argument("reports", nargs="+", help="processed game folders (out/<game id>)")
    e.add_argument("--out", default="dataset")
    e.add_argument("--min-confidence", type=float, default=0.5)
    e.set_defaults(func=cmd_export)

    s = sub.add_parser("sim-games", help="print the iOS Simulator's games folder")
    s.set_defaults(func=cmd_sim_games)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
