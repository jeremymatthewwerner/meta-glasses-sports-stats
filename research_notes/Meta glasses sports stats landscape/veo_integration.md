# Veo (AI sports camera) as a secondary input source: product, outputs, export paths, ToS, and alternatives

Research date: 2026-11-07. Note on sources: veo.co now 301-redirects to veo.com. The Veo help center (support.veo.com), the Veo Ideas Board (veo.nolt.io) and the developer pages returned HTTP 403 to direct fetches, so claims from those pages come from search-result snippets, not full-page reads. Treat them as somewhat less certain than claims from veo.com pages that were read in full. Watch for name collisions: most "Veo pricing/API" search results are about Google's Veo video-generation model, which has nothing to do with Veo Technologies (the Danish sports-camera company).

## 1. Veo hardware: camera specs, stitching, resolution, follow-cam vs panorama, recording length, sports

### Takeaway
Veo Cam 3 (and a 5G variant) has two synchronized lenses, marketed as "dual 4K", stitched into a 180° panorama of the whole pitch. From that panorama the AI crops a 1080p broadcast-style "follow-cam" view. Veo says the full panoramic source is always kept, and users can view it in "Interactive"/panoramic mode in the Editor. The camera sits on a mast up to about 7.4 m (24.3 ft) high. Veo markets it for about ten team sports, but its AI analytics are soccer-first.

