# Sideline: Meta-glasses sports stats system — product & engineering plan

*Working name: "Sideline". Draft v1.1, 2026-11-07. Key decisions are settled in §16: football → soccer → baseball, iOS first, free personal project, testing on Ray-Ban Meta Gen 3 + Meta Ray-Ban Display.*

Research behind this plan: [reports/Meta glasses sports stats landscape.md](../reports/Meta%20glasses%20sports%20stats%20landscape.md). Raw notes are in `research_notes/`.

---

## 1. What we're building, in one paragraph

A wearer of Meta glasses records a sports game. That might be a parent, coach or ref on the sideline (**spectator mode**), or a player in a pickup game or practice (**player mode**). The system works out who is who, logs plays, events and stats, keeps the score, and produces a game summary, a box score/play-by-play, and a clip gallery sortable by player, event type, game and season. Every game goes into a private online library for the team or group. Launch order is American football, then soccer, then baseball. Veo and other fixed-camera MP4s are a secondary input that can be fused with glasses footage.

## 2. What the research changes

| Finding | Consequence for the plan |
|---|---|
| No product, open or closed, turns Meta-glasses footage into team-sport stats. Hudl and QwikCut football breakdown is still done by **humans** ($450–$1,700 per team per season). No video auto-scorer exists for youth baseball. | The opening is real. The bar for "better than Hudl Assist" in youth football is fast, cheap and good enough, not perfect. |
| Third-party apps get at most a **720×1280 @ ≤30fps stream over Bluetooth** to the phone (DAT 1.0, GA 2026-09-30). Native glasses clips are ≤3 min at up to 3K and portrait-only. Total recording is roughly **30–50 min per charge**. | Continuous capture of a whole game from the glasses is not possible. We need a **hybrid capture** design (§5) and battery-aware session management. |
| Third-party code does not run on camera-only glasses. On **Meta Ray-Ban Display**, apps can render UI and HTML/JS web apps run on the device. | All vision runs on the phone or in the cloud. Display becomes the scorer's **confirm/HUD** surface. |
| DAT public distribution is "coming soon". Release channels were capped at **100 testers** as of May 2026. | Early phases are a private beta. Watch distribution on the roadmap. |
| Meta's Wearables AUP bans "unique identification of people based on … faces" unless **Meta pre-approves an exception**. GitHub issue #334 says there is no public approval process. | Face recognition is in scope (your decision) but **gated on a Meta exception**, or on a capture path proven to sit outside the AUP. Engineering it so it can be switched off per source is mandatory. |
| BIPA/CUBI/Colorado, amended COPPA (face templates are named PI, enforceable 2026-04-22), GDPR Art. 9. | Consent-first identity design: guardian consent for minors, team scope, deletion. This is product work, not a legal afterthought. |
| Players wearing consumer smart glasses in organized games likely breaks equipment rules (IFAB Law 4, NFHS). | Player mode targets **pickup games, practices and drills**, where it shines and has no rules problem. |
| Little League claims ownership of game video. NFHS Network holds postseason exclusives. | Per-game "rights restricted" flag; libraries are private by default. |
| Permissive open-source stack exists (RF-DETR, BoT-SORT, PARSeq, Torchreid, faster-whisper, Qwen3-VL, SFace/YuNet). **Ultralytics YOLO is AGPL** and **InsightFace weights are non-commercial**. | Pick the stack for licensing from day one (§8). |
| Football has the thinnest open tooling. Soccer has the deepest (SoccerNet). | Football v1 leans on **voice and human-in-the-loop**, not full automation. Soccer gets more automation when it arrives. |
| Veo exports only a single-match follow-cam MP4. There is no event export and no public API. Veo Analytics 2 already does soccer player stats. | Veo comes in through a generic **"import fixed-camera MP4"** path. Our value is fusion with glasses POV, not re-deriving Veo's stats. |
| Only **TeamSnap** (OAuth) and **LeagueApps** (API key) have roster APIs. GameChanger, BYGA, SportsEngine and Hudl don't. **MaxPreps** accepts `.txt` stat-file uploads from registered partners. | Roster: universal CSV import plus TeamSnap OAuth first, with BD outreach to BYGA and GameChanger. Stats out: become a MaxPreps stat partner. |

## 3. Product principles

