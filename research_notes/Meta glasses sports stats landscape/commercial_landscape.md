# Commercial Landscape: Video-Based Recording, Auto-Stats and Highlights for Amateur/Youth/HS/College Football, Soccer, Baseball/Softball, and Wearable/First-Person Capture

Research date: 2026-11-07. Scope: closed-source commercial products. Most sources are vendor pages, vendor-adjacent comparison blogs, and trade press; pricing from third-party blogs is often inconsistent and is flagged as such. Some vendor pages (e.g., Veo support docs) returned 403 and could not be read directly. Items I could not verify this session are listed under Gaps rather than stated as fact.

## American football: Hudl, Krossover, QwikCut, DVSport/XOS/Catapult, and AI auto play-by-play for youth/HS football

### Takeaway
Hudl dominates youth/HS/college football video. Its "Assist" breakdown is still done mainly by human analysts for football; per Hudl's own FAQ, AI (Balltime) is used only for volleyball. Fully automatic play-by-play and stats from video for youth/HS football is still a thin, early market. Small startups (BallHawk, PlayIQ) say they auto-tag plays and formations, but nobody has published accuracy data. Hudl's competitor QwikCut also uses human taggers.

### Cited Findings
**Hudl Assist (football)**
- Hudl Assist uses "professional human analysts and, in some sports, advanced AI technology". For most sports, trained analysts tag every play, event and stat by hand. Per the FAQ, AI is currently used only in volleyball. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)
- Sports covered by Assist: volleyball, American football, basketball, soccer, lacrosse, ice hockey, baseball, softball, wrestling. Assist+ adds tags for individual skill players in football. Every data point is linked to video, and Assist automatically builds a playlist for every rostered player. Teams can submit up to 3 games per 24 hours. Tiers are Standard vs Express priority, and "Game" vs "Game and Scout". Assist is staffed 24/7, but the FAQ gives no turnaround SLA. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)
- Player identification in Assist: the submitter enters jersey colors, which athletes played, and the final score. Roster and jersey metadata are supplied by humans, and there is no automated identity resolution. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)
- Club football Assist pricing, per team per season (as summarized from Hudl's pricing page):
  - Priority Assist+: $450 for own games, or $1,250 with scout games.
  - Express Priority Assist+: $650, or $1,700 with scout games.
  — [Hudl Assist Pricing, Club Football](https://www.hudl.com/pricing/assist/football)
- Hudl HS package pricing conflicts across third-party sources:
  - One lists Silver+ $1,500, Gold+ $2,500 and Platinum+ $4,000 per program per year. — [hoopbrief](https://hoopbrief.com/blog/how-much-does-hudl-cost-2026)
  - Others list older figures of $900, $1,600 and $3,300. — [visualeyesapp](https://www.visualeyesapp.com/blog/how-much-does-hudl-cost)
  - HS Assist pricing is not published.

**Hudl Focus (capture hardware)**
- Focus is a fixed AI camera that "automatically starts on time and uses AI video analysis to follow the action". It records, uploads and livestreams with no operator. — [Hudl Focus](https://www.hudl.com/products/focus)
- I found no current official Focus price.

**Krossover**
- Hudl acquired Krossover, "one of its largest competitors". Krossover was a breakdown and film service that largely specialized in basketball and was expanding into football.
  - Wikipedia dates the deal to May 2019. — [Wikipedia: Hudl](https://en.wikipedia.org/wiki/Hudl); [FootballScoop](https://footballscoop.com/news/hudl-made-major-announcement)
  - LeadIQ says January 2020. — [LeadIQ](https://leadiq.com/c/krossover/5a1d882e240000240061f736)
  - Crunchbase lists the acquisition. — [Crunchbase](https://www.crunchbase.com/acquisition/hudl-acquires-krossover-intelligence--5c9d2e68)
- Blue Star Sports had acquired Krossover in 2017. — [Wikipedia: Hudl](https://en.wikipedia.org/wiki/Hudl)

**QwikCut**
- QwikCut is a football and soccer game-film platform aimed at HS athletic directors and youth leagues. — [QwikCut Football](https://qwikcut.com/football/); [QwikCut AD packages](https://www.qwikcut.com/athletic-directors/)
- Its QwikStats service is human: "our analysts will tag your games in as little as 12 hours". — [QwikCut](https://qwikcut.com/football/)
- It also offers videography services, i.e., humans film the games. — [QwikCut Videography](https://www.qwikcut.com/videography/)
- Its tagging schema covers formation and play type, with formation-based filtering. — [QwikCut](https://www.qwikcut.com/lp/double-storage-2022/)

**AI football film startups**
- BallHawk: "AI film analysis built for high school football". It says it auto-tags plays, formations and tendencies from game film "in minutes". Film comes in from Hudl, Catapult or local files and exports to Hudl, CSV or Excel. All claims are vendor marketing. — [BallHawk](https://ballhawkfootball.com/)
- PlayIQ: automatically splits uploaded film into individual plays and claims 22-player tracking. It recommends a high sideline angle, so it depends on conventional elevated camera footage. — [PlayIQ](https://theplayiq.com/ai-football-film-analysis/)
- SportsVisio does not currently do football. Its platform works with court sports (basketball, volleyball). Its June 2025 raise was earmarked for "new sports, including baseball". — [SportsPro](https://www.sportspro.com/news/sportsvisio-sony-investment-fund-tech-ai-june-2025/); [The AI Insider](https://theaiinsider.tech/2025/06/20/sportsvisio-secures-3-2m-additional-funding-to-scale-ai-sports-solution/)

**Incumbents**
- A dated UNL honors thesis lists XOS Digital and DVSport as Hudl competitors in college/pro football video. — [UNL thesis](https://digitalcommons.unl.edu/cgi/viewcontent.cgi?article=1275&context=honorstheses)

### Inferences
- In football, the expensive and slow step is still human breakdown: tagging down, distance, formation, play type, result and the players involved. Hudl monetizes it as a per-team-per-season service ($450 to $1,700 for club teams), and QwikCut quotes a 12-hour turnaround. An AI product that produces equivalent breakdown in minutes at youth price points targets a real, paid pain point.
- Every incumbent football workflow assumes an elevated sideline or end-zone camera. Football's line-of-scrimmage occlusion and helmeted, look-alike players make automatic player identification hard. Even Hudl relies on humans plus roster metadata.
- A sideline-worn POV camera (coach or parent) does not replace the elevated all-22 angle coaches want for scheme analysis. It could, however, capture individual-player-centric moments (e.g., "my kid's plays") that all-22 breakdowns serve poorly.

### Gaps
- No verified current pricing for Hudl Focus cameras, Hudl Sideline, DVSport, XOS (Thunder) or Catapult football video (formerly SBG/XOS-related products). I did not verify current XOS/Catapult corporate relationships this session.
- No independent accuracy benchmarks for BallHawk, PlayIQ, or any automatic football tagging.
- Pixellot football-specific automation (beyond auto-production) was not verified.
- Whether Hudl has launched AI auto-tagging for football in 2026 is unclear. The FAQ language says AI is volleyball-only, and the page is undated.

## Soccer: Veo, Pixellot, Trace, Spiideo, XbotGo, Hudl Focus, Once, Track160, Metrica, Playermaker, Wyscout/StatsBomb/Kinexon

### Takeaway
Soccer is the most automated of the three sports. AI cameras (Veo, Pixellot, Spiideo, XbotGo, Hudl Focus) handle unmanned capture and auto-follow, and Veo and Trace layer on automatic event detection and per-player clips. Player identity usually comes from:
- jersey-number OCR (Veo: reliable for numbers 1 to 50, all numbers must be unique, needs contrast);
- a wearable beacon (Trace); or
- a manual roster plus claiming.
Deep event data (Wyscout, StatsBomb) is pro-oriented and largely human-collected.

### Cited Findings
**Veo**
- Pricing is quote-based. Cam 3 is cited around EUR 1,294, or bundled with some plans. Other sources say $2,000 or more, which conflicts. Subscription tiers run from Starter (1 team, 10 recording hours a month) to Enterprise (20 teams, 600 hours), with add-ons for analytics and streaming. — [soccerstories](https://soccerstories.net/pixellot-vs-veo-vs-hudl/); [sportssteps](https://sportssteps.com/pixellot-vs-veo-vs-xbotgo-best-ai-cameras-youth-sports/)
- A third-party comparison reports individual player stats "since August 2026" via the paid Veo Analytics 2 add-on. I could not confirm this on Veo's site. — [soccerstories](https://soccerstories.net/pixellot-vs-veo-vs-hudl/)
- Veo's own pages:
  - Analytics 2 links player names to stat data through jersey numbers.
  - Recognized numbers are 0 to 99. Numbers 1 to 50 typically perform better, every player needs a unique number, and strong number/shirt contrast helps.
  - Players can "claim" their jersey number in the Veo app to see their stats and moments.
  - Player Moments (auto per-player clips) requires the Veo Player Spotlight add-on.
  — [Veo support: Analytics 2](https://support.veo.com/hc/en-us/articles/49272029444241-How-to-get-the-best-results-with-Veo-Analytics-2) (via search snippet; the page returned 403 when fetched); [Veo Player Moments](https://support.veo.com/hc/en-us/articles/27698176364817-Overview-of-Veo-Player-Moments-How-to-track-and-follow-players-in-your-Veo-recordings); [Veo Player Spotlight](https://www.veo.com/product/veo-player-spotlight); [Veo App](https://www.veo.com/en-us/product/veo-app)
- Veo funding is about $111M to $113M total. The last round found was a $79M Series C in June 2022. No 2026 round was found. — [multiples.vc](https://multiples.vc/private-comps/veo); [Clay](https://www.clay.com/dossier/veo-funding)

**Pixellot**
- Portable Air NXT is about $949 to $1,149 plus subscription. Other sources cite Air at $849 with a $69/month Lite plan, or about $199/month per team (basketball). Pricing is inconsistent and not vendor-published. — [sportssteps](https://sportssteps.com/pixellot-vs-veo-vs-xbotgo-best-ai-cameras-youth-sports/); [hoopbrief](https://hoopbrief.com/blog/pixellot-cost-2026)
- Positioned for institutions at scale. Advanced analytics come via third parties. — [soccerstories](https://soccerstories.net/pixellot-vs-veo-vs-hudl/)
- Funding:
  - $161M Series D led by PSG (2022). — [Sportico](https://www.sportico.com/business/tech/2022/pixellot-israeli-sports-tech-1234682156/)
  - Over $200M total across four rounds. — [Wikipedia](https://en.wikipedia.org/wiki/Pixellot)
  - Owler lists $253.3M total including $20M debt in January 2026 (aggregator, unverified). — [Owler](https://www.owler.com/company/pixellot)
- Acquired VidSwap (video analysis) in 2019. — [Wikipedia](https://en.wikipedia.org/wiki/Pixellot)

**XbotGo**
- Falcon Standard pack is $699. Tracking, recording and livestreaming need no subscription. It is a phone-on-gimbal (BYOD) design. AI match analysis is "still in development" with pricing TBD. — [sportssteps](https://sportssteps.com/pixellot-vs-veo-vs-xbotgo-best-ai-cameras-youth-sports/); [soccerstories](https://soccerstories.net/veo-go-vs-xbotgo-falcon-ai-camera/)

**Trace (PlayerFocus)**
- Pairs a wide-angle camera with a wearable BLE beacon on each player, which provides identity and auto-edits per-player highlight reels. It targets parents and club players.
- Pricing (from Trace's own blog):
  - PlayerFocus Basic: $180/yr or $25/mo.
  - PlayerFocus Pro: $300/yr or $35/mo.
  - Annual plans include the TraceCam (valued at $795). Monthly plans carry a $99 camera lease fee.
  - PlayerFocus Analytics adds possession and performance data.
  — [Trace Academy (vendor blog)](https://traceup.com/academy/best-ai-sports-cameras-for-automatically-recording-youth-games-in-2026)

**Spiideo**
- Fixed camera systems with automatic tracking. SmartCam has an AI Tracker for player and ball movement. Entry pricing is around $3,800/yr for one team, or about $6,100 for clubs (third-party). Customers are leagues, academies and clubs. — [socceredu](https://www.socceredu.com/en-US/blog/camera-video-analysis); [renderfoot](https://www.renderfoot.com/blog/football-video-analysis-software)

**Analysis tools and sensors**
- Metrica Sports: automatic player and field tracking from existing video "without any special hardware". PlayBase is for amateur/semi-pro coaches and Nexus for elite analysts. — [sportsdatacampus](https://english-programs.sportsdatacampus.com/football-video-analysis-software/); [slashdot](https://slashdot.org/software/p/Metrica-Sports-PLAY/alternatives)
- Once Sport: a tagging plus 3D telestration tool used by pro clubs. Mainly manual tagging. — [sportsdatacampus](https://english-programs.sportsdatacampus.com/football-video-analysis-software/)
- Track160: Israeli company founded in 2017. Automated football analytics with tracking, automated event tagging and highlights. — [CB Insights](https://www.cbinsights.com/investor/track160)
- Playermaker: shoe-mounted IMU wearable for players aged 8 and up. Measures technical metrics (touches, releases, speed). About $180 to $200 plus a mandatory membership (third-party). — [Playermaker](https://www.playermaker.com/); [socceredu GPS](https://www.socceredu.com/en-US/blog/gps-trackers-soccer); [soccerwares](https://soccerwares.com/blogs/our-blogs/soccer-gps-tracking)
- Hudl Assist for soccer is human-tagged. Assist+ adds "more granular, player-specific soccer data". — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)

### Inferences
- Soccer capture is commoditizing. Hardware ranges from $699 (XbotGo) to about $1,000 (Pixellot Air) to about $1,300 to $2,000+ (Veo), and value is migrating to subscriptions for analytics and per-player highlights.
- Identity is the weak link. Jersey OCR from a wide, distant camera is fragile (Veo itself warns about numbers above 50 and low contrast). Trace solves identity with per-player beacons, which adds hardware and friction.
- A wearable POV device worn by a parent or coach who naturally tracks one player could sidestep identity entirely: the wearer is effectively "following" their target. This is a structural advantage for "my player" highlights, though not for team tactics.

### Gaps
- Could not confirm Veo's August 2026 player-stats launch on a primary source (the support page returned 403).
- No verified details this session on Wyscout, StatsBomb (now part of Hudl per background knowledge, unverified), or Kinexon. Their event data is understood to be largely human-collected or optical/UWB for pros, but this was not verified.
- Once Sport and Track160 pricing were not found.

## Baseball/softball: GameChanger, Rapsodo, TrackMan, Hawk-Eye, Pitchlogic, Diamond Kinetics, Blast, Pixellot, AI auto-scoring

### Takeaway
Youth and HS baseball/softball runs on manual scorekeeping (GameChanger dominates), with video clips keyed off human-logged plays. I found no commercial product that auto-scores a youth baseball game from video. Ball-flight radar and optical devices (Rapsodo, TrackMan) and bat/ball/sleeve IMU sensors (Blast, Diamond Kinetics, Pitchlogic) measure individual swings and pitches, not game events. Auto-scoring from video is therefore an open gap.

### Cited Findings
**GameChanger**
- Automatic clips are generated from scored plays: hits (single, double, triple, HR) and most out types. A clip is created once a play is logged, "so scoring in real time is essential". Streamed-and-scored games get a clip of each hit after the game ends. — [GameChanger Help: Automatic Video Clips](https://help.gc.com/hc/en-us/articles/4482237253517-Automatic-Video-Clips-for-Baseball-Softball); [gc.com](https://gc.com/post/automatic-hit-clips)
- GameChanger promotes "AutoStream: AI-Driven Innovation for Hands-Free Streaming", listed under basketball, not baseball. — [GameChanger Content Hub](https://gc.com/content-hub)
- Competitor Rizzler claims AI lineups and pitch-location scoring, and rates GameChanger as having no AI features. This is a competitor's characterization. — [Rizzler](https://rizzlersports.com/learn/best-baseball-scorekeeping-apps)
- Scorekeeping features overview. — [GameChanger scorekeeping](https://gc.com/app-features/scorekeeping)

**Sensors** (single-blog prices, internally inconsistent)
- Diamond Kinetics sensor is about $99 to $149, with an app at around $9.99/month. Rapsodo Pitching 2.0 runs from $299 plus about $240/yr software, while full units run $3,000+. Blast Motion sensors are $99 to $150. — [mindandmuscle.ai pitching](https://mindandmuscle.ai/best-baseball-apps-for-pitchers); [mindandmuscle.ai hitters](https://mindandmuscle.ai/best-baseball-apps-for-hitters)

**Pixellot**
- Pixellot lists baseball/softball. DoublePlay (multi-camera baseball) pricing is not public and is aimed at larger programs. — [hoopbrief](https://hoopbrief.com/blog/pixellot-cost-2026); [linkedin review](https://www.linkedin.com/pulse/pixellot-review-features-ai-sports-camera-micah-ocran)

**SportsVisio and Hudl**
- SportsVisio plans baseball but has not launched it (as of the June 2025 funding). — [SportsPro](https://www.sportspro.com/news/sportsvisio-sony-investment-fund-tech-ai-june-2025/)
- Hudl Assist covers baseball and softball with human analysts. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)

### Inferences
- Baseball is structurally well-suited to auto-scoring: discrete plays, a fixed geometry and a slow pace. Yet the market's dominant workflow is a parent manually scoring on a phone. A product that auto-logs pitches, balls in play and outcomes from video, even with human confirmation, would cut GameChanger's core friction.
- First-person angle: a catcher-, umpire- or dugout-coach-worn camera offers views that fixed cameras don't. Examples include the strike-zone view from behind the plate and pitch sequencing. Sensors such as Blast and Diamond Kinetics already own individual swing metrics, so game-context video plus identity is the open lane.

### Gaps
- Pitchlogic, TrackMan (youth/HS portable B1 or similar), and Hawk-Eye (pro-only) pricing and capabilities were not verified this session.
- GameChanger's ownership (DICK'S Sporting Goods, per background knowledge) and user numbers were not verified.
- I found no evidence of any startup shipping video auto-scoring for amateur baseball. That could mean none exists or that search coverage was insufficient.

## Multi-sport AI stats and auto-highlight startups (SportsVisio, Balltime, Reely, WSC Sports, Magnifi, Playsight, etc.)

### Takeaway
Real AI auto-stats in amateur sports have shipped first in court sports: volleyball (Balltime, now Hudl) and basketball (SportsVisio). Auto-highlight engines (WSC Sports, Magnifi, Reely) are mostly B2B tools for leagues and broadcasters. The pattern is that AI startups get acquired by Hudl, which made 5 acquisitions in 2025 alone.

### Cited Findings
**Balltime (volleyball)**
- Hudl acquired Balltime (Tel Aviv, founded 2022) on February 6, 2025. — [Mergr](https://mergr.com/transaction/hudl-acquires-balltime); [Hudl blog](https://www.hudl.com/blog/hudl-expands-volleyball-focus-through-game-changing-acquisition-of-balltime); [Silicon Prairie News](https://siliconprairienews.com/2025/06/lincoln-based-hudl-acquires-titan-sports-and-balltime-expanding-access-to-performance-data-for-athletes/)
- Balltime uses computer vision to track player movements and ball contacts automatically, with metrics such as serve speed and attack height "within minutes". It "may miss minor details when players block the view". It requires endline video and is available only for club volleyball teams. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq); [Hudl blog](https://www.hudl.com/blog/hudl-expands-volleyball-focus-through-game-changing-acquisition-of-balltime)

**SportsVisio (basketball, volleyball)**
- Raised $3.2M in June 2025, bringing total funding to $9M. Investors include Sony Innovation Fund, Mighty Capital, Alumni Ventures, Sapphire Sport, Hyperplane and Sovereign's Capital. Used by 150+ leagues, clubs and teams. — [SportsPro](https://www.sportspro.com/news/sportsvisio-sony-investment-fund-tech-ai-june-2025/)
- Other trackers conflict: PitchBook says $10.7M. Startup Geek lists an undisclosed April 2026 round led by 359 Capital (unverified aggregator). — [PitchBook](https://pitchbook.com/profiles/company/496668-70); [Startup Geek](https://startupgeek.com/funded/sportsvisio)

**Auto-highlight engines**
- WSC Sports: $100M Series D led by ION Crossover Partners (circa 2022). About $136M total per aggregators, though totals are inconsistent. — [Front Office Sports](https://frontofficesports.com/article/highlights-creator-wsc-sports-lands-100m-funding-round/); [StartupHub](https://www.startuphub.ai/startups/wsc-sports)
- REELY: multi-year deal with NFHS Network for AI-detected real-time highlights in HS sports (an older announcement, circa 2019). — [NFHS](https://www.nfhs.org/articles/reely-selected-by-nfhs-network-for-real-time-highlights-in-high-school-sports/)
- Magnifi: about $3.6M raised, seed stage. — [Tracxn](https://tracxn.com/d/companies/magnifi-ai/__1fPHgqm6HyNIr9meC0J8GM1fD-wceVcMIeEY0l_0ABs)
- Pitz (youth highlights): about $345K raised, listed by Tracxn as "deadpooled". — [Tracxn](https://tracxn.com/d/companies/magnifi-ai/__1fPHgqm6HyNIr9meC0J8GM1fD-wceVcMIeEY0l_0ABs)

### Inferences
- AI auto-stats work first where the view is constrained and the action discrete. That means court sports filmed from a fixed endline or baseline. Outdoor field sports with 22 players (football, soccer) lag.
- Hudl's habit of buying AI startups (Balltime) suggests the likely exit path for a successful youth AI-stats product is acquisition by Hudl or a peer (Pixellot, Veo, GameChanger).
- The youth consumer auto-highlight space has casualties (Pitz). Distribution and monetization are hard, and B2B through leagues and associations (REELY to NFHS) has been the more durable path.

### Gaps
- Playsight, Hoopsalytics, ShotTracker, Minute Media, Twelve Labs sports and Google Gemini sports demos were not researched this session due to the tool-call budget.
- No 2025 or 2026 funding confirmed for WSC, Magnifi or Reely.

## First-person / wearable sports capture (GoPro, referee cams, helmet cams, smart-glasses sports apps)

### Takeaway
Pro leagues are mainstreaming referee POV:
- Bundesliga RefCam, a Riedel headset camera over private 5G, continues into 2026-27.
- FIFA deployed referee body cameras at the 2026 World Cup (weaker source).
- IFAB opened body-cam trials to domestic competitions.

On consumer smart glasses, Meta's Wearables Device Access Toolkit (public preview) now gives phone apps access to the 12MP camera and mics. Early users are mostly streaming (Twitch) and golf (18Birdies). I found no shipping smart-glasses app that produces team-sport stats or highlights, which leaves that segment open.

### Cited Findings
**Referee cams**
- Bundesliga RefCam continues into 2026-27 on "Platinum Matches": 15 Bundesliga and 5 Bundesliga 2 games per season. It is built by Riedel (MindFly also trialed), headset-mounted, and sends audio and video over private 5G. Testers preferred the headset perspective because it moves with the referee's head. — [Sports Video Group, Apr 2026](https://www.sportsvideo.org/2026/04/07/a-new-pov-refcams-rise-in-the-bundesliga-signals-a-potential-new-era-for-soccer-broadcasts/); [SVG Europe](https://www.svgeurope.org/blog/headlines/boosting-the-broadcast-bundesligas-refcam-and-man-of-the-match-evolution/)
- Germany widened bodycam use. IFAB said body-camera trials can extend to domestic competition organizers who apply (AP via Yahoo, 2025). — [Yahoo Sports/AP](https://sports.yahoo.com/article/soccer-referees-tech-extended-announce-123233746.html)
- FIFA "Referee Body Camera" was reportedly used across all 104 matches of the 2026 World Cup. The source is a rental-company blog, so verify independently. — [DFI Rentals](https://www.dfirentals.com/news/fifa-refcam-coolest-camera-tech-2026-world-cup)
- Premier League: referee Jarred Gillett wore a RefCam in a 2024 Crystal Palace vs Man United match (single secondary source). — [DFI Rentals](https://www.dfirentals.com/news/fifa-refcam-coolest-camera-tech-2026-world-cup)

**Meta glasses and developer access**
- Meta Wearables Device Access Toolkit is in public preview. Phone apps can receive camera imagery from the 12MP ultra-wide camera and use the 5-mic array and open-ear speakers.
- Limits:
  - Apps cannot display on the HUD.
  - Apps don't run on the glasses.
  - Meta AI is not supported at launch.
  - Neural Band gestures are excluded.
  - Publishing is limited to restricted audiences during the preview.
  — [UploadVR public preview](https://www.uploadvr.com/meta-wearables-device-access-toolkit-public-preview/); [UploadVR announcement](https://www.uploadvr.com/meta-wearables-device-access-toolkit-announced-smart-glasses-sdk/); [Road to VR](https://roadtovr.com/meta-ray-ban-smart-glasses-third-party-app-sdk-device-access-toolkit/); [Meta for Developers](https://developers.meta.com/wearables/)
- Early adopters: Twitch tested hands-free POV streaming from Ray-Ban Meta, and golf app 18Birdies is cited as a toolkit user. A community proof-of-concept sent camera frames to a vision model for exercise form feedback (a demo, not a product). — [Social Media Today](https://www.socialmediatoday.com/news/meta-enables-third-party-developers-build-for-ai-glasses/760593/); [Nervegna Substack](https://nervegna.substack.com/p/metas-wearables-developer-center)

**Meta sports hardware**
- Meta's sports positioning centers on Oakley Meta (Vanguard at $499). It offers voice-activated fitness stats (heart rate, pace, distance) through Garmin pairing and post-workout summaries. This is endurance-oriented, not team sports. — [Meta: AI glasses for sports](https://www.meta.com/ai-glasses/sports/); [thesmarterplay](https://thesmarterplay.com/sports/tech/best-ai-smart-glasses-athletes-2026)
- Battery: up to 4 hours for Ray-Ban Meta Gen 1 and up to 8 hours for Gen 2. — [thesmarterplay](https://thesmarterplay.com/sports/tech/best-ai-smart-glasses-athletes-2026); [GSMArena](https://m.gsmarena.com/meta_rayban_display_and_rayban_meta_gen_2_smart_glasses_debut-news-69560.php)
- A 2026 roundup says Meta and Solos glasses "don't track performance metrics" natively. This conflicts with Meta's Garmin-paired claims, and is likely about the base models. — [thesmarterplay](https://thesmarterplay.com/sports/tech/best-ai-smart-glasses-athletes-2026)

**Snap Spectacles**
- Spectacles 5 is developer-focused, with a consumer AR version forthcoming. No sports coaching or stats app was found. — [cybernews](https://cybernews.com/vr-ar/best-camera-glasses/)

### Inferences
- Demand for POV footage is validated at the top of the market: broadcasters pay for 5G referee headset cams. At the amateur level, nobody packages wearer POV into stats or highlights.
- The Meta toolkit makes a glasses-to-phone-to-cloud vision pipeline technically feasible today: camera frames stream to the phone app, then go to a multimodal model. Constraints include no HUD output, preview-only distribution, battery (4 to 8 hours is adequate for one game), and the fact that the wearer's head motion is the camera motion.
- Referee and umpire POV is an analogous amateur opportunity. Youth referee assessment and training, and umpire strike-zone review, need footage that fixed cameras don't provide.

### Gaps
- No verified info on NFL referee cams in 2025 or 2026, helmet-cam products for youth football, GoPro's sports-specific programs, or smart-glasses sports apps on Xreal, Vuzix, Solos or Even Realities.
- Did not verify whether any app built on the Meta toolkit has shipped publicly beyond the preview.

## Market size, funding, and acquisitions

### Takeaway
Hudl is the consolidator: about 18 acquisitions, 5 of them in 2025 (Balltime, FastModel, Titan Sports, ADI). Earlier deals include Krossover, Wyscout and Sportstec. Pixellot is the best-funded camera player (over $200M). Veo raised about $111M (last round 2022). Hudl's revenue and valuation figures are third-party estimates and conflict widely. I found no credible market-size number specific to youth sports video technology.

### Cited Findings
**Hudl**
- About 18 acquisitions, 5 in 2025: Balltime, FastModel, Titan Sports, Athletic Data Innovations and others. — [Hudl 20 years, Silicon Prairie News, Jun 2026](https://siliconprairienews.com/2026/06/hudl-celebrates-20-years-demonstrating-global-growth-and-reach-in-sports-video-analysis/); [Mergr FastModel](https://mergr.com/transaction/hudl-acquires-fastmodel-holdings)
- Hudl acquired Wyscout and Krossover in 2019, and Sportstec (Sportscode) in 2015. — [UNL thesis](https://digitalcommons.unl.edu/cgi/viewcontent.cgi?article=1275&context=honorstheses); [Wikipedia: Hudl](https://en.wikipedia.org/wiki/Hudl)
- Funding: about $236M over 10 rounds, the latest a $120M Series E on May 21, 2020 (CB Insights). PitchBook says $228M and Latka $108.9M. — [CB Insights](https://www.cbinsights.com/company/hudl/financials); [PitchBook](https://pitchbook.com/profiles/company/56408-68)
- Revenue and valuation are unreliable third-party estimates: Latka gives $730.4M revenue and a $5.1B valuation, while other sources range from $69M to $638M. — [Latka](https://getlatka.com/companies/hudl); [techlist.ai](https://techlist.ai/hudl.com)
- Users: estimates range from 3.5M customers to 6M users. Volleyball alone has 27,000 organizations and 400,000+ users. — [Youth Sports Business Report](https://youthsportsbusinessreport.com/exclusive-how-hudl-built-americas-largest-amateur-sports-media-platform-with-adam-gouttierre-vice-president-of-media-at-hudl/); [Hudl blog](https://www.hudl.com/blog/hudl-expands-volleyball-focus-through-game-changing-acquisition-of-balltime)

**Others**
- Pixellot: $161M Series D (2022, PSG) and over $200M total. A $20M debt facility in January 2026 is reported only by Owler. — [Sportico](https://www.sportico.com/business/tech/2022/pixellot-israeli-sports-tech-1234682156/); [Wikipedia](https://en.wikipedia.org/wiki/Pixellot); [Owler](https://www.owler.com/company/pixellot)
- Veo: about $111M total, with a $79M Series C in June 2022. — [multiples.vc](https://multiples.vc/private-comps/veo)
- SportsVisio: $9M total (June 2025). — [SportsPro](https://www.sportspro.com/news/sportsvisio-sony-investment-fund-tech-ai-june-2025/)
- WSC Sports: about $136M total. — [StartupHub](https://www.startuphub.ai/startups/wsc-sports)

**Market size**
- The only figure found is the broad "$54 billion youth sports market", which is not specific to video tech. — [Youth Sports Business Report](https://youthsportsbusinessreport.com/exclusive-how-hudl-built-americas-largest-amateur-sports-media-platform-with-adam-gouttierre-vice-president-of-media-at-hudl/)

### Inferences
- Capital is concentrated in capture hardware (Pixellot, Veo) and the platform incumbent (Hudl). AI-stats startups raise small rounds (SportsVisio at $9M) and tend to be absorbed.
- A new entrant should plan for Hudl interoperability (export to Hudl, as BallHawk does) rather than head-on competition.

### Gaps
- No credible TAM for amateur sports video, analytics or highlights. The report writer should not cite a market-size figure from these notes beyond the general $54B youth-sports number.
- Spiideo, Trace and XbotGo funding were not found.

## Notable gaps an AI-from-smart-glasses product could exploit

### Takeaway
The incumbent stack assumes a fixed, elevated, wide-angle camera with team-level outputs. Identity and per-player stats are bolted on through human tagging (Hudl Assist, QwikCut), fragile jersey OCR (Veo), or per-player beacons (Trace). Baseball scoring is still manual (GameChanger). A wearer-POV product has four openings:
- the wearer implicitly selects the subject, which solves identity;
- capture without a tripod or mount;
- voice annotation in the moment;
- views fixed cameras cannot get (umpire, referee, coach, catcher).

### Cited Findings
- Human tagging is the paid bottleneck in football: Hudl Assist is human-tagged, $450 to $1,700 per team per season for club football. QwikCut quotes up to 12 hours. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq); [Hudl pricing](https://www.hudl.com/pricing/assist/football); [QwikCut](https://qwikcut.com/football/)
- Jersey-number identity is fragile: Veo says numbers 1 to 50 work best, numbers must be unique, and contrast matters. — [Veo support](https://support.veo.com/hc/en-us/articles/49272029444241-How-to-get-the-best-results-with-Veo-Analytics-2)
- The beacon approach adds hardware per player. — [Trace](https://traceup.com/academy/best-ai-sports-cameras-for-automatically-recording-youth-games-in-2026)
- Baseball clips depend on manual real-time scoring. — [GameChanger Help](https://help.gc.com/hc/en-us/articles/4482237253517-Automatic-Video-Clips-for-Baseball-Softball)
- Even AI-native Balltime struggles with occlusion and needs a specific endline camera. — [Hudl Assist FAQ](https://www.hudl.com/products/assist/faq)
- Glasses camera access exists, with constraints: no HUD output, preview-limited publishing, and phone-side processing. — [UploadVR](https://www.uploadvr.com/meta-wearables-device-access-toolkit-public-preview/)
- Pro leagues validate POV as compelling content. — [SVG 2026](https://www.sportsvideo.org/2026/04/07/a-new-pov-refcams-rise-in-the-bundesliga-signals-a-potential-new-era-for-soccer-broadcasts/)

### Inferences
- **"My player" highlights.** A parent's gaze already follows their child. Glasses footage plus a voice cue ("that was Jake") could produce per-player reels without beacons or OCR. This competes with Trace PlayerFocus ($180 to $300/yr) and the Veo Player Spotlight add-on.
- **Voice-assisted stat logging.** A coach or parent says "strikeout looking" or "Jake, 7-yard run" and the system pairs the call with the clip. This hybrid of human labels and AI segmentation could undercut Hudl Assist turnaround and fix GameChanger's need for manual scoring, especially in baseball/softball, where no automatic video scorer was found.
- **Official and umpire POV for amateur training and assessment.** Pro RefCams show the angle has value. Youth referee development lacks tools.
- **Weaknesses to acknowledge:**
  - Head-motion jitter.
  - Partial field of view, so no all-22 or tactics.
  - 4 to 8 hour battery.
  - Meta preview-only distribution.
  - Privacy and consent when filming minors.
  - Football coaches will still want elevated all-22 film from Hudl.
  Positioning as a complement (e.g., export to Hudl or GameChanger) is likely more viable than replacement.

### Gaps
- No user research (Reddit r/footballcoaching, r/bootroom, r/Homeplate) was gathered this session to confirm parent and coach willingness to pay for POV-based highlights. This remains a key open question.
- No evidence was found either way on whether Meta allows youth-sports filming use cases under its developer policies.
