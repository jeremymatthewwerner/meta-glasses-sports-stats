# Open-Source CV/ML Building Blocks for Extracting Players, Events, Plays and Stats from Sports Video (Football, Soccer, Baseball; Sideline and Egocentric Footage)

Methodology note: repo maturity figures (stars, license SPDX id, last push) were pulled live from the GitHub REST API on 2026-11-07 (`api.github.com/repos/<owner>/<repo>`); a few repos could not be queried after the unauthenticated rate limit was hit and are marked as such. "NOASSERTION" means GitHub could not map the license file to a standard SPDX license, which usually means a custom or non-standard license. The SoccerNet 2025 results paper was downloaded and its text was read directly. Other facts come from web search results and fetched pages, cited inline.

## 1. General pipelines: detection, segmentation, tracking, re-ID

### Takeaway
The most practical permissive-license (MIT/Apache) stack today is Roboflow `supervision` + `sports` (MIT) for glue/annotation/team clustering, RF-DETR or RT-DETR (Apache-2.0) for detection, ByteTrack/OC-SORT/BoT-SORT (MIT) for tracking, and Torchreid (MIT) for re-ID. Ultralytics YOLO (v8/11/26/27) is the most mature but is AGPL-3.0, so a closed commercial product needs an Enterprise license. SAM 2 is Apache-2.0, but SAM 3 moved to a custom "SAM License".

### Cited Findings
**Catalog (GitHub API, 2026-11-07):**

| Repo | URL | License | Stars | Last push | What it does |
|---|---|---|---|---|---|
| roboflow/supervision | https://github.com/roboflow/supervision | MIT | 51.5k | 2026-11-06 | Reusable CV tools: annotators, ByteTrack wrapper, zone counting, dataset utilities |
| roboflow/sports | https://github.com/roboflow/sports | MIT | 5.5k | 2026-08-28 | Sports CV tools: soccer example with pitch keypoints, player/ball detection, team classification, radar view |
| ultralytics/ultralytics | https://github.com/ultralytics/ultralytics | AGPL-3.0 | 63.2k | 2026-11-07 | YOLO27, YOLO26, YOLO11, YOLOv8 detection/segmentation/pose/tracking (repo description) |
| roboflow/rf-detr | https://github.com/roboflow/rf-detr | Apache-2.0 | 10.0k | 2026-11-06 | Real-time DETR detector + segmentation |
| lyuwenyu/RT-DETR | https://github.com/lyuwenyu/RT-DETR | Apache-2.0 | 5.7k | 2026-10-09 | CVPR 2024 real-time detection transformer |
| IDEA-Research/GroundingDINO | https://github.com/IDEA-Research/GroundingDINO | Apache-2.0 | 10.7k | 2024-08-12 | Open-vocabulary detection, useful for auto-labeling |
| facebookresearch/sam2 | https://github.com/facebookresearch/sam2 | Apache-2.0 | 20.1k | 2026-05-30 | Promptable image and video segmentation and tracking |
| facebookresearch/sam3 | https://github.com/facebookresearch/sam3 | NOASSERTION (custom SAM License) | 12.2k | 2026-10-23 | Concept-prompted detect + segment + track |
| FoundationVision/ByteTrack (formerly ifzhang) | https://github.com/FoundationVision/ByteTrack | MIT | 6.8k | 2024-06-19 | ECCV 2022 tracker that associates every detection box |
| NirAharon/BoT-SORT | https://github.com/NirAharon/BoT-SORT | MIT | 1.6k | 2024-08-08 | Tracker with camera-motion compensation + ReID |
| noahcao/OC_SORT | https://github.com/noahcao/OC_SORT | MIT | 1.2k | 2026-04-21 | CVPR 2023 observation-centric SORT, robust to non-linear motion |
| nwojke/deep_sort | https://github.com/nwojke/deep_sort | GPL-3.0 | 6.2k | 2025-03-02 | Classic DeepSORT; GPL makes it a poor fit for closed products |
| mikel-brostrom/boxmot | https://github.com/mikel-brostrom/boxmot | AGPL-3.0 | 8.3k | 2026-11-04 | Pluggable SOTA tracker zoo (ByteTrack, BoT-SORT, OC-SORT, StrongSORT, etc.) |
| KaiyangZhou/deep-person-reid (Torchreid) | https://github.com/KaiyangZhou/deep-person-reid | MIT | 4.9k | 2026-01-09 | Person re-ID library (OSNet etc.) |
| TrackingLaboratory/tracklab | https://github.com/TrackingLaboratory/tracklab | MIT | 255 | 2026-05-01 | Modular end-to-end tracking framework; the base of the SoccerNet GSR baseline |
| TrackingLaboratory/CAMELTrack | https://github.com/TrackingLaboratory/CAMELTrack | Apache-2.0 | 137 | 2026-02-16 | Context-aware multi-cue online MOT |
| Atomscott/sportslabkit | https://github.com/Atomscott/sportslabkit | GPL-3.0 | 329 | 2023-12-19 | "Turning sports video into CSV files"; stale |
| open-mmlab/mmaction2 | https://github.com/open-mmlab/mmaction2 | Apache-2.0 | 5.2k | 2026-03-18 | Video action recognition/localization toolbox |
| sming256/OpenTAD | https://github.com/sming256/OpenTAD | Apache-2.0 | 349 | 2026-07-14 | Temporal action detection toolbox |

