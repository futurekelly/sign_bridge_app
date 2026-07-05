# SignBridge Development Journey & Task Tracker

This document tracks all features built, debugged, and validated, as well as the remaining production improvements.
Last updated: **2026-07-05** — Phase 2.1 complete.

---

## 1. Project Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **Backend / Auth** | Firebase Auth + Cloud Firestore |
| **Real-time Media** | WebRTC (`flutter_webrtc`) |
| **Native AI Layer** | Kotlin + MediaPipe Tasks Vision (HandLandmarker) |
| **On-device Inference** | TensorFlow Lite (`tflite_flutter`) |
| **Local Storage** | Hive (settings, contacts, translation preferences) |
| **Accessibility** | `vibration` package (deaf haptic alert system) |
| **Bilingual** | Static translation map — English + Swahili |

---

## 2. Completed Milestones

### Phase 1 — Core Signaling & Security ✅
- [x] **SignBridge ID Uniqueness** — Lowercase unique IDs via Firestore transactions on `/usernames` + profile writes under `/users/{uid}`
- [x] **Double-Write Rollbacks** — Auto-deletes Firebase Auth accounts if profile DB write fails
- [x] **Direct Dialing Locks** — Caller atomically checks callee `'idle'`, locks both to `'busy'`/`'ringing'`, creates WebRTC signaling document
- [x] **Firestore Security Rules** — Production-grade rules: write restricted to owner, status-only updates permitted cross-user, call history logging allowed
- [x] **Bootstrap Auth Fix** — Prevents existing registered users from being signed out mid-call by anonymous re-auth

### Phase 2 — Ring UI & Vibration Engine ✅
- [x] **Incoming Call Overlay** — Animated glassmorphic overlay with Accept/Decline buttons
- [x] **Vibration Engine** — Periodic haptic timer loops continuously for deaf callee until answered/declined
- [x] **Overlay Life-cycle Sync** — Firestore listener auto-dismisses overlay if caller hangs up (30s timeout)
- [x] **Overlay Context Fix** — Uses `AppRoutes.navigatorKey.currentState?.overlay` to avoid null context crashes
- [x] **Handshake Race Condition Fix** — Callee waits for caller's WebRTC offer if callee answers before camera initialises

### Phase 3 — Bilingual & Refinement ✅
- [x] **Bilingual Support** — Full English/Swahili localisation across onboarding, login, settings, calling, and history screens
- [x] **Saved Contacts Directory** — Alphabetically sorted Hive directory with add, search, delete, copy, and dial
- [x] **Contact Support** — Settings email dispatch to `futurekelly360@gmail.com`
- [x] **AI Simulator Panel** — Hidden glassmorphic panel (double-tap AI icon) for E2E validation with simulated gestures and speech

### Phase 4 — Native MediaPipe Integration (Real AI) ✅
- [x] **VideoSink Architecture** — `HandLandmarkVideoSink` attaches to WebRTC local track; every 2nd frame sent to MediaPipe
- [x] **NV21 Frame Pipeline** — `VideoFrame` → I420 → NV21 → JPEG → `BitmapImageBuilder` → `HandLandmarker.detectAsync()`
- [x] **EventChannel Landmark Stream** — 21 `{id, x, y, z}` maps pushed from Kotlin → Dart on every detection result
- [x] **InferenceManager** — Subscribes to EventChannel, normalises landmarks (wrist-centred, scale-normalised), runs `gesture_model.tflite`
- [x] **TFLite Model** — Custom MLP trained on 6 signs: `hello`, `thank_you`, `yes`, `no`, `help`, `iloveyou` (63-feature input)
- [x] **PredictionStabilizer** — Gates predictions: 2 consecutive frames ≥ 0.65 confidence required before emitting
- [x] **TranslationController** — Receives stable predictions → TTS speech output + WebRTC DataChannel message to peer
- [x] **Emulator Fallback** — `UnsatisfiedLinkError` caught; app falls back to idle AI status on devices without Google Play JNI support (Huawei HMS)
- [x] **GitHub milestone tag** — `v0.2.0-phase2-mediapipe` pushed to `futurekelly/sign_bridge_app`

### Phase 4.1 — Landmark Overlay Alignment ✅
- [x] **Coordinate Axis Fix** — Discovered MediaPipe outputs landmarks in landscape bitmap space; swapped axes: `screen_x = (1-lm.y)*W`, `screen_y = (1-lm.x)*H`
- [x] **Portrait Orientation** — Skeleton now correctly shows fingers pointing up, wrist at bottom
- [x] **Detection Latency Improvement** — Reduced `requiredConsecutiveFrames` 3→2, `minConfidenceThreshold` 0.75→0.65, `cooldownDuration` 2s→1.5s, `gestureEndTimeout` 700ms→500ms
- [x] **Frame Skip Optimisation** — Every 2nd frame processed (~15fps) to halve YUV decode CPU cost and prevent pipeline queue backup
- [x] **GitHub commit** — `fix(vision): correct HandLandmarksPainter axis orientation for portrait display`

---

## 3. What Remains (Production Roadmap)

### Phase 5 — Vocabulary Expansion 🔜
- [ ] **Dataset Collection** — Record 30+ samples per new sign using the built-in landmark recorder
- [ ] **Model Retraining** — Expand `gesture_model.tflite` from 6 → 30+ signs using Python training pipeline (`python_scripts/train_model.py`)
- [ ] **Model Evaluation** — Validate per-class accuracy ≥ 90% before deploying new model
- [ ] **Vocabulary UI** — Show recognised gesture name + translation GIF in overlay during call

### Phase 6 — Production Hardening 🔜
- [ ] **FCM Push Notifications** — Wake device for incoming calls when app is backgrounded or killed
- [ ] **Paid TURN Servers** — Replace free `openrelay.metered.ca` with production TURN for cellular reliability
- [ ] **Background MediaPipe** — Keep landmark detection alive when screen dims (WorkManager / Foreground Service)
- [ ] **Multi-hand Support** — Extend HandLandmarker to `setNumHands(2)` for two-handed signs
- [ ] **Adaptive Frame Rate** — Dynamically adjust frame skip ratio based on device CPU temperature/load

### Phase 7 — Dissertation Submission Polish 🔜
- [ ] **User Study** — Conduct structured usability test with deaf and hearing participants
- [ ] **Performance Benchmarks** — Formal latency and accuracy measurements for dissertation chapter
- [ ] **App Store Listing** — Prepare Play Store screenshots, description, and privacy policy
- [ ] **Final README** — Production-grade README with full installation guide and architecture diagrams
