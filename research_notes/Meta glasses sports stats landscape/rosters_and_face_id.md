# Roster/Team Platform Integrations and Consent-Based, Human-Seeded Player Identification

Research date: 2026-11-07. Scope: (A) pulling rosters from and pushing stats/video to youth/amateur team platforms; (B) recognizing only enrolled, consented people in Meta smart-glasses footage (face and non-face re-ID), plus licensing, vendor policy and Meta wearables policy constraints. Many findings come from search-result summaries of vendor help pages; where only a secondary source exists that is flagged. Each claim has a source link. Anything I could not source is under Inferences or Gaps.

---

## A1. Which roster platforms expose an API, and what can be pulled?

### Takeaway
Of the platforms listed, only **TeamSnap** (OAuth 2, Collection+JSON API v3) and **LeagueApps** (API-key Public/Private API, aimed at the organization/admin) have documented developer APIs. **GameChanger, SportsEngine, Hudl (core), MaxPreps, Spond, Heja and BYGA** have no public roster API I could find. For them the realistic paths are a **CSV/Excel export the user uploads**, in-product partner syncs, or business-development partnerships. CSV import should be the baseline, with TeamSnap OAuth as the first "connect your account" integration.

### Cited Findings

**TeamSnap**
- Every API request needs an OAuth 2 access token in the request header. The authorize, token and revoke endpoints are on auth.teamsnap.com. A web-application (server-side code exchange) flow is documented along with a "2-leg" flow for clients with no server. Scopes are `read` (default) and `write`. — [TeamSnap API v3 Authorization (search summary; the direct fetch returned 404 on 2026-11-07, so the page may have moved)](https://www.teamsnap.com/documentation/apiv3/authorization)
- The API is served over HTTPS at `https://api.teamsnap.com/v3/`. It uses Collection+JSON, not plain REST JSON, and the docs list HTTP 429 for "hit your rate limit". No numeric limit appears in the results. — [TeamSnap API v3 Getting Started](https://www.teamsnap.com/documentation/apiv3/getting-started)
- A "member" is a team member, "also called a roster in the apps". A `members` endpoint lists members tied to an object (team). — [TeamSnap API v3 Objects](https://teamsnap.com/documentation/apiv3/objects); collection names are in the [TeamSnap JS SDK collections doc](https://github.com/teamsnap/teamsnap-javascript-sdk/blob/master/./docs/collections.md)
- Developers register an application in the TeamSnap Developer Portal (redirect URI, client ID, secret). A community MCP server ("TeamSnapMCP") reads rosters with read-only scope, which is precedent for third-party roster access. — [TeamSnapMCP on Glama](https://glama.ai/mcp/servers/@mrelph/TeamSnapMCP); older community Ruby client: [adammcfadden/teamsnap](https://github.com/adammcfadden/teamsnap)
- CSV fallback: TeamSnap supports exporting a roster/directory list and an org-level participant export. — [TeamSnap: Export Roster List](https://helpme.teamsnap.com/article/742-directory-export); [For organization admins](https://helpme.teamsnap.com/article/461-export-roster-list); [Export participant list](https://helpme.teamsnap.com/article/1717-export-participant-list)

**LeagueApps**
- LeagueApps documents a **Public API** and a **Private API**. Together they give "access to information ... such as member details, registration, transactions, as well as public facing information like program lists, teams and schedules". The Private key also unlocks the Public API, every request needs a Site ID in the path, and the key goes in an `la-api-key` header. — [LeagueApps Public API overview (Notion)](https://leagueapps.notion.site/Public-API-overview-450d53df689c47cb89593d453c73a6c9); [START HERE](https://leagueapps.notion.site/START-HERE-528ce4b9a95843a28942f5502bb10302)
- Rate limits: 15 requests/second to `*.leagueapps.io`, and 5/second for exports. — [LeagueApps API docs (Notion), via search summary](https://leagueapps.notion.site/START-HERE-528ce4b9a95843a28942f5502bb10302)
- A third-party iPaaS (MindCloud) ships a LeagueApps connector with actions such as "List Program Teams", which is integration precedent. — [MindCloud LeagueApps connector](https://mindcloud.co/docs/universal/rest/leagueapps/latest)
- LeagueApps documents CSV export for migrating into SportsEngine. — [Export LeagueApps Data to Import into SportsEngine](https://support.leagueapps.com/hc/en-us/articles/1500011116361-Export-LeagueApps-Data-to-Import-into-SportsEngine)

**GameChanger (DICK'S Sporting Goods)**
- No public GameChanger developer API surfaced. Its integrations are partner syncs with MaxPreps. — [MaxPreps & GameChanger Data Sync](https://support.maxpreps.com/hc/en-us/articles/5494411289755-MaxPreps-GameChanger-Data-Sync)
- A roster/schedule can be imported **from MaxPreps into GameChanger only at team creation**, and later MaxPreps edits do not sync. Nothing flows from GameChanger rosters or schedules back to MaxPreps. — [Sync Schedule & Roster from MaxPreps to GameChanger](https://support.maxpreps.com/hc/en-us/articles/360041632034-Sync-Schedule-Roster-from-MaxPreps-to-GameChanger)
- A scorekeeper can copy an opponent's roster when that opponent also scores in GameChanger. — [GameChanger: Opponent Roster Import](https://help.gc.com/hc/en-us/articles/360043583891-Opponent-Roster-Import)
- Org admins of baseball/softball teams can export centralized stats from the "Leaders" tab (version note dated 2025-03-31, per search summary). — [GameChanger App Store listing](https://apps.apple.com/lk/app/gamechanger/id1308415878)
- Sports Connect / Blue Sombrero leagues have a sync where one family imports the team and the rest see it populated. — [Blue Sombrero GameChanger Team Manager doc (PDF)](https://tshq.bluesombrero.com/portals/21245/docs/gamechanger%20team%20manager%20%20blue%20sombrero%20support.pdf)

**SportsEngine (NBC Sports)**
- No public or partner API documentation surfaced. — [search result summary; no official developer page found]
- CSV fallback is documented. Admins with "Full Access" or "Limited Access – HQ Tools" can export member data from Members > Directory > Export, as a CSV of the filtered view or all data. — [SportsEngine: How to view and export member data](https://intercom.help/SportsEngine/en/articles/6310277-how-to-view-and-export-member-data)
- SportsEngine documents exporting registration player data for GotSoccer, and importing iScout scores/stats into SportsEngine (a stats-in precedent). — [Export player info to GotSoccer](https://intercom.help/SportsEngine/en/articles/6512949-how-to-export-player-information-from-a-sportsengine-registration-into-gotsoccer); [Exporting scores and stats from iScout to SportsEngine](https://intercom.help/SportsEngine/en/articles/6345532-exporting-scores-and-stats-from-iscout-to-sportsengine)
- Third-party apps advertise "Import a Roster from SportsEngine or a CSV", which is precedent for the CSV-bridge pattern. — [MaxOne guide](https://gomaxone.notion.site/How-to-Import-a-Roster-from-SportsEngine-or-a-CSV-715c282b01b0443da9781bd2c26cfbb8)
- SportsEngine signs governing-body partnerships (e.g., USA Swimming team-management partner through 2030, USA Lacrosse). These are commercial deals, not developer programs. — [Youth Sports Business Report](https://youthsportsbusinessreport.com/sportsengine-usa-lacrosse-partnership-expands-to-full-platform/)

**MaxPreps (CBS)**
- Roster/schedule data reaches GameChanger and Hudl through partner syncs. See A2 for stats. — [MaxPreps HUDL Data Sync](https://support.maxpreps.com/hc/en-us/articles/5493128608283-MaxPreps-HUDL-Data-Sync)
- A search summary of MaxPreps' partner page says MaxPreps "does not provide an API for stat partners" and that vendors register as partners instead. — [MaxPreps Stat Import Partners](https://support.maxpreps.com/hc/en-us/articles/202266384-Stat-Import-Partners)

**Hudl**
- A third-party API directory says core Hudl video and Hudl Focus "do not publish a public developer API". B2B integrations are sales-mediated, and Hudl's developer-facing data APIs are Wyscout and StatsBomb (pro data, not team video upload). This is a secondary source. — [SportsFirst: Hudl API](https://www.sportsfirst.net/sportsapi/hudl-api)
- Third-party tools connect to Hudl by asking users for a Hudl download link or **Hudl email and password**, a credential-sharing workaround rather than OAuth. — [Frame Sports: video sources](https://docs.framesports.ai/sessions/video-sources.md); [Pro QuickDraw Cutup Generator: connect video platform](https://help.proquickdraw.com/helpcenter/cutupgeneratorweb/connect-video-platform)

**Spond**
- No official public API. An unofficial Python library (`spond`, GitHub Olen/Spond) uses the user's Spond login and exposes `get_groups()` (groups and members) and `get_person()`. It notes breaking changes between 0.99 and 1.0. — [Olen/Spond on GitHub](https://github.com/Olen/Spond); [PyPI spond](https://pypi.org/project/spond/0.99.0)
- Official fallback: admins can download a group member list as Excel in the app or on the web, with subgroups on separate tabs. — [Spond Help: download a group member list](https://help.spond.com/en/articles/25936-how-to-download-a-group-member-list-from-the-spond-app)

**Heja (Heja Sports AB)**
- Heja is a free team communication/organization app with a "Heja Pro" tier (attendance stats, payment tracking, unlimited admins, desktop access). No API or roster export was documented in the results. — [Heja App Store listing](https://apps.apple.com/gb/app/id1157335714); [heja.io](https://heja.io)

**BYGA (verified identity)**
- BYGA (Byga, Inc.; byga.net) is a **youth sports club management platform** with web plus iOS/Android apps. It covers "Tryouts, Teams, Registration, Calendars, Fields, Evaluations, Profiles, and Results". Team managers and coaches handle lineups, health checks, attendance and photo uploads. Families manage player profiles, medical documents and waivers. I found no evidence that "BYGA" stands for "Build Your Game App". — [byga.net](https://byga.net/); [Byga Mobile features](https://www.byga.net/mobile/features); [Solutions for Families](https://www.byga.net/families); [App Store listing](https://apps.apple.com/us/app/byga/id1416710083)
- No public API or export documentation surfaced. — [search result summary]

### Inferences
- Roster fields likely available through TeamSnap (`members`) include names, jersey number, position, guardian contacts and possibly a profile photo. The search results did **not** confirm exact field names such as `jersey_number`/`position`, so verify against [TeamSnap Objects](https://teamsnap.com/documentation/apiv3/objects) before building.
- Hudl and Spond integrations based on stored user credentials would likely violate their terms and break easily. They are not a sound product basis.
- A single "universal roster CSV" importer (name, number, position, optional guardian email, optional photo URL) with column-mapping presets for TeamSnap, SportsEngine, Spond (Excel) and LeagueApps exports would cover most platforms with no partnership needed.
- Roster profile photos (where present) could serve as seed enrollment images, but only with explicit guardian consent for biometric use, because the original upload was not made for that purpose (see B2/B5).

### Gaps
- TeamSnap numeric rate limits, partner-program requirements and API terms (e.g., whether commercial apps need approval or must avoid storing data) were not found. The authorization doc URL returned 404 on fetch.
- LeagueApps: whether a third-party app (not the org itself) can obtain keys, and the exact roster/registrant endpoint names.
- GameChanger: no evidence of a general roster CSV import for one's own team, and no public partner program.
- SportsEngine, Hudl, MaxPreps, BYGA, Heja: no partner-program pages found. Contact BD teams.
- Restrictive terms of use for each platform's data (e.g., bans on ML training or biometric use) were not reviewed.

---

## A2. Can stats or video be pushed back (GameChanger, MaxPreps, Hudl, SportsEngine)?

### Takeaway
The proven route is the **MaxPreps stat file**. MaxPreps accepts stat-file uploads (usually `.txt`) from 80+ registered "stat import partners", including GameChanger, Hudl, DakStats, iScore and Pixellot. The coach publishes inside MaxPreps, and there is no API. GameChanger and Hudl accept no third-party stat push through a public API. Video upload to Hudl has no public API.

### Cited Findings
- MaxPreps works with "over 80 different stat partners" across football, basketball, volleyball, baseball/softball, lacrosse, water polo and soccer. Vendors register through MaxPreps, and per the search summary MaxPreps provides no API for stat partners. — [MaxPreps: Stat Import Partners](https://support.maxpreps.com/hc/en-us/articles/202266384-Stat-Import-Partners)
- The file is generally a plain-text MaxPreps export (`.txt`): GameChanger has a "MaxPreps TXT export", DakStats exports "MaxPreps (*.txt)", Pixellot says the file must end in `.txt`, and Hudl advises renaming files with special characters to `import.txt`. No official public spec of the internal format surfaced. — [GameChanger: MaxPreps Manual Stat Upload](https://help.gc.com/hc/en-us/articles/11298180524685-MaxPreps-Manual-Stat-Upload); [Pixellot: Export Stats To MaxPreps](https://docs.pixellot.tv/portal/en/kb/articles/export-stats-to-maxpreps); [Daktronics quick guide](https://manualmachine.com/daktronics/uploadinggamefilestomaxpreps/1506129-user-manual)
- Upload workflow: in coach admin, choose the file, import, Calculate Team totals, then "Publish & Continue". Stats appear publicly within 15–30 minutes. — [MaxPreps: Looking to enter stats](https://support.maxpreps.com/hc/en-us/articles/202103644); [IHSA MaxPreps procedures (PDF)](https://WWW.Ihsa.org/documents/MaxPreps_Reporting_Procedures.pdf)
- Baseball/softball can auto-sync with some apps, while other sports generally need a manual upload per game. — [MaxPreps: Commonly Asked Questions About Stats](https://support.maxpreps.com/hc/en-us/articles/4404593358107)
- GameChanger to MaxPreps auto-sync is switched on in team Stat Settings. Enabling sync on multiple teams can corrupt MaxPreps stats. — [Sync Stats from GameChanger to MaxPreps](https://support.maxpreps.com/hc/en-us/articles/4409903717659-Sync-Stats-from-GameChanger-to-MaxPreps)
- Hudl has a MaxPreps data sync. — [MaxPreps HUDL Data Sync](https://support.maxpreps.com/hc/en-us/articles/5493128608283-MaxPreps-HUDL-Data-Sync)
- An independent stat-tool author documents the MaxPreps text format for their own export (possible reverse-engineering reference). — [Statman MaxPreps page (FSU)](https://myweb.fsu.edu/abrady/Statman/MaxPreps.html)
- State associations (e.g., OHSAA, IHSA, WVSSAC) name MaxPreps the official stats/scores source, so pushing to MaxPreps matters for high-school teams. — [OHSAA](https://www.ohsaa.org/Sports/News/maxpreps-ohsaa-official-source-for-scores-and-statistics); [WVSSAC FAQ (PDF)](https://www.wvssac.org/wp-content/uploads/2025/09/WV_FAQ_2025_26.pdf)
- NFHS named a dedicated platform (FlagStat) as the official flag-football statistics platform in a three-year deal, so sport-specific "official stat platform" deals exist. — [Youth Sports Business Report](https://youthsportsbusinessreport.com/nfhs-names-flagstat-official-flag-football-statistics-platform-in-three-year-deal/)
- No public Hudl video-upload API was found. — [SportsFirst: Hudl API](https://www.sportsfirst.net/sportsapi/hudl-api)

### Inferences
- The most practical "push back" features are: (1) become a registered MaxPreps stat import partner and emit the `.txt` format per sport; (2) export a generic CSV/PDF box score; (3) export MP4 clips the user uploads to Hudl manually.
- MaxPreps covers high-school teams. Most youth/rec/pickup users will not have MaxPreps pages, so a native shareable stat page and CSV are needed anyway.

### Gaps
- The official MaxPreps file-format spec per sport and partner-registration requirements (needs the MaxPreps partner page `maxpreps.com/utility/stat_import/partners.aspx`, not fetched).
- Whether GameChanger accepts any third-party stat import (none found).
- Whether TeamSnap's `write` scope allows posting game results/scores (plausible, not verified).

---

## A3. Social graphs and device contacts (Instagram, Facebook, Apple, Google) as a "roster" source

### Takeaway
Social friend lists are effectively closed. Facebook `user_friends` returns only friends who also use your app and needs app review, and Instagram removed follower-list endpoints in 2018. Device contacts (Apple Contacts, Google People) are a better way to invite parents or teammates, but they contain no jersey/position data or consent.

### Cited Findings
- Since Graph API v2.0, `user_friends` returns only friends who have also authorized the app. From March 2018 it needs Facebook app review. — [Pete Freitag: Facebook API now requires review for user_friends](https://www.petefreitag.com/blog/facebook-user-friends/); [Graph API versioning notes (gist)](https://gist.github.com/manchunlam/90a44b7c157123ec33df) (older sources, 2014–2019)
- Instagram removed the follower-list endpoint (starting 2018-07-31), and the Instagram Graph API exposes only `followers_count`. Scraping tools are against Instagram terms. — [TechCrunch (2018) via reader mirror](https://hn.jakechampion.name/reader/https://techcrunch.com/2018/04/02/instagram-api-limit/); [Power Digital on Instagram Graph API](https://powerdigitalmarketing.com/blog/instagram-graph-api-and-how-it-will-affect-your-marketing-efforts/)

### Inferences
- For pickup games without jerseys, the realistic "roster" is: the organizer picks players from phone contacts (iOS `CNContactPickerViewController` gives one-off, user-selected access, and Android has its contacts picker), or shares an invite link or QR code that each player uses to self-enroll and consent. That self-enrollment doubles as biometric consent capture.
- This was not verified against current Meta/Apple/Google docs in this session, so confirm current permission rules before relying on them.

### Gaps
- Current (2026) Facebook/Instagram permissions were not re-verified on Meta's developer docs. Apple Contacts / Google People API terms on using contacts for invitations were not fetched.

---

## B1. Open-source face detection and recognition models: licenses and commercial usability

### Takeaway
The licensing trap is **weights and training data, not code**. InsightFace code is MIT, but its pretrained models (buffalo_l, antelopev2, ArcFace weights, SCRFD weights) are **non-commercial research only** unless licensed. The cleanest commercially usable stack found is **OpenCV Zoo YuNet (detector) + SFace (recognizer)**, both Apache 2.0 (one mirror says YuNet is MIT). AdaFace and Torchreid code/weights are reported as MIT, but they were trained on research-licensed datasets (MS1M, WebFace, VGGFace2, etc.), which is a legal grey area that needs counsel.

### Cited Findings
- **InsightFace**: "The code of InsightFace is released under the MIT License. There is no limitation for both academic and commercial usage." Training data and models trained on it "are available for non-commercial research purposes only". Models downloaded from the repo or Python library follow that non-commercial policy. As of the 2025-11-24 update, commercial licensing for buffalo_l and other open recognition models goes through `recognition-oss-pack@insightface.ai`, and InspireFace SDK/advanced models through `contact@insightface.ai`. SCRFD (detector) and ArcFace (recognizer) live in the same repo under the same model policy. — [deepinsight/insightface README](https://github.com/deepinsight/insightface)
- **Immich** (self-hosted photo app) uses InsightFace antelopev2/buffalo_l/m/s. It got email permission from InsightFace's maintainer on 2023-03-18, and states that permission "does not extend to the redistribution or commercial use of their models by third parties". — [Immich machine-learning README (mirror)](https://ark.sudovanilla.org/Infrastructure/immich/raw/branch/main/machine-learning/README.md); [immich-app/antelopev2 on Hugging Face (license: other)](https://huggingface.co/immich-app/antelopev2/blob/main/README.md)
- **SFace (OpenCV Zoo)**: "All files in this directory are licensed under Apache 2.0 License." OpenCV does not state SFace's training data (opencv_zoo#313). — [opencv_zoo face_recognition_sface README](https://github.com/opencv/opencv_zoo/blob/main/models/face_recognition_sface/README.md); [lumen-faces mirror noting training-data issue](https://huggingface.co/subhashhhhhh/lumen-faces)
- **YuNet (OpenCV Zoo)**: a Hugging Face mirror lists YuNet as MIT with its own LICENSE file. The OpenCV Zoo top-level README says Apache 2.0 and tells users to check per-model licenses. Either is permissive, but verify the upstream `models/face_detection_yunet` LICENSE. — [opencv_zoo README (HF mirror)](https://huggingface.co/opencv/opencv_zoo/blame/main/README.md)
- **AdaFace**: weights for ir_18/50/101 are reported as MIT "per the original AdaFace repository" (secondhand). CVLFace model cards are tagged MIT but say to "follow the license of the training dataset". — [yakhyo/uniface-weights](https://huggingface.co/yakhyo/uniface-weights); [CVLFace AdaFace IR101 WebFace4M](https://huggingface.co/minchul/cvlface_adaface_ir101_webface4m)
- **facenet-pytorch**: PyPI metadata has an empty license field. Weights were ported from David Sandberg's TensorFlow facenet and pretrained on VGGFace2 and CASIA-WebFace. A Hugging Face mirror (py-feat/facenet) labels the weights MIT. — [PyPI facenet-pytorch](https://pypi.org/project/facenet-pytorch/2.0.1); [py-feat/facenet](https://huggingface.co/py-feat/facenet)
- **PhotoPrism** (AGPL-3.0 Community edition) now defaults to **YuNet** detection plus **SFace** embeddings. FaceNet is legacy, and libraries migrate with `photoprism faces migrate`. Older docs describe SCRFD (ONNX) detection, 512-d FaceNet embeddings and DBSCAN clustering (defaults: cluster core 4 faces, distance 0.64, match distance 0.46). — [PhotoPrism user guide: Face Recognition](https://docs.photoprism.app/user-guide/ai/face-recognition/); [PhotoPrism developer guide: Face Recognition](https://docs.photoprism.app/developer-guide/vision/face-recognition/)
- **Google ML Kit** is face *detection* (landmarks, contours, tracking), not identity recognition. Faces must be at least 100x100 px for detection and 200x200 px for contours, and with contours on only one face is detected. — [ML Kit face detection (iOS)](https://developers.google.cn/ml-kit/vision/face-detection/ios)

### Inferences
- Commercial-use classification (subject to legal review):
  - **Likely OK**: OpenCV YuNet + SFace (Apache/MIT; training data undisclosed). PhotoPrism made the same switch, which is a useful signal.
  - **Code OK, weights grey**: AdaFace, facenet-pytorch (VGGFace2/CASIA are research datasets), MagFace/ElasticFace (not verified this session; typically trained on MS1MV2), Torchreid OSNet (MIT; Market/Duke/MSMT datasets are research-only).
  - **Not OK without license**: InsightFace pretrained models (buffalo_l, antelopev2, SCRFD/ArcFace weights). They can be licensed commercially through the emails above.
  - **DeepFace (serengil)** is a wrapper. Its license depends on the backend chosen (it can load InsightFace/ArcFace, FaceNet, SFace, etc.), so pick backends deliberately. Not verified this session.
- **Apple Vision** provides face detection, landmarks and capture-quality scores, but no public face-identity API (Photos' People recognition is not exposed). This comes from general knowledge and a search tool's note, not an Apple page fetched this session.
- A clean-room option is to fine-tune a permissive backbone on licensed or consented data, or to license a commercial SDK (InsightFace InspireFace, Paravision), to remove training-data risk.

### Gaps
- License files not directly fetched this session: dlib's `dlib_face_recognition_resnet_model_v1` (commonly reported as CC0/public domain; unverified), face_recognition (ageitgey; MIT code, uses the dlib model), MagFace, ElasticFace, DeepFace, CLIP-ReID, RetinaFace (biubug6 Pytorch_Retinaface).
- "OpenCV Zalando": no such OpenCV/Zalando face model was found. The user's "check" note is unresolved. It may be a mix-up with OpenCV Zoo (verified above) or Zalando Research's unrelated fashion/Fashion-MNIST work.

---

## B2. Commercial face APIs: availability, minors and consent policies

### Takeaway
**AWS Rekognition** is the most accessible commercial 1:N "collections" API, but its Biometric Notice and Consent Terms put the burden of BIPA/CUBI-style notice, written consent and deletion on the customer. **Azure Face identification/verification** is Limited Access: managed customers only, organizational email, approved use cases, and Microsoft said it isn't accepting new managed-customer requests. **Google Cloud Vision** only detects faces. **Paravision** reviews every use case in sales and favors opt-in consent. Clarifai's biometric terms were not found.

### Cited Findings
- **AWS Biometric Notice and Consent Terms** (last updated 2024-11-14) cover Rekognition. If your use falls under biometric privacy laws (e.g., Illinois BIPA, Texas CUBI), you must inform the people whose biometric data is processed, obtain necessary consents (including written consent where required) on your behalf **and on behalf of AWS as your service provider**, and instruct AWS to delete data when the law requires. If you don't comply, you may not use the service. AWS provides sample notice/consent language. — [AWS Biometric Notice and Consent Terms](https://aws.amazon.com/legal/biometric-notice-and-consent-terms)
- **AWS Service Terms §50.4**: the customer is responsible for legally adequate privacy notices and necessary consent for AI services. — [Tech Monitor](https://www.techmonitor.ai/?p=345421); [AWS Service Terms](https://aws.amazon.com/service-terms/) (not fetched directly)
- AWS also has law-enforcement terms (human review, public disclosure, a moratorium on police use) and a sustained-surveillance prohibition. These come from a third-party tracker, so verify. — [Conduct Atlas: Rekognition provisions](https://conductatlas.com/platform/aws-bedrock/aws-service-terms/provision/CA-P-052830/rekognition-sustained-surveillance-prohibition-without-independent-review/)
- **Azure Face**: identification and verification are Limited Access. Access is at "Microsoft's sole discretion based on eligibility criteria and a vetting process" and available only to Microsoft-managed customers and partners. You register through the Face Recognition intake form with an org email (personal emails are denied), pick an approved use case, and Microsoft may require periodic reverification. Face *detection* needs no registration. A Microsoft Q&A answer says "We are not able to accept requests to become a managed customer at this time." — [Microsoft Learn: Limited Access Face](https://learn.microsoft.com/legal/cognitive-services/computer-vision/limited-access-identity); [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/1614037/when-do-i-need-to-request-access-from-microsoft-to); [Microsoft Responsible AI blog (2022)](https://azure.microsoft.com/blog/responsible-ai-investments-and-safeguards-for-facial-recognition/)
- **Paravision**: "We review all use cases as part of a sales review process". Its consumer-deployment best-practices doc says "Opt-in / consent-driven use of face recognition ... puts the service provider on the most stable legal and ethical ground". — [Paravision AI Principles](https://www.paravision.ai/ai-principles/); [Paravision best practices for consumer-facing deployments (May 2023, PDF)](https://www.paravision.ai/wp-content/uploads/2023/05/paravision-doc-face-recognition-best-practices-developing-policies-for-consumer-facing-deployments-may-2023.pdf)
- **Clarifai** markets face recognition (geometry/attribute analysis). Only marketing pages surfaced, with no biometric terms. — [Clarifai face recognition page](https://www.clarifai.com/campaigns/face-recognition)

### Inferences
- None of the vendor terms found **ban** minors' faces, but all push consent and legal compliance onto the customer. For minors, consent would come from a parent or guardian.
- Google Cloud Vision does detection and attributes only, with no identity matching. This comes from general knowledge and was not re-fetched.
- Server-side recognition through any cloud API adds a processor (AWS or another vendor) that must be named in consent, as the AWS terms explicitly require.

### Gaps
- No explicit minors clauses found in AWS, Azure, Paravision or Clarifai terms. Clarifai's ToS/DPA was not reviewed.
- Current 2026 status of Azure managed-customer intake was not confirmed.

---

## B3. Accuracy on low-res, blurred, side-on and helmeted faces; distance limits for glasses footage

### Takeaway
Face recognition degrades sharply below roughly 32 px face height. On native low-res faces (TinyFace, ~20x16 px average), rank-1 identification is in the teens to twenties percent. From a sideline at 1080p, usable faces probably extend only to a few meters, so **face ID will be a seeding/confirmation signal, not the primary in-play identifier**. Jersey numbers plus appearance re-ID plus tracking carry the rest. Football helmets with facemasks make face ID largely impractical during play.

### Cited Findings
- The TinyFace benchmark defines low-res faces as at or below 32x32 px (typical benchmarks use 100 px or more). It has 5,139 identities and 169,403 native low-res images averaging about 20x16 px, built for 1:N testing. — [Cheng et al., Low-Resolution Face Recognition (arXiv 1811.08965)](https://arxiv.org/abs/1811.08965); [core.ac.uk PDF](https://core.ac.uk/download/219803514.pdf)
- A follow-up reported TinyFace top-1 of about 11.75%, or about 26.21% with super-resolution before alignment. The settings are unclear, so treat these as indicative. — [arXiv 1907.13255](https://arxiv.org/pdf/1907.13255)
- CMU work on multi-resolution embeddings cut small-face error by at least 70% on IJB-C/LFW/MegaFace variants, which shows that resolution-aware training helps. — [CMU RI: Recognizing Tiny Faces](https://ri.cmu.edu/?p=122772)
- ML Kit needs at least 100x100 px faces to detect reliably and recommends images of at least 480x360. Head orientation changes which features are detected. — [ML Kit face detection](https://developers.google.cn/ml-kit/vision/face-detection/ios)
- PhotoPrism ignores faces below a configured minimum size (cluster size about 112 px in newer docs), a practical precedent for minimum face-size gating. — [PhotoPrism face recognition user guide](https://docs.photoprism.app/user-guide/ai/face-recognition/)
- Waldo Photos combines "facial and jersey recognition" for event photos, which is precedent for fusing face and jersey cues. — [Waldo FaceBlocker patent press release](https://prnewswire.com/news-releases/waldo-photos-issued-faceblocker-patent-tech-allows-professional-photographers-to-copyright-protect-mobile-proofs-301259468.html)

### Inferences
- **Distance estimate (my calculation, with assumptions flagged).** Assume a head-mounted ultra-wide camera with about 100° horizontal FOV (unverified for Meta glasses) and an adult/teen face about 15 cm wide.
  - 1080p (1920 px wide), about 19 px/degree: a face is ~55 px wide at 3 m, ~33 px at 5 m, ~16 px at 10 m.
  - 720p (1280 px), about 13 px/degree: ~37 px at 3 m, ~22 px at 5 m.
  - "3K" (~2880 px), about 29 px/degree: ~80 px at 3 m, ~50 px at 5 m, ~25 px at 10 m.
  - Against the ~32 px "low-res" line (TinyFace) and 100 px ML Kit guidance, usable recognition likely tops out at about **3–5 m at 1080p** and **5–8 m at 3K**, and less with motion blur from head movement. Most soccer/football action is farther away, so face ID mostly works on benches, huddles, sideline close-ups, pre- and post-game, and at-bat/on-deck in baseball.
- Glasses video adds head-motion blur and rolling shutter. Pick high-quality frames (sharpness, pose, size) per track and recognize per track (aggregate embeddings over a tracklet) rather than per frame.
- **Helmets (American football)**: the facemask blocks the lower face and the visor or shadow often hides the eyes. Rely on jersey number, helmet/jersey appearance and track continuity, and seed identity from sideline or unhelmeted shots. Baseball batting helmets and catcher masks have similar but smaller effects.
- Side-on (profile) faces degrade sharply for most 2D recognizers. Treat yaw over about 45° as low-confidence. This is a general CV norm, not sourced here.

### Gaps
- Published face-ID accuracy on helmeted football players, and an exact pixels-per-face requirement per model (e.g., SFace vs AdaFace at 24/32/48 px), were not found.
- Exact Meta glasses camera FOV and the toolkit streaming resolution/bitrate were not verified in this session (see the sibling note meta_glasses_platform.md).

---

## B4. Non-face re-ID for pickup games and the human-in-the-loop labeling loop

### Takeaway
For jersey-less pickup games, use **within-game appearance re-ID** (Torchreid/OSNet, MIT code) plus tracking to build per-game "person clusters". The human then names clusters once, Google/Apple Photos style, and the system asks only about low-confidence merges (active learning). Clothing re-ID does not carry across days, so identity across games comes from face matches where available and from the user re-confirming each game.

### Cited Findings
- **Torchreid** (KaiyangZhou/deep-person-reid) is MIT-licensed, has about 4.9k stars, and includes OSNet. — [SourceForge mirror listing MIT](https://sourceforge.net/projects/torchreid.mirror/); [Torchreid paper summary](https://www.opentrain.ai/papers/torchreid-a-library-for-deep-learning-person-re-identification-in-pytorch--arxiv-1910.10093/)
- OSNet weights are distributed under MIT by the upstream author, but training datasets (MSMT17, DukeMTMC-reID, CUHK03) carry research terms. DukeMTMC was withdrawn by its creators (general knowledge, not sourced here). — [LibreReID-osnet on Hugging Face](https://huggingface.co/LibreYOLO/LibreReID-osnet)
- PhotoPrism's precedent pipeline: detect, embed, DBSCAN-cluster with a minimum core count, then the user names clusters, and new faces auto-match within a distance threshold (0.46 in older defaults). Changing the embedding model requires re-embedding while keeping person assignments. — [PhotoPrism developer guide](https://docs.photoprism.app/developer-guide/vision/face-recognition/); [PhotoPrism user guide](https://docs.photoprism.app/user-guide/ai/face-recognition/)

### Inferences
- Suggested loop: (1) track all players; (2) build per-tracklet appearance embeddings (OSNet) and, where visible, face embeddings (SFace); (3) cluster within the game; (4) show the user about 10–15 cluster "contact sheets" to assign to roster entries or mark "not enrolled / ignore"; (5) surface only uncertain merges or splits, ranked by expected information gain; (6) propagate labels; (7) store only face templates of enrolled, consented people, and discard per-game clothing embeddings after the game.
- Unenrolled people (opponents, bystanders) should stay anonymous track IDs, never be clustered across games, and never have face templates persisted. This keeps the system "known people only" and limits biometric exposure.
- Gait recognition from head-mounted, moving-camera footage is unlikely to be reliable. Treat it as research-stage. No source was gathered on this.
- CLIP-ReID's license was not verified. Check its repo LICENSE before use.

### Gaps
- No benchmarks were found for re-ID on egocentric (head-mounted) sports footage.
- Apple Photos / Google Photos UX details (e.g., "Is this the same person?" prompts, confirm/reject faces) were not fetched this session. They are described from general knowledge only.

---

## B5. UX and consent precedents: photo apps and youth-sports / race-photo face search

### Takeaway
Precedents exist (Waldo Photos for camps and youth events with "facial and jersey recognition", EnMotive's race "Selfie" search, SmugMug face-match through a camp vendor, Immich/PhotoPrism clustering), but primary documentation on **how they get consent for minors is thin**. The legal environment is risky (BIPA suits against PimEyes, Google/Flickr settlement, the Texas AG suit against Google). That favors explicit, guardian-signed, purpose-limited enrollment with retention/deletion schedules.

### Cited Findings
- **Waldo Photos** uses facial recognition (and jersey recognition) to find a purchaser's photos and overlays its logo on faces in mobile proofs (FaceBlocker patent). It is used at summer camps to text each camper's photos to families. The consent details come from an opinion piece. — [Waldo press release](https://prnewswire.com/news-releases/waldo-photos-issued-faceblocker-patent-tech-allows-professional-photographers-to-copyright-protect-mobile-proofs-301259468.html); [Substack critique](https://joecadillic.substack.com/p/waldo-photos-claims-it-is-fun-to-18-08-02)
- **SmugMug face recognition via UltraCamp**: a camp-management vendor offers face matching of a child's profile photo against a SmugMug gallery. — [UltraCamp: Facial Recognition for the SmugMug Photo Gallery](https://help.ultracamp.com/hc/en-us/articles/46007654415508-Facial-Recognition-for-the-SmugMug-Photo-Gallery)
- **Pixieset and SmugMug** reportedly offer no client-side face search natively. These are competitor and aggregator sources. — [FotoOwl SmugMug alternatives (2026)](https://fotoowl.ai/blogs/best-smugmug-alternatives-for-photographers); [Aftershoot client gallery roundup](https://aftershoot.com/blog/best-client-gallery-photographers/)
- **Race photos**: at the Illinois Marathon, the timing company EnMotive offered a "Selfie" facial-recognition search that auto-tagged runners in event photos. The article assumed but did not confirm consent. — [IDTechWire](https://idtechwire.com/facial-recognition-illinois-marathon-runners-505115)
- **BIPA risk examples**: a PimEyes class action alleges it scanned images of millions of Americans without consent. Google settled a BIPA case over a Flickr-derived face dataset. New BIPA theories target generative-AI face-photo analysis (e.g., a suit against xAI Grok alleging no notice, written release or retention policy). — [PimEyes (Wikipedia)](https://en.wikipedia.org/wiki/PimEyes); [CADE: Google settles BIPA dataset suit](https://cadeproject.org/updates/google-settles-biometric-privacy-lawsuit-over-facial-recognition-dataset/); [Frankfurt Kurnit: "Not Just a Selfie"](https://technologylaw.fkks.com/post/102o602/not-just-a-selfie-the-new-bipa-theory-aimed-at-generative-ai); [Perkins Coie: new biometrics lawsuits](https://perkinscoie.com/insights/update/new-biometrics-lawsuits-signal-potential-legal-risks-ai)
- **Texas AG v. Google** over facial recognition in photos without consent (CUBI). — [Frame & Focal](https://frameandfocal.com/post-processing/texas-ag-sues-google-for-collecting-facial-data-from-photos) (secondary)
- **Immich** clusters faces with InsightFace models under a non-transferable permission. **PhotoPrism** (AGPL) clusters with YuNet+SFace. Both are self-hosted, so biometric data stays with the owner. — [Immich ML README](https://ark.sudovanilla.org/Infrastructure/immich/raw/branch/main/machine-learning/README.md); [PhotoPrism docs](https://docs.photoprism.app/user-guide/ai/face-recognition/)

### Inferences
- Consent design that follows from the AWS terms and Paravision best practice: (a) per-person enrollment initiated by the person, or by a guardian for minors, with a written electronic release naming the purpose (sports stats/highlights for this team), the processors, retention (e.g., delete templates at season end or after X months of inactivity) and deletion on request; (b) a coach can propose a roster link, but the template is activated only after guardian consent; (c) a public retention and destruction policy (a BIPA requirement); (d) no cross-team or global search.
- On-device enrollment and matching (phone) reduces but does not remove biometric-law exposure. BIPA/CUBI apply to collection and storage of face geometry regardless of where it is stored. This is an inference, so check with counsel (see sibling note legal_privacy.md).
- Pic2Go, RaceID, Spotted and FotoFinder were not researched in depth this session, so no claims are made about their consent practices.

### Gaps
- No primary-source consent flows were found for Waldo, Pic2Go, RaceID, Spotted, FotoFinder or Pixieset regarding minors.
- No race-photo-specific BIPA case was found.

---

## B6. Meta Wearables Developer Acceptable Use Policy on face identification

### Takeaway
The Meta Wearables Developer AUP (last updated **2026-09-22**) prohibits using "device sensors for unique identification of people based on physical characteristics, such as voices and faces", with exceptions "granted for specific use cases, including accessibility apps, with prior Meta approval." Meta says the GitHub tracker can't approve use cases (2026-10-13), and no public application process exists. The policy says it applies "when you use any component of the platform". It does not explicitly address phone/server processing or media imported from the Meta AI app gallery, so that is **unresolved and high-risk**.

### Cited Findings
- Exact prohibition: "Use device sensors for unique identification of people based on physical characteristics, such as voices and faces". Exception: "exceptions are granted for specific use cases, including accessibility apps, with prior Meta approval." — [Meta Wearables Developer Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy/)
- Related prohibitions: "Encouraging covert filming, harassing incidents or pranks, or analyzing people in a user's surroundings"; "Surreptitiously collect recognizable audio or video content of the user or others"; and enabling "bypassing, tampering with, or obscuring hardware-level recording indicators (such as the capture LED)". Children: bans "Exploitation or harm to children" and illegal distribution of materials to minors, with no specific rules on minors' data. — [Meta Wearables AUP](https://wearables.developer.meta.com/acceptable-use-policy/)
- Scope: "These policies apply to you when you use any component of the platform." The page has no definitions section and does not say whether it covers only toolkit-sourced data or downstream processing. Last updated September 22, 2026. — [Meta Wearables AUP](https://wearables.developer.meta.com/acceptable-use-policy/)
- Breaches lead to enforcement "up to and including account disablement" (per search summary). Developers must accept the Wearables Developer Terms and the AUP before getting the SDK. — [Meta Wearables AUP](https://wearables.developer.meta.com/acceptable-use-policy/); [Device Access Toolkit integration](https://wearables.developer.meta.com/docs/develop/dat)
- **Meta's public response on face-ID approval (GitHub issue #334).** The request was filed 2026-10-09 by a government-focused team. On 2026-10-13 Meta replied that the AUP does not permit identifying people by face or voice through device sensors, that exceptions need prior approval and are limited to specific cases like accessibility, and that the Wearables Developer Terms separately ban surveillance uses (law enforcement, national security, intelligence), which an AUP exception doesn't override. Meta said the issue tracker can't review or approve use cases and closed the issue. — [facebook/meta-wearables-dat-ios issue #334](https://github.com/facebook/meta-wearables-dat-ios/issues/334)
- The toolkit FAQ says "developers can process data locally or via cloud/edge platforms", that the Meta AI app must be used to pair glasses, and that "Wearables Device Access Toolkit 1.0 ... begins rolling out September 30, 2026". Publishing submissions are "soon". The FAQ says nothing about face recognition or about Meta AI gallery media. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

### Inferences
- The prohibition is about using **device sensors** for unique identification. A strict reading covers any identification derived from toolkit camera frames, whether computed on glasses, phone or server, since the sensor is the data source and the AUP covers "any component of the platform". Treat downstream phone/server processing of toolkit-streamed video as covered.
- **Media imported from the Meta AI app gallery** (videos the user recorded natively and exported to the camera roll, then imported like any phone video) arguably uses no toolkit component. If the app never uses the toolkit for that flow, the Wearables AUP may not technically apply. However, (a) Meta's general terms and the Meta AI app terms may still apply (not reviewed here); (b) if the same app also integrates the toolkit, Meta could view the product as a whole; (c) the "analyzing people in a user's surroundings" clause shows Meta's intent. **Do not rely on this distinction without written confirmation from Meta.**
- Low-risk product designs: (1) do face recognition only on imported gallery/camera-roll video in a module separate from any toolkit integration; (2) use toolkit streaming only for capture and live stats with no identification (jersey OCR of numbers is arguably not "physical characteristics"; this is an inference, unconfirmed); (3) seek a written Meta exception through official partner or developer-support channels, presenting the consent-only, enrolled-roster design. Note that the only named exception class is accessibility.
- Jersey-number recognition and clothing re-ID are less clearly "unique identification of people based on physical characteristics", but clothing/appearance re-ID that links a track to a named person could still be argued to be identification. Get clarity from Meta.

### Gaps
- No documented exception-application process or contact was found.
- Whether the Wearables Developer Terms (as distinct from the AUP) define "device sensors" or "platform data" in a way that settles phone/server processing or gallery imports was not fetched. Review those terms next.
- How the Meta AI app terms govern third-party processing of exported glasses media was not reviewed.