**Ultralytics licensing:**
- Ultralytics markets YOLO26 as edge-first with optional NMS-free end-to-end inference, "up to 43% faster CPU inference", and export to TensorRT, ONNX, CoreML, TFLite and OpenVINO — [Ultralytics YOLO26 page](https://www.ultralytics.com/yolo/yolo26)
- Ultralytics' license page says AGPL is for those "comfortable open-sourcing your entire project". An Enterprise license is required for integration into business products and services, including internal tools and production deployments — [Ultralytics License](https://www.ultralytics.com/license). The docs describe the AGPL tier as aimed at students and enthusiasts — [Ultralytics docs](https://docs.ultralytics.com). These two framings of what AGPL permits are inconsistent.
- The GitHub repo description already lists "YOLO27" alongside YOLO26/11/v8 — [GitHub ultralytics/ultralytics](https://github.com/ultralytics/ultralytics)
- Note: model weights fine-tuned with Ultralytics (including BaseballCV's models, see Section 6) inherit AGPL questions — [Ultralytics License](https://www.ultralytics.com/license)

**SAM 3:**
- SAM 3 "detects, segments, and tracks objects in images and videos based on concept prompts". It was released under a custom SAM License (Nov 19, 2025), not the Apache-2.0 license of SAM/SAM 2 — [Roboflow SAM 3 license page](https://roboflow.com/model-licenses/segment-anything-3); [Roboflow blog: What is SAM 3](https://blog.roboflow.com/what-is-sam3/)
- Third-party summaries describe SAM 3's license as worldwide and royalty-free for commercial use. Its restrictions cover military/weapons/espionage use, ITAR work, sanctioned parties and reverse engineering, and Meta can change the terms. These are secondary summaries; the primary license text was not read in this session — [Roboflow](https://roboflow.com/model-licenses/segment-anything-3); [HF mirror README](https://huggingface.co/AEmotionStudio/sam3/blob/main/README.md)

**What winning pro pipelines actually use (SoccerNet GSR 2025):**
- Fine-tuned detectors are standard, with YOLO-X, YOLOv8, YOLOv11 and RF-DETR widely used. Tracking-by-detection dominates, often with Deep-EIoU and BoT-SORT, plus tracklet-linking (GTA) or two-stage tracking. Optical flow was newly used for temporal smoothing. CLIP- and OSNet-based features were strong for re-ID, role, team and jersey tasks — [SoccerNet 2025 Challenges Results, arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
- One top entry (3rd place, GSR-3) used YOLOv12 for persons and a custom RT-DETR for 27 field-line categories. It added Farneback optical flow to improve Kalman motion prediction during abrupt movements, CLIP-ReIdent features, and a 6-layer Transformer for tracklet aggregation — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)

**Community repos (common tutorials, not production):**
- abdullahtarek/football_analysis (YOLO + KMeans team colors + camera-movement estimation tutorial): 1.0k stars, no license file, last push 2024-04 — [GitHub](https://github.com/abdullahtarek/football_analysis)
- SkalskiP/sports (Roboflow author's experiments): 559 stars, no license, last push 2023-12 — [GitHub](https://github.com/SkalskiP/sports)

### Inferences
- For a commercial or closed product, avoid Ultralytics weights and code, BoxMOT (AGPL), DeepSORT (GPL) and sportslabkit (GPL) unless you buy a license. RF-DETR/RT-DETR + supervision's ByteTrack + Torchreid OSNet gives a fully permissive stack.
- BoT-SORT's camera-motion compensation and the optical-flow-aided Kalman prediction used by SoccerNet 2025 entries matter most for handheld and head-mounted footage, where ego-motion dominates. OC-SORT's tolerance to non-linear motion is also relevant.
- SAM 2/SAM 3 are best used offline, for auto-labeling amateur footage to fine-tune a small detector, or for re-acquiring a lost target. They are not a per-frame tracker on-device.

### Gaps
- No benchmark was found for these trackers on handheld or egocentric amateur sports footage; all reported numbers are on broadcast or fixed cameras.
- The primary SAM 3 license text was not retrieved; verify it before shipping.

## 2. Jersey number recognition, team classification, player re-ID

### Takeaway
The best open pipeline is Koshkina & Elder's jersey-number-pipeline: legibility classifier, pose-guided torso crop, PARSeq STR, then tracklet aggregation. It reports 87.4% tracklet accuracy on SoccerNet. But the 2025 SoccerNet GSR winners moved to VLMs (LLaMA-3.2-Vision, Qwen2-VL) or fine-tuned CLIP for jersey reading. Team assignment by SigLIP embeddings + UMAP + KMeans (Roboflow) or by clustering jersey colors is standard and unsupervised.

### Cited Findings
- **mkoshkina/jersey-number-pipeline:** https://github.com/mkoshkina/jersey-number-pipeline, 74 stars, license NOASSERTION (check terms), last push 2024-10. It reports 91.4% accuracy on hockey images and 87.4% on SoccerNet tracklets, using PARSeq pretrained on SynthText/COCOText/TextOCR and fine-tuned on legible jersey crops. PARSeq trained on hockey transferred better to soccer than the reverse — [arXiv 2405.13896](https://arxiv.org/html/2405.13896v1)
- **baudm/parseq** (the STR model): https://github.com/baudm/parseq, Apache-2.0, 747 stars, last push 2024-05 (GitHub API)
- SoccerNet jersey challenge devkit: https://github.com/SoccerNet/sn-jersey (30 stars, no license file, last push 2024-07). SoccerNet re-ID devkit: https://github.com/SoccerNet/sn-reid (MIT, 93 stars) (GitHub API)
- A 2025 SoccerNet jersey entry used Gaussian outlier rejection on embeddings, ViTPose torso extraction and PARSeq OCR — [arXiv 2508.19182 via search](https://arxiv.org/pdf/2508.19182)
- A 2025 UBC Okanagan extension adds NAFNet image restoration, YOLOv8-pose torso cropping and a confidence-weighted ensemble of PARSeq with two VLMs. Both restoration and confidence weighting improved tracklet accuracy — [mahatav.github.io PDF](https://mahatav.github.io/research/Jersey_Number_Recognition.pdf)
- One 2025 paper cites a prior top system at 92.85% accuracy. The benchmark and split could not be verified, so it may not be comparable to 87.4% — [search result summary, arXiv 2405.13896 family](https://www.arxiv.org/pdf/2405.13896)
- **SoccerNet GSR 2025 winner (KIST, GS-HOTA 63.90):** YOLO-X detection, Deep-EIoU + OSNet ReID tracking and multi-frame keypoint pitch mapping. LLaMA-3.2-Vision estimated role, jersey number and color via instruction prompts. Tracklets were split on identity inconsistency and merged on ReID similarity. Team side came from jersey-color clustering plus mean x-position, with majority voting within tracklets — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
- The GSR-3 entry used K-means for team assignment and a fine-tuned ViT-L14 CLIP for jersey number recognition — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
- **Roboflow team classifier:** SigLIP extracts features from player crops, UMAP reduces dimensionality, KMeans clusters into two teams. Roboflow reused the method in its basketball tutorial — [roboflow/sports soccer example](https://github.com/roboflow/sports/tree/main/examples/soccer); [Roboflow blog: identify basketball players](https://blog.roboflow.com/identify-basketball-players/)
- Roboflow Universe hosts open datasets for soccer player detection, ball detection, pitch keypoints, basketball court keypoints and basketball jersey-number OCR — [roboflow/sports README](https://github.com/roboflow/sports)

### Inferences
- For amateur and sideline footage, numbers are often small, blurred or occluded. A per-tracklet voting design (legibility filter → OCR → aggregate) is essential. A VLM fallback (Qwen-VL, or Claude/Gemini on a few best crops) is now competitive with specialized STR, as the 2025 SoccerNet winner shows.
- Head-mounted footage gives close-range, high-resolution views of nearby players, which helps jersey OCR. It loses the global view needed for team clustering by field side, so team assignment should rely on color/embedding clustering, not position.
- For a youth or amateur team, a roster (number → name) prior collapses the problem to a closed set of roughly 15–25 numbers, which should boost accuracy over open-set benchmarks.

### Gaps
- No public jersey-number accuracy was found for American football (helmets and pads, numbers on both front and back) or baseball. All open benchmarks are soccer or hockey.
- The 2025 SoccerNet jersey-only leaderboard accuracy was not extracted. The 2025 report covers jersey numbers only inside GSR.

## 3. Field registration / homography from moving cameras

### Takeaway
Soccer field registration is mature: PnLCalib, No-Bells-Just-Whistles (NBJW), BroadTrack and the Sportlight 2023 winner are commonly used in SoccerNet. American football yard-line registration has only older academic work with no maintained repo, and no open baseball-diamond registration project was found. Keypoint/line detection plus per-frame homography with temporal smoothing is the standard recipe.

### Cited Findings
- mguti97/PnLCalib (points + lines field registration): https://github.com/mguti97/PnLCalib, 112 stars, NOASSERTION license, last push 2026-10-26 (GitHub API)
- mguti97/No-Bells-Just-Whistles (field registration by leveraging lines/keypoints): https://github.com/mguti97/No-Bells-Just-Whistles, 61 stars, NOASSERTION, last push 2024-10 (GitHub API)
- NikolasEnt/soccernet-calibration-sportlight (1st place, SoccerNet Camera Calibration 2023): https://github.com/NikolasEnt/soccernet-calibration-sportlight, 66 stars, no license file (GitHub API)
- SoccerNet/sn-calibration devkit: https://github.com/SoccerNet/sn-calibration, 112 stars, no license file, last push 2024-06 (GitHub API)
- SoccerNet 2025 GSR teams commonly used NBJW, PnLCalib and BroadTrack: landmark detection followed by calibration or homography estimation, plus optical flow for temporal smoothing. GSR-3 combined radial distortion correction with PnLCalib, with parameters simplified to pan/tilt/roll/focal and temporally smoothed — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
- Roboflow's soccer example uses pitch keypoint detection + homography to make a radar/minimap — [roboflow/sports](https://github.com/roboflow/sports). A community project uses a 32-keypoint YOLOv8 pitch model plus homography — [DesusLove/Football-PitchVision](https://github.com/DesusLove/Football-PitchVision)
- A 2025 paper studies registration for central-circle (low-landmark) soccer views using geometry — [arXiv 2504.20052](https://arxiv.org/pdf/2504.20052)
- **American football:** a CVPR-W 2013 pipeline finds the formation frame, detects the line of scrimmage (reportedly within about a yard) and classifies offensive formation using inter-frame homographies — [Atmosukarto et al. CVPRW 2013](https://openaccess.thecvf.com/content_cvpr_workshops_2013/W19/papers/Atmosukarto_Automatic_Recognition_of_2013_CVPR_paper.pdf). Oregon State's WACV 2014 play-type paper notes that yard-line-based homography is noisy and not robust for long-range registration — [WACV 2014](https://web.engr.oregonstate.edu/~sinisa/research/publications/wacv14.pdf)

### Inferences
- For football, a builder will likely need to train a custom yard-line, hash-mark and yard-number keypoint model, for example on Roboflow Universe-style annotations. Yard numbers can be read with OCR to resolve which 5-yard line is which.
- With head-mounted cameras, a full-field homography is rarely possible: few landmarks are visible and roll is extreme. Relative position, such as "ball crossed the line to gain" judged from visible yard markers, is more realistic than a full minimap. Gyroscope/IMU from the glasses, where available, can stabilize the camera pose (see Section 7).

### Gaps
- No maintained open-source American football field registration or baseball diamond registration repo was found.
- Licenses for PnLCalib/NBJW are non-standard (NOASSERTION); their actual terms were not read.

## 4. Soccer: SoccerNet tasks, open data, event-data tooling, highlights

### Takeaway
SoccerNet provides the richest open benchmarks and baselines: action spotting, ball action spotting (now team- and player-attributed), game state reconstruction, tracking, calibration, re-ID, jersey numbers and VQA. Its devkits are mostly unlicensed or GPL. StatsBomb open data (now under the Hudl GitHub org) + kloppy + socceraction/SPADL give a ready event schema and valuation models (VAEP/xT) to target as the output format.

### Cited Findings
- **SoccerNet 2025:** four tasks: Team Ball Action Spotting, Monocular Depth, Multi-View Foul Recognition, GSR — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
  - Team Ball Action Spotting: 16 teams, 67 submissions. The winner (Kamil Czarnogórski, re-implemented T-DEED) scored Team-mAP@1 = 60.03 vs a T-DEED baseline of 51.72, with a 1-second tolerance — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)
  - GSR leaderboard (GS-HOTA): KIST 63.90, Constructor.Tech 63.81, lianyou 62.76, Playbox & MIXI 61.64; baseline 29.01. The top score rose only marginally over 2024, though the field as a whole improved — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182). The 2024 GSR SOTA paper reported 63.81 — [arXiv 2504.06357](https://arxiv.org/pdf/2504.06357)
  - GS-HOTA multiplies localization similarity (pitch-plane distance) by an identity similarity that requires role, jersey number and team to all match — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182); [Somers et al. CVPRW 2024](https://openaccess.thecvf.com/content/CVPR2024W/CVsports/papers/Somers_SoccerNet_Game_State_Reconstruction_End-to-End_Athlete_Tracking_and_Identification_on_CVPRW_2024_paper.pdf)
- **SoccerNet 2026:** tasks: Ball Action Anticipation, Player-Centric Ball Action Spotting (action + team + jersey number), Novel View Synthesis, Spiideo SynLoc (pitch-coordinate localization from a static calibrated camera) and VQA. 427 teams submitted 1,129 entries. One entry is titled "Frontier VLMs are Strong Zero-Shot Soccer Video Reasoners" (Gemini 3.1 Pro Preview) — [SoccerNet 2026 Challenges Results, arXiv 2607.07320](https://arxiv.org/abs/2607.07320)
- **Repos (GitHub API):**
  - SoccerNet/sn-gamestate (GSR baseline): https://github.com/SoccerNet/sn-gamestate, GPL-3.0, 470 stars, last push 2026-05
  - SoccerNet/sn-spotting: https://github.com/SoccerNet/sn-spotting, 106 stars, no license, last push 2024-02
  - SoccerNet/sn-tracking: https://github.com/SoccerNet/sn-tracking, 114 stars, no license, last push 2023-07
  - SoccerNet/sn-teamspotting: https://github.com/SoccerNet/sn-teamspotting, GPL-3.0, 19 stars, last push 2025-08
  - SoccerNet pip package: https://github.com/SoccerNet/SoccerNet, MIT, last push 2026-10
  - SilvioGiancola/SoccerNetv2-DevKit: https://github.com/SilvioGiancola/SoccerNetv2-DevKit, MIT, 230 stars
  - arturxe2/T-DEED (temporally precise event spotting, used as the BAS baseline): https://github.com/arturxe2/T-DEED, GPL-3.0, 41 stars, last push 2026-01
  - jhong93/spot (E2E-Spot, precise spotting): https://github.com/jhong93/spot, BSD-3-Clause, 88 stars, last push 2023-02
  - lRomul/ball-action-spotting (1st place BAS 2023): https://github.com/lRomul/ball-action-spotting, MIT, 140 stars
- **Open data and schemas (GitHub API):**
  - StatsBomb open data, now at hudl/open-data: https://github.com/hudl/open-data, 3.8k stars, NOASSERTION (StatsBomb user agreement), last push 2026-10-27
  - PySport/kloppy (standardizes tracking + event data across providers): https://github.com/PySport/kloppy, BSD-3-Clause, 571 stars, last push 2026-11-06
  - ML-KULeuven/socceraction (SPADL conversion, VAEP, xT valuation): https://github.com/ML-KULeuven/socceraction, MIT, 824 stars, last push 2026-10-18
- **Zero-shot highlights and event spotting:** a 2026 paper (IEEE ISM 2026) splits matches into 15-second clips, makes a 15-frame storyboard per clip, aligns a Whisper-Medium transcript of the commentary, and prompts an MLLM. On 3 full broadcasts (130 events, 6 classes, ±5 s), GPT-5.5 zero-shot scored F1 72.02 / mAP 76.24, vs NetVLAD++ 38.49 / 56.82 and CALF 19.60 / 31.95. The supervised baselines were run cross-dataset without retraining, so the comparison favors the zero-shot model. Code: https://github.com/sadia14/zero-shot-soccer-event-spotting-IEEE-ISM_2026 — [arXiv 2610.37583](https://arxiv.org/html/2610.37583)

### Inferences
- Emit events in SPADL-like or kloppy-compatible form (action type, team, player, start/end location, result) so that existing valuation tools (VAEP, xT) and visualizations work out of the box.
- SoccerNet's move toward player-centric spotting (2026) mirrors exactly the "who did what" stat need. Its baselines are broadcast-only, though, so expect a large domain gap on amateur sideline or egocentric footage.
- The zero-shot MLLM storyboard + ASR approach is the fastest path to amateur-video highlights without training data. It also maps naturally onto a glasses wearer's spoken commentary (see Section 9).

### Gaps
- The best open-source soccer auto-highlight repos beyond research code were not surveyed in depth.
- No SoccerNet-style benchmark exists for youth or amateur matches.

## 5. American football: data, datasets, play/formation recognition, auto play-by-play

### Takeaway
American football has rich pro tracking data (Big Data Bowl) and Kaggle helmet video datasets. Vision tooling is thin: formation and play-type recognition research is mostly 2013–2024 academic work without maintained code, and no open-source project doing auto play-by-play from amateur game film was found. Commercial (Hudl) dominates.

### Cited Findings
- **Big Data Bowl 2026** (8th edition, Kaggle): focused on player movement while the ball is in the air. It had a prediction track (predict player movement in frames after the throw, from pre-pass tracking + Next Gen Stats) and an analytics track. Winner: Lucca Ferraz (Rice University) — [NFL Operations](https://operations.nfl.com/updates/football-ops/nfl-announces-eighth-annual-big-data-bowl-powered-by-aws); [AWS](https://www.aws.amazon.com/sports/nfl-big-data-bowl/); [SumerSports](https://sumersports.com/the-zone/sumersports-big-data-bowl-2026)
- **Big Data Bowl 2027** (9th edition) was announced in Oct 2026, linking Scouting Combine sensor data with regular-season performance — [SVG](https://www.sportsvideo.org/2026/10/08/nfl-announces-ninth-annual-big-data-bowl-powered-by-aws/)
- The old nfl-football-ops/Big-Data-Bowl GitHub repo is stale (last push 2019-04, 155 stars); current data lives on Kaggle — [GitHub](https://github.com/nfl-football-ops/Big-Data-Bowl); [Kaggle BDB 2025](https://kaggle.com/competitions/nfl-big-data-bowl-2025/overview)
- The unravelsports library has an American football (NFL BDB) tutorial for converting tracking data to graph form — [unravelsports docs](https://unravelsports.readthedocs.io/en/stable/tutorials/american_football.html)
- **Kaggle NFL video datasets:**
  - 1st and Future – Impact Detection (2021): 9,947 still images for helmet detection, plus 60 sideline/endzone video pairs with player tracking for impact detection — [BigDATAwire](https://www.bigdatawire.com/2021/08/12/nfl-aws-launch-new-competition-to-track-helmet-impacts-in-football); [Roboflow blog](https://blog.roboflow.com/football-kaggle-computer-vision-safety-scaled-yolov4/)
  - Health & Safety – Helmet Assignment (2021–22): link helmet boxes in video to tracking-data player IDs; 833 teams — [Kaggle discussion](https://kaggle.com/c/nfl-health-and-safety-helmet-assignment/discussion/285007)
  - 1st and Future – Player Contact Detection (2023) provided baseline helmet boxes from the previous year's winning assignment model — [albumentations competitions list](https://albumentations.ai/adoption/verticals/sports/competitions/)
- **Play and formation research:**
  - Pre-play formation classification with deep learning on overhead images: 84.8% accuracy over 25 formation classes; code availability not confirmed — [ResearchGate](https://www.researchgate.net/publication/367976420_Automated_Pre-Play_Analysis_of_American_Football_Formations_Using_Deep_Learning)
  - American football play type and player position recognition (MDPI Electronics 2024) — [MDPI](https://www.mdpi.com/2079-9292/13/18/3628)
  - Older work: offensive formation recognition (CVPRW 2013) — [CVF](https://openaccess.thecvf.com/content_cvpr_workshops_2013/W19/papers/Atmosukarto_Automatic_Recognition_of_2013_CVPR_paper.pdf); play-type recognition in real-world football video (WACV 2014) — [OSU](https://web.engr.oregonstate.edu/~sinisa/research/publications/wacv14.pdf)
  - A USPTO patent covers snap-moment detection from formation detection, which may matter for freedom-to-operate — [USPTO 12315258](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12315258)
- **Commercial:** Hudl sells AI cameras with automated sideline/end-zone film from youth to pro — [Hudl](https://www.hudl.com/sports/football). Mixpeek markets automated event logs (touchdowns, interceptions) on a pay-per-minute basis — [Mixpeek](https://mixpeek.com/solutions/sports)

### Inferences
- Football is naturally segmented into plays. The most reliable building blocks for amateur film are snap detection (motion onset after a static formation), end-of-play detection (whistle audio plus players decelerating) and scoreboard or wearer-speech OCR/ASR for down, distance and score. Fine-grained play type (run/pass, direction, yards gained) is better delegated to a video-LLM per play clip.
- Kaggle helmet datasets are useful for pretraining helmet/player detectors on pads-and-helmets appearance, but they are pro sideline/end-zone views. Check the Kaggle competition rules for commercial use of the data.

### Gaps
- No open-source project for auto play-by-play from amateur or youth football video was found.
- No open-source down/distance graphic OCR specific to football was found, beyond generic scoreboard OCR (Section 10).
- Kaggle NFL dataset licenses (competition-use-only vs broader) were not verified.

## 6. Baseball: pitch/swing detection, ball tracking, stats schemas, datasets

### Takeaway
BaseballCV (MIT code; YOLO models built with Ultralytics) is the main open CV toolkit, with ball-, bat- and glove-oriented models trained on broadcast footage. pybaseball gives the Statcast/Baseball-Reference schema. The MLB-YouTube dataset (2018, fine-grained activity) is the main open video dataset. No open "Statcast-from-a-phone" or automatic scorekeeping project was found.

### Cited Findings
- **BaseballCV** (repo moved from dylandru/BaseballCV to the BaseballCV org): https://github.com/BaseballCV/BaseballCV, MIT, last push 2026-10-25. The GitHub API showed only 22 stars after the move, which may reflect a reset after the transfer (GitHub API). The PyPI package ships pretrained YOLO models such as `ball_tracking.pt` (ball from pitcher's hand to home plate) and `bat_tracking.pt`, loaded by alias and run through Ultralytics. Demos show ball and glove tracking — [PyPI baseballcv](https://pypi.org/project/baseballcv/)
- **jldbc/pybaseball** (Statcast, Baseball Reference, FanGraphs pulls): https://github.com/jldbc/pybaseball, MIT, 1.7k stars, last push 2026-01-04 (GitHub API)
- **piergiaj/mlb-youtube** (MLB-YouTube dataset, CVsports 2018, fine-grained activity recognition): https://github.com/piergiaj/mlb-youtube, 103 stars, no license file, last push 2023-05 (GitHub API)
- pascalewalters/baseball-tracking uses classical pitch tracking; it notes the detector struggles when the ball passes in front of the pitcher's white pants — [GitHub](https://github.com/pascalewalters/baseball-tracking)
- The duxMLB blog describes estimating pitch speed with pretrained YOLO baseball weights — [blog](https://purge12.github.io/blog/developing-duxmlb)

### Inferences
- Because BaseballCV's models are Ultralytics-trained, commercial use likely needs an Ultralytics Enterprise license or retraining on a permissive detector (RF-DETR), even though the BaseballCV code is MIT.
- Baseball's discrete, state-machine structure (count, outs, bases) makes automatic scorekeeping more tractable than other sports. Pitch events from vision, the outcome from a VLM or the wearer's speech, and the scoreboard from OCR can feed a rule engine that emits pybaseball/Retrosheet-style records.
- A tiny ball at amateur sideline distances makes pitch-speed and trajectory estimation from glasses unrealistic. Pitch count, swing/no-swing and contact outcome are achievable.

### Gaps
- No open automatic baseball scorekeeping research or repo was found in this session.
- The note "baseball-cv by Dalton?" in the brief appears to refer to BaseballCV, whose original repo was dylandru/BaseballCV. Maintainer identity beyond the GitHub handle was not verified.

## 7. Egocentric / first-person sports and stabilization

### Takeaway
Ego-Exo4D is the key dataset, with soccer and basketball skill scenarios plus gaze, IMU and SLAM, and benchmarks for proficiency estimation and keystep recognition. There is no egocentric team-sport game dataset with event or stat labels; first-person sports work is mostly single-person skill or fitness. Gyroflow (GPL-3.0) offers gyro-based stabilization, and ffmpeg vidstab works when no IMU is available.

### Cited Findings
- **Ego-Exo4D** (CVPR 2024; IJCV 2025): skilled activity in soccer, basketball, dance, bouldering, music, cooking, bike repair and health care. 1,422 hours of video, with eye gaze, IMU and SLAM streams — [Ego-Exo4D docs](https://docs.ego-exo4d-data.org/); [CVPR 2024 paper](https://openaccess.thecvf.com/content/CVPR2024/papers/Grauman_Ego-Exo4D_Understanding_Skilled_Human_Activity_from_First-_and_Third-Person_Perspectives_CVPR_2024_paper.pdf)
- Participant counts differ by source: 740 in early versions and 839 later — [search summary of Ego-Exo4D sources](https://ego-exo4d-data.org/paper/ego-exo4d.pdf)
- Proficiency estimation (4 levels, Novice to Late Expert) is a benchmark task. SkillFormer (2025) evaluates on basketball, soccer and others — [arXiv 2505.08665](https://arxiv.org/pdf/2505.08665); follow-up with generative feedback — [arXiv 2605.03848](https://arxiv.org/pdf/2605.03848)
- ExpertEdit (2026) uses Ego-Exo4D basketball and soccer (mid-range jumpshot, penalty kick) clips — [arXiv 2604.10466](https://arxiv.org/pdf/2604.10466)
- **Ego4D repo:** https://github.com/facebookresearch/Ego4d, MIT code, 663 stars, last push 2026-07 (GitHub API). Dataset access requires a separate license agreement — [Ego4D repo](https://github.com/facebookresearch/Ego4d)
- **Other egocentric sports data:**
  - EOAD (Egocentric Outdoor Activity Dataset), mostly sports; its YouTube portion includes soccer, basketball and tennis — [Zenodo](https://zenodo.org/record/7742660)
  - WEAR (head-mounted camera + inertial sensors, 22 participants, workouts) — [search summary](https://arxiv.org/pdf/2304.05088v4)
  - Egocentric tennis with synchronized allocentric views, contact times and stroke types — [deeplearn.org listing](https://deeplearn.org/arxiv/858262/perceiving-and-predicting-dynamic-sports:-spatiotemporal-intelligence-in-vision-models-for-egocentric-tennis-video)
  - EgoExo-Fitness — [arXiv 2406.08877](https://arxiv.org/html/2406.08877)
  - 2018 one-on-one basketball head-mounted dataset (988 sequences) — [arXiv 1803.01413](https://arxiv.org/pdf/1803.01413)
- **Stabilization:** gyroflow/gyroflow (stabilization from gyroscope data): https://github.com/gyroflow/gyroflow, GPL-3.0, 9.7k stars, last push 2026-11-07 (GitHub API)
- The facebookresearch/Ego-Exo GitHub repo is an unrelated 2021 representation-transfer project (40 stars), not the Ego-Exo4D dataset — [GitHub](https://github.com/facebookresearch/Ego-Exo)

### Inferences
- Glasses footage is spectator or participant POV with heavy head rotation. Gyro-based stabilization (Gyroflow-style, using the glasses' IMU if accessible) is preferable to purely visual stabilization, which struggles with fast pans over textureless grass. Gyroflow's GPL means using it as a separate tool or process, or reimplementing.
- Ego-Exo4D's soccer and basketball clips are drills, not games, so they are useful for pretraining or domain adaptation but not for game event labels. A builder will need to collect and label their own glasses game footage.

### Gaps
- No dataset was found of egocentric team-sport game footage (football, soccer, baseball) with event or stat annotations, and none from Meta Ray-Ban glasses specifically.
- Ego-Exo4D's per-domain hours for soccer and basketball were not verified from the official release.
- ffmpeg vidstab documentation was not fetched in this session.

## 8. Video-language models for event understanding and summaries

### Takeaway
Frontier closed VLMs (GPT-5.x, Gemini 3.x) are now strong zero-shot soccer event spotters and reasoners when given frame storyboards plus a transcript, beating cross-dataset supervised spotters in one 2026 study. Open VLMs (Qwen3-VL, InternVideo, VideoLLaMA3) are Apache-2.0 and usable for on-prem per-clip classification, but they trail closed models. Rule-heavy sports reasoning remains weak (GPT-4o 57.8% on SPORTU's hardest tier).

### Cited Findings
- **Open VLM repos (GitHub API):**
  - QwenLM/Qwen3-VL (Qwen2.5-VL redirects here): https://github.com/QwenLM/Qwen3-VL, Apache-2.0, 20.2k stars
  - OpenGVLab/InternVideo: https://github.com/OpenGVLab/InternVideo, Apache-2.0, 2.4k stars, last push 2026-07
  - DAMO-NLP-SG/VideoLLaMA3: https://github.com/DAMO-NLP-SG/VideoLLaMA3, Apache-2.0, 1.2k stars, last push 2025-08
  - roboflow/maestro (fine-tuning for PaliGemma 2, Florence-2, Qwen2.5-VL): https://github.com/roboflow/maestro, Apache-2.0, 2.7k stars
  - Model weights may carry separate licenses from the code; check each model card.
- **SPORTU benchmark** (ICLR 2025): 1,701 slow-motion clips across 7 sports with 12,048 QA pairs, including foul detection and rule application. GPT-4o reached only 57.8% on the hardest tier; common failures were question-understanding errors and hallucination — [SPORTU, alphaXiv](https://www.alphaxiv.org/abs/2410.08474); [Semantic Scholar](https://www.semanticscholar.org/paper/SPORTU:-A-Comprehensive-Sports-Understanding-for-Xia-Yang/2d7d498d6eb673f0ea26c42c896cb921af5f08c9)
- **Zero-shot soccer event spotting** (GPT-5.5 storyboard + Whisper transcript): F1@5s 72.02 / mAP 76.24, vs supervised NetVLAD++ 56.82 mAP cross-dataset. Qwen3.5-4B was the open generative model tested — [arXiv 2610.37583](https://arxiv.org/html/2610.37583)
- SoccerNet 2026 includes a VQA task and an entry titled "Frontier VLMs are Strong Zero-Shot Soccer Video Reasoners", which used Gemini 3.1 Pro Preview; its scores were not retrieved — [arXiv 2607.07320](https://arxiv.org/abs/2607.07320)
- On SoccerNet/NBA QA, GPT-4o and Gemini-1.5-Pro were evaluated, with Gemini scoring higher on both. The metric labels were unclear in the snippet — [arXiv 2503.13956](https://arxiv.org/html/2503.13956v1)
- Other 2025–26 sports VLM work includes DeepSport (multimodal LLM for sports) — [arXiv 2511.12908](https://arxiv.org/pdf/2511.12908); universal soccer video understanding (MatchVision/SoccerReplay-1988) — [arXiv 2412.01820](https://arxiv.org/pdf/2412.01820); commentary generation for highlights — [arXiv 2508.07543](https://arxiv.org/pdf/2508.07543); and long-form temporal compositional reasoning in sports — [arXiv 2604.22226](https://arxiv.org/pdf/2604.22226)
- VLMs were used for jersey number recognition in SoccerNet GSR 2025 (LLaMA-3.2-Vision in the winning entry; Qwen2-VL Instruct elsewhere) — [arXiv 2508.19182](https://arxiv.org/abs/2508.19182)

### Inferences
- A hybrid architecture looks best. Cheap CV handles segmentation into plays or possessions plus tracking and IDs. A VLM (Claude/Gemini/GPT on storyboards, or Qwen3-VL on-prem) then labels each segment's event type and outcome, using wearer speech as extra context. VLMs should not be asked to localize events in long untrimmed video unaided.
- Claude vision on sampled frames fits the storyboard paradigm, since the zero-shot paper feeds a single 5×3 frame grid per 15-second clip. No published sports-spotting benchmark for Claude was found.

### Gaps
- No published head-to-head accuracy was found for Gemini 2.x/3, Qwen3-VL, Claude or Twelve Labs on football or baseball event detection.
- SoccerNet 2026 VQA leaderboard numbers were not extracted.

## 9. Audio cues: whistle, crowd, referee, wearer commentary ASR

### Takeaway
ASR is a solved, permissively licensed building block: Whisper (MIT), faster-whisper (MIT), whisperX (BSD-2, word timestamps + diarization) and whisper.cpp (MIT, on-device). Commentary transcripts measurably help MLLM event spotting. Whistle detection has only small open datasets and models (RoboCup-derived), so expect to train your own.

### Cited Findings
- **ASR repos (GitHub API):**
  - openai/whisper: https://github.com/openai/whisper, MIT, 112k stars
  - SYSTRAN/faster-whisper: https://github.com/SYSTRAN/faster-whisper, MIT, 26.6k stars, last push 2026-11-06
  - m-bain/whisperX (word-level timestamps + diarization): https://github.com/m-bain/whisperX, BSD-2-Clause, 25.1k stars
  - ggml-org/whisper.cpp (C/C++ port for edge): https://github.com/ggml-org/whisper.cpp, MIT, 55k stars
- Whisper-Medium commentary transcripts aligned to clips were part of the best zero-shot soccer spotting pipeline — [arXiv 2610.37583](https://arxiv.org/html/2610.37583)
- **Whistle detection:**
  - bit-bots/whistle_detection: ResNet classifier on fixed-length audio chunks, trained on RoboCup SPL data (10 .wav recordings), "under heavy development" — [GitHub](https://github.com/bit-bots/whistle_detection)
  - A 2024 RoboCup referee-understanding paper uses continuous-kernel CNNs for whistle detection, with a 10:1 class imbalance (60k no-whistle vs 6k whistle samples), recorded in lab and in matches — [arXiv 2411.17347](https://arxiv.org/pdf/2411.17347)
  - The OpenWhistle-Detection-Finetuning HF dataset has 0.5 s windows (3,920/840/840 splits); its domain (sports or not) is unverified — [Hugging Face](https://huggingface.co/datasets/dolphinteam/OpenWhistle-Detection-Finetuning)
  - A classical spectral whistle detector for soccer highlights (2014) notes that video context is needed to tell referee whistles from vuvuzelas, horns and fans' whistles — [arXiv 1411.6496](https://arxiv.org/pdf/1411.6496)

### Inferences
- For glasses, the wearer's own speech ("touchdown, number 22", "ball four") is likely the highest-precision stats signal available. Have a coach or parent wearer speak lightweight cues and parse them with Whisper + an LLM into structured events, then use vision to confirm or timestamp them.
- In football, whistles mark play ends, so a small on-device whistle classifier (fine-tuned on self-collected sideline audio) is a cheap play segmenter. A generic audio tagger (AudioSet-class models such as YAMNet/PANNs) may work as a starting point, but this was not verified.

### Gaps
- No large open dataset of real referee whistles from football, soccer or baseball games was found.
- The crowd-noise excitement detector literature was not surveyed in depth.
- YAMNet/PANNs licenses and whistle-class accuracy were not verified (the google/yamnet repo path did not resolve; YAMNet lives in tensorflow/models, NOASSERTION per GitHub API).

## 10. Scoreboard OCR for score and clock

### Takeaway
The recipe is detect the scoreboard, crop it, then OCR. ScoreSight (an open-source OBS-oriented tool) plus its small ONNX layout detector is the nearest ready-made option, but its reported field accuracy is modest. General OCR engines (PaddleOCR, EasyOCR, MMOCR; all Apache-2.0) or a VLM on the crop are the practical engines.

### Cited Findings
- ScoreSight: open-source scoreboard OCR for Windows/Mac/Linux. Inputs include USB/virtual cams, NDI, files and RTSP; it offers perspective correction and outputs txt/csv/xml — [OBS forum](https://obsproject.com/forum/resources/scoresight-ocr-for-tool-scoreboards.1884)
- royshilkrot/scoreboard-layout (ONNX detector for ScoreSight) was trained on fewer than 200 photos. On its test set the clock was correct 74% of the time (35/47), the period 43%, and home/away were sometimes swapped — [Hugging Face](https://huggingface.co/royshilkrot/scoreboard-layout)
- xyk2/Scoreboard-webcam-OCR addresses reading physical venue scoreboards via webcam, because scoreboard data protocols vary across vendors — [GitHub](https://github.com/xyk2/Scoreboard-webcam-OCR)
- Academic: YOLO + OCR on 1,200 images reported an average F1 of 0.979 across sports, on a small self-selected test set — [IRJET 2024](https://issuu.com/irjet/docs/irjet-v11i6147); a similar 2021 approach was tested on Bundesliga, EPL, cricket and kabaddi broadcasts — [ELCVIA 2021](https://doaj.org/article/22bf6dc3f96e49c9abd0ad54e79f87c7)
- **OCR engines (GitHub API):**
  - PaddlePaddle/PaddleOCR: https://github.com/PaddlePaddle/PaddleOCR, Apache-2.0, 92k stars
  - JaidedAI/EasyOCR: https://github.com/JaidedAI/EasyOCR, Apache-2.0, 30k stars
  - open-mmlab/mmocr: https://github.com/open-mmlab/mmocr, Apache-2.0, 4.7k stars, last push 2024-11 (stale)
  - PARSeq (Section 2) also works for short digit strings

### Inferences
- Amateur venues have physical LED or seven-segment scoreboards, seen at oblique angles and only occasionally in a glasses POV. Opportunistic OCR whenever the scoreboard is in frame, with temporal consistency rules (scores only increase, the clock decreases monotonically), is more robust than continuous reading. Seven-segment digits often need a dedicated recognizer or a VLM.
- Many youth games have no scoreboard or clock at all. Wearer speech and the event log then become the source of truth for the score.

### Gaps
- No open benchmark was found for physical-venue scoreboard OCR from handheld or egocentric footage.
- ScoreSight's GitHub repo, license and maturity were not verified.