### Cited Findings
- The follow-cam is built from a panoramic video stitched from "two synchronized streams". It has "180° field coverage", the follow-cam output is "1080p, always on the action", and it is "generated the instant you hit record" — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3)
- Veo's machine-readable site summary says its cameras use "dual 4K lenses" to record the "entire pitch/field (180° view) continuously", and that the full panoramic source file is always preserved alongside the AI-generated follow view. Users can zoom out or pan to recover off-ball action — [veo.com/llms.txt](https://www.veo.com/llms.txt)
- Conflicting resolution claims: Veo's support comparison table lists Veo Cam 3 at 4K / 30 fps (same as Cam 2). The product page headlines 1080p, and retailers list "1080 HD". The likely reconciliation is 4K-class capture with 1080p follow-cam output, but this is not confirmed — [Veo support: Compare Veo Cam 2, 3, 3 5G](https://support.veo.com/hc/en-us/articles/22689559243537) (snippet only); [Unisport retailer listing](https://www.unisportstore.com/accessories/veo-cam-3/433784)
- Battery: "up to 6.5 hours" while recording and livestreaming, and the camera can be used while charging. Another Veo page and a retailer say about 4.5 hours — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3); [Unisport](https://www.unisportstore.com/accessories/veo-cam-3/433784)
- Weight is 1.25 kg (2.8 lb). It operates from -10 °C to 45 °C (14–113 °F) and records in rain or snow. Software includes "SteadyView" post-recording smoothing, wind-noise reduction, and phone remote control — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3)
- Tripod/mast: the small tripod reaches 17.1 ft (about 5.2 m) and weighs 13.4 lb. The large tripod reaches 24.3 ft (about 7.4 m) and weighs 15.6 lb — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3)
- The 5G variant adds a 4G/5G SIM for livestreaming without Wi-Fi. The standard model uses Wi-Fi or a hotspot — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3); [Veo support comparison](https://support.veo.com/hc/en-us/articles/22689559243537) (snippet)
- Recordings upload automatically once the camera is online, and are typically available for review "within a few hours" — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3); [Veo football page](https://www.veo.com/sport/football)
- Sports listed: soccer, indoor soccer, rugby, lacrosse, basketball, ice hockey, American football, field hockey, baseball, "and other sports". llms.txt also lists volleyball — [Veo Cam 3 product page](https://www.veo.com/en-us/product/veo-cam-3); [veo.com/llms.txt](https://www.veo.com/llms.txt)
- Camera price in the US shop: $999 one-time, plus a required per-camera subscription — [Veo US shop](https://us.shop.veo.co/)
- **Veo Go** (phone-based alternative): it turns two or three iPhones on a Veo rig and tripod into a stitched camera. One phone controls, and each camera phone records half the field. Footage uploads over Wi-Fi and is then deleted from the phone. Recordings appear in the app and at app.veo.co — [Veo support: Recording with Veo Go](https://support.veo.com/hc/en-us/articles/43899691605521) (snippet); [Veo support: Upload a Veo Go recording](https://support.veo.com/hc/en-us/articles/33190289619729) (snippet); [Veo Go product page](https://veo.co/en-us/product/veo-go)
- Veo Go availability and compatibility are inconsistent across pages: "UK only" on one page, "not available in your region" on others; iOS 17+ vs iOS 18+; and "iPhone 11 and newer, except SE" — [Veo Go plan explained](https://support.veo.com/hc/en-us/articles/33196190545297-Veo-Go-plan-explained-Features-and-limitations) (snippet); [Veo Go supported iPhones](https://support.veo.co/hc/en-us/articles/32445379389713-Veo-Go-Supported-iPhones-Compatibility-Guide) (snippet)

### Inferences
- For a third-party analytics system, the panorama is the valuable signal: the full field all the time, from a fixed and roughly known camera pose. The follow-cam is a moving, AI-chosen crop with no published camera-motion metadata, so pitch homography would have to be re-estimated frame by frame.
- No "Veo Cam 4" turned up in any search as of November 2026. "Veo Cam 3 and newer" currently means Cam 3 and Cam 3 5G, plus Veo Go.

### Gaps
- No published sensor model, per-lens resolution, stitched-panorama pixel dimensions, frame rate of the panorama, codec, or bitrate.
- Maximum recording length and internal storage capacity were not found. Battery life is the only duration figure.
- I could not read the full support comparison table (403).

## 2. Veo software tiers and pricing (2026); what Veo Analytics already automates

### Takeaway
Veo sells a camera ($999 in the US) plus a mandatory per-camera subscription, roughly $84–$250 per month depending on tier. The Veo Editor is included in every plan. Veo Analytics 2 (launched 19 Aug 2026) is a paid add-on and already automates a lot: auto-detected events, per-player technical and physical stats from video, shirt-number-based player identification, heat, shot and pass maps, Player Spotlight reels, a Match Report, and an LLM "Coach Assist". Any third-party system should assume these exist for soccer and not try to duplicate them.

### Cited Findings
**Plans and pricing (official numbers are sparse and inconsistent)**
- US shop: camera $999. The FAQ says subscriptions range "from about $84 to $250 per month" depending on team size, with a personalized quote. Tiers shown are Family (1 team, 4 users, limited Editor), Team (1 team, 30 users), Club (5 teams, 150 users) and Enterprise (20 teams, 600 users), each with 12-month storage. Billing is monthly, 6-monthly, yearly or 2-yearly. This shop page still references Veo Cam 2 and the original "Veo Analytics" add-on, and add-on prices render as "$0" placeholders, so it may be partly stale — [Veo US shop](https://us.shop.veo.co/)
- Help center (snippet) gives different tiers: Starter (1 team, 15 users, 10 recording hours/month), Team (1 team, 30 users, 20 h), Club (10 teams, 300 users, 200 h), Enterprise (20 teams, 600 users). The pricing page says Club is 5 teams. The sources conflict — [Veo support: choose the right plan](https://support.veo.com/hc/en-us/articles/4450464075025) (snippet); [veo.co/pricing](https://veo.co/pricing)
- A third-party review lists Starter at $119/mo, Team at $199/mo and Club at $239/mo, with annual discounts. Unverified — [AiToolScoop Veo review](https://aitoolscoop.com/tool/veo/)
- Veo product pages show "From {PRICE}" as an unfilled template, and "Subscription required" for each camera — [Veo Cam 3](https://www.veo.com/en-us/product/veo-cam-3); [Veo Analytics](https://www.veo.com/en-us/product/veo-analytics)

**Veo Editor (all plans)**
- Auto-detected events: goals, shots, corners and free kicks are "detected automatically". The event menu also has goal kicks, penalties and kick-offs. Shots and goals are auto-clipped. AI events cover football, rugby and lacrosse — [Veo Editor product page](https://www.veo.com/product/veo-editor)
- Other Editor features: manual events, player tagging on events and clips, drawings/telestration, player spotlighting, "Speedrun" (skips dead ball time), timeline and journal, formations, and five tiers of team roles. Views are Follow-cam and Interactive (drag/zoom, or a panoramic pitch overview) — [Veo Editor product page](https://www.veo.com/product/veo-editor); [Veo support: views in the Editor](https://support.veo.com/hc/en-us/articles/10288769409425) (snippet)

**Veo Analytics 2 (add-on, soccer only)**
- Announced 19 August 2026. It produces individual player stats from Veo Cam footage, with "No wearables, no manual tagging". It includes distance, top speed, high-intensity runs, tackles and passes per player. "Veo Vision" overlays live speed and distance on the follow-cam. The Analytics Studio has season leaderboards, comparisons, shot maps linked to clips, and heat maps. Player Spotlight, previously a standalone add-on, is now bundled. "Ask Coach Assist" answers natural-language questions about your matches. The "Veo Live" app was renamed "Veo" and is free for all users. The Match Report was due for all Analytics 2 users in October 2026 — [Veo product update announcement](https://updates.veo.co/announcements/ann_93FN3qsJTPLfd)
- Product page: AI "detects every shot, pass, and tackle and attributes it to the player who made it". The Match Report (beta) is a "six-tab report, built automatically" with goals, shots, corners, free kicks, throw-ins, attempts and possession %. Per-player stats include minutes, goals, assists, passes, dribbles, recoveries, interceptions, tackles, duels, high-intensity runs and distance. There are heat maps, shot maps, pass maps/passing networks, and a 2D radar. "Connect Players" shows live distances between players. Physical data comes "straight out of the video". It requires Veo Editor and a Veo Cam, and is soccer only — [Veo Analytics product page](https://www.veo.com/en-us/product/veo-analytics)
- Player stats are available for matches uploaded after 18 August 2026 on teams with Analytics 2 — [Veo support: Player stats in the Veo app](https://support.veo.com/hc/en-us/articles/49676211129489) (snippet)
- **Jersey-number recognition:** Player Spotlight uses "advanced shirt number detection" to track each player. Players can "Claim Jersey" in the app, and unlinked detections show as "Jersey #X". Duplicate numbers on a team, long hair or anything else obscuring the number reduce accuracy. Admins assign shirt numbers in the members list and set default lineups — [Veo Player Spotlight](https://www.veo.com/en-us/product/player-spotlight); [Veo support: Player stats in the Veo app](https://support.veo.com/hc/en-us/articles/49676211129489) (snippet); [Veo product update announcement](https://updates.veo.co/announcements/ann_93FN3qsJTPLfd)
- Player Spotlight builds a reel of moments where a player was involved, "based on proximity to the ball and AI-detected match events" — [Veo product update announcement](https://updates.veo.co/announcements/ann_93FN3qsJTPLfd)
- **Veo Live / livestreaming:** this is a paid add-on per camera, football only, with a data plan not included, according to the US shop — [Veo US shop](https://us.shop.veo.co/). Veo also offers RTMP external streaming under separate terms — [Veo stream terms page](https://veo.co/de/stream) (snippet)

### Inferences
- Veo now covers most of the "stats from a fixed camera" value chain for soccer: event detection, player ID by shirt number, physical tracking, maps, and a natural-language Q&A layer. A glasses-first product should differentiate on the first-person or parent perspective, on sports and levels Veo doesn't cover, and on fusing perspectives. Re-deriving Veo's team-level stats from Veo footage adds little.
- Veo's event and stat data appears to be viewable only inside Veo's apps (see section 3). Duplicating some detection from raw MP4 may therefore still be necessary just to get the data into a third-party system, even though Veo has already computed it.

### Gaps
- No authoritative 2026 USD price for any tier or for the Analytics 2 add-on (pages show template placeholders).
- I couldn't confirm whether the Match Report actually shipped in October 2026.
- Analytics 2 accuracy figures (event precision/recall, jersey-ID rate) were not found.

## 3. Export: full-match MP4, panorama, clips, event/stat export, integration partners, API, webhooks

### Takeaway
The only clearly documented export is a single-match **follow-cam MP4** download from app.veo.co, available to team-assigned users or club admins, one match at a time, with no bulk download. Clips and highlight reels can also be downloaded. Per the help center, the **panorama is not downloadable**. No public CSV/JSON/XML export of events or stats was found. Veo has an API that is described as limited and first-version, with no public developer portal found. Users have asked for an XML event export for Sportscode/Nacsport, but that is not confirmed as shipped. The practical third-party path today is the user's MP4 download, or credentialed account connection like Framesports uses. Neither path gives you Veo's event metadata.

### Cited Findings
- "You can only download the follow-cam view of a match." On desktop, use the Download button in app.veo.co; on mobile, the gear icon. It downloads "as an MP4 file". "You can only download a match if it has been assigned to your team, or you are a clubhouse admin." Download is available only once the follow-cam version is generated — [Veo support: How to download your Veo recordings](https://support.veo.com/hc/en-us/articles/4451733961361) (snippet; full page 403)
- Conflicting: one Veo page says Cam 3 recordings can be downloaded from the Editor "on all plans above Starter" — summarized in search results for [veo.com Cam 3 e-commerce page](https://www.veo.com/product/veo-cam-3-e-commerce). The Editor page simply says "download as MP4 to share" — [Veo Editor](https://www.veo.com/product/veo-editor)
- Panoramic mode exists only inside the Interactive player in the Editor, not as an export — [Veo support: views in the Editor](https://support.veo.com/hc/en-us/articles/10288769409425) (snippet)
- Per a third-party guide: "bulk downloading games is not currently possible". Downloads are follow-cam only, and team assignment is required. Full recordings are retained 6 months on Starter and 12 months on Team/Club/Enterprise, then deleted after 30 days' notice. Saved clips are not deleted — [Cutsio: how to download Veo recordings](https://cutsio.com/blog/how-to-download-veo-recordings.md)
- Clip and highlight downloads are documented: "How to download all saved clips from a Veo recording" — [Veo support](https://support.veo.com/hc/en-us/articles/4520649230225); "How to download a highlight reel" — [Veo support](https://support.veo.com/hc/en-us/articles/38958611618705-How-to-download-a-highlight-reel-from-your-recording); League Exchange downloads — [Veo support](https://support.veo.com/hc/en-us/articles/28048236995217-How-to-download-a-video-from-Veo-League-Exchange) (all titles/snippets only)
- **API:** Veo's terms define a "Veo API" through which Content is distributed (GTC 1.1), but give no usage rules — [Veo Terms](https://www.veo.com/terms). A Veo Ideas Board post says Veo "recently released a first version of our API" with more planned, and a user said it lacked the event detail they wanted — [Veo Ideas Board: Veo api](https://veo.nolt.io/1151) (snippet; 403). A streaming-platform integrator says Veo "does offer an API for some use cases" but its "primary design is for ease of sharing rather than deep platform integration", and typical integration is an iframe embed (article dated 4 Nov 2026) — [Icareus](https://icareus.com/how-to-integrate-spiideo-and-veo-videos-into-a-sports-streaming-platform/)
- **Not Veo:** developer.veo.co.uk ("VEO API – VEO Developer Docs", OAuth client-credentials, `videos/v3/get-all`) appears to belong to a different UK company, a video-tagging/observation service. Don't confuse it with Veo Technologies — [developer.veo.co.uk](https://developer.veo.co.uk/apioverview)
- **XML/event export:** an Ideas Board request asks for XML export of AI-generated events "to be analyzed in external platforms like Sportscode, Angles or Nacsport". It was merged into a broader statistics-export request, and I couldn't confirm it shipped — [Veo Ideas Board: Export as XML](https://veo.nolt.io/997) (snippet)
- **Nacsport workflow:** "you cannot take the live feed from VEO into Nacsport". The workaround is to tag live in Nacsport without a video source, export XML, and sync it later to the MP4 downloaded from Veo — [AnalysisPro: Using VEO cameras with Nacsport](https://www.analysispro.com/blog/veo-camera-sports-video-analysis-nacsport)
- **Framesports** (third-party AI analysis) calls Veo "Our most popular integration. Connect your Veo account and we'll automatically pull your footage." Users enter their Veo login, choose the account, or paste a direct Veo link — [Framesports docs: supported platforms](https://docs.framesports.ai/games/video-sources); [Framesports integrations](https://framesports.ai/features/integrations/)
- **No official Hudl, Wyscout, Once, Coach Paint, Dartfish or Metrica integration** was found in any Veo page or search. Hudl/Wyscout XML exports exist, but they concern Wyscout's own data, not Veo's — [Hudl blog: Sportscode XML Wyscout](https://www.hudl.com/blog/hudl-sportscode-xml-wyscout)
- Veo's official partnerships pages cover distribution/league deals (GotSport, VYSA, Player Toolbox, Inside Lacrosse), not data integrations — [Veo x GotSport](https://www.veo.com/en-us/partnership/gotsport); [Veo x VYSA](https://www.veo.com/en-us/partnership/vysa); [Veo x Player Toolbox](https://veo.co/en-us/partnership/player-toolbox)
- **Livestream out:** Veo has an RTMP external streaming service with its own terms, so a live follow-cam feed can be pushed to a custom RTMP endpoint — [Veo stream terms](https://veo.co/de/stream) (snippet)

### Inferences
- Realistic ingestion options, from most to least sanctioned:
  1. The user downloads the follow-cam MP4 and uploads or links it to our system, as Cutsio does.
  2. A user-configured RTMP push of the Veo livestream to our ingest endpoint. This is follow-cam only and needs the livestream add-on.
  3. A partnership with Veo for API access. The API exists but is not public; contact Veo business development.
  4. Credential-based account connection, as Framesports does. ToS-grey; see section 4.
- Event and timestamp metadata will probably have to be re-derived or entered by the user, because there's no confirmed export. The Analytics 2 data is locked in Veo's UI.
- Because only the follow-cam is downloadable, a third-party system loses Veo's main structural advantage, the fixed full-field panorama. Off-ball and tactical analysis from exported Veo video is much weaker than in Veo's own UI.

### Gaps
- No public Veo API docs, auth model, endpoints, rate limits or webhooks were found. Partner-program terms are unknown.
- Download resolution and bitrate of the follow-cam MP4 are not documented.
- I couldn't confirm whether the plan restriction ("above Starter") applies to downloads in 2026.

## 4. Terms of service: downloaded video reuse and automated access/scraping

### Takeaway
Under Veo's General Terms (effective 29 May 2026), the customer owns uploaded Content. Veo gets a broad, sublicensable licence, including AI training, and owns any insights or models derived from Content. Users may not reproduce or download Veo's own "Material" without permission, and may not reverse engineer the Services. There is **no explicit anti-scraping or anti-bot clause**, and **no data-portability or export right**. Danish law applies by default; for US residents it is Delaware.

### Cited Findings
- General Terms effective "May 29th 2026" — [Veo Terms](https://www.veo.com/terms)
- Ownership: uploaded Content is "the intellectual property of the customer or the User" (User Terms 7.2) and "belongs to the customer" (3.8). Veo's IP covers the platforms "except for Content" (GTC 6.1) — [Veo Terms](https://www.veo.com/terms)
- Licence to Veo: "a non exclusive, worldwide, royalty free, sublicensable, transferable license" to use and adapt Content, including developing and training AI systems (GTC 6.3, User Terms 7.6). Insights and models generated from Content "shall be wholly owned by Veo" (GTC 6.3). Veo "reserves the right to utilize any uploaded Content for the development and optimization of products" (GTC 8.3). Advertising use requires prior approval (GTC 6.5) — [Veo Terms](https://www.veo.com/terms)
- Restrictions: users may not "access, reproduce, download, distribute, transmit, broadcast, display, sell" Service material except as permitted or with Veo's prior permission (User Terms 7.4). They may not download or use Platform "Material" for publications or commercial purposes without permission (7.3). They may not "reverse engineer, decompile, disassemble or otherwise attempt to discover the source code" (8.1.5) or "interfere with or damage the operation of the Services" (8.1.6) — [Veo Terms](https://www.veo.com/terms)
- No explicit scraping or bot provisions were found in the text read, though the last ~1.4k characters of the page were not read — [Veo Terms](https://www.veo.com/terms)
- Third-party services are used "solely at the User's own risk", and Veo "does not endorse any such Third-party Services" (User Terms 15.1–15.2). When publishing to YouTube and similar platforms, the customer is "jointly responsible" for compliance (GTC 7.1) — [Veo Terms](https://www.veo.com/terms)
- Retention: Veo may delete Content or move it to cold storage "without prior notice" (GTC 3.6, User Terms 4.3). If fees go unpaid, the customer loses access to uploaded Content and the account may be deleted (GTC 5.4) — [Veo Terms](https://www.veo.com/terms)
- Governing law: Danish law with the Copenhagen District Court, or Delaware law and courts for US residents. Mandatory consumer law can override (GTC 17.1–17.3) — [Veo Terms](https://www.veo.com/terms)
- Camera use implies agreement to the Terms of Use and Privacy Policy — [Veo Cam 2 safety information](https://support.veo.com/hc/en-us/articles/20762030716433-Important-Veo-Cam-2-and-safety-information) (snippet)
- Data protection: when customers record, they collect, process and may share personal data, so the club or customer is a data controller — [Veo data protection role](https://www.veo.com/legal/information-regarding-veos-data-protection-role)

### Inferences
- Reusing a **customer-downloaded MP4** in a third-party analysis tool looks permissible: the customer owns the Content. The main obligations are privacy (the club is controller; minors' footage under GDPR/COPPA-like rules) and any club or league media policies. Our system would be a processor for the club or parent.
- **Automated access** (headless login, scraping app.veo.co or unofficial API calls with user credentials) isn't explicitly banned. It could still conflict with 7.3/7.4 (Material), 8.1.6 (interference), and the "as amended" policy clause (GTC 1.6). Storing users' Veo passwords also creates security and liability exposure. A Veo partnership or official API is the safer route. This is not legal advice.
- Veo owns derived insights and models, so analytics computed inside Veo (events, stats) are arguably Veo's data, not the customer's. That may explain why there is no stats export.

### Gaps
- No standalone API Terms or developer agreement was found.
- No Veo statement was found on whether third-party tools like Framesports are sanctioned.

## 5. Third-party analytics built on Veo video; community experiences

### Takeaway
Several startups ingest Veo footage: Framesports (account connection), Cutsio (MP4 upload and search), and the Nacsport/AnalysisPro workflows (MP4 plus XML sync). I found no open-source project built specifically for Veo footage. Generic open-source soccer computer-vision pipelines (YOLO + tracking + homography) exist and would apply to downloaded follow-cam MP4s. Reddit coverage did not surface in searches.

### Cited Findings
- Framesports pulls footage automatically from a connected Veo account and calls it its "most popular integration" — [Framesports docs](https://docs.framesports.ai/games/video-sources)
- Cutsio indexes uploaded Veo MP4s with "Visual Intelligence" so footage is searchable by description across seasons, independent of the Veo subscription. Pricing is by stored minutes — [Cutsio blog](https://cutsio.com/blog/how-to-download-veo-recordings.md)
- AnalysisPro/Nacsport: post-match XML-plus-MP4 sync workflow — [AnalysisPro](https://www.analysispro.com/blog/veo-camera-sports-video-analysis-nacsport)
- Icareus (OTT platform) integrates Veo and Spiideo videos through embed or file ingestion — [Icareus](https://icareus.com/how-to-integrate-spiideo-and-veo-videos-into-a-sports-streaming-platform/)
- Generic open-source soccer CV: foovision (YOLO detection, K-means jersey-colour team assignment, optical-flow camera-motion estimation) — [foovision](https://awesome.ecosyste.ms/projects/github.com%2Fblue-davinci%2Ffoovision); tcoca27/football_analysis (adds perspective transform) — [GitHub](https://github.com/tcoca27/football_analysis); a blog noting tracking difficulty with fast camera motion and partial pitch views — [zzsi blog](https://zzsi.github.io/blog/posts/20240915-soccer-tracking/index.html); FOOTBALLTrace (panoramic stitching + YOLOv7 + ID association, non-Veo cameras) — [SciTePress paper](https://www.scitepress.org/publishedPapers/2023/122268/pdf/index.html)
- Trustpilot has about 1,189 reviews of Veo Technologies, a source of user sentiment I did not read in detail — [Trustpilot](https://ca.trustpilot.com/review/veo.co)

### Inferences
- Startups such as Framesports and Cutsio already target the gap between Veo's coach-centric UI and other workflows. A glasses product that ingests Veo footage would compete with or resemble them on the Veo side. Its unique value would be fusing Veo footage with first-person glasses footage.

### Gaps
- No Reddit (r/bootroom, r/SoccerCoachResources) threads surfaced through search, so community sentiment on export limits is not captured here.
- No YouTube review content was gathered.
- No Veo-specific GitHub tooling (downloaders, API clients) was found.

## 6. Competitors with more open data (fixed-camera ingestion alternatives)

### Takeaway
Pixellot is the clear "open" option. It has a documented Partner API with staging and production environments, CRUD on entities, webhooks, and highlight .zip downloads, and a community dlt connector exists. Spiideo reportedly offers API access to video metadata, clips and playback URLs, but I found no public docs. I found no public API documentation for Trace or XbotGo.

### Cited Findings
- Pixellot: "a dedicated Partner API for creating new entities, updating and retrieving them. In addition, a partner can subscribe to Pixellot webhooks". Staging and production environments; highlights downloadable as a .zip — [Pixellot Marketplace API docs](https://docs.pixellot.tv/portal/en/kb/articles/pixellot-marketplace-api-documentation); [Pixellot API Advanced Breakdown](https://docs.pixellot.tv/portal/en/kb/articles/api-advanced-breakdown); [Pixellot API troubleshooting](https://docs.pixellot.tv/portal/en/kb/articles/api-integration-troubleshooting-and-q-a); [Pixellot venue monitoring API](https://docs.pixellot.tv/portal/en/kb/articles/api-integration-venue-monitoring)
- A community dlt connector loads Pixellot clubs and events into DuckDB and similar stores — [dltHub Pixellot](https://dlthub.com/context/source/pixellot)
- Pixellot has third-party integrations, for example a VidSwap–PlayMaker integration — [Pixellot docs: VidSwap](https://docs.pixellot.tv/portal/en/kb/articles/vidswa)
- Spiideo "provides API access that allows platforms to retrieve video metadata, clip information, and playback URLs" (integrator claim, not Spiideo docs) — [Icareus](https://icareus.com/how-to-integrate-spiideo-and-veo-videos-into-a-sports-streaming-platform/)
- XbotGo is a smartphone-based auto-tracking gimbal system for team sports. No public API was found — [XbotGo App Store listing](https://apps.apple.com/us/app/-/id1581355712)

### Inferences
- If "fixed camera" ingestion with programmatic access is a requirement, Pixellot (common in US high schools and venues) is the best-documented target. Spiideo is worth a direct business-development enquiry. Phone-based systems like XbotGo and Trace produce local or cloud MP4s that users can share manually, which is functionally similar to the Veo download path.

### Gaps
- No primary Spiideo, Trace (traceup.com / PlayerFocus) or XbotGo developer documentation was retrieved. Searches returned nothing relevant.

## 7. Technical considerations for analyzing Veo footage

### Takeaway
Veo's capture is a two-lens 180° stitch from a mast about 5–7.4 m high at the halfway line. The downloadable product is a 1080p, AI-panned, SteadyView-smoothed crop, so lens distortion and camera motion are baked in and undocumented. Jersey-number OCR is feasible near the camera but degrades on the far touchline and in the far corners. Veo's own shirt-number detection carries caveats about duplicates and occlusion.

### Cited Findings
- Capture geometry: two synchronized streams stitched into 180° coverage — [Veo Cam 3](https://www.veo.com/en-us/product/veo-cam-3); "dual 4K lenses" — [veo.com/llms.txt](https://www.veo.com/llms.txt)
- Mast height up to 17.1 ft (small) or 24.3 ft (large) — [Veo Cam 3](https://www.veo.com/en-us/product/veo-cam-3)
- Follow-cam output is 1080p, and SteadyView smoothing is applied after every recording — [Veo Cam 3](https://www.veo.com/en-us/product/veo-cam-3)
- Veo's shirt-number detection is degraded by duplicate numbers and by long hair or anything else obscuring the number — [Veo support: Player stats in the Veo app](https://support.veo.com/hc/en-us/articles/49676211129489) (snippet)
- In generic soccer CV, fast camera movement and partial pitch views make keypoint and player tracking harder, and YOLO-World misses overlapping players — [zzsi blog](https://zzsi.github.io/blog/posts/20240915-soccer-tracking/index.html)
- Open-source pipelines handle broadcast-style panning with optical-flow camera-motion estimation and perspective transforms — [foovision](https://awesome.ecosyste.ms/projects/github.com%2Fblue-davinci%2Ffoovision); [tcoca27/football_analysis](https://github.com/tcoca27/football_analysis)

### Inferences
- **Distortion:** the follow-cam is a virtual camera re-projected from the stitched panorama, so it likely looks roughly rectilinear. Its effective focal length and pan vary over time, though, and no intrinsics are published. Pitch-line keypoint detection per frame (or per shot) is needed for homography. The panorama in Interactive mode would show strong cylindrical or fisheye warping, plus a stitch seam at the centre, which falls near the halfway line.
- **Resolution budget:** spreading roughly two 4K sensors across 180° of a full-size pitch leaves far-side players at very few pixels. The 1080p follow-cam crop adds digital zoom on the ball area, which helps near the ball and loses everything off-crop. Expect reliable jersey OCR mainly on near-side players and in zoomed moments. Plan to combine OCR with team-colour clustering, tracking and lineup priors (Veo's own approach), or with glasses footage for close-up identity.
- **Bitrate:** not documented. Full-match MP4s are described only as "large files". Measure a sample: ffprobe on a downloaded MP4 to read codec, resolution, frame rate and bitrate.
- **Sync with glasses:** the follow-cam has no published timecode or GPS metadata beyond what the MP4 container holds. Audio cross-correlation (whistles) or visual event alignment (kick-off) is the practical way to sync it with smart-glasses footage.

### Gaps
- No published codec, bitrate, GOP or frame rate for the downloaded MP4.
- No published panorama projection or stitch parameters, and no camera intrinsics.
- No independent measurement of Veo jersey-ID accuracy was found.