1. **The wearer's attention and voice are the superpower.** Where the parent looks solves "which player matters". What the coach says ("22 for 7 yards, tackle by 54") solves attribution that vision can't. Computer vision and VLMs segment, timestamp, propose, confirm and clip.
2. **Propose, then confirm.** Every event carries `source` (auto / voice / human) and `status` (proposed / confirmed / rejected) plus a `confidence`. Stats are always *derived* from events through a rule set, so a correction recomputes everything.
3. **Capture-agnostic core.** Glasses stream, glasses native clips, phone, Veo and other MP4s are all just `MediaAsset`s on a shared game clock.
4. **Sport packs, not forks.** Each sport is a plug-in: event taxonomy, voice grammar, segmenter, rule sets, summary templates and exporters.
5. **Consent before identity.** Nobody is named or face-matched without a consent record. We only recognize people someone has enrolled; we never identify strangers.
6. **Private by default.** Team- and group-scoped libraries; sharing is explicit.

## 4. Users, modes and jobs-to-be-done

| Persona | Mode | Top jobs |
|---|---|---|
| Parent on the sideline | Spectator | Clips of *my kid*; their stat line; share a highlight reel |
| Coach / assistant | Spectator | Play-by-play and stats without a dedicated stat-keeper; push to MaxPreps; film review by player |
| Volunteer stat-keeper / scorekeeper | Spectator | Faster, more accurate scoring than paper or GameChanger; baseball pitch counts |
| Ref / umpire | Spectator (ref sub-mode) | Rec and pickup: game log, score, incident clips. Sanctioned leagues only where pilots allow |
| Player in a pickup game / practice | Player | "What did I do": touches, shots, runs, catches; POV highlights; pickup group leaderboard |
| Recruit (HS) | Consumer of outputs | NCSA-style reel: name/number/position/grad-year title card, 20–25 clips |

**Spectator mode** optimizes for coverage. It assumes the wearer follows the ball, uses voice tagging heavily, and fuses with an optional fixed camera.
**Player mode** optimizes for low effort. It assumes no voice during play, auto-capture around high-motion moments (IMU), and post-game labeling. Pickup games usually have **no jerseys**, so identity comes from enrolled faces, appearance clustering and the group's friends list.

## 5. Capture architecture (the hard constraint)

Three capture paths, all landing on one game timeline:

```
            ┌────────────────────── Glasses ───────────────────────┐
            │  A. DAT live stream (≤720p, 2–30fps, HEVC, BT/Wi-Fi) │──► Phone app: live segmentation,
            │     + mic audio (wearer voice, whistles)             │    voice parsing, HUD confirm
            │  B. Native clips (3K, ≤3 min, high quality)          │──► imported later via Meta AI app
            └──────────────────────────────────────────────────────┘    gallery → phone → upload
            C. Fixed camera (phone on tripod, Veo/XbotGo/Pixellot MP4) ──► full-game backbone (optional)
```

- **A. Live stream (always on during a session).** Runs at a low frame rate (7–15fps, tuned in Phase 0 for battery) to drive live play segmentation, voice capture, the scoreboard/score state, and HUD confirmations on Display. The phone records it locally as a full-game proxy timeline.
- **B. Native clips (quality layer).** The wearer captures 3K clips of key moments: a voice command, the capture button, the Gen 3 Action button, or Meta's own **Autocapture** ("Hey Meta, start autocapture"; early access since May 2026 on Gen 2/HSTN/Vanguard), which records moments hands-free. See [docs/research/prior-art-sweep.md](research/prior-art-sweep.md). They're imported from the phone gallery after the game and aligned to the timeline by timestamp plus audio cross-correlation. Highlights prefer B over A when both exist.
- **C. Fixed camera (backbone, optional).** A phone on a tripod, or Veo, Pixellot or XbotGo MP4s. These cover what the wearer didn't see and give the all-field view football coaches want.
- **Battery plan:** a session manager watches DAT thermal and battery events, degrades fps and resolution gracefully, and prompts case recharges at quarter and half breaks (the case reaches about 50% in ~20 min). It supports **two-pair hand-off** for full games. Phase 0 measures real endurance on Gen 2, Gen 3, Vanguard and Display.
- **Time sync:** wall-clock from each device, refined by whistle and crowd audio cross-correlation. Fallback is a visual anchor (kickoff, first pitch).
- **Portrait problem:** native video is portrait-only until landscape ships. Vanguard's 122° FOV helps. The pipeline must handle portrait natively (crop-aware tracking; vertical highlight formats are actually ideal for social sharing).

## 6. System architecture

