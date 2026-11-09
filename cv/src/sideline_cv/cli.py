"""sideline-cv command line.

    sideline-cv game  --games ~/path/to/games [--game latest|<id>] [--out out]
    sideline-cv video file.mp4 [--start 0 --end 20] [--out out]
    sideline-cv export-crops out/<game id> [...] --out dataset
    sideline-cv faces enroll|list|forget --store team.faces.json [...]
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


def _roles(args):
    if args.no_roles:
        return None
    from .roles import RoleClassifier

    print("loading CLIP role classifier (first run downloads ~600 MB)…", file=sys.stderr)
    return RoleClassifier()


def _faces(args):
    if not getattr(args, "faces", None):
        return None
    from .faces import FaceID

    print("loading InsightFace (first run downloads ~280 MB; non-commercial license)…", file=sys.stderr)
    return FaceID(Path(args.faces).expanduser(), tuple(args.no_faces_on or ()),
                  log=lambda m: print(m, file=sys.stderr))


def cmd_game(args) -> int:
    from .game import find_game, load_game
    from .pipeline import process_game

    game = load_game(find_game(Path(args.games).expanduser(), args.game))
    out = process_game(game, Path(args.out), _detector(args), sample_fps=args.fps, reader=_reader(args),
                       roles=_roles(args), faces=_faces(args))
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
                                          reader=_reader(args), extra=extra, roles=_roles(args),
                                          faces=_faces(args), source=args.source)
    seg = extra.get("segment")
    print("action:", "none found" if not seg else
          f"{seg['start']:.1f}–{seg['end']:.1f}s (confidence {seg['confidence']:.2f}), refined clip {extra.get('refined_clip')}")
    numbers = sorted({t["jersey"]["number"] for t in tracks if (t.get("jersey") or {}).get("number") is not None})
    print(f"{n} frames, {mean_people:.1f} people/frame, {len(tracks)} track(s), numbers read: {numbers or 'none'} → {out}")
    named = [t for t in tracks if (t.get("face") or {}).get("person")]
    if any("face" in t for t in tracks):
        seen = sum(1 for t in tracks if (t.get("face") or {}).get("faces"))
        print(f"  faces: {seen} track(s) showed a usable face; enrolled people recognized: "
              + (", ".join(f"{t['face']['name']} (track {t['track_id']}, {t['face']['similarity']:.2f})" for t in named)
                 or "none"))
    from .roles import is_player
    from .teams import TeamModel, cluster_two, lab_to_hex
    import numpy as np
    roles = {k: sum((t.get("role") or {}).get("role") == k for t in tracks) for k in ("official", "sideline")}
    if any(roles.values()):
        print(f"  {roles['official']} official track(s), {roles['sideline']} sideline track(s), kept out of team colors")
    colored = [(t, np.array(t["color"]["lab"])) for t in tracks if t.get("color") and is_player(t)]
    if len(colored) >= 2:
        model = TeamModel(cluster_two([c for _, c in colored], [t["frames"] for t, _ in colored]), {}, {})
        for t, lab in colored:
            a = model.assign(lab)
            num = (t.get("jersey") or {}).get("number")
            print(f"  track {t['track_id']:>3}: {t['color']['hex']} → team {a['cluster']}{' (unsure)' if a['unsure'] else ''}"
                  f"{f', #{num}' if num is not None else ''}")
        print("  team colors:", ", ".join(f"{k} {lab_to_hex(c)}" for k, c in model.centers.items()))
    return 0


def cmd_faces(args) -> int:
    from .faces import ConsentError, FaceModel, FaceStore, enroll_folder

    path = Path(args.store).expanduser()
    if args.action == "enroll":
        store = FaceStore.load(path) if path.exists() else FaceStore(args.scope or "")
        if not store.scope:
            print("a new store needs --scope (the team or group it belongs to)", file=sys.stderr)
            return 2
        model = FaceModel()
        for folder in args.folders:
            try:
                p = enroll_folder(store, Path(folder).expanduser(), model)
            except (ConsentError, ValueError, FileNotFoundError) as e:
                print(f"not enrolled: {folder}: {e}", file=sys.stderr)
                continue
            print(f"enrolled {p.name}" + (f" #{p.jersey}" if p.jersey is not None else "")
                  + f" from {len(p.embeddings)} photo(s), consent by {p.consent['consent_by']} ({p.consent['relationship']})")
        store.save(path)
    elif args.action == "list":
        store = FaceStore.load(path)
        print(f"{store.scope}: {len(store.people)} enrolled")
        for p in store.people:
            print(f"  {p.id}: {p.name}" + (f" #{p.jersey}" if p.jersey is not None else "")
                  + f", {len(p.embeddings)} photo(s), consent by {p.consent['consent_by']} on {p.consent['date']}")
    elif args.action == "forget":
        store = FaceStore.load(path)
        for who in args.folders:
            print(("deleted " if store.forget(who) else "not found: ") + who)
        store.save(path)
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
        p.add_argument("--no-roles", action="store_true", help="don't tell officials and sideline people from players")
        p.add_argument("--faces", help="enrolled face store (JSON) to recognize people from; off when omitted")
        p.add_argument("--no-faces-on", action="append", choices=["glasses", "phone", "other"],
                       help="switch face ID off for footage from this source (repeatable)")

    g = sub.add_parser("game", help="every called play with video in a game")
    g.add_argument("--games", required=True, help="the app's games folder (copied from the phone)")
    g.add_argument("--game", default="latest", help="game id (or prefix); default: newest")
    common(g)
    g.set_defaults(func=cmd_game)

    v = sub.add_parser("video", help="one video file (or a time range of it)")
    v.add_argument("file")
    v.add_argument("--start", type=float, default=0.0)
    v.add_argument("--end", type=float)
    v.add_argument("--source", default="other", choices=["glasses", "phone", "other"],
                   help="what recorded the video (for --no-faces-on); default other")
    common(v)
    v.set_defaults(func=cmd_video)

    f = sub.add_parser("faces", help="enroll consented people for face ID, list them, or delete them")
    f.add_argument("action", choices=["enroll", "list", "forget"])
    f.add_argument("folders", nargs="*", help="enroll: folders with consent.json + photos; forget: person ids or names")
    f.add_argument("--store", required=True, help="face store file, one per team or group")
    f.add_argument("--scope", help="team or group name for a new store (must match each consent's scope)")
    f.set_defaults(func=cmd_faces)

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
