# Stat Categories, Event Taxonomies and Data Schemas (Football, Soccer, Baseball/Softball; youth/HS level)

Method note: About 20 tool calls. I verified the primary schema docs (nflfastR source, SPADL/Atomic-SPADL docs, Retrosheet, kloppy, StatsBomb live API guide, Little League rules). Several vendor help centers did not load: GameChanger help returned 403, the NCAA PDF could not be parsed, and the nflreadr dictionary page rendered empty. Statements that rest on general domain knowledge, not on a source fetched in this session, are marked **[unverified, domain knowledge]** and appear only in Inferences or Gaps.

---

## 1. American football: play-by-play structure, individual and team stats, MaxPreps/Hudl entry, NCAA rules, nflverse schema, youth variants

### Takeaway
The de facto open play-by-play schema is nflverse/nflfastR. It has one row per play, with game situation fields (down, distance, yard line, clock), a small `play_type` enum, boolean result flags, and player-ID columns per role. Situation and result are easy to model. Defensive credit (tackles, assists, half sacks) follows stat-manual rules that differ by level (NCAA vs NFL), and it is the hardest part to infer from video. At the HS level, coaches enter stats into MaxPreps, directly or through partner tools, and coverage is patchy.

### Cited Findings
- nflfastR `play_type` values: `pass`, `run`, `kickoff`, `punt`, `field_goal`, `extra_point`, `no_play`, `qb_spike`, `qb_kneel`. Administrative rows (GAME_START, END_QUARTER, END_GAME, COMMENT) map to NA. — [nflfastR source, helper_add_nflscrapr_mutations.R](https://github.com/nflverse/nflfastR/blob/master/R/helper_add_nflscrapr_mutations.R)
- The nflverse play-by-play data dictionary is published at nflreadr (v1.5.x). The rendered page did not load its column table in this session, and the source is `vignettes/dictionary_pbp.Rmd` in nflverse/nflreadr. — [nflreadr PBP dictionary](https://nflreadr.nflverse.com/articles/dictionary_pbp.html)
- NCAA sack rules: when two players combine on a sack, each gets half a sack. — [Daily Princetonian stat column](https://www.dailyprincetonian.com/article/2012/09/column-stat-corner-tackling-defensive-statistics)
- NCAA vs NFL divergence: on a sack that causes a fumble, the NCAA credits the fumble but not the sack, while the NFL credits a 0-yard sack, a TFL and a forced fumble. The NCAA also does not credit a 0-yard or positive-yard QB takedown as a sack. — [Sports Info Solutions, "When a sack is not a sack"](https://www.sportsinfosolutions.com/?p=965); [SIS revisited, 2023](https://www.sportsinfosolutions.com/2023/08/07/when-a-sack-isnt-a-sack-revisited)
- Official NCAA Football Statisticians' Manual (authoritative source for tackle/assist, TFL, PBU, hurry and yardage rules; this session could not parse its text): — [NCAA Football Stats Manual PDF](https://s3.amazonaws.com/fs.ncaa.org/Docs/stats/Stats_Manuals/Football.pdf)
- Assisted tackles are recorded when two or more defenders make a tackle together. Some analytics (StatsBomb American football) weight an assist as 0.5 when combining tackles. — [arXiv 2403.14769](https://arxiv.org/html/2403.14769v1)
- HS football: coaches enter stats on MaxPreps.com or in the free "Teams by MaxPreps" app, and state associations take standings and stat leaders from that input. — [GHSA MaxPreps stats](https://www.ghsa.net/maxpreps-stats/football); [NCHSAA MaxPreps instructions](https://www.nchsaa.org/schools/maxpreps-instructions-faqs)
- MaxPreps manual entry is done section by section per athlete, and stats appear on the team page in 15–30 minutes. — [MaxPreps support 202103644](https://support.maxpreps.com/hc/en-us/articles/202103644)
- Some states (e.g., Utah) let a volunteer provide live play-by-play and scoring to MaxPreps. — [UHSAA MaxPreps intro](https://www.uhsaa.org/football/MaxPrepIntro.pdf)
- Third-party stat tools upload to MaxPreps and Hudl. Statman Football (Excel) offers play-by-play and drive summaries with upload to both. — [Statman](https://myweb.fsu.edu/abrady/Statman/)
- QwikCut publishes an "advanced" football stat-entry workflow, an example of video-tagging-based stat entry. — [QwikCut Football Stat Entry – Advanced](https://support.qwikcut.com/portal/en/kb/articles/football-stat-entry-advanced-22-7-2023)
- The historical MaxPreps "MaxStats" app (2010) tracked per play: down, distance, yards gained, play type, score, possession, game clock, hash, penalties. — [CBS Sports press release, 2010](https://www.cbssports.com/info/ir/press/2010/maxstats)
- Coverage is patchy: only about one-third of Washington's 66 Class 4A teams entered stats on MaxPreps for all games in a season. — [HeraldNet](https://www.heraldnet.com/sports/lack-of-centralized-database-leaves-void-for-prep-football-stats)

### Inferences
- **Minimal play record** (based on the nflfastR structure; column names **[unverified, domain knowledge]** from nflfastR usage): `game_id, play_id, qtr, game_seconds_remaining, posteam, defteam, down, ydstogo, yardline_100, play_type, yards_gained, first_down, touchdown, interception, fumble, fumble_lost, sack, penalty(+team, yards, type), safety, field_goal_result, extra_point_result, two_point_conv_result`. Player roles: `passer, rusher, receiver, kicker, punter, returner, solo_tackle_1..2, assist_tackle_1..4, sack_player / half_sack_1..2, qb_hit_1..2, interception_player, pass_defense_1..2, forced_fumble_player, fumble_recovery_player`. nflfastR adds model outputs (EPA, WPA, CPOE) that are irrelevant for youth.
- **Standard individual stats** (box-score convention **[unverified, domain knowledge]**):
  | Group | Stats |
  |---|---|
  | Passing | Comp, Att, Yds, TD, INT, Sacked, Long, Rating |
  | Rushing | Car, Yds, Avg, TD, Long |
  | Receiving | Rec, Yds, Avg, TD, Long, (Targets) |
  | Defense | Solo, Ast, Total Tkl, TFL, Sacks (0.5 units), QB Hurries, INT, PBU, FF, FR, Def TD, Safeties |
  | Kicking | FG M/A (by distance band), XP M/A, Long, Kickoff #/Yds/Touchbacks |
  | Punting | #, Yds, Avg, Long, Inside-20 |
  | Returns | KR/PR #, Yds, TD, Long |
  | Team | First downs (rush/pass/penalty), 3rd/4th-down conv., total yds, turnovers, penalties-yds, TOP, red-zone |
- **Level-specific rule sets matter.** Sack yardage counts as team rushing in NCAA/HS but as passing in the NFL **[unverified, domain knowledge]**, and the fumble-on-sack and 0-yard rules above also differ. Store raw facts (who touched the QB, ball spot, fumble) and let the "stat rule set" (NFHS, NCAA, NFL) compute credits.
- **Youth variants** (no source fetched): flag football has no tackles. Track "flag pulls", no-run zones, and often mandatory-pass rules. 7v7 has no linemen or run game, so mostly passing/coverage stats.
- **Video feasibility:** score changes, TDs, completion vs incompletion, interceptions, ball spot / yards gained (with field-line detection) and play_type (run vs pass) are relatively visual. Tackle and assist attribution, half sacks, QB hurries, PBU vs drop, penalties (flags are visible, type and player are not) and down/distance (which needs chain-crew or scoreboard OCR) need human input or high-quality multi-angle footage.

### Gaps
- Could not extract the NCAA manual's exact tackle/assist, TFL, PBU and hurry definitions (PDF parsing failed). Fetch the PDF and read it directly.
- No authoritative current list of MaxPreps' or Hudl's football entry fields, or of Hudl Assist's tagging fields (Hudl help pages not fetched).
- Found no sourced spec for flag football or 7v7 stat categories (NFL FLAG, USA Football). Needs follow-up.
- NFHS has no public stat manual that I found. HS stat crews generally follow NCAA conventions **[unverified]**.

---

## 2. Soccer: StatsBomb, SPADL/Atomic-SPADL, Opta, Wyscout, kloppy; youth-relevant stats and match timeline

### Takeaway
Soccer has the richest open event standards. StatsBomb open data (now under the Hudl org) provides JSON events, lineups and 360 freeze frames. SPADL (12 attributes, 22 action types) and Atomic-SPADL convert vendor formats into one schema. kloppy is the Python layer that loads ~15 providers into one vendor-neutral event/tracking model. For a youth product, a small subset matters: goals, assists, shots (on target), saves, cards, subs/minutes, corners. That subset maps cleanly onto these models.

### Cited Findings
- StatsBomb open data: free JSON for competitions, matches (per competition/season), events (per match), lineups, and 360 positional freeze frames for some matches. Event specs are in `doc/`. Use requires crediting StatsBomb. The repo now lives at github.com/hudl/open-data, reflecting Hudl's ownership of StatsBomb. — [StatsBomb open-data GitHub](https://github.com/statsbomb/open-data)
- StatsBomb event types (live API guide): starting-xi, half-start/half-end, pass, ball-receipt, ball-recovery, block, clearance, dispossessed, dribble, dribble-past, duel, fifty-fifty, foul-committed, foul-won, goal-keeper, interception, miscontrol, out, own-goal-for/against, shot, substitution, player-off/on, bad-behaviour (cards outside play), stoppage/end-stoppage, referee-ball-drop, tactical-shift. Carry and Pressure exist in the open-data spec but are not on this page. — [StatsBomb Live Data API: event descriptions](https://live-data-api-guide.statsbomb.com/api-reference/event-descriptions.html)
- SPADL: 12 attributes per action: `game_id, period_id, seconds, player, team, start_x, start_y, end_x, end_y, action_type, result, bodypart`, plus `original_event_id` for traceability. — [socceraction SPADL docs](https://socceraction.readthedocs.io/en/latest/documentation/spadl/spadl.html)
- SPADL's 22 action types: pass, cross, throw-in, crossed free kick, short free kick, crossed corner, short corner, take-on, foul, tackle, interception, shot, penalty shot, free kick shot, keeper save, keeper claim, keeper punch, keeper pick-up, clearance, bad touch, dribble, goal kick. Results: success, fail, offside, own goal, yellow card, red card. Body parts: foot, head, other, none (Wyscout gives head/other combined). — [socceraction SPADL docs](https://socceraction.readthedocs.io/en/latest/documentation/spadl/spadl.html)
- Atomic-SPADL: 11 attributes (`x, y, dx, dy` replace start/end, and there is no `result`). Outcomes become separate actions: pass then receival, shot then goal, plus interception and out. — [socceraction Atomic-SPADL docs](https://socceraction.readthedocs.io/en/latest/documentation/spadl/atomic_spadl.html)
- kloppy: vendor-independent model for event and tracking data. Loaders: DataFactory, HawkEye, Impect, Hudl Sportscode, Hudl StatsBomb, Metrica, Opta, PFF FC, SecondSpectrum, Signality, SkillCorner, Sportec, Stats Perform, TRACAB, Wyscout. Event types: Generic, Pass, Shot, TakeOn, Carry, Clearance, Interception, Duel, Substitution, Card, PlayerOn/Off, Recovery, Miscontrol, BallOut, FoulCommitted, Goalkeeper, Pressure, FormationChange. Qualifiers: BodyPart, Card, CounterAttack, Duel, GoalKeeper, Pass, SetPiece. A CoordinateSystem (origin, orientation, pitch dimensions) supports transforms. Exports to pandas/Polars and to SportsCode XML. — [kloppy docs](https://kloppy.pysport.org/)

### Inferences
- **Opta and Wyscout** are proprietary. Opta uses numeric `type_id`s plus qualifiers, and Wyscout uses event/subEvent plus tags **[unverified, domain knowledge]**. kloppy and socceraction already map both, so a product needs no native support for either.
- **Youth/HS soccer stat set** (MaxPreps/GameChanger-style **[unverified, domain knowledge]**):
  | Persona | Stats |
  |---|---|
  | Field player | Goals, assists, shots, shots on goal, minutes played, (yellow/red cards) |
  | Goalkeeper | Saves, goals against, shutouts, minutes, save % |
  | Team timeline | Kickoff/half/end, goals (scorer, assist, minute), cards, subs (in/out, minute), corners, PKs, (offsides, fouls) |
- **Mapping:** these youth stats are a strict subset of SPADL/kloppy. Goal = shot with result success (SPADL) or a goal action (Atomic). An assist is derived from the preceding pass by a teammate. Minutes come from lineup data plus substitution events.
- **Video feasibility:** goals (net or celebration plus a scoreboard change), corners, throw-ins, goal kicks, and cards (visible cards) are fairly detectable. Shots on target vs saves is moderate. Assists (attribution of the last pass), jersey-number player ID on wide or amateur footage, fouls (and which player), offsides, and minutes (which need substitution tracking) need human confirmation. Pass completion at scale needs tracking-quality video, which is unrealistic from a single phone or glasses camera.

### Gaps
- Did not fetch the Opta event-type ID list or the Wyscout v2/v3 API docs.
- Did not fetch the full StatsBomb open-data event spec PDF, so common attributes (`timestamp`, `location`, `possession`, `play_pattern`, `under_pressure`, `related_events`) are **[unverified, domain knowledge]**.
- No sourced list of the soccer fields that MaxPreps or GameChanger collect for HS/youth.

---

## 3. Baseball/softball: scorekeeping, Retrosheet, MLB Stats API/Statcast, GameChanger, pitch-count rules, box score

### Takeaway
Baseball has the most mature event notation. Retrosheet's `play` record (inning, home/visitor, batter, count, pitch sequence, event string with modifiers and runner advances) is essentially a machine-readable scorebook and an excellent canonical model. For youth play, the single most important compliance stat is the **pitch count**, with mandatory rest days (Little League Regulation VI). GameChanger is the dominant youth scorekeeping app.

### Cited Findings
- Retrosheet record types: `id, version, info, start, sub, play, com, data`, plus adjustments (`badj`, `padj`, `ladj`, `radj` for the extra-inning runner, `presadj`). Format: `play,inning,home/visitor,batterID,count,pitches,event`. — [Retrosheet event file](https://www.retrosheet.org/eventfile.htm)
- Retrosheet pitch codes: C called strike, S swinging, F foul, T foul tip, L foul bunt, M missed bunt, B ball, I intentional ball, X in play, H HBP, pickoff throws 1/2/3, `>` runner going, `*` blocked pitch, among others. — [Retrosheet](https://www.retrosheet.org/eventfile.htm)
- Retrosheet event grammar: fielder-number sequences (e.g., `63`: last fielder gets the putout, earlier fielders get assists), `S7`, `K`, `HR`, `W`, `IW`, `HP`, `E5`, `SB2`. Modifiers after `/` (G, L, F, P, SF, SH, FO, GDP...). Advances after `.` (e.g., `2-3`, `1X2`) with parameters such as `(RBI)`, `(NR)`, `(UR)`, `(WP)`, `(E4/TH)`. — [Retrosheet](https://www.retrosheet.org/eventfile.htm)
- Little League daily pitch limits: ages 6–8: 50, 9–10: 75, 11–12: 85, 13–16: 95. Rest for ages ≤14: 1–20 pitches 0 days, 21–35 1 day, 36–50 2 days, 51–65 3 days, 66+ 4 days. Ages 15–16 use thresholds 30/45/60/75. No pitching on three consecutive days. Catcher/pitcher restrictions: 4+ innings caught means no pitching that day, and pitching 21+ pitches (31+ for ages 15–16) means no catching afterward. — [Little League pitch count rules](https://www.littleleague.org/playing-rules/pitch-count/)
- Standard batting/pitching/fielding abbreviation glossaries (AB, 1B/2B/3B, PO, A, E, fielding % = (PO+A)/(PO+A+E)). — [Baseball-Reference batting glossary](https://baseball-reference.com/about/bat_glossary.shtml); [Baseball-Reference pitching glossary](https://www.baseball-reference.com/about/pitch_glossary.shtml); [Cooperstown Cred](https://www.cooperstowncred.com/statistics-glossary/abbreviations/)

### Inferences
- **Box score structure** (convention **[unverified, domain knowledge]**): linescore (runs by inning, R/H/E). Batting: AB, R, H, RBI, BB, SO, 2B, 3B, HR, SB, CS, HBP, SAC/SF, LOB, plus AVG/OBP/SLG/OPS. Pitching: IP, H, R, ER, BB, SO, HR, HBP, WP, BF, **#P (pitches) / strikes**, W-L-SV, ERA, WHIP. Fielding: PO, A, E, DP, plus catcher PB, SB-allowed, CS.
- **GameChanger** (help center blocked, 403) is known to track pitch-by-pitch with live pitch counts, spray charts, and batting/pitching/fielding/catching tabs, including derived stats such as QAB, BABIP and strike %, with pitch-count rest alerts **[unverified, domain knowledge]**. Verify before relying on it.
- **MLB Stats API / Statcast** **[unverified, domain knowledge]**: hierarchical game feed (game → plays → playEvents with pitch data such as `pitchData.startSpeed`, `breaks`, `zone`, and `hitData.launchSpeed/launchAngle/totalDistance`). Statcast CSVs (Baseball Savant) have ~90+ columns per pitch (`pitch_type, release_speed, plate_x/z, events, description, launch_speed, launch_angle, bb_type, hit_location`). Radar-grade metrics are out of scope for glasses video. Pitch-level `description` and `events` enums are still useful vocab.
- **Recommended canonical model:** a Plate Appearance containing ordered Pitches (Retrosheet codes), then an outcome event (Retrosheet-style string or a structured equivalent: `result_type`, `fielders[]`, `batted_ball_type`, `location`), plus RunnerAdvances[] with RBI/earned attribution. Every box-score stat derives from this.
- **Softball**: same model. Rule differences such as innings, the pitching circle and the absence of a balk in some codes go in rule-set config **[unverified]**.
- **Video feasibility:** pitch delivered (count the pitch), swing vs take, contact vs miss, ball in play, home runs, and runner reaching base are fairly visual, and counting pitches from a fixed vantage is a strong, valuable automation target. Balls vs called strikes (which depends on the umpire's call and needs audio or a gesture), pitch type, hit vs error (a scorer's judgment), earned vs unearned runs, RBI edge cases, fielder-sequence assists, and stolen base vs wild pitch need human input.

### Gaps
- GameChanger stat glossary not retrieved (403). Need the exact GC stat list and its pitch-count/rest-day alert behavior.
- MLB Stats API and Statcast docs not fetched this session (statsapi.mlb.com has no official public docs; Baseball Savant has a CSV documentation page).
- USA Softball, NFHS and Perfect Game pitch rules (e.g., NFHS state pitch-count rules, softball having no pitch limit in many codes) not researched.
- MLB/USA Baseball Pitch Smart age guidelines, which differ slightly from Little League, not fetched.

---

## 4. Cross-sport standards and a generic "event + participants + timestamps + video refs" model

### Takeaway
IPTC SportsML 3.0 (2016) is the main open multi-sport interchange standard. It is XML with a generic sports-event, then actions container, plus sport-specific attribute groups and IPTC controlled vocabularies. IPTC's newer Sport Schema (an RDF ontology, 1.1 draft 2023) modernizes it. Neither is widely used in youth tech. The practical pattern is a generic core with sport-specific typed payloads and a pluggable stat rule set.

### Cited Findings
- SportsML 3.0, released July 2016 by IPTC, is an open standard for sports-data interchange that covers the "full gamut of sports events". — [IPTC news](https://iptc.org/news/iptc-releases-sportsml-3-0-standard/)
- SportsML schema: a `sports-event` holds event-metadata, event-stats, team, player, officials, and an `actions` container of individual `action` elements. Attribute groups are sport-specific (e.g., golfActionAttributes, motorRacingActionAttributes) alongside a generic base event-state group. (Source is a third-party XSD mirror, so verify against IPTC.) — [SportsML 3.0.3 XSD mirror](https://schemas.liquid-technologies.com/SportsML/3.0.3/sportsml_xsd.html); [eventActionsComplexType](https://schemas.liquid-technologies.com/SportsML/3.0.3/eventactionscomplextype.html)
- IPTC maintains SportsML controlled vocabularies, extensible to new sports and terms. — [IPTC controlled vocabularies](https://iptc.org/news/controlled-vocabularies-sportsml/); [SportsML guidelines](https://iptc.org/std/SportsML/guidelines/)
- IPTC Sport Schema ontology (1.1 draft, 2023): a high-level model of the core elements of competitive sport, which references SportsML action vocabularies. — [IPTC Sport Schema ontology](https://iptc.org/std-dev/SportSchema/1.1-draft/docs/ontologies/iptc-sport-ontology.html); [EBU overview](https://tech.ebu.ch/publications/iptc-sport-schema--the-next-generation-of-sports-data)
- kloppy already exports soccer events to Hudl SportsCode XML, the de facto clip/timeline interchange for video tagging. — [kloppy](https://kloppy.pysport.org/)

### Inferences
- **Proposed generic model** (synthesis):
  - `Game {id, sport, ruleset (e.g., LL-11U, NFHS-FB, NCAA-FB, FLAG-5v5), teams, venue, start_time, periods}`
  - `Event {id, game_id, seq, sport_type (enum per sport, e.g., fb.play / soc.shot / bb.pitch), period, game_clock, wall_clock_utc, video_refs[{clip_id, t_start, t_end, source_device}], location{x,y, coord_system}, team_id, participants[{player_id, role}], result, qualifiers{...sport-specific JSON}, parent_event_id, confidence, source (auto|human|human-confirmed), provenance}`
  - Roles are per-sport enums: football `passer/rusher/receiver/tackler_solo/tackler_assist/sacker_half/interceptor`, soccer `shooter/assister/keeper/fouler/sub_in/sub_out`, baseball `batter/pitcher/catcher/fielder[seq]/runner[from,to]`.
  - `GameState` snapshots (score, down/dist/yardline; count/outs/base runners; minute) are derived from events, not entered independently.
  - Stats are always derived by a `StatRuleSet` (NCAA vs NFL sack rules, Little League rest-day calculation), never stored as primary data. That allows recomputation after corrections.
- The `source` + `confidence` fields are key for a video-assisted product: auto-detected events stay "proposed" until a human confirms them, and that status flows into which stats are "official."
- Export adapters: nflfastR-like CSV (football), SPADL via socceraction or kloppy (soccer), Retrosheet-like event strings (baseball), MaxPreps/GameChanger import formats (unknown, see Gaps), and SportsCode XML or EDL for video clips.

### Gaps
- Sportradar, Genius Sports and Stats Perform "common models" not researched, and their docs are mostly gated.
- No evidence found of SportsML adoption by youth platforms (MaxPreps, GameChanger, Hudl).
- MaxPreps and GameChanger import/export file formats are undocumented in the sources found.

---

## 5. What coaches, parents, players (recruiting) and refs value; recruiting-platform requirements

### Takeaway
Evidence was thin in this session. Recruiting guidance (NCSA) puts identifying metadata first and favors short, curated highlight reels backed by full-game video. That implies the product's highest-value outputs are accurately attributed per-player clips plus a basic stat line, not advanced analytics. Pitch counts are compliance-critical for youth baseball coaches.

### Cited Findings
- NCSA: the first frame of a highlight video should show name, school, jersey number, position, graduation year and contact info. Update it at least twice a year. Host it on the NCSA profile and YouTube (link back to the profile). — [NCSA tips for creating a great highlight video](https://www.ncsasports.org/blog/tips-creating-great-highlight-video)
- NCSA soccer: highlight reel of about 3–6 minutes with about 20–25 clips for field players. Film from an elevated vantage point. — [NCSA soccer recruiting video](https://ncsasports.org/mens-soccer/recruiting-video-highlights); [inkl/NCSA soccer filming tips](https://www.inkl.com/news/ncsa-tips-for-filming-a-soccer-highlight-video)
- Coaches who like a highlight want a full unedited game next (NCSA basketball guidance). — [NCSA women's basketball highlight video](https://ncsasports.org/womens-basketball/highlight-video)
- Avoid shaky footage and loud spectator audio, which distract evaluators. — [IMG Academy](https://www.imgacademy.com/resources/articles/how-to-make-a-highlight-video); [SoccerWire](https://www.soccerwire.com/soccer-blog/five-tips-for-making-a-great-highlight-video-for-college-soccer-recruiting/)
- Youth baseball pitch counts and rest days are mandatory league rules, so tracking them is a compliance need, not optional. — [Little League](https://www.littleleague.org/playing-rules/pitch-count/)
- HS association standings and stat leaders depend on coach-entered MaxPreps stats, so coaches have an obligation to enter stats. — [GHSA](https://www.ghsa.net/maxpreps-stats/football)

### Inferences
- **Coaches:** compliance (pitch counts), accurate official stats for MaxPreps and association leaderboards, and fast entry. Partial entry rates (about one-third in WA 4A football) suggest entry burden is the pain point.
- **Parents:** their own kid's clips and simple stat lines (goals/assists, hits/RBIs, TDs/yards, tackles). Highly visual events dominate.
- **Players (recruiting):** jersey-number-tagged highlight clips with metadata overlay (name, number, position, grad year), plus full-game video access.
- **Refs:** game timeline (cards, goals, subs; in football, penalties), mainly for game reports. No sources found.
- **Feasibility summary (synthesis of the per-sport notes):**
  | Highly visual / auto-detectable | Moderate (auto plus confirm) | Requires human input |
  |---|---|---|
  | Goals, TDs, HRs, scoreboard changes, pitch delivered (count), kickoffs/punts, corners/throw-ins, cards shown | Run vs pass, completions/INTs, yards gained, shots on target, saves, hits vs outs, ball-in-play type, swing/miss | Tackle/assist credit, half sacks, hurries, PBU, penalty type/player, assists (soccer), fouls/offside, hit vs error, earned runs, ball/strike calls without audio, pitch type, player ID when jersey numbers aren't legible |

### Gaps
- No survey data found on which stats coaches or parents value most. Needs product research (interviews, app-store reviews of GameChanger, Hudl, MaxPreps).
- Did not fetch NCSA's football- or baseball-specific highlight requirements, Hudl highlight/recruiting profile fields, or MaxPreps recruiting profile fields.
- No sources on referee needs (e.g., NFHS or US Youth Soccer match report fields).