```
┌───────────── Edge ─────────────┐        ┌──────────────────── Cloud ─────────────────────┐
│ iOS app (Swift, DAT SDK)       │        │ API (auth, teams, games, consent)              │
│  • session mgr / battery       │ upload │ Ingest: resumable upload → object storage      │
│  • on-device ASR + voice parse │ ─────► │ Job orchestrator (per-game DAG)                │
│  • light CV: segmentation,     │        │ GPU workers: detect/track/OCR/face/re-ID/VLM   │
│    scoreboard, play boundaries │ ◄───── │ Event store (Postgres) + stat engine           │
│  • review & labeling UI        │  sync  │ Clip renderer (ffmpeg) → HLS/CDN               │
│ Display HUD (DAT display UI /  │        │ Summary generator (LLM)                        │
│  HTML web app, Neural Band)    │        │ Web app: library, gallery, summaries, review   │
│ Android app (later, Kotlin)    │        │ Integrations: TeamSnap, CSV, MaxPreps, exports │
└────────────────────────────────┘        └─────────────────────────────────────────────────┘
```

**Edge does what must be live:** voice, play boundaries, score state and HUD. **Cloud does what must be accurate:** tracking, identity, VLM event labeling, stats and rendering. Everything that runs live is re-run in the cloud at higher quality, and the cloud result wins unless a human confirmed otherwise.

## 7. Processing pipeline (per game)

1. **Ingest & normalize.** Transcode, extract audio, read device metadata, register `MediaAsset`s.
2. **Sync.** Put all assets on one game clock.
3. **Stabilize.** Gyro/IMU where available (DAT IMU is experimental), otherwise optical flow (ffmpeg vidstab). Gyroflow is GPL, so we avoid linking it.
4. **Segment.** Sport-specific units: a football play (snap to whistle), a baseball pitch / plate appearance, a soccer possession or stoppage. Inputs are motion energy, whistle detection, voice cues and VLM checks.
5. **Detect & track.** RF-DETR (Apache-2.0) plus BoT-SORT with camera-motion compensation (MIT). Team assignment via jersey-color clustering (roboflow/sports approach: SigLIP embeddings + clustering).
6. **Identify** (see §9). Jersey number (PARSeq + VLM fallback, voting per tracklet, constrained to the roster), enrolled faces (consented only), within-game appearance re-ID, then human labels.
7. **Propose events.** Merge three sources:
   - **Voice:** ASR (faster-whisper / on-device) → LLM parser with the sport grammar → structured event.
   - **Vision:** VLM over a clip storyboard (≈15 frames + transcript), the zero-shot method that beat supervised baselines on soccer.
   - **Heuristics:** e.g. a score change from scoreboard OCR or the voice "touchdown".
8. **Review.** A low-confidence queue goes to the phone and web review UI: swipeable "confirm / fix" cards. Corrections become training data.
9. **Derive.** The stat engine applies a `StatRuleSet` (NFHS-FB, NCAA, FLAG-5v5, LL-11U, US-Youth-Soccer, …) → box score, player stat lines, game state.
10. **Render.** Per-event clips (best available source, padded), player reels, a game highlight reel with title cards.
11. **Summarize.** An LLM writes the game recap, per-player blurbs and coach notes from the *confirmed event log*, never from raw video, so it can't hallucinate stats.
12. **Publish** to the team library; notify. Optional exports (MaxPreps `.txt`, CSV, Hudl-friendly XML/CSV, SPADL/kloppy, Retrosheet).

## 8. Technology choices

| Layer | Choice | Why / notes |
|---|---|---|
| Mobile | **Native iOS first (SwiftUI)**, Android (Kotlin) in Phase 4 | DAT is native Swift/Kotlin; cross-platform wrappers add risk around streaming and background modes |
| Display HUD | DAT display UI from the phone app, plus an HTML/JS web app for standalone HUD | Meta's own example use case is "real-time scores" |
| On-device ASR | Apple Speech / whisper.cpp | Low-latency voice tagging; DAT on-device speech is experimental |
| Backend API | Python (FastAPI) or TypeScript, **Postgres** | Python keeps the ML pipeline and API in one language |
| Orchestration | Temporal (or a simpler queue to start) | Long-running, retryable per-game DAGs |
| Storage / video | S3-compatible object storage, ffmpeg, HLS via CDN | |
| GPU workers | Serverless GPU (Modal / RunPod) to start | Bursty per-game load |
| Detection / tracking | RF-DETR, **roboflow/trackers** (Apache-2.0: ByteTrack/OC-SORT/…), BoT-SORT-style camera-motion compensation, supervision | **Avoid Ultralytics (AGPL)** unless we buy an Enterprise license |
| Jersey OCR | Koshkina/Elder-style pipeline: legibility filter → pose torso crop → PARSeq → tracklet vote; VLM fallback | 87.4% on SoccerNet; roster constraint helps; needs football/baseball fine-tuning |
| Face | **YuNet + SFace (OpenCV Zoo)**; AWS Rekognition as an alternative | InsightFace weights are non-commercial; Rekognition puts the BIPA consent burden on us |
| Re-ID | Torchreid / OSNet (verify weight licenses) | Within-game only unless the person is enrolled |
| VLM | Hosted frontier model (Claude / Gemini) for quality; Qwen3-VL (Apache-2.0) self-hosted for cost | Benchmark both in Phase 0 |
| LLM text | Claude (e.g. `claude-sonnet-5-5`) for voice parsing, summaries and review assist | Structured outputs into our event schema |
| Web app | Next.js (TypeScript) | Library, gallery, summaries, review, admin |
| Schemas | Sport-neutral core; export to nflfastR-style, SPADL/kloppy, Retrosheet | No new schema needed |

