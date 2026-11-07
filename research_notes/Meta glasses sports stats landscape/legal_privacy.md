# Legal, Privacy, and Policy Constraints: Smart-Glasses Recording and Player ID for Amateur/Youth Sports

Scope: a product that records amateur and youth games (American football, soccer, baseball) with Meta Ray-Ban, Oakley, or Display glasses, identifies players automatically (jersey numbers, possibly faces), and stores games, stats, and player galleries in an online library. US first, with EU/UK notes. Current as of November 7, 2026. These are research notes, not legal advice. Items marked "verify" or "counsel" need a lawyer's review before launch.

Research method note: about 19 searches and fetches. Most findings come from law-firm summaries, league web pages, and press. Primary statute text was not fetched for every state law. Where a point relies on general background knowledge rather than a source retrieved in this session, it is in "Inferences" or "Gaps" and flagged as such, not in "Cited Findings".

---

## 1. Biometric privacy law: does face recognition of players trigger BIPA, CUBI, Washington, Colorado, CCPA/CPRA, GDPR Art. 9, or UK GDPR? Does jersey or appearance re-ID count as biometric?

### Takeaway
Face recognition of players, which builds a face template to match the same person across clips or games, very likely creates "biometric identifiers" under BIPA, Colorado's HB24-1130, Texas CUBI, Washington law, and GDPR/UK GDPR Art. 9. That triggers written notice and consent, retention schedules, and (in Illinois) a private right of action with statutory damages. Ordinary video and photos, and jersey-number OCR, are generally not biometric. The legal line is whether you derive a template or measurements that can uniquely identify a person, so the product should not generate face or body templates at all.

