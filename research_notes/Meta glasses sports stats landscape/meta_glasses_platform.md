# Meta Smart Glasses Platform: Hardware and Developer Capabilities for a Third-Party Sports Recording/Analysis App (as of Nov 2026)

Research date: 2026-11-07. Scope: Ray-Ban Meta Gen 1 (2023), Ray-Ban Meta Gen 2 (2025), Ray-Ban Meta Gen 3 (2026), Oakley Meta HSTN, Oakley Meta Vanguard, Meta Ray-Ban Display + Neural Band, other 2026 devices, and the Meta Wearables Device Access Toolkit (DAT).

## 1. Device lineup and camera specs per device (incl. whether a Gen 3 exists)

### Takeaway
A Ray-Ban Meta Gen 3 does exist: announced and on sale at Connect on Sept 23, 2026, from $449. It keeps a 12MP / 3K camera and has a rated 9 h battery. Every camera-equipped model tops out at about 3K/30 (portrait). 60fps is only available at lower resolutions. Native clips are capped at about 3 minutes, livestreams at about 30 minutes, and landscape capture had not shipped as of Connect 2026. Vanguard is the most "action-cam-like" model, with a 122-degree FOV, slow-mo, hyperlapse, adjustable stabilization and IP67.

### Cited Findings
**Ray-Ban Meta Gen 3 (shipped Sept 2026)**
- Announced at Meta Connect 2026 and "on sale starting today" (Sept 23, 2026), from $449, in 27 lens/color combos. Styles are Aviator, Zena (cat-eye) and Wayfarer. Specs: 12MP camera, 3K video, six-mic array (Meta claims it cuts "over 90 percent of background noise"), and up to 9 h battery vs 8 h on Gen 2. Dolby Atmos spatial-audio video recording is coming "soon". The chip was not specified. — [Engadget: Everything announced at Connect 2026](https://www.engadget.com/2267230/everything-announced-at-meta-connect-2026/)
- Hands-on details: there is a new programmable Action button (Meta AI command, capture mode, etc.). Dolby Atmos video and landscape photo/video orientation "aren't out yet", and Meta plans to bring landscape capture to other models later. — [Engadget Gen 3 hands-on](https://www.engadget.com/2267213/ray-ban-meta-gen-3-hands-on-better-battery-life/)
- Gen 3 records up to 3K at 30fps (not 4K) with a 12MP ultra-wide camera. One review notes that landscape video is still absent. — [Dymesty Gen 3 review (secondary)](https://dymesty.com/blogs/articles/ray-ban-meta-gen-3-review); [Geeky Gadgets Gen 3 review](https://www.geeky-gadgets.com/ray-ban-meta-gen-3-review/)
- Other Connect 2026 hardware:
  - **Ray-Ban Meta Audio:** the first camera-free Meta glasses. 43 g, up to 12 h battery, $349, ships Oct 13, 2026. It is irrelevant for video capture.
  - **Meta VR Glasses:** about 100 g, $1,299.99, spring 2027. These are VR, not camera glasses.
  - **Muse Charm:** an AI pendant, teased only, with no specs.
  — [Engadget](https://www.engadget.com/2267230/everything-announced-at-meta-connect-2026/); [vr.org Connect 2026](https://vr.org/meta-connect-2026)
- **Ray-Ban Meta Optics:** another 2026 SKU, added to DAT support in v0.6.0 (Apr 15, 2026). DAT v0.8.0 (Jun 25, 2026) added generic "Meta Glasses" support and mocks for Ray-Ban Meta, Oakley Meta HSTN, Oakley Meta Vanguard, Ray-Ban Meta Optics and generic Meta Glasses. — [meta-wearables-dat-ios CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)

**Ray-Ban Meta Gen 1 (2023)**
- Qualcomm Snapdragon AR1 Gen 1, 12MP camera, livestreaming to Facebook/Instagram, Meta AI. — [Wikipedia: Ray-Ban Meta](https://en.wikipedia.org/wiki/Ray-Ban_Meta); [TechCrunch 2023](https://techcrunch.com/2023/09/27/ray-ban-meta-smart-glasses-livestream-to-instagram-and-facebook)
- Video was 1080p. Android Central contrasts Oakley's 3K with "Ray-Ban Meta's 1080p cameras". — [Android Central HSTN camera review](https://www.androidcentral.com/gaming/virtual-reality/oakley-meta-hstn-camera-review)
- The June 2024 v6.0 update raised the max clip from 60 s to 3 minutes. The setting must be changed manually, because the default stays at 60 s. — [9to5Google](https://9to5google.com/2024/06/22/meta-ray-ban-video-recording-limit-extended/); [Neowin](https://www.neowin.net/news/ray-ban-meta-smart-glasses-new-update-extends-video-recording-to-3-minutes/)

**Ray-Ban Meta Gen 2 (Sept 2025)**
- Video modes are 3K@30fps, 1440p@30fps and 1200p@60fps, with clips up to 3 minutes. Battery is up to 8 h typical (about 2x Gen 1), the case adds about 48 h, and it reaches 50% in about 20 min. Price is $379. Hyperlapse and slow-motion were promised in a later software update. — [9to5Google](https://9to5google.com/2025/09/17/ray-ban-meta-gen-2-battery-video-upgrades/); [Meta Newsroom](https://about.fb.com/news/2025/09/ray-ban-meta-gen-2-better-battery-life-video-capture/)
- Conflict: Techlomedia claims "3K at 60fps for 30 seconds", and another review cites a 5-minute clip limit. Most sources say 3 minutes. — [Techlomedia](https://techlomedia.in/2025/09/ray-ban-meta-gen-2-announced-with-better-camera-and-battery-life-116729/)

**Oakley Meta HSTN (summer 2025)**
- 12MP ultrawide. 3K mode is about 2300x3100 @30fps, portrait only, and the default is 1080p. Retailer listings show 1080p30, 1080p60 and 3K30. Meta claims 8 h typical battery. — [Android Central HSTN camera review](https://www.androidcentral.com/gaming/virtual-reality/oakley-meta-hstn-camera-review); [UploadVR](https://www.uploadvr.com/oakley-meta-glasses-announced/)

**Oakley Meta Vanguard (Oct 21, 2025, $499)**
- Camera: centered 12MP camera with a 122-degree wide-angle lens, video up to 3K, Slow Motion and Hyperlapse modes, and "adjustable video stabilization".
- Durability and audio: IP67, five-mic array with wind-noise reduction, and speakers 6 dB louder than HSTN.
- Battery: up to 9 h (6 h continuous music), and the case adds 36 h.
- Not stated in the official post: fps, clip length, chip and storage.
— [Meta Newsroom: Oakley Meta Vanguard](https://about.fb.com/news/2025/09/oakley-meta-vanguard-performance-ai-glasses/)
- T3 reports video capture "tops out at 3K/30 (for up to ~3 minutes per clip)". — [T3 review](https://www.t3.com/active/oakley-meta-vanguard-review); a lower-quality site lists about 30 s typical — [thewearify](https://thewearify.com/?p=93816)

**Meta Ray-Ban Display + Neural Band (Sept 2025, $799)**
- Camera: 12MP with 3x digital zoom, stills at 3024x4032 and video at 1440x1920 @30fps (portrait).
- Glasses: about 6 h mixed use, case adds up to 24 h. 600x600 monocular display, 20-degree FOV, 68-70 g.
- Neural Band: 18 h battery, IPX7.
— [Techpoint Africa guide](https://techpoint.africa/guide/meta-ray-ban-display-glasses/); [Tom's Guide](https://www.tomsguide.com/computing/smart-glasses/meta-ray-ban-display-glasses-features-neural-link-price-and-availability); [TechCrunch](https://techcrunch.com/2025/09/17/meta-unveils-new-smart-glasses-with-a-display-and-wristband-controller/)
- 2026 updates:
  - Pricing: $799 US / £749 / $1,149 CAD / €899. Launches in Germany, France and Italy on Oct 13, 2026.
  - New features: Dolby Atmos video capture, on-display photo editing, holographic avatars in WhatsApp calls, cycling/transit directions, and web apps via Meta AI app/Explore.
  — [Engadget](https://www.engadget.com/2267230/everything-announced-at-meta-connect-2026/)

**Livestreaming (native)**
- Ray-Ban Meta has supported hands-free Instagram Live / Facebook Live since the 2023 launch. — [TechCrunch 2023](https://techcrunch.com/2023/09/27/ray-ban-meta-smart-glasses-livestream-to-instagram-and-facebook)
- The cap is commonly cited as up to 30 minutes per stream, with switching between glasses and phone camera. This comes from low-quality secondary sources plus a Best Buy Q&A, and is not confirmed on an official Meta page. — [thetoolstrunk](https://thetoolstrunk.com/how-long-can-you-live-stream-with-meta-glasses/); [Best Buy Q&A](https://www.bestbuy.com/site/questions/ray-ban-meta-wayfarer-large-gen-1-glasses-with-meta-ai-audio-photo-video-compatability-clear-to-green-transition-lenses-matte-black/6596886?page=2)

### Inferences
- For sports, the practical native ceiling on all devices is 3K/30 portrait or about 1080-1200p/60. Portrait-only capture is a real problem for field/court sports, which suit landscape framing. Landscape is "coming" but was unshipped as of Sept 2026.
- Vanguard's 122-degree FOV and stabilization make it the best capture device for the wearer's POV. The Display is the only device that can show live stats back to the wearer.

### Gaps
- Official per-device FOV for Gen 1/Gen 2/Gen 3/HSTN/Display. Only Vanguard's 122-degree figure was confirmed officially.
- Vanguard slow-mo fps and hyperlapse max duration. Secondary coverage mentions 120fps slow-mo and hyperlapse up to 30 min, but I could not pin this to a reliable source.
- Gen 3 chip (whether AR1 Gen 1 or newer), Gen 3 video modes beyond 3K30, and Gen 3 storage.
- Whether Display or Gen 3 support Instagram/Facebook Live, and the current official livestream time cap.

## 2. Battery, thermals, storage, and capturing a full 1-3 hour game

### Takeaway
No Meta glasses can natively record a 1-3 hour game continuously.
- Native clips are capped at about 3 min, livestreams at about 30 min, and total recording per charge is roughly 30-50 min (measured on Gen 1/HSTN).
- The glasses expose thermal, battery and "peak power" stream errors, which confirms throttling and shutdown happen.

A full game would need segmented capture with case recharges, or a different primary camera, with the glasses as a supplementary POV.

### Cited Findings
- Android Central measured about 50 min of total record time at 1080p on Oakley Meta HSTN vs about 30 min on Ray-Ban Meta Gen 1 at the same resolution. At 3K the gap narrows. — [Android Central HSTN camera review](https://www.androidcentral.com/gaming/virtual-reality/oakley-meta-hstn-camera-review)
- Gen 2 owners anecdotally report about 25-30 min of total recording per charge. No measured continuous-recording test of Gen 3 has been published, and Meta's 9 h figure is mixed use, not continuous recording. — [Dymesty Gen 3 review (secondary, anecdotal)](https://dymesty.com/blogs/articles/ray-ban-meta-gen-3-review)
- Gizmodo measured about 6 h of continuous audio playback on Gen 3 vs about 5 h on Gen 2. No video endurance test was run. — [Gizmodo Gen 3 review](https://gizmodo.com/ray-ban-meta-gen-3-ai-glasses-review-2000822961)
- Stuff's Vanguard review says battery life is boosted but not enough to keep "recording mile markers for very long". — [Stuff Vanguard review](https://www.stuff.tv/review/oakley-meta-vanguard-review/)
- Storage is 32GB on Ray-Ban Meta, with no SD slot. You must sync to the phone app when it fills. — [vrarwiki](https://vrarwiki.com/wiki/Ray-Ban_Meta_Smart_Glasses) (secondary)
- Livestreaming drains the battery faster than typical use. Official runtime for live use is not published. — [thetoolstrunk](https://thetoolstrunk.com/how-long-can-you-live-stream-with-meta-glasses/) (low quality)
- DAT 1.0 (Sept 24, 2026) adds device state accessors for battery, charging, don (worn), hinge and thermal, plus a device state listener. `StreamError` cases were renamed for "thermal, peak power, battery", which means streams can be terminated for those reasons. DAT 0.7.0 (May 2026) added thermal and battery state reporting. — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)
- Charging cases recharge to 50% in about 20 min:
  - Gen 2 case: about 48 h
  - Vanguard case: 36 h
  - Display case: 24 h
  — [9to5Google](https://9to5google.com/2025/09/17/ray-ban-meta-gen-2-battery-video-upgrades/); [Meta Newsroom Vanguard](https://about.fb.com/news/2025/09/oakley-meta-vanguard-performance-ai-glasses/)

### Inferences
- A realistic full-game strategy with glasses alone:
  - Burst or highlight capture: native 3-min clips, Vanguard-style autocapture, or DAT photo/low-fps capture.
  - Low-fps or low-res DAT streaming (for example 2-7 fps) to the phone to stretch battery.
  - Swapping the glasses into the case at breaks such as halftime and quarters, about 20 min to 50%.
  - Owning two pairs and rotating them.
- Continuous 720p/30 DAT streaming for 1-3 h is very likely beyond battery and thermal limits on every model. Apps should handle thermal and battery `StreamError` gracefully and auto-resume.
- For analytics of a whole game, a fixed sideline camera (phone or action cam) as the primary source, with glasses as a POV and annotation input, is more robust.

### Gaps
- No published measured test of continuous recording or DAT-streaming battery life on Gen 2, Gen 3, Vanguard or Display.
- No published thermal-throttle onset times.
- Storage capacity for Gen 2/Gen 3/Vanguard/Display was not confirmed (32GB is cited for Gen 1).

## 3. Meta Wearables Device Access Toolkit (DAT): capabilities, specs, status, publishing

### Takeaway
DAT reached a stable 1.0 at Connect 2026, rolling out from Sept 30, 2026, after a year in developer preview. It is a native iOS (Swift) and Android (Kotlin) SDK that runs on the phone.

What it exposes:
- A camera stream at up to 720x1280 at up to 30fps, constrained by Bluetooth Classic, with HEVC background streaming and a newer Wi-Fi transport.
- Display UI rendering on Meta Ray-Ban Display.
- Experimental modules: photo capture, camera audio, motion/IMU, input events, on-device speech, "Hey Meta" voice invocation.

Public store-style publishing/discovery was still "coming soon" as of Connect 2026. Several experimental features are explicitly "unavailable for production publishing".

### Cited Findings
**Status and timeline**
- Announced Sept 18, 2025. The developer preview gave access to the camera, microphones and open-ear audio, with native iOS/Android SDKs and samples on GitHub. Meta AI and voice commands were excluded from the initial preview. Public publishing was "planned for 2026", and only select partners could publish during the preview. — [Meta dev blog: Introducing DAT](https://developers.meta.com/blog/introducing-meta-wearables-device-access-toolkit/)
- "After a year in developer preview, Wearables Device Access Toolkit 1.0 is here, a stable, supported release", rolling out Sept 30, 2026. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)
- Connect 2026 recap:
  - DAT 1.0 launched, with launch via "Hey Meta" invocation and navigation by Neural Band swipe.
  - One integration covers display and displayless glasses.
  - Capabilities named: camera capture, voice streaming, and motion tracking (head movement/orientation).
  - Submission and approval for discovery surfaces (the Display and a curated Meta AI app list) is "coming soon".
  — [Meta Connect 2026 dev recap](https://developers.meta.com/blog/meta-connect-recap/)
- FAQ on publishing: submissions are not yet open, so developers should create a Wearables Developer Center account. The Developer Center manages organizations and release channels. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)
- The iOS README still describes developer-preview access: SDK, docs, testing on glasses, and creating organizations and release channels. The current SPM version is 1.0.1. — [GitHub facebook/meta-wearables-dat-ios](https://github.com/facebook/meta-wearables-dat-ios)
- Testers: DAT builds distribute via release channels with up to 100 testers (as of May 2026). — [Meta dev blog: Build for display glasses](https://developers.meta.com/blog/build-for-display-glasses/)

**Supported devices**
- Ray-Ban Meta (Gen 1 and Gen 2), Meta Ray-Ban Display, Oakley Meta HSTN and Oakley Meta Vanguard. "New SKUs are supported as they launch." "Capability availability varies by device." — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)
- Ray-Ban Meta Optics was added in v0.6.0 and Display glasses in v0.4.0 (Feb 2026). Gen 3 is not named in the changelog. — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)

**Camera streaming specs**
- Stream resolutions: HIGH 720x1280, MEDIUM 504x896, LOW 360x640.
- Frame rates: 2, 7, 15, 24 or 30 fps.
- Resolution and frame rate are constrained by the Bluetooth Classic link to the phone, and per-frame compression adapts to the available bandwidth. Delivered images may look lower quality than the reported resolution suggests.
- Under constrained bandwidth the SDK first steps resolution down one level, then reduces fps. A third-party mirror of Meta's SDK skill says it does not drop below 15 fps.
- These details came via Meta's docs as surfaced in search, and the iOS details via third-party mirrors of Meta's agent-skill files. Verify them against the official "Start a camera stream" page.
— [Meta Android integration guide](https://wearables.developer.meta.com/docs/develop/dat/build-integration-android/); [mcpservers.org mirror of DAT camera-streaming skill](https://mcpservers.org/agent-skills/facebook/meta-wearables-dat-ios/camera-streaming)
- Changelog for streaming:
  - v0.5.0 (Mar 11, 2026) added "higher-resolution video (720x1280)" and HEVC (`hvc1`) streaming that continues in the background. The default raw codec still pauses when the app is backgrounded.
  - v0.8.0 (Jun 25, 2026) added a Wi-Fi transport.
  - v0.2.1 added raw `CMSampleBuffer` frames.
  — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)
- Wi-Fi: the iOS guide (updated Oct 29, 2026) says the phone joins a Wi-Fi network hosted by the glasses, so the app needs the Hotspot Configuration capability. — [Meta iOS integration guide](https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios/)
- In April 2026, "Wi-Fi direct" and voice invocation were still described as in progress. — [Meta dev blog, Apr 1 2026](https://developers.meta.com/blog/explore-whats-possible-with-wearables-device-access-toolkit/)

**Other modules (1.0)**
- v1.0.0 (Sept 24, 2026) adds experimental modules for:
  - Inputs (glasses input events)
  - Motion (orientation/movement samples, i.e. IMU)
  - Speech (on-device transcription)
  - Voice invocations ("Hey Meta"-style, starting with launching an app)
  - Photo capture (standalone high-quality photos with transfer progress)
  - Camera audio streaming
  - Display mock preview
  — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)
- README: standalone photo capture and synchronized PCM audio via the camera stream are "experimental" and "unavailable for production publishing". Analytics and crash reporting to Meta are on by default, with Info.plist opt-outs. — [GitHub README](https://github.com/facebook/meta-wearables-dat-ios)
- The FAQ lists DAT capabilities as video streaming, photo capture, microphone, audio, camera, motion and IMU. The Mock Device Kit does not support display glasses. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

**Android packaging and permissions**
- Artifacts on Maven Central: `mwdat-core`, `mwdat-camera`, `mwdat-display` and `mwdat-mockdevice`.
- Apps need `APPLICATION_ID` and `CLIENT_TOKEN` from the Wearables Developer Center for attestation. Developer Mode skips attestation (set both to 0).
- Camera permission is requested through the Meta AI app.
- Sessions start via `AutoDeviceSelector` / `SpecificDeviceSelector`, and a stopped session can't be restarted.
— [Meta Android integration guide](https://wearables.developer.meta.com/docs/develop/dat/build-integration-android/)
- iOS minimum target was raised to iOS 17.2 in v0.9.0. — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)
- Region: the SDK downloads worldwide, but full capabilities and the Developer Center require residence in "AI glasses supported countries". — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

**Display SDK and Neural Band**
- May 14, 2026 (developer preview): DAT added display UI components (text, images, lists, buttons, video playback) in Swift/Kotlin.
- Web Apps (HTML/CSS/JS) run directly on Meta Ray-Ban Display, with access to motion/orientation, phone GPS, Neural Band input and local storage. A starter kit is on GitHub.
- Neural Band uses sEMG gestures. No named low-level gesture API was described.
— [Meta dev blog: Build for display glasses](https://developers.meta.com/blog/build-for-display-glasses/)
- Display changelog: v0.7.0 added Display text/buttons/images/icons/MP4 playback and the DAT App Model (DAM). v0.9.0 added `ButtonGroup` and the `supportsDisplay` check. — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)
- Input and UI tooling:
  - Navigation and selection come from Neural Band and captouch.
  - Text entry uses dictation, handwriting or an on-screen keyboard.
  - There is a UI Toolkit for Display plus a browser-based simulator.
  - Web Apps get "Neural Band wrist motion" context.
  - Web Apps are shared by URL, deeplink or QR code via Developer Mode.
  — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

**Meta AI access**
- Meta AI Connectors (developer preview) expose a service as API/MCP tools callable inside Meta AI conversations on glasses and in the app. WebMCP (developer preview) lets Meta AI operate functions that a Display web app exposes. Sign-up is at dev.meta.ai. — [Meta Connect 2026 dev recap](https://developers.meta.com/blog/meta-connect-recap/); [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

**Tooling**
- The repo ships rule files and plugins for Claude Code, Codex, Cursor, Copilot and Muse Code, plus a hosted docs MCP server. — [GitHub README](https://github.com/facebook/meta-wearables-dat-ios)

### Inferences
- For a sports app, DAT's 720p/30 maximum (and often lower in practice over Bluetooth) is the hard ceiling for live analysis. It is adequate for coarse tracking (scoreboard reading, player/ball detection at close range) but weak for fine ball tracking at distance.
- The Wi-Fi transport may improve quality, but no figures were published.
- Native 3K clips are higher quality but not exposed as a live stream to third parties. The only DAT path to high-res is experimental photo capture.
- Because photo and audio capture are experimental and "unavailable for production publishing", a shippable v1 should rely on the video stream only. Store-style distribution beyond about 100 testers per release channel was not yet open as of early Nov 2026.

### Gaps
- Official published latency figures (none found; "low-latency" is only qualitative).
- Wi-Fi transport resolution and fps limits.
- Photo-capture resolution.
- Audio sample rate.
- Whether per-device capability varies, for example whether Gen 1 supports Wi-Fi/HEVC.
- Gen 3 DAT support (implied by "new SKUs supported as they launch" but not explicitly confirmed).
- The exact Wearables Developer Terms text on revenue, distribution and review criteria.
- Whether a "1.0" Android changelog matches the iOS one.

## 4. Alternative data paths (Meta AI app import, livestream hacks, Garmin/Strava, Live AI)

### Takeaway
Outside DAT, glasses media flows through the Meta AI app (formerly Meta View), which syncs and imports clips from the glasses' internal storage to the phone. Livestreaming natively targets Instagram/Facebook Live, capped at about 30 min.

Vanguard has first-party Garmin and Strava integrations:
- Metric overlays on video
- Autocapture triggered by distance, heart rate, speed or elevation
- Post-workout summaries

None of these give third parties a documented API to the raw high-res video stream.

### Cited Findings
- Storage fills and must sync with the Meta View/Meta AI app. There is no SD card. — [vrarwiki](https://vrarwiki.com/wiki/Ray-Ban_Meta_Smart_Glasses) (secondary)
- Vanguard and Garmin:
  - Hands-free Meta AI queries such as "Hey Meta, what's my heartrate?"
  - A peripheral status LED shows whether you are on target for heart rate or pace.
  - Autocapture records video clips at distance milestones or when heart rate, speed or elevation rises.
  — [Meta Newsroom Vanguard](https://about.fb.com/news/2025/09/oakley-meta-vanguard-performance-ai-glasses/)
- Vanguard and Strava: performance metrics can be overlaid on photos and videos and shared to Strava, Instagram, Facebook, WhatsApp and other apps from the Meta AI app. App Connections with Garmin Connect, Apple Health or Health Connect give post-workout summaries. — [Meta Newsroom Vanguard](https://about.fb.com/news/2025/09/oakley-meta-vanguard-performance-ai-glasses/)
- T3 calls the Garmin/Strava integration "clever but clunky in practice". You record on the watch or phone and manually ask the glasses for stats. — [T3 review](https://www.t3.com/active/oakley-meta-vanguard-review)
- Native Instagram/Facebook livestreaming has been available since 2023. — [TechCrunch 2023](https://techcrunch.com/2023/09/27/ray-ban-meta-smart-glasses-livestream-to-instagram-and-facebook)
- Twitch and Logitech Streamlabs built IRL-streaming integrations on DAT. Streamlabs offers hands-free streaming with dynamic overlays and multistreaming. — [Meta dev blog: Introducing DAT](https://developers.meta.com/blog/introducing-meta-wearables-device-access-toolkit/)
- Meta Ray-Ban Display has a "Record display" button in the Meta AI app or glasses settings. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)

### Inferences
- A non-DAT "hack" workflow could work:
  - Record native 3-min 3K clips, or Vanguard autocapture clips.
  - Let the Meta AI app import them to the phone gallery.
  - Have the third-party app ingest them from the photo library.
- This gives higher quality than DAT streaming, but is not real-time and is limited by clip caps and battery.
- Streamlabs/Twitch-style integrations show that live RTMP-like egress is achievable via DAT (phone relays the stream). Native glasses livestreaming only targets Meta's own platforms.

### Gaps
- Whether the Meta AI app auto-exports to the phone gallery, and how it transfers (Wi-Fi vs Bluetooth). No primary source was fetched.
- Whether WhatsApp/Messenger video calls from glasses can be captured by a third party. I found no source.
- Meta "Live AI" feature details and any developer access. Not covered in the sources fetched.
- Whether Garmin/Strava integration exists on non-Vanguard models.

## 5. On-device compute: can third parties run code on the glasses?

### Takeaway
On displayless glasses, third-party code does not run on the glasses. DAT apps run on the phone (iOS/Android) and receive streamed sensor data, and processing happens on the phone or in the cloud.

The one exception is Meta Ray-Ban Display:
- Third-party Web Apps (HTML/CSS/JS) run "directly on" the glasses.
- DAT can push display UI components to them.

Ray-Ban Meta uses the Qualcomm Snapdragon AR1 Gen 1.

### Cited Findings
- Ray-Ban Meta uses the Qualcomm Snapdragon AR1 Gen 1. — [Wikipedia: Ray-Ban Meta](https://en.wikipedia.org/wiki/Ray-Ban_Meta)
- DAT is a mobile SDK. Connect 2026 framed it as extending "a mobile app to AI glasses without rebuilding it", keeping existing code, infrastructure and store listing. — [Meta Connect 2026 dev recap](https://developers.meta.com/blog/meta-connect-recap/)
- "Developers can process data locally or through cloud or edge platforms." — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/)
- Web Apps are built with HTML, CSS and JavaScript and run directly on Meta Ray-Ban Display glasses, with no SDK or native app. — [Meta Wearables FAQ](https://developers.meta.com/wearables/faq/); [Meta dev blog: Build for display glasses](https://developers.meta.com/blog/build-for-display-glasses/)
- DAT 1.0 includes "on-device speech" transcription, which runs on Meta's side rather than as third-party code. — [DAT iOS CHANGELOG](https://github.com/facebook/meta-wearables-dat-ios/blob/main/CHANGELOG.md)

### Inferences
- All computer vision for sports analysis (player/ball tracking, stat extraction) must run on the phone or in the cloud.
- On Display, a lightweight web app could show live scores and stats pushed from the phone or cloud.

### Gaps
- Gen 2, Gen 3, Vanguard, HSTN and Display chip identities were not confirmed in fetched sources.
- Display Web App compute and performance limits, and whether Web Apps can access the camera, were not documented in the sources fetched.

## 6. Real-world third-party apps on the toolkit (especially sports)

### Takeaway
The only sports-related DAT partner found is 18Birdies (golf): real-time yardages, club recommendations and hands-free social capture. Other launched or prototype apps focus on:
- Accessibility (Be My Eyes, Seeing AI, OOrion, Aira, HumanWare)
- Streaming (Twitch, Streamlabs)
- Hobby and lifestyle (Simply Draw, Planta)

No team-sport game recording or analytics app was found, which suggests open whitespace.

### Cited Findings
- Launch partners (Sept 2025):
  - **Disney Imagineering:** park tips
  - **18Birdies:** golf yardages, club recommendations, hands-free social capture
  - **Be My Eyes:** about 1M users
  - **HumanWare**
  - **Logitech Streamlabs:** hands-free streaming, overlays, multistreaming
  - **Twitch:** IRL streaming
  - **Microsoft Seeing AI**
  - **L+R**
  - **Pixel and Texel**
  — [Meta dev blog: Introducing DAT](https://developers.meta.com/blog/introducing-meta-wearables-device-access-toolkit/)
- April 1, 2026 showcase:
  - **Simply Draw:** time-lapse recording of drawing sessions with camera and audio. Available on iOS.
  - **Planta:** plant identification. Available on iOS.
  - **OOrion:** blind/low-vision object and text finding. Available on iOS.
  - **Aira:** live interpreters over a "low-latency camera feed".
  - Prototypes: MultiSet AI (VPS localization), DB Creations "Hide n'Seek" (video recording during play with kids), SmartSight "Luna" (study coach).
  - No sports or fitness apps were named.
  — [Meta dev blog, Apr 1 2026](https://developers.meta.com/blog/explore-whats-possible-with-wearables-device-access-toolkit/)
- Meta's example use cases for Display include "real-time scores and status updates". — [Meta dev blog: Build for display glasses](https://developers.meta.com/blog/build-for-display-glasses/)
- Connect 2026 sports announcements were VR-focused: ESPN Immersive 8K 180-degree streaming on Meta VR Glasses, and 100+ live events with MLB, NBC Sports, TNT Sports and UFC. These are not camera-glasses capture. — [Engadget](https://www.engadget.com/2267230/everything-announced-at-meta-connect-2026/)

### Inferences
- Simply Draw (time-lapse capture plus audio) and Hide n'Seek (recording during play) are the closest architectural analogs to a "record a game from POV" app. They show that recording via DAT to the phone is an accepted pattern.

### Gaps
- Whether 18Birdies' glasses integration shipped publicly, and its current state.
- Any other sports or coaching apps (tennis, basketball, soccer, cycling) on DAT. None found.
- Download and usage numbers for shipped DAT apps.

## 7. Policies: privacy LED, recording indicators, facial recognition, data use

### Takeaway
The Meta Wearables Developer Acceptable Use Policy (last updated Sept 22, 2026) has these relevant rules:
- It prohibits identifying people from faces or voices via device sensors. Exceptions such as accessibility apps need prior Meta approval.
- It bans bypassing, tampering with or obscuring the capture LED.
- It bans surreptitious capture of recognizable audio or video, and recording in sensitive locations.

A sports app that identifies players by face would therefore need approval or a non-biometric approach, for example jersey numbers.

### Cited Findings
- AUP quotes:
  - Prohibited: "Use device sensors for unique identification of people based on physical characteristics, such as voices and faces". "Exceptions are granted for specific use cases, including accessibility apps, with prior Meta approval."
  - Prohibited: to "promote or enable bypassing, tampering with, or obscuring hardware-level recording indicators (such as the capture LED)".
  - Prohibited: to "Surreptitiously collect recognizable audio or video content of the user or others".
  - Prohibited: "analyzing people in a user's surroundings to facilitate unwanted approaches or interactions".
  - Prohibited: to "Encourage the use of device sensors or recording in sensitive locations".
  - Also covered: age-gating requirements and harassment.
  - The AUP page did not address data sale, AI-training or health-data rules.
  — [Meta Wearables Developer AUP](https://wearables.developer.meta.com/acceptable-use-policy/)
- Developer Terms govern integration development and submission, alongside the AUP. — [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms/)
- DAT SDK analytics and crash reporting send data to Meta by default (opt-out available), and Meta "may collect data on how users' devices communicate with your app". — [GitHub README](https://github.com/facebook/meta-wearables-dat-ios)
- The capture LED is a white light that blinks while capturing. Reporting notes it can be covered with tape. — [virtual.reality.news](https://virtual.reality.news/news/meta-ai-glasses-privacy-concerns-bystanders-data-and-whats-unresolved/) (secondary)
- WIRED-reported dormant "NameTag" facial-recognition code in Meta's companion app was later removed. Meta says no consumer facial-recognition feature has launched. — [Captain Compliance summary of WIRED](https://captaincompliance.com/education/meta-removes-hidden-facial-recognition-system-from-smart-glasses-app-after-wired-investigation/); [Digital Trends](https://digitaltrends.com/wearables/meta-denied-face-scanning-tech-on-ai-smartglasses-and-then-silently-wiped-the-evidence)
- Meta's separate Horizon Developer Data Use Policy (updated Jul 2, 2026) also addresses facial-recognition identification of natural persons. It is adjacent, not confirmed to apply to wearables. — [Meta Developer Data Use Policy](https://developers.meta.com/vr/policy/data-use/)

### Inferences
- Player identification should use jersey numbers, team colors, roster assignment by the user, or position tracking, not face or voice biometrics, unless Meta grants an exception.
- Recording youth sports may raise "minors" and sensitive-location concerns. Surface the LED and consent clearly.
- Anonymous body tracking (pose, ball) does not appear to be prohibited by the quoted AUP text, but "analyzing people in a user's surroundings" wording warrants legal review.

### Gaps
- Full Developer Terms text (data retention, cloud processing, monetization, app review) was not fetched.
- Whether the LED is software-enforced during DAT streaming on every device. It is presumed hardware-level from the AUP wording, but there is no explicit doc.
- Whether DAT data may be used to train ML models.