## 9. Identity system: rosters, labeling, faces, pickup games

**Roster sources, in build order:**
1. **Manual + universal CSV import** with column presets for TeamSnap, SportsEngine, LeagueApps and Spond exports (name, number, position, guardian email, photo URL).
2. **TeamSnap OAuth** (API v3, `read` scope): the first "connect your account" integration.
3. **Friends / group list** for pickup: in-app invite links and phone contacts. Facebook and Instagram friend graphs are effectively closed, so we don't rely on them.
4. **LeagueApps** (org-level API key) for leagues that onboard as organizations.
5. **BYGA, GameChanger, SportsEngine:** no public APIs. CSV for now, BD partnership outreach in Phase 1. A GameChanger opponent-roster import is a manual stopgap.

**Human-seeded labeling (the core loop):**
- After a game, the system clusters unidentified tracklets (jersey number where readable; appearance within the game; faces where consented).
- A coach, parent or teammate gets **"Who is this?" cards** (Google Photos-style), each with 3–5 representative crops and a roster picker. Labeling one cluster labels all of its appearances.
- Active learning: the next cards show the most uncertain or most impactful clusters first (players attached to key events).
- Labels persist as **per-game ground truth**. For people with face-consent on file, they also become **enrollment samples** that improve recognition in later games.

**Face recognition (opt-in, enrolled-only):**
- **Enrollment** happens from labeled shots or roster photos, *only* after a consent record exists. A guardian consents for a minor; COPPA verifiable parental consent applies under 13.
- **Matching** is closed-set against the team's or group's enrolled people only. It never matches across teams or groups. Unmatched faces are never clustered across games and are discarded after the game.
- **Storage:** templates are encrypted in a team-scoped store and deleted when consent is withdrawn or the retention period ends (end of season / group inactivity). A published retention schedule and a BIPA-style written policy.
- **Meta gating:** a kill-switch per source. Face matching on glasses-sourced media turns on only once Meta grants an AUP exception (or counsel confirms the imported-gallery path is out of scope). Phone, Veo and MP4 sources may run earlier if counsel agrees.
- **Accuracy reality:** recognition degrades below ~32px faces. Rough estimates for usable faces are 3–5 m at 1080p and 5–8 m at 3K. Football helmets defeat it. So faces are a **seeding and confirmation signal** (bench, huddle, pickup), while jersey numbers, tracking and appearance carry identity during play.

**Pickup games (no jerseys):** identity = group roster + enrolled faces + within-game appearance clusters (shirt color/clothing) + post-game "Who is this?" cards. An optional "pinnie colors" setting at game start adds a team-assignment cue.

## 10. Data model (core)

```
Organization ─< Team ─< RosterMembership >─ Person ─< Consent
                  │                            │
Group (pickup) ───┤                            └─< FaceEnrollment (team/group-scoped)
                  ▼
Game (sport, rule_set, rights_flag, location, teams) ─< MediaAsset (source, device, offsets)
  │
  ├─< Segment (play / pitch / possession; t_start, t_end)
  ├─< Event (type, sport_payload, t_game, t_wall, participants[{person, role}],
  │          video_refs[{asset, t0, t1}], source, status, confidence, author)
  ├─< IdentityObservation (tracklet, asset, method: jersey|face|appearance|label, person?, conf)
  ├── GameState (derived: score, clock, down&distance / count&outs / period)
  └── StatLine (derived per person via StatRuleSet)
Clip / Reel (rendered from Events) · Summary (LLM, from confirmed Events)
```

Gallery = a query over `Event ⨝ participants ⨝ video_refs`, filterable by person, event type, game, season, team and source quality.

## 11. Sport packs