### Cited Findings
- **Illinois BIPA, photo exclusion is narrow.** BIPA excludes photographs from its definitions, but courts have mostly refused to treat that as a blanket defense when photos are used as input to generate face templates. In the Shutterfly case the court rejected the defense because Shutterfly used photos "as an input to generate a distinct biometric template." In a case against Onfido the court held that information derived from photos could still be a "biometric identifier." Another court held that "scans of face geometry" derived from photos can be biometric identifiers. — [Revision Legal (Shutterfly)](https://revisionlegal.com/corporate/revision-legal/court-ruling-allows-shutterfly-case-to-move-forward/); [Privacy World (2022, photo-derived data)](https://www.privacyworld.blog/2022/04/breaking-federal-judge-in-illinois-affirms-that-bipa-extends-to-information-derived-from-photographs/); [Workplace Class Action blog](https://www.workplaceclassaction.com/2022/04/picture-this-illinois-federal-court-holds-that-bipa-applies-to-photographs/)
- **Limits recognized by courts.** In a suit over Apple's Photos app, claims about creating facial data went forward, but "face crops" (smaller images cut from photos) were held not to be biometric identifiers by themselves. The Ninth Circuit in *Zellmer v. Meta* held that face-geometry scans are on BIPA's list but "are not covered by BIPA if they cannot identify a person." — [Ashurst Perkins Coie (Apple faceprints)](https://www.ashurstperkinscoie.com/en/insights/apples-faceprints-and-bipa--a-new-ruling-on-biometric-data-and-control/); [Lewis Brisbois 2024 BIPA developments](https://old.lewisbrisbois.com/print/23527)
- **Video analysis can count.** In a suit against Arlo (home video cameras), allegations that the system captured light data and "map[ped] peoples' face geometry" were enough to plead a biometric-identifier claim. This is the closest analogue to video analytics found; no sports-specific BIPA case was found. — [Lewis Brisbois 2024 BIPA developments](https://old.lewisbrisbois.com/print/23527)
- **BIPA 2024 amendment (SB 2979).** Effective August 2, 2024. Damages for 15(b) consent and 15(d) disclosure violations moved from per-scan to per-person ("at the most, one recovery"). Statutory amounts stay at $1,000 per negligent and $5,000 per intentional or reckless violation. The amendment added an "electronic signature" definition, which confirms consent can be collected electronically. A secondary summary reports an April 2026 Seventh Circuit decision applying the amendment retroactively (not verified against the opinion). — [Shook Hardy & Bacon](https://shb.com/intelligence/client-alerts/pds/may-2024-bipa-amendment-wolfe-searle); [Fisher Phillips](https://www.fisherphillips.com/en/insights/insights/breaking-bipa-news-illinois-curtails-massive-damage-awards-in-biometric-cases); [Baker Donelson](https://www.bakerdonelson.com/bipa-amendments-passed-by-illinois-legislature-what-companies-need-to-know); [Business Law Today (7th Cir. retroactivity)](https://businesslawtoday.org/?p=35454)
- **Colorado HB24-1130.** Amends the Colorado Privacy Act to add biometric-specific rules, effective July 1, 2025. It applies to any entity processing biometric data, including small businesses and nonprofits, regardless of the CPA's usual thresholds. The Attorney General enforces it. — [BiometricUpdate (Texas vs Colorado)](https://www.biometricupdate.com/202506/texas-and-colorado-take-diverging-paths-on-biometric-privacy); [Colorado HB24-1130 enrolled text](https://legiscan.com/CO/text/HB1130/id/3002852/Colorado-2024-HB1130-Enrolled.pdf); [BCLP biometric law tracker](https://www.bclplaw.com/en-US/events-insights-news/us-biometric-laws-and-pending-legislation-tracker.html)
- **Texas CUBI (Tex. Bus. & Com. Code 503.001).** Covers capturing or using biometric identifiers "for commercial purposes," with civil penalties up to $25,000 per violation enforced by the Texas AG. It was amended in June 2025 by HB 149 (TRAIGA). — [BiometricUpdate](https://www.biometricupdate.com/202506/texas-and-colorado-take-diverging-paths-on-biometric-privacy)
- **Washington.** RCW 19.375 covers biometric data "enrolled" in databases for identification, with AG enforcement under the Consumer Protection Act. Separately, the My Health My Data Act includes biometric data in its broad definition of "consumer health data." — [BCLP tracker](https://www.bclplaw.com/en-US/events-insights-news/us-biometric-laws-and-pending-legislation-tracker.html); [Captain Compliance (Colorado/Washington summary)](https://captaincompliance.com/education/colorados-biometrics-privacy-rules/)
- **GDPR / UK GDPR.** Recital 51: photographs are biometric data "only when processed through a specific technical means allowing the unique identification or authentication of a natural person." An ordinary photo or video of a child is personal data but not special-category data. Face matching makes it Art. 9 special-category data. — [GDPR Recital 51](https://gdpr-info.eu/recitals/no-51/); [UK GDPR Recital 51 (Mishcon)](https://www.mishcon.com/uk-gdpr/recital/no-51)
- **COPPA now covers biometrics too** (details in Q2): the amended rule adds "biometric identifiers that can be used for the automated or semi-automated recognition of an individual," including facial templates. — [Infolaw Group](https://www.infolawgroup.com/insights/2025/4/29/little-data-big-requirements-is-your-business-ready-for-coppas-amendments)

### Inferences
- **Face recognition across games is the highest-risk feature.** A "player gallery" built by clustering or matching faces creates face templates of minors, which triggers BIPA (private action, per-person damages), CUBI, Colorado (which reaches any size of entity), and COPPA for under-13s. It is also Art. 9 data in the EU/UK, where explicit consent is the only realistic lawful basis.
- **Jersey-number OCR is not biometric.** Reading a printed number is not a measurement of a body characteristic. It still produces personal data once linked to a roster name.
- **Appearance-based re-ID is a gray area.** Tracking by kit color, body shape, or gait to keep a player's identity between frames when the number is hidden could be argued to be a biometric measurement. Washington-style definitions and Colorado's broad ones, and Meta's own VR data policy (which bans identifying people via "gait identification"), point that way. Lower-risk choices: keep any re-ID embeddings ephemeral (within one clip, in memory, never stored), never link them across games, and never use face regions. Counsel should confirm.
- **From general background knowledge, not verified this session:** BIPA's "biometric identifier" lists "scan of hand or face geometry," and the statute requires a public retention policy, written informed release, and a ban on profiting from biometrics. The CCPA/CPRA treats biometric information processed to identify a consumer as "sensitive personal information" (right to limit). Verify against statute text.

### Gaps
- No sports-specific BIPA or CUBI case was found (team photos, stadium cameras, or game-film analytics).
- Exact current statutory definitions for CUBI (after the 2025 amendment), RCW 19.375.010, and C.R.S. 6-1-1303 were not pulled. Washington's private right of action and employee coverage were reported inconsistently by secondary sources.
- The current status of *Zellmer v. Meta* and whether it governs ephemeral, non-stored face detection was not verified.

---

## 2. Children's privacy: COPPA (incl. the 2025 amendments), state minors' laws, GDPR-K. Storing videos/images of minors and profiling their performance.

### Takeaway
The amended COPPA rule has been fully enforceable since April 22, 2026. It applies if the service is directed at children under 13 or has actual knowledge it collects their data, and a youth-league video library with photos, video, names, and stats of under-13 players likely qualifies. COPPA already treats photos and videos containing a child's image as personal information, and it now expressly covers biometric identifiers. State laws push protections up to 16 or 18 (California treats under-16 data as sensitive; New York's Child Data Protection Act covers under-18s). Treat every player as a minor by default and route consent through parents.

### Cited Findings
- **Timeline.** Final COPPA amendments were published April 22, 2025, took effect June 23, 2025, and had a general compliance date of April 22, 2026. The deadline has passed and operators must follow the amended rule now. — [Federal Register, 90 FR 16918 (Apr. 22, 2025)](https://www.govinfo.gov/content/pkg/FR-2025-04-22/html/2025-05904.htm); [Hunton](https://hunton.com/privacy-and-information-security-law/ftc-publishes-final-coppa-rule-amendments); [Foley Hoag (July 2026)](https://foleyhoag.com/news-and-insights/blogs/security-privacy-and-the-law/2026/july/the-amended-children-s-online-privacy-protection-act-(coppa)-regulations-what-your-business-needs/)
- **The FTC is prioritizing enforcement** of the new obligations. — [Davis Polk](https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect)
- **Biometric identifiers added** to "personal information." The list is non-exhaustive (fingerprints, voiceprints, retina and iris patterns, genetic data, facial templates), and the FTC declined to carve out security or age-verification uses. — [Infolaw Group](https://www.infolawgroup.com/insights/2025/4/29/little-data-big-requirements-is-your-business-ready-for-coppas-amendments)
- **Other amended-rule obligations** (written information-security program, separate parental consent for third-party disclosures, data-retention limits) are summarized in firm alerts. — [Latham & Watkins](https://www.lw.com/en/insights/2025/05/ftc-publishes-updates-to-coppa-rule); [BBB National Programs reminder](https://bbbprograms.org/media/insights/blog/coppa-amended)
- **California.** Amended CCPA regulations expand "sensitive personal information" to include personal information of consumers known to be under 16, with enhanced security required from January 1, 2026. — [Covington, 2026 privacy developments](https://www.cov.com/-/media/files/corporate/publications/2026/03/2026-privacy-developments-to-watch.pdf); [Alston & Bird (Nov. 2025)](https://www.alston.com/en/insights/publications/2025/11/minors-privacy-online-safety-laws)
- **Other states.** Sixteen comprehensive state laws require consent plus a data protection assessment before processing sensitive data, while Iowa and Utah use opt-out. Oregon, Montana, and New Hampshire require opt-in to sell or target ads at minors 13 to 15, and New Jersey for 13 to 16. Oregon bans targeted ads to under-16s from January 1, 2026. — [Infolaw Group, "13 Going on 18"](https://www.infolawgroup.com/insights/2025/8/5/13-going-on-18-is-your-business-ready-for-privacy-laws-impacting-customers-younger-than-18); [AdExchanger](https://www.adexchanger.com/data-driven-thinking/new-us-state-childrens-privacy-laws-continue-to-reshape-digital-marketing/)
- **New York Child Data Protection Act.** In effect since June 20, 2025. It restricts processing minors' personal data without informed consent; sources differ on whether it covers 13 to 17 or all under-18 users. The NY AG has issued guidance. — [NY AG guidance (PDF)](https://ag.ny.gov/sites/default/files/2025-05/nycdpa-guidance.pdf); [Loeb & Loeb (June 2026)](https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-2026-state-app-store-design-code-and-social-media-laws)
- **Effective dates are moving.** A June 2026 Loeb update describes some state app-store, design-code, and social media laws as "enacted, then delayed" (litigation or legislative delays). — [Loeb & Loeb](https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-2026-state-app-store-design-code-and-social-media-laws)

### Inferences
- **Who the user is matters.** If the account holder is a parent or coach (an adult) and kids never use the service, COPPA's "directed to children" analysis is less direct. But the product collects and hosts images, video, and names of children, often for whole teams, and possibly gets to teens through player accounts. Plan as if COPPA applies to under-13 content: verifiable parental consent before publishing or identifying a child, deletion on request, a written retention policy, and no third-party disclosure (ads or analytics SDKs) without separate consent.
- **Performance profiling.** Per-player stats and highlight reels of minors are "profiles" under several state laws and under GDPR. Keep profiles team-scoped and parent-controlled, and do not use them for ads, recruiting marketplaces, or sale.
- **GDPR-K.** Under GDPR Art. 8 the age of digital consent is 13 to 16 depending on member state; the UK sets 13 and has the Age Appropriate Design Code (Children's Code). Both come from general knowledge, not retrieved this session.

### Gaps
- No FTC statement or case was found on youth-sports video platforms specifically.
- ICO guidance on photographing children at sports clubs was not retrieved. The UK Children's Code's applicability was not verified this session.
- Whether California's Age-Appropriate Design Code remains enjoined in November 2026 was not verified.

---

## 3. Recording in public or semi-public venues; youth league and governing-body filming policies (US Youth Soccer, AYSO, US Club Soccer, Pop Warner, NFHS/state associations, Little League, NCAA)

### Takeaway
US law generally allows spectators to video-record visible activity at a public or semi-public game (no reasonable expectation of privacy on a field). Audio-recording consent laws and venue rules are separate. The binding constraints are contractual and organizational. **Little League** claims exclusive rights to webcasting and game video and requires releases. **State high school associations** often give the **NFHS Network** exclusive postseason streaming rights and hold schools responsible for parents who stream. Soccer bodies rely on registration-form photo consents with opt-outs. A product that uploads full games to an online library can look like "webcasting or distribution" under these policies.

### Cited Findings
- **Little League exclusive rights.** "Little League International has the exclusive right to authorize any and all webcasting (live or recorded) of Regular Season and Special Games." It grants local leagues non-commercial webcast rights. — [Little League streaming FAQs](https://www.littleleague.org/help-center/internet-webcast-and-streaming-faqs/); [Little League, Streaming and Webcasting: FAQs, Guidelines, and Policies](https://littleleague.org/?p=11496)
- **Little League releases.** Before streaming any Little League event (live or recorded), a release and waiver must be signed and filed with the local league or district. Leagues must adopt a policy on images and video of participants consistent with Little League International's Privacy Policy. — [Little League streaming best practices](https://www.littleleague.org/university/articles/little-league-online-internet-webcast-and-streaming-faqs-guidelines-and-policies/)
- **Little League ownership of game video.** Video of a game between two chartered teams "remains the property of Little League Baseball, Incorporated and CANNOT be sold, gifted to, or shared with" any team or other party. No local league may permit a streaming platform to distribute recorded content without Little League's express written consent. — [Little League streaming FAQs](https://www.littleleague.org/help-center/internet-webcast-and-streaming-faqs/)
- **Little League cautionary case.** Little League cites a family who won a judgment ordering a webcaster to remove all of a league's game videos and refund subscribers ("Sued for Internet Streaming without Permission"). — [Little League article](https://www.littleleague.org/?p=11508)
- **Little League tournaments.** At Region and World Series events, recording is limited to credentialed TV outlets, and "all forms of video recording of game footage are strictly prohibited at all Little League stadiums." Little League publishes annual TV and video restrictions. — [Little League World Series recording FAQ](https://www.littleleague.org/help-center/can-i-stream-or-record-games-at-the-little-league-baseball-world-series/); [2025 TV and Video Restrictions](https://www.littleleague.org/downloads/2025-tv-and-video-restrictions)
- **NFHS Network postseason exclusivity.** Mississippi's MHSAA: the NFHS Network is "the exclusive broadcast rights holder of all postseason events," violations may bring MHSAA discipline or NFHS Network legal action, and schools must inform students, parents, and fans. — [MHSAA 2025-26 Media Policy](https://www.misshsaa.com/2025/11/07/2025-26-media-policy/)
- **Parents' streams create school liability.** CHSAA: the school "will be responsible to pay the per-game rights fee if any of your parents or spectators are using these platforms to live-stream games." — [CHSAA, NFHS Network Postseason Streaming Rights](https://chsaanow.com/sports/2025/10/28/chsaa-nfhs-network-postseason-rights.aspx)
- **Other states.** GHSA (Georgia): the NFHS Network has first rights to stream postseason events. Indiana: for regular-season games the host school owns property rights. Texas UIL offers an "Exclusive NFHS Network Streaming Distribution" option. — [GHSA live streaming rules](https://www.ghsa.net/node/14814); [GHSA NFHS Network postseason info](https://www.ghsa.net/node/15834); [UIL postseason broadcast information](https://www.uiltexas.org/media/info/postseason-broadcast-information); [Michigan MHSAA Media Info for Schools](https://www.mhsaa.com/sites/default/files/Media/Media-Info-for-Schools.pdf)
- **AYSO.** Photos and video "may be taken from time to time" and used in AYSO materials "as permissioned through the AYSO Registration forms." AYSO does not publish names or locations of children in photos. Regional forms let parents opt out of having photos posted. — [AYSO Privacy Policy](https://ayso.org/privacy-policy/); [AYSO Social Media Policy (wiki)](https://wiki.ayso.org/wiki/Policy_%E2%80%93_Social_Media); [AYSO New Season Waivers](https://wiki.ayso.org/wiki/New_Season_Waivers)
- **US Youth Soccer and state associations.** USYS regularly photographs and records its events for promotion. Arizona's state association treats entering a facility used for its events as consent to photography and recording. — [USYS Data Retention Policy (Apr. 2025)](https://www.usyouthsoccer.org/wp-content/uploads/sites/160/2025/04/Data-Retention-Policy-4.25.25.pdf); [Arizona Soccer Association social media waiver](https://www.azsoccerassociation.org/wp-content/uploads/sites/186/2024/04/Social-Media-Waiver-05.19.23.pdf)
- **Best practice from a youth-sports policy guide:** do not post rosters with names, jersey numbers, and contact info publicly; do not tag minors by name. — [Signature Locker, "Please Don't Post My Child"](https://signaturelocker.com/blogs/news/please-dont-post-my-child)
- **UK guidance exists** on photographing and filming children in sport. — [NSPCC Child Protection in Sport Unit, photography and filming](https://thecpsu.org.uk/resource-library/feature-boxes/key-info-photography)

### Inferences
- **Personal recording vs distribution.** A parent filming their own child's regular-season game for personal use is generally fine under league rules. A platform that hosts, shares across teams, or monetizes full-game video of Little League games collides with Little League's ownership and webcasting rules. Little League would likely require the league itself to opt in, with releases on file.
- **High school postseason.** The product should block or disable live streaming and public sharing of state-association postseason games, or at least warn users, because liability flows to the school. Regular-season policy varies by state and school.
- **Organization-level agreements.** The cleanest path is to contract with the league, club, or school (not only individual parents). Their registration forms already collect photo and video consents and opt-outs, and the product can ingest those flags.
- **Audio.** Recording audio of conversations (coaches, bench talk) could implicate two-party-consent wiretap laws in some states, for example California. This is general knowledge, not retrieved this session; counsel should check. A design option is to strip or not keep audio by default.

### Gaps
- No Pop Warner, US Club Soccer, or NCAA filming policy was retrieved. NCAA rules matter mainly for recruiting video and are less relevant to amateur or youth play.
- No national NFHS rule on spectator recording was found. It is state by state, and schools may add rules.
- Whether US Youth Soccer has a policy specific to parent or third-party platform uploads was not found.

---

## 4. SafeSport and youth-protection policies on filming minors and sharing images

### Takeaway
The U.S. Center for SafeSport's MAAPP (Minor Athlete Abuse Prevention Policies) applies to Olympic and Paralympic national governing bodies (e.g., U.S. Soccer and its member organizations) and adult participants. Under it, parents can refuse photography or video of their child without the child losing participation, recording in locker rooms, bathrooms, or other private settings is banned, and adults' electronic contact with minors must be open and transparent. A sports-video product should build in per-player "do not record or publish" flags and hard bans on private spaces.

### Cited Findings
- **Parental right to refuse.** "Parents or guardians have the right to refuse consent for their children to be photographed or recorded on video." Using that right may not be a basis to limit or deny participation. Some implementations also require the organization to approve each specific instance of recording. — [U.S. Center for SafeSport, 2025 MAAPP Manual](https://uscenterforsafesport.org/2025-maapp-manual); [Soccer 2025 MAAPP (Jan. 1, 2025)](https://maapp.uscenterforsafesport.org/wp-content/uploads/2022/01/Soccer_2025MAAPP_01.01.25.pdf)
- **Private spaces.** "Photography is strictly prohibited in locker rooms, bathrooms, and any setting where privacy is expected," with a narrow exception for media and championship celebrations. — [Example club photography policy implementing MAAPP](https://www.gomotionapp.com/iscpsc/__doc__/212553_2_CPSC%20Photography%20Policy.pdf)
- **Electronic communications.** All electronic communication between an adult participant and a minor athlete, including social media DMs, must be "open and transparent" unless an exception applies. — [SafeSport MAAPP communications one-pager (2023)](https://maapp.uscenterforsafesport.org/wp-content/uploads/2023/11/MAAPP_OnePagers_Communications_102623-A_v1.pdf); [USA Swimming MAAPP electronic communication](https://www.usaswimming.org/docs/default-source/safe-sportdocuments/maapp_2.0/electronic-communication.pdf)
- **U.S. Soccer has its own Safe Soccer policy** that applies to member organizations. — [U.S. Soccer Safety Policy (via Louisiana Soccer)](https://www.playlouisianasoccer.org/wp-content/uploads/sites/205/2023/08/us_soccer_safety_policy.pdf)

### Inferences
- **Coach messaging.** A coach (adult participant) sending clips directly to a minor player through the app could fall under the MAAPP rules on electronic communications. Design all coach-to-player clip sharing to copy or go through parents, or into team-visible channels, never as private DMs.
- **Smart glasses and covert recording.** Head-worn cameras are harder to see than phones, which raises the "covert recording of minors" worry that youth-protection programs focus on. A visible app-level signal (e.g., league-announced "this game is being recorded") and organization approval are prudent.
- **Recreational leagues.** Leagues outside the Olympic movement (Little League, Pop Warner) are not bound by MAAPP the same way, but many adopt similar policies, and the US Safe Sport Act's reporting requirements are broader. Verify per league.

### Gaps
- The full photography section of the 2025 MAAPP text was not fetched directly; quotes come from club implementations of it.
- Pop Warner's and Little League's own child-protection photography rules were not retrieved.

---

## 5. Meta's own policies: Wearables developer terms (face recognition, data use, LED tampering), and Meta glasses privacy controversies and public perception

### Takeaway
Meta's Wearables Developer Terms (last updated October 6, 2025) do not mention facial recognition explicitly. They do ban surveillance uses, re-identification or de-anonymization, selling data, and circumventing limits, and they require a privacy policy and deletion on request. Meta's glasses hardware and terms forbid tampering with the capture LED, and firmware now disables the camera if the LED is blocked. Public trust is low after the 2024 Harvard I-XRAY demo and 2026 reports of Meta's own "Name Tag" face-recognition plans. A sports product that identifies kids by face would land directly in that controversy.

### Cited Findings
- **Terms version.** "Last Updated: October 6, 2025." Users of the Device Access Toolkit agree to the Meta Wearables Developer Terms and the Acceptable Use Policy (§2.4). — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/)
- **Data restrictions.** §5.2.3 bars using Technology Data "to perform, facilitate, or provide tools for surveillance," defined in terms of collecting or sharing information about people, groups, or events for law enforcement, national security, or intelligence purposes. §5.2.4 bars attempts to "re-identify, de-anonymize." §5.2.2 bars selling, licensing, or renting data. §2.2(b) bars circumventing limitations of the technology. — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/)
- **Privacy obligations.** §6.1: a privacy policy must "accurately and clearly explain what data you are Processing." §6.2: process only as described there. §5.3: share only on user direction or consent, legal requirement, or with service providers. §5.5: delete on user request, account deletion, or when Meta or law requires. Meta may audit (§4.3) and require annual self-certification (§4.4). — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/)
- **What the terms don't cover.** The fetched Developer Terms contain no explicit clause on facial recognition, biometrics, bystanders, the LED, or minors. Meta's separate VR (Horizon) Developer Data Use Policy does prohibit using user data to ascertain a person's identity "including through facial recognition or gait identification." Whether the Wearables Acceptable Use Policy has the same rule was not confirmed. — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/); [Meta Developer Data Use Policy (VR)](https://developers.meta.com/vr/policy/data-use/)
- **Toolkit scope.** The Wearables Device Access Toolkit gives mobile apps access to the glasses' sensors and camera. Early reporting described camera access as coming later. — [heise](https://heise.de/-10662660); [Engadget](https://www.engadget.com/wearables/meta-will-let-outside-developers-create-ai-powered-apps-for-its-smart-glasses-194159233.html)
- **LED tampering.** Meta's AI-glasses supplemental terms (Singapore version found) bar interfering with recording-signal features, including the external LED. From the second generation onward, the camera is disabled if the capture LED is blocked. In July 2026 Meta extended this to physical alteration or destruction of the LED and to covering it mid-recording. Meta says the LED has no off switch. — [Meta AI Glasses Supplemental Terms](https://www.meta.com/legal/ai-glasses/supplemental-facebook-view-terms-of-service/); [Tom's Guide](https://www.tomsguide.com/ai/less-pervert-y-meta-ai-glasses-will-now-stop-recording-if-you-cover-the-warning-light); [iPhone in Canada (July 8, 2026)](https://www.iphoneincanada.ca/2026/07/08/metas-ai-glasses-will-now-disable-the-camera-if-you-tamper-with-the-light-heres-why/); [The Star (July 14, 2026)](https://www.thestar.com.my/tech/tech-news/2026/07/14/meta-updates-ray-ban-smart-glasses-to-prevent-hidden-recording); [GSMArena](https://www.gsmarena.com/metas_smart_glasses_will_disable_recording_when_capture_led_is_blocked-news-73645.php)
- **Harvard I-XRAY (Oct. 2024).** AnhPhu Nguyen and Caine Ardayfio paired Ray-Ban Meta glasses with the PimEyes face search engine and an LLM to look up strangers' names, addresses, and phone numbers in real time. They did not release the code. Meta's response was that neither the glasses nor its software had face recognition. — [404 Media](https://www.404media.co/someone-put-facial-recognition-tech-onto-metas-smart-glasses-to-instantly-dox-strangers); [Engadget](https://www.engadget.com/wearables/students-used-metas-smart-glasses-to-automatically-dox-strangers-via-instagram-streams-170228496.html); [ITV](https://itv.com/news/2024-10-05/harvard-students-use-metas-smart-glasses-to-create-a-privacy-nightmare)
- **Meta "Name Tag" (2026).** The New York Times reported in February 2026 that Meta planned a face-recognition feature code-named "Name Tag," possibly shipping in 2026. Meta had considered and dropped face recognition for the first-generation glasses in 2021. In June 2026 WIRED found dormant face-recognition code in the Meta AI companion app. Meta says it has not deployed face recognition in consumer glasses. One headline reports Meta removed the code after WIRED's story (only the headline seen). — [MacRumors (Feb. 13, 2026)](https://www.macrumors.com/2026/02/13/meta-facial-recognition-smart-glasses/); [Android Authority (code in app)](https://androidauthority.com/meta-smart-glasses-face-recognition-code-in-app-3674720); [IDTechWire](https://idtechwire.com/researchers-find-dormant-face-recognition-code-in-metas-smart-glasses-app/); [Freevacy (WIRED summary)](https://www.freevacy.com/news/wired/meta-removes-facial-recognition-code-from-smart-glasses-after-wired-expose/7438)
- **Accessibility and policy critique** of Meta's glasses program. — [Tech Policy Press](https://techpolicy.press/for-metas-smart-glasses-access-is-an-afterthought)

### Inferences
- **Face ID and Meta's terms.** Doing face recognition of bystanders or players on Meta glasses data risks Meta enforcement under §2.2(f) (violating laws or Meta policies), §5.2.4 (re-identification), and probably the Acceptable Use Policy. Combined with BIPA and COPPA, it is the single biggest risk item. Jersey-number ID avoids it.
- **The LED limits stealth recording,** which helps with bystander perception. But many parents and players will not notice an LED from across a field. App-level transparency (team notice, roster consent) is still needed.
- **Reputation.** Press coverage frames Meta glasses plus face ID as doxxing and surveillance. Marketing should explicitly say "no facial recognition."

### Gaps
- The text of the Meta Wearables Acceptable Use Policy and the Supplemental MPT Privacy Policy was not retrieved, so it is unconfirmed whether they ban face recognition outright. Counsel or developer relations should confirm.
- Whether "Name Tag" launched by November 2026 is unknown; only press reports were found.
- The LED tamper clause was confirmed only in the Singapore-localized terms; the US version should be checked.

---

## 6. Referees wearing cameras: league rules permitting or banning official-worn cameras in youth games

### Takeaway
Referee-worn cameras are allowed only in sanctioned pilots. IFAB permits them in grassroots soccer only within approved trial competitions, and the WIAA (Washington) has allowed officials' body cameras to deter abuse. Outside such approvals, a referee wearing Meta glasses to record would likely breach equipment and association rules, and footage use would be limited to incident reporting, not public libraries.

### Cited Findings
- **IFAB trial.** In 2022 IFAB approved a limited trial of referee body cameras in grassroots football (adult and youth). Body cams may only be worn in competitions approved as part of the official trial, under a protocol. — [IFAB body cameras trial protocol](https://downloads.theifab.com/downloads/body-cameras-trial-protocol?l=en); [IFAB trials page](https://backup.theifab.com/trials/body-cameras)
- **Washington.** The WIAA and the Washington Officials Association agreed to let referees wear body cameras as a deterrent to abusive spectators, coaches, and players. A pilot of about 100 cameras reported nearly half of officials seeing improved behavior. — [Coach & AD](https://coachad.com/?p=41664); [Youth Sports Business Report](https://youthsportsbusinessreport.com/youth-sports-officials-test-body-cams-to-reduce-abuse)
- **Canada.** Ontario Soccer piloted 50 cameras for about 6,000 referees, with footage tied to incident reports reviewed by the association. A Quebec minor-soccer association planned body cams. — [Humber News](https://humbernews.ca/2024/01/ontario-soccer-begins-testing-body-cameras-on-referees-to-stop-abuse); [CTV Montreal](https://montreal.ctvnews.ca/quebec-minor-soccer-association-to-equip-referees-with-body-cameras-1.6716631)
- **England.** The FA has used body cams in trials. A teenage referee publicly asked for body cams, implying they are not allowed in his league. — [Sports Destination Management](https://www.sportsdestinations.com/management/safety-security/body-cam-usage-increasing-among-soccer-referees-33017); [Yorkshire Evening Post](https://www.yorkshireeveningpost.co.uk/watch-this/halifax-teenage-referee-pleads-for-body-cams-after-suffering-abuse-from-men-twice-his-age-4861017)

### Inferences
- **The "referee mode" use case** (officials recording for stats or review) needs explicit association approval and narrow use (incident review), and it would likely conflict with IFAB trial protocols if footage feeds a public stats library.
- **Spectator, coach, or parent wearers** are the realistic primary users. Referees and players are not.

### Gaps
- No Little League, Pop Warner, or NFHS football rule specifically on official-worn cameras was found.

---

## 7. Players wearing glasses during play: equipment safety rules (NFHS football eyewear, IFAB Law 4, Little League)

### Takeaway
Players wearing Meta glasses in games is a poor and likely non-compliant design target. In soccer, Law 4 allows only non-dangerous equipment such as "sports spectacles," at the referee's discretion, and consumer smart glasses (rigid frames, electronics, a battery, not impact-rated) are unlikely to qualify. In NFHS football, glasses can sit under a helmet but would interfere with fit and pose injury risk, and helmet eyeshields must be clear. Little League's rules were not retrieved. Assume player-worn use is out of scope and position the product for spectators, coaches, and parents.

### Cited Findings
- **IFAB Law 4.** Non-dangerous protective equipment, such as soft, lightweight padded items, plus goalkeepers' caps and "sports spectacles," are permitted. The referee decides whether an item is dangerous. — [The FA, Law 4 (2025-26)](https://www.thefa.com/-/media/files/thefaportal/governance-docs/laws-of-the-game/2025-26/law-4-the-players-equipment.ashx); [The FA Law 4 page](https://www.thefa.com/football-rules-governance/lawsandrules/laws/football-11-11/law-4---the-players-equipment)
- **National association guidance.** Players may wear sports goggles, sports glasses, or sports sunglasses if, in the referee's opinion, they pose no danger. — [Football NSW glasses guidance](https://www.glenmoreparkfootball.com.au/wp-content/uploads/2014/05/Football-NSW-Glasses.pdf)
- **IFAB 2026-27 changes.** Accessories are permitted if not dangerous and safely and securely covered. Taping over jewellery is still not permitted. — [IFAB Changes to the Laws of the Game 2026/27](https://downloads.theifab.com/downloads/changes-to-the-laws-of-the-game-202627?l=en)
- **NFHS football.** Eyeshields attached to the helmet must be clear with no tint (rule 1-5-3c(4) in recent editions). Tinted athletic goggles or glasses worn separately are generally legal. Safety rules have no waivers. — [South Dakota HSAA, tinted eyeshields](https://www.sdhsaa.com/Officials/FB-TintedEyeShields.pdf); [WIAA Wisconsin, helmet visors](https://www.wiaawi.org/about-wiaa/news/helmet-visors-tint); [Iowa HSAA Football Memo 3 (2024)](https://www.iahsaa.org/wp-content/uploads/2024/08/Football-Memo-3-8.28.24.pdf); [NSGA, NFHS splash shield ruling](https://nsga.org/news/nfhs-rules-schutt-football-helmet-splash-shield-can-be-worn-in-2020/)

### Inferences
- **"Sports spectacles"** in Law 4 means athletic eyewear. Meta Ray-Ban, Oakley, or Display frames are consumer electronics with hinges and a battery, not impact-rated sports goggles. A referee could reasonably rule them dangerous, and leagues and insurers would likely object. Oakley Meta models are marketed as sport sunglasses, but nothing found shows ANSI or ASTM impact certification for contact sport.
- **Football.** A device under a helmet adds injury risk and could interfere with helmet certification fit (NOCSAE). Not advisable.
- **Baseball.** Batting and catching helmets plus ball-impact risk make face-worn electronics hazardous. Coaches in the dugout or base coaches are a more plausible use, though base coaches wearing devices may fall under league equipment and communication rules.
- **Practice vs games.** Player-worn POV for training drills is a separate, lower-stakes case that still needs league and insurance sign-off.

### Gaps
- The Little League equipment rules (e.g., on electronic devices or eyewear) and the current-year NFHS football rule text were not retrieved.
- No impact-safety certification data for Meta or Oakley glasses was found.
- No league rule was found that names smart glasses specifically.

---

## 8. Content ownership and sharing: parents sharing videos, DMCA, right of publicity and NIL for high school athletes

### Takeaway
League and association rules (Little League's ownership of game video, state associations' postseason media rights) can override the instinct that "the parent who filmed it owns it." The platform needs a DMCA-style takedown process and user terms that put responsibility for rights on uploaders. High school NIL is now allowed in nearly every state, but most states bar the use of school names, logos, and uniforms in NIL deals, so any feature that helps athletes monetize highlight reels in school uniforms needs care.

### Cited Findings
- **Little League ownership.** Game video between chartered teams "remains the property of Little League Baseball" and cannot be sold, gifted, or shared with teams or others. Leagues cannot authorize platforms to distribute recorded streams without Little League's written consent. — [Little League streaming FAQs](https://www.littleleague.org/help-center/internet-webcast-and-streaming-faqs/)
- **Postseason rights.** State associations assign postseason media rights (NFHS Network). Violations can lead to association discipline or NFHS Network legal action. — [MHSAA 2025-26 Media Policy](https://www.misshsaa.com/2025/11/07/2025-26-media-policy/); [CHSAA](https://chsaanow.com/sports/2025/10/28/chsaa-nfhs-network-postseason-rights.aspx)
- **High school NIL.** Nearly every state permits some form of high school NIL, with wide variation. Most states bar NIL deals using school names, logos, uniforms, facilities, or other school IP (Oklahoma and Minnesota given as examples). Indiana bars NIL activity during team activities, Wisconsin bans vice sponsors and requires disclosure, and violations can cost eligibility. — [On3 high school NIL laws](https://www.on3.com/nil/laws/high-school); [Opendorse state-by-state](https://biz.opendorse.com/?p=7321); [Sportsepreneur (updated July 2026)](https://sportsepreneur.com/high-school-nil/); [National Law Review](https://natlawreview.com/article/nil-rules-apply-high-school-athletes-well-almost)
- **Minors' contracts.** Laws differ by state on minors' capacity to contract and their ability to void contracts. — [National Law Review, "Big Baller, Shot Caller"](https://natlawreview.com/article/big-baller-shot-caller-high-school-athletes-and-emerging-nil-framework)

### Inferences
- **Copyright.** Under US copyright the person who records generally owns the footage, but league membership terms, venue entry terms, and contracts can limit distribution. A sports game itself is not copyrightable (general knowledge), so Little League's position is mainly a contractual and membership claim. Little League has also called unauthorized tournament recording "copyright infringement" in its own materials. Counsel should review.
- **DMCA.** Register a DMCA agent with the Copyright Office, publish a takedown policy, and add a non-DMCA privacy takedown path (a parent wanting their child removed), which matters more in practice for youth content. General knowledge; verify.
- **Right of publicity.** Using a minor's name or likeness commercially (in ads, or selling highlight reels to third parties) needs parental consent. Most state right-of-publicity laws cover commercial use, not news or personal use. NIL features in uniform could break association rules. Not researched in depth; counsel needed.
- **Team-scoped licensing.** The library's terms should grant the platform only a limited license to host and display content to authorized team members, not broad rights to reuse or train on minors' footage.

### Gaps
- No right-of-publicity case involving youth-game footage or highlight apps was found.
- The DMCA agent and safe-harbor requirements were not sourced this session.
- Whether Hudl, GameChanger, or similar platforms have faced league or association rights disputes was not researched.

---

## 9. Synthesis for product design: what is allowed, what needs consent, what to avoid, and recommended patterns

### Takeaway
Lowest-risk architecture: **jersey-number and roster-based identification, no facial recognition, team-scoped private libraries, organization-level opt-in with parental consent, per-player opt-out and blur, and no player-worn devices.** Face recognition of minors is the one feature that most clearly triggers BIPA, CUBI, Colorado, COPPA biometric rules, GDPR Art. 9, Meta's re-identification ban, and bad press, so leave it out.

### Cited Findings (supporting the patterns, all cited above)
- Facial templates are personal information under amended COPPA and biometric identifiers under BIPA even when derived from photos. — [Infolaw Group](https://www.infolawgroup.com/insights/2025/4/29/little-data-big-requirements-is-your-business-ready-for-coppas-amendments); [Privacy World](https://www.privacyworld.blog/2022/04/breaking-federal-judge-in-illinois-affirms-that-bipa-extends-to-information-derived-from-photographs/)
- Photos become GDPR biometric data only when processed by technical means for unique identification. — [GDPR Recital 51](https://gdpr-info.eu/recitals/no-51/)
- Meta's developer terms bar re-identification, surveillance tooling, and selling data, and require deletion on request. — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/)
- Parents may refuse recording without penalty (MAAPP). — [SafeSport 2025 MAAPP](https://uscenterforsafesport.org/2025-maapp-manual)
- Little League requires releases and restricts sharing of game video. — [Little League FAQs](https://www.littleleague.org/help-center/internet-webcast-and-streaming-faqs/)
- Postseason high school streaming is often exclusive to the NFHS Network, with school liability for parent streams. — [CHSAA](https://chsaanow.com/sports/2025/10/28/chsaa-nfhs-network-postseason-rights.aspx)
- AYSO does not publish children's names or locations with photos. — [AYSO Privacy Policy](https://ayso.org/privacy-policy/)

### Inferences (recommendations; counsel to validate)

**Generally allowed (low risk)**
- A parent, coach, or spectator records a regular-season game from the sideline for personal or team use, with the LED visible.
- Reading jersey numbers on-device or server-side and mapping them to a roster the team admin supplies.
- Aggregate team stats and play-by-play keyed to roster entries inside a private team space.

**Requires consent or organizational approval**
- Any identification of a named minor (roster linkage). Get verifiable parental consent; for under-13s that is COPPA-grade consent.
- Sharing clips beyond the team (opposing team, public links, social media).
- Uploading full-game video of Little League games: league-level agreement plus releases; distribution may need Little League International's written consent.
- High school games: check state association and school policy, and block postseason streaming or public posting by default.
- Any EU/UK users: a lawful basis for processing children's images (likely consent or legitimate interests with a DPIA), a DPIA for systematic monitoring of children, and parental consent below the Art. 8 age.
- Audio capture: consider muting by default; two-party consent states.

**Avoid**
- Facial recognition, face clustering, or face templates of players or bystanders, including "auto-tag everyone in this photo." If ever offered, it would need written, BIPA-grade informed consent per person, a public retention policy, opt-in only, and exclusion of minors. Recommendation: do not build it.
- Persistent cross-game appearance or gait embeddings (gray-area biometric).
- Public, searchable player profiles of minors (names plus jersey numbers plus team plus location).
- Selling, licensing, or ad-targeting with player data (banned by Meta terms, restricted by state minors' laws).
- Player-worn glasses in games (equipment and safety rules).
- Referee-worn recording outside sanctioned pilots.
- Anything that defeats or hides the capture LED.
- Private DMs of clips between adult coaches and minors (MAAPP).
- Recording in locker rooms or bathrooms: geofence or auto-stop guidance.

**Recommended design patterns**
1. **Jersey-number-first ID.** OCR the number plus team color, map it to the roster, and let humans confirm. When a number is not visible, use short-lived tracking within a clip only, never stored and never face-based.
2. **Roster opt-in.** The team admin imports the roster. Each player's guardian gets a consent request with three tiers: (a) appear in team video, (b) be named or tagged, (c) be shareable outside the team. Default is (a) only, or none, depending on league policy.
3. **"Do not identify / blur me" flag** per player. Unconsented players are rendered anonymous (number masked in stats; optional automated blur, which uses face *detection* without identity, generally not a template, but confirm with counsel for Illinois).
4. **Team-scoped privacy.** Libraries are private to a team or organization by default. Sharing uses expiring links, no public indexing, and no cross-team search of minors.
5. **Organization-level onboarding.** League, club, or school admins accept terms, confirm their media policy and registration consents, and can disable recording for given games (e.g., postseason) or venues.
6. **Postseason and tournament guard.** A per-game "rights-restricted" flag disables live streaming and public sharing (NFHS Network events, Little League tournaments).
7. **Data minimization and retention.** Raw video retention limits (e.g., season plus N days), automatic deletion, parent-initiated deletion and export, and a written security program (COPPA and Meta §5.5).
8. **Transparency.** Visible "recording" notices to the team, a plain-language privacy policy (Meta §6.1), and an in-app "no facial recognition" statement.
9. **No ad SDKs or data brokers** in kid-facing surfaces. Do not sell data; use separate consent for any third-party disclosure (COPPA 2025).
10. **Privacy and DMCA takedown flows.** Fast removal on parent request, plus a registered DMCA agent.
11. **Coach-to-player sharing via team channels or parents** (MAAPP open and transparent).
12. **EU/UK.** Run a DPIA, collect parental consent, apply UK Children's Code defaults (high privacy by default, no profiling by default), and pick a data location strategy.

### Gaps
- No review by counsel. Items needing a lawyer: BIPA, CUBI, and Colorado exposure for ephemeral face *detection* and blurring; COPPA "directed to children" or actual-knowledge status for a parent-run app; Little League rights for parent-recorded regular-season video; state wiretap laws for audio; EU lawful basis for minors' sports video.
- Insurance and league liability implications were not researched.
