# Prior-art sweep: GitHub + web (2026-11-07)

This is a targeted follow-up to the main research report ([reports/](../../reports/Meta%20glasses%20sports%20stats%20landscape.md)). The question: is there existing work we can **use or build on**, not just learn from?

**Bottom line:** nothing on GitHub or the web does what we're building. No project or product turns glasses footage into team-sport stats; the only other repo matching "meta glasses sports" is this one. There are useful building blocks, though, plus one Meta feature we should design around.

## Highest-impact finds

| Find | What it is | How we use it |
|---|---|---|
| **Meta Autocapture** (early access since May 2026; US/Canada; Gen 2, HSTN, Vanguard) | "Hey Meta, start autocapture": Meta AI records moments and assembles highlight videos on its own ([Meta release notes](https://www.meta.com/help/ai-glasses/1809764829519902/)) | It could be capture path **B** (native high-quality clips) without the wearer pressing anything. Phase 0: check whether Gen 3 supports it, and whether its clips import with usable timestamps. It is also competition for "auto highlights", which is one more reason our value is *stats + identity + library*, not reels. |
| **GameChanger is expanding computer-vision stats** beyond basketball and volleyball, to football, soccer and lacrosse ([Yahoo/GameChanger](https://ca.news.yahoo.com/gamechangers-ai-tech-helping-support-131533190.html)) | The largest youth platform is moving toward auto-stats from fixed cameras | A competitive risk (added to the plan). Our edge stays the wearer's POV + voice + face/roster identity + pickup games. |
| **roboflow/trackers** (Apache-2.0, ~4k★) | Clean re-implementations of SORT, ByteTrack, OC-SORT and others, usable with any detector | Use it instead of individual tracker repos; it keeps the stack permissive |
| **roboflow/sports** (MIT, ~5.5k★) + Roboflow's youth-soccer highlight-reel write-up ([blog](https://roboflow.com/blog/make-automatic-highlight-reels-from-soccer-games)) | Player/ball/pitch detection, team clustering, jersey reading → kids' soccer reels | Reference pipeline for the soccer pack. The blog also documents a real failure: a scoreboard overlay caused jersey misreads |
| **mkoshkina/jersey-number-pipeline** (~74★, license "other": **check before use**) | The best published open jersey-number pipeline (87.4% on SoccerNet) | Model for our jersey-OCR design; reimplement if the license blocks use |

## Meta-glasses community code (DAT)

| Repo | License | Notes |
|---|---|---|
| [meta/meta-wearables-dat-ios](https://github.com/meta/meta-wearables-dat-ios) / [-android](https://github.com/meta/meta-wearables-dat-android) | Meta (other) | Official SDK, 1.0.1. **Moved from the `facebook` org to `meta`**. Samples: CameraAccess, DisplayAccess, BirdSpotter (a full app with session recording, speech, Display UI, tests). BirdSpotter is the best reference for our app architecture. |
| [jasondukes/SpecBridge](https://github.com/jasondukes/SpecBridge) | MIT, Swift | Ray-Ban Meta → RTMP bridge. Useful if we ever livestream or push the proxy stream to the cloud live |
| [ethanpaschkes/meta-glasses-voice-bridge](https://github.com/ethanpaschkes/meta-glasses-voice-bridge) | MIT, Swift | Voice commands from the glasses routed through Claude. Close to our voice-tagging loop |
| [circus-kitchens/expo-meta-wearables-dat](https://github.com/circus-kitchens/expo-meta-wearables-dat) (MIT), [rodcone/flutter_meta_wearables_dat](https://github.com/rodcone/flutter_meta_wearables_dat), [spectra](https://github.com/jacksonmafra-umain/spectra) (Kotlin Multiplatform) | various | Cross-platform DAT wrappers. We chose native iOS, but these matter if Android arrives sooner |
| VisionClaw, rayban-meta-god-mode, TeroGlasses, metaview | various | AI-assistant apps (look/describe/translate). Nothing sports-specific; useful as patterns for wake-word → speech-to-text → LLM |

## Sports analytics code (no end-to-end project)

- **Soccer:** SoccerNet devkits and baselines (sn-gamestate is **GPL-3.0**; avoid linking), lRomul/ball-action-spotting (MIT), mradovic38/football-analysis (MIT, YOLO-based → Ultralytics AGPL weights), Norfair possession code. Data/eval tooling: socceraction (MIT), kloppy, unravelsports (MPL-2.0).
- **American football:** there is **no open video-analysis project of note**. nflverse/nflfastR covers schema and pro data only. This confirms football is the build-it-ourselves sport.
- **Baseball:** data libraries (mlbgame, pybaseball, Retrosheet tools) plus small React scorekeeping apps (e.g. rscampbell333/baseball-scorekeeper, MIT). There is no CV scorekeeper.
- **Highlights:** small hobby projects only (e.g. arghyadeep99/Sports-Highlights-Generator, which works from audio and needs no CV).

## Long-video event finding (research code)

- **[Tanveer81/ReVisionLLM](https://github.com/Tanveer81/ReVisionLLM)** (CVPR 2025, ~45★, last push Nov 2025). A recursive vision-language model that finds events in **hour-long videos**: it searches broad segments first, then narrows to exact time boundaries. That matches our "find every play in a full game" problem. Caveats:
  - The license is **CC BY-NC-ND 4.0** (non-commercial, no derivatives), so it can't ship in a product. Using it for internal experiments on a personal project is fine.
  - It was trained on movies (MAD) and YouTube chapters (VidChapters-7M), not sports.
  - Use it as a design reference for long-game segmentation (coarse-to-fine search), not as a dependency.

## Commercial things found that weren't in the main report

- **Mixpeek:** a per-minute video API with youth-basketball box scores, play-by-play and jersey detection. It could serve as a hosted fallback or benchmark; it isn't open.
- **FIFA/Lenovo Referee View** (2026 World Cup): head-worn referee cameras at all 104 matches, with AI stabilization reported to cut blur by up to 50% ([Gizmodo](https://gizmodo.com/the-world-cup-is-quietly-making-a-case-for-smart-glasses-in-sports-2000779083)). This validates the ref-POV angle at the top level.

## Changes made to the plan

1. Capture path B now covers **Meta Autocapture** as a hands-free source (Phase 0 checks Gen 3 support and import).
2. The tracking stack uses **roboflow/trackers** (Apache-2.0).
3. Risks add **GameChanger expanding AI stats** into football and soccer.
4. The DAT package URL now points to `github.com/meta/meta-wearables-dat-ios`.