### 11.1 American football (first)
**v1 promise:** "a voice scorebook plus a highlight reel per player". This is not automated all-22 breakdown.
- **Segmenter:** snap detection (motion onset + voice "set/hike" + whistle) → play clips.
- **Voice grammar:** `[ball carrier/passer #] [run|pass|complete to #|incomplete|sack|punt|FG|PAT|kickoff] [for N yards] [tackle by #] [flag|penalty …] [touchdown|turnover|fumble|interception by #]`, plus down/distance corrections ("second and seven").
- **Auto (v1):** play boundaries, play-type suggestion (run/pass/kick via VLM), score from voice and scoreboard OCR, jersey reads near the wearer.
- **Human/voice:** tackle credit, yards, penalties, assists.
- **Rule sets:** NFHS, NCAA, FLAG-5v5/7v7 (stat credit differs, e.g. NCAA vs NFL sack-fumble).
- **Exports:** MaxPreps `.txt` (become a stat partner), CSV, nflfastR-like play-by-play.

### 11.2 Soccer (second)
- **Segmenter:** possessions and stoppages (whistle, ball out).
- **Auto:** goals, shots, corners, kick-offs (SoccerNet-grade models); jersey OCR at its strongest here; field registration (PnLCalib/NBJW) on fixed-camera sources.
- **Voice:** "goal 9, assist 14", cards, subs.
- **Veo/MP4 fusion:** import the follow-cam MP4 → backbone. Glasses add close-up IDs and "my player" moments.
- **Exports:** SPADL/kloppy, CSV.

### 11.3 Baseball / softball (third — but the sleeper)
- **Segmenter:** pitch delivery → plate appearance (very structured).
- **Auto:** pitch counting (a compliance feature: Little League limits by age), swing / contact / no-contact, home runs.
- **Voice:** "ball", "strike looking", "6-3", "single to left, runner to third"; Retrosheet-style grammar.
- **Human:** hit vs error, earned runs.
- **Strong wearer fit:** a dugout coach or scorekeeper is stationary with a great view, and equipment rules aren't an issue for them.
- **Exports:** Retrosheet event format, GameChanger-comparable box score, MaxPreps.
- **Note:** Little League video ownership → rights flag plus team-private default.

## 12. Outputs

- **Game page:** final score, scoring summary, LLM recap, box score, play-by-play with clip links, per-player stat lines.
- **Gallery:** grid of clips, filters (player, event type, game, season, team, quality), sort (time, "best" by event weight + clip quality), multi-select → reel.
- **Player page:** season stat lines, every clip, auto reel with an NCSA-style title card (name/number/position/grad year).
- **Library:** all games by team/group/season; search ("Jake touchdowns 2026").
- **Sharing:** private links, team-only by default, per-player "do not identify", guardian controls.

## 13. Privacy, consent & compliance workstream (runs alongside every phase)

- Org-level onboarding so registration consents flow in. Tiered guardian consent: **appear** / **be named** / **face recognition** / **share beyond the team**.
- Per-person "do not identify" and "blur me" options. Blurring uses ephemeral face *detection* only (counsel to confirm the BIPA position).
- Rights-restricted game flag (postseason, Little League, NFHS exclusives) → no public sharing, no streaming.
- Data deletion on request; retention schedules; no ad SDKs; no sale of data; no cross-team identity.
- **Asks for counsel before Phase 2:** Meta AUP exception scope; BIPA/CUBI/CO consent text; COPPA status of a parent-run app; audio-recording consent (two-party states); GDPR DPIA if the EU is targeted.
- **Ask Meta developer relations in Phase 0:** the face-ID exception process; the distribution timeline beyond 100 testers; whether imported gallery media is covered by the AUP.
- Public stance: "We only recognize people your team enrolled. We never identify strangers."

## 14. Phased roadmap

### Phase 0 — Feasibility (split by hardware dependency)

Phase 0 is split in two so work doesn't wait on glasses. Everything built in 0a is reused unchanged once hardware arrives.

#### Phase 0a — No hardware needed (start now, ≈2–3 weeks)
- [x] **Football event model + stat engine** *(done 2026-11-07: `SidelineCore/Football`, 32 tests)* in `packages/SidelineCore`: plays, a derived game state (score, possession, down and distance) and rule-set-aware stats (NFHS vs NCAA credit rules) producing a box score.
- [x] **Voice play parser** *(v1 grammar done; needs real sideline utterances to tune)*: spoken play calls ("22 run for 7, tackle by 54") → structured plays. Deterministic grammar first; an LLM fallback for what the grammar misses comes later.
- [x] **Voice scorebook prototype** *(built and simulator-verified with typed input; speech recognition is untested on a real phone)* (iOS, phone mic / AirPods): push-to-talk, on-device speech recognition, parse, confirm/undo, live score and box score. It logs every utterance alongside its parse and any correction, so we can measure parse accuracy.
- [x] **Display HUD prototype** *(pulled forward from Phase 2; built 2026-11-07, verified on MockDeviceKit and then on a real Display: readable, Confirm works from the glasses)*: the scorebook's live score, situation, last play and Confirm / Undo on the Meta Ray-Ban Display lens, driven from the phone. While the HUD is up the scorebook uses the phone mic, because the glasses' Bluetooth mic ends Display sessions ([dat-ios#342](https://github.com/meta/meta-wearables-dat-ios/issues/342)).
- [ ] **Proxy footage:** film youth games or practices with a phone at head height in portrait (chest or head mount if possible). Downscale to the DAT stream envelope (504×896 or 720×1280 @ 15 fps) so it stands in for glasses footage.
- [x] **CV v0 pipeline** *(built 2026-11-07, `cv/`)*: per called play, sample the clip → RF-DETR person detection → ByteTrack tracks → best crop per track + annotated preview + report with the called jerseys. Verified on a mock-glasses game and a people sample; not yet on real footage. Jersey numbers: PARSeq on torso windows + multi-frame vote + match to the called jerseys (matched / missing / unexpected per play); off-the-shelf accuracy is a baseline to beat with fine-tuning on voice-labeled crops. Team colors: game-level 2-color clustering of jerseys, named home/away from number-matched calls, then team-aware matching (splits home #22 from away #22, flags number reads on the wrong team's colors). Play boundaries: player + camera motion curve → longest high-activity stretch → clip trimmed to the play. Round trip: the app imports the CV report (per-play "who CV saw", trimmed clips, team colors), and `export-crops` turns voice-matched tracks into a labeled jersey-number training set.
- [ ] **Model bake-off on proxy footage:** play segmentation, jersey OCR (PARSeq vs VLM), VLM play-type labeling (hosted vs Qwen3-VL).
- [ ] **Meta + counsel conversations** (§13).
- **0a exit:** voice parse ≥90% field-accurate on real sideline utterances; box score matches a hand-kept scorebook for one game; ≥90% of plays segmented on proxy footage.

#### Phase 0b — Needs one pair of glasses (≈1 week once available)
The probe app is already built and simulator-verified; the protocol is [docs/phase0/TEST-PROTOCOL.md](phase0/TEST-PROTOCOL.md).
- [ ] **DAT on Gen 3:** Meta has confirmed Gen 3 works with DAT 1.0 (Gen 3 support was confirmed 2026-11-07: Meta replies in [dat-ios#323](https://github.com/meta/meta-wearables-dat-ios/discussions/323), [dat-android#185](https://github.com/meta/meta-wearables-dat-android/discussions/185) and [#221](https://github.com/meta/meta-wearables-dat-android/discussions/221), plus a hands-on report; the official FAQ device list lags). Verify on our hardware, and log the reported `DeviceType`: Meta says Gen 3 may report as `.rayBanMetaOptics` instead of `.rayBanMeta`, so never filter on device type.
- [ ] **Hardware endurance:** DAT stream at 7/15/30fps on Gen 3 and Display. Measure minutes to thermal/battery cutoff, case-recharge cadence, and the Gen 3 + Display two-pair hand-off (one wearer swaps pairs; running both at once needs two wearers, e.g. a parent filming on Gen 3 and a coach scoring on Display).
- [ ] **Native clip import:** the path from the Meta AI app gallery to our app; timestamp fidelity; audio alignment. Also test whether **Autocapture** works on Gen 3 and whether its clips import with usable timestamps.
- [x] **DAT on Display** *(T1 passed 2026-11-07: HEVC medium/15 fps streamed at 15.2 fps for 2 min, no stalls. Sessions first ended immediately until the on-glasses DAT app was installed under Meta AI → App Info → Developer Mode.)*
- [ ] **Display HUD on the real lens:** *(2026-11-07: readable indoors; Confirm pressed on the glasses confirms the play on the phone.)* Still to check: legibility outdoors in sun, Undo, update latency, and HUD + camera stream together (needs one shared session; today the HUD and the probe each open their own).
- [x] **Hands-free play calls from the lens** *(built 2026-11-07; works on a real Meta Ray-Ban Display, recognition is very fast; full T7 run still to do)*: Call play on the lens → the glasses' own recognizer (MWDATSpeech, experimental) → parse → proposed play with Confirm focused. Ends on a final transcript, 1.6 s of silence, 12 s, or Done/Cancel. Falls back to the phone mic if the glasses can't listen. Also added Redo (lens, toolbar, "redo").
- [x] **Game mode** *(built 2026-11-07; verified end to end on MockDeviceKit, not yet on real glasses; tests T8 → T5)*: one DAT session carries the lens, the glasses mic and the camera (HEVC 504×896 @ 15 fps, passthrough to `games/<id>/glasses-NN.mov`). Each called play stores a `VideoRef` from 15 s before the call to 2 s after (`ClipPolicy.football`), and plays back as a clip on the phone. Works on glasses without a display too (recording + glasses mic). This is the data engine for the CV work: every scored game yields video already cut and labeled by play.
- [x] **Gallery, rosters and reels** *(built 2026-11-07, simulator-verified)*: per-player and per-event-type views of the game's plays (`FootballGallery`, `PlayTag`), CSV/paste roster import (`Roster`), and highlight reels stitched from play clips (passthrough export). Covers the "gallery sortable by player and event" goal for one game; the multi-game library comes later.
- [x] **Game library and summaries** *(built 2026-11-07, simulator-verified)*: library of saved games, game page (score by quarter, recap, scoring, leaders, key plays with clips), season record and player totals per team, end/reopen game. Local only; the online library is still to come.
- [x] **Web library export** *(built 2026-11-08, simulator-verified)*: the app writes the library as a static website (`WebLibrary`: index with season records, a page per game with quarters, recap, leaders and plays filterable by player and event type, with per-play `.mp4` clips) and zips it for sharing. Hostable anywhere static; the first step toward the online library. Still to come: automatic sync and private sharing.
- [ ] **Voice through the glasses:** rerun the 0a voice prototype using the glasses' microphones (six-mic array on Gen 3); compare accuracy with the phone mic.
- [ ] **Data collection:** record 3–5 real youth football games (glasses + tripod phone), plus a pickup game. Hand-label plays, events and identities. This becomes our eval set (no public egocentric team-game dataset exists).
- **0b exit:** a viable full-game capture recipe; a written answer on the face-ID path.

### Phase 1 — Football MVP: voice scorebook + highlights (≈8–10 weeks)
- iOS app: team setup, CSV roster import, DAT capture session with battery manager, voice tagging, live score.
- Cloud: ingest, sync, segmentation, jersey OCR assist, event proposal (voice + VLM), review queue, NFHS stat engine.
- Outputs: game page, box score, play-by-play, per-player gallery and reel, LLM recap; team-private library (web).
- Exports: CSV (MaxPreps `.txt` is optional for a personal project).
- Private use: the owner's team(s) plus friends, well within DAT tester limits.

### Phase 2 — Identity & HUD (≈6–8 weeks)
- "Who is this?" labeling loop + active learning; appearance re-ID within a game.
- Consent system (tiered, guardian, deletion) → **face enrollment & enrolled-only matching** (behind the Meta/counsel gate).
- **Pickup / player mode:** groups, invite links, no-jersey identity, IMU-triggered auto-capture, personal POV stats.
- TeamSnap OAuth roster sync.
- **Display HUD:** live score, last-event confirm/undo, Neural Band gestures.
- Ref sub-mode for rec/pickup games (game log, score, incident clips).

### Phase 3 — Soccer + fixed-camera fusion (≈8 weeks)
- Soccer sport pack (taxonomy, voice grammar, segmenter, rule sets, SPADL export).
- Generic **fixed-camera MP4 import** (Veo follow-cam, XbotGo, Pixellot, phone tripod) + multi-source sync + fusion (best-angle clip selection, glasses IDs → backbone tracks).
- Field registration on fixed sources; automated goal/shot/corner detection.

### Phase 4 — Baseball/softball + Android (≈8 weeks)
- Baseball sport pack: pitch segmentation, pitch-count compliance alerts by league/age, Retrosheet-grammar voice scoring, box scores.
- Android app (Kotlin DAT SDK).
- MaxPreps export for football / soccer / baseball; GameChanger-comparable outputs.

### Phase 5 — Depth & scale
- More automation: fine-tuned football play-type and formation models trained on our accumulated, human-corrected data; soccer and baseball event models.
- LeagueApps / org onboarding; BYGA / GameChanger partnerships if they land; Pixellot partner API for programmatic fixed-camera ingest.
- Season analytics, leaderboards, recruiting reels, public sharing options for consenting players.

## 15. Top risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Glasses can't sustain a full game | High / High | Hybrid capture; low-fps stream; case swaps; two-pair hand-off; fixed-camera backbone |
| Meta denies the face-ID exception | Medium / Medium | Per-source kill switch; jersey + appearance + human labels still work; faces only on non-glasses sources if counsel OKs |
| DAT distribution stays capped | Medium / Low (personal project) | Personal use fits within 100 testers; native-clip import path works without DAT |
| DAT quirks on Gen 3 (reports as `.rayBanMetaOptics`; official docs lag) | Low / Low | Meta confirmed support in GitHub discussions; don't filter on `DeviceType`; verify in Phase 0 T1 |
| Stream restart and HFP conflicts in DAT 1.0.x | Medium / Medium | Per Meta: never restart a stopped stream (create a fresh `Camera` per burst, keep the `DeviceSession`); keep Bluetooth HFP closed while a DAT session is open (it can end the session on some firmware); use stream audio instead |
| Football automation accuracy too low | High / Medium | v1 promise is voice-first; review queue; collect corrected data to train on |
| Portrait-only, head-motion footage hurts CV | High / Medium | Stabilization, BoT-SORT CMC, Vanguard 122° FOV, rely on voice, fixed-camera fusion |
| League rights (Little League, NFHS) | Medium / Medium | Rights flag, team-private default, org onboarding, no streaming |
| Privacy incident / bad press | Low–Med / High | Enrolled-only, team-scoped, deletion, clear public stance, no ad SDKs |
| GameChanger (and Hudl) ship AI auto-stats for football/soccer from fixed cameras | Medium / Medium | Differentiate on wearer POV + voice, face/roster identity, pickup games, and fusion with any camera |
| Licensing contamination (AGPL/non-commercial weights) | Medium / High | License allow-list in CI; model registry records weight provenance |
| Cloud GPU / VLM cost per game | Medium / Medium | Segment first, then run VLM only on segments; self-hosted Qwen3-VL fallback; cache |

## 16. Decisions (settled 2026-11-07)

| # | Decision | Choice | What it changes |
|---|---|---|---|
| 1 | Sport order | **Football → soccer → baseball** (original order kept) | Football v1 is "voice scorebook + highlights". Soccer brings Veo/MP4 fusion in Phase 3. Baseball stays Phase 4 despite being easiest to automate. |
| 2 | Platform | **iOS first** | One native SwiftUI app; Android waits for Phase 4 (or later). |
| 3 | Business model | **Free / personal project** | No billing, plans or sales motion. Optimize for the owner, friends and a few teams. The DAT 100-tester cap is not a blocker. MaxPreps stat-partner registration and BYGA/GameChanger BD drop to "nice to have". **Consent is still required:** friends' kids are still minors and face templates are still biometric data. Cloud cost matters more than scale, so we favor cheap per-game processing. |
| 4 | Test hardware | **Ray-Ban Meta Gen 3 + Meta Ray-Ban Display** | Phase 0 measures endurance on these two. Gen 3 isn't in the official FAQ list yet, but **Meta confirmed in GitHub discussions that it works with DAT 1.0** (it may report as `.rayBanMetaOptics`). Gen 3 (3K capture, 9 h, Action button) is the capture device; Display (HUD, Neural Band, on-glasses web apps) is the scorer/confirm device. One person wears one pair at a time, so using both at once means two wearers (filmer + scorer) or a halftime swap. Vanguard/HSTN/Gen 1–2 stay supported via DAT but untested by us. |
| 5 | Hosted vs self-hosted models | *Default:* **hosted frontier APIs allowed** under no-training / zero-retention terms; Qwen3-VL as a cost fallback | Fastest path for a personal project; revisit if footage of other people's kids is shared widely. |
| 6 | Geography | *Default:* **US only** | Defers GDPR Art. 9 / DPIA work. |

Items 5–6 are defaults; change them any time.

## 17. Proposed repository layout

```
apps/
  ios/                 # SwiftUI app + DAT SDK integration
  android/             # (Phase 4)
  display-hud/         # HTML/JS web app for Meta Ray-Ban Display
  web/                 # Next.js library, gallery, review, admin
services/
  api/                 # auth, teams, games, consent, integrations
  pipeline/            # per-game DAG: ingest, sync, segment, track, identify, events, render
  stat-engine/         # rule sets → derived stats & game state
packages/
  schema/              # event model + sport payload schemas (JSON Schema → Swift/TS/Python)
  sport-packs/         # football/, soccer/, baseball/: taxonomy, voice grammar, rule sets, exporters
  ml/                  # model wrappers, eval harness, license registry
data/
  eval/                # labeled Phase 0 games (private; not committed)
docs/
  PLAN.md
reports/ research_notes/
```
