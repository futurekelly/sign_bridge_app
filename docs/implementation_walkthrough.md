# SignBridge — Implementation Walkthrough
**Last Updated:** 2026-07-05 | **Current Tag:** `v0.2.0-phase2-mediapipe` + alignment fix commit `960bcf9`

This document is a running log of every major implementation step taken during the SignBridge project, serving as both a technical reference and a dissertation evidence trail.

---

## Phase 1 — Firebase Auth, SignBridge IDs & Direct Signaling Core ✅

### What was built
- **Unique ID Registry** (`/usernames/{lowercase_id}`): Firestore transactions guarantee no two users share a SignBridge ID. Registration is atomic — if the DB write fails, the Firebase Auth account is automatically deleted (double-write rollback).
- **Direct Dialing Locks** (`call_manager.dart`): Orchestrates atomic call initiation. Checks callee `status == idle`, locks both users to `busy`/`ringing`, generates `/calls/{callId}` documents.
- **Security Rules** (`firestore.rules`): Production-grade — writes restricted to owning UID, cross-user status updates permitted only for the `status` field, call history write-only by participants.
- **ICE Candidate Purging**: `CallManager` clears ICE sub-collections and call documents on reject/disconnect/timeout.

---

## Phase 2 — Ring UI & Deaf Vibration Engine ✅

### What was built
- **Incoming Call Overlay** (`incoming_call_overlay.dart`): Glassmorphic, animated overlay with Accept/Decline buttons; automatically dismissed if caller hangs up via Firestore listener.
- **Vibration Service** (`vibration_service.dart`): Periodic haptic timer loops continuously for deaf callee until answered or declined. Tied directly to overlay life-cycle (`initState`/`dispose`).
- **Overlay Context Fix**: Replaced `Overlay.of(context)` with `AppRoutes.navigatorKey.currentState?.overlay` to avoid null-check crashes.
- **Handshake Race Fix**: Callee now waits for caller's WebRTC offer before proceeding if callee accepts before the caller's camera initialises.

---

## Phase 3 — Bilingual Support & Contacts ✅

### What was built
- **AppTranslations** (`lib/core/translations.dart`): Static map covering 50+ keys in English and Swahili across all screens.
- **Saved Contacts** (`contacts_repository.dart` + `contacts_screen.dart`): Hive-backed directory, alphabetically sorted, with join/create/copy/dial actions.
- **AI Simulator Panel** (`call_screen.dart`): Hidden glassmorphic panel (double-tap AI icon) with vocabulary buttons to simulate gestures and speech for E2E testing without a real hand.

---

## Phase 4 — Native MediaPipe Real-Time Vision Pipeline ✅

This was the most significant technical phase. The goal was to replace the AI Simulator Panel with real on-device hand gesture recognition.

### Architecture Decision
The native Android layer is **only a landmark producer**. All AI logic (normalization, inference, stabilization, TTS, DataChannel) remains in Dart.

### Files Created / Modified

| File | Role |
|---|---|
| `HandLandmarkerHelper.kt` | Initializes MediaPipe HandLandmarker (LIVE_STREAM mode), converts `VideoFrame` → NV21 → JPEG → Bitmap → MPImage, calls `detectAsync()`, emits 21 landmark maps via callback |
| `HandLandmarkVideoSink.kt` | Implements WebRTC `VideoSink`; receives every frame from the local camera track and passes it to `HandLandmarkerHelper.detectFrame()` |
| `MainActivity.kt` | Exposes `EventChannel("sign_bridge/landmarks")`; wires `HandLandmarkVideoSink` to the local WebRTC track after camera starts |
| `inference_manager.dart` | Subscribes to EventChannel; normalises landmarks; runs TFLite model; feeds `PredictionStabilizer` |
| `prediction_stabilizer.dart` | Gates raw predictions; emits only stable gestures; handles cooldown and gesture-end events |
| `translation_controller.dart` | Receives stable predictions → TTS audio + WebRTC DataChannel message to peer |
| `call_screen.dart` | `HandLandmarksPainter` draws the 21-point skeleton on top of the RTCVideoView |

### Frame Pipeline (end-to-end)
```
Camera Hardware
    │
    ▼ (30fps)
WebRTC Local Track
    │
    ▼
HandLandmarkVideoSink.onFrame()
    │  skip odd frames → ~15fps to MediaPipe
    ▼
HandLandmarkerHelper.detectFrame()
    │  VideoFrame → I420 → NV21 → JPEG → Bitmap → MPImage
    ▼
MediaPipe HandLandmarker.detectAsync()
    │  (async callback ~10-30ms)
    ▼
onLandmarksDetected callback
    │  List<{id, x, y, z}> × 21 landmarks
    ▼
EventChannel → Dart
    │
    ▼
InferenceManager._processNativeLandmarks()
    │  normalize (wrist-centred, scale by max span)
    │  TFLite inference → PredictionResult{label, confidence}
    ▼
PredictionStabilizer.processPrediction()
    │  2 consecutive frames ≥ 0.65 confidence → emit
    ▼
TranslationController._onStablePrediction()
    │  TTS.speak() + DataChannel.send(label)
    ▼
Peer device receives label → shows caption + GIF
```

### Emulator Fallback
On devices without Google Play JNI (e.g. Huawei HMS), `UnsatisfiedLinkError` is caught in `HandLandmarkerHelper.init`. The app gracefully falls back to `AiStatus.idle` with no crash.

---

## Phase 4.1 — Landmark Overlay Alignment & Performance Tuning ✅

### Problem
The HandLandmarksPainter was mapping MediaPipe coordinates directly onto the container dimensions, ignoring two critical facts:
1. MediaPipe outputs landmarks in **landscape bitmap coordinate space** (640×480), not portrait display space
2. `RTCVideoViewObjectFitCover` crops the video, requiring crop offset compensation

### Coordinate Axis Investigation

| Attempt | x formula | y formula | Observed result |
|---|---|---|---|
| Original | `(1-lm.x) × W` | `lm.y × H` | Fingers pointing **left** (90° rotated) |
| Fix attempt 1 | `(1-lm.x) × sWidth - dx` (3:4 ratio) | `lm.y × H` | Still **right-shifted** |
| Fix attempt 2 | `(1-lm.y) × W` | `lm.x × H` | Fingers pointing **down** (180° off) |
| **Final fix** ✅ | `(1-lm.y) × W` | `(1-lm.x) × H` | Fingers pointing **up** ✓ |

### Root Cause Explanation
MediaPipe processes the raw landscape frame (640×480) with `.setRotationDegrees(frame.rotation)`. The rotation is applied **internally** during processing, but the **output landmark coordinates remain expressed in the original landscape bitmap axis order**:
- `lm.x`: 0→1 along landscape width → corresponds to portrait **vertical** (top→bottom)
- `lm.y`: 0→1 along landscape height → corresponds to portrait **horizontal** (left→right)

Swapping and inverting both axes maps correctly onto the portrait RTCVideoView.

### Performance Tuning

| Parameter | Before | After | Reason |
|---|---|---|---|
| `requiredConsecutiveFrames` | 3 | **2** | Faster trigger (~130ms vs ~200ms) |
| `minConfidenceThreshold` | 0.75 | **0.65** | Fewer counter resets on borderline frames |
| `cooldownDuration` | 2000ms | **1500ms** | Allows re-detection sooner |
| `gestureEndTimeout` | 700ms | **500ms** | Clears state faster when hand lowers |
| Frame skip | None (every frame) | **Every 2nd frame** | Halves YUV decode CPU cost at same detection quality |

---

## Verification Status

| Test | Status |
|---|---|
| App builds without errors | ✅ |
| MediaPipe initializes on Huawei physical device | ✅ |
| Landmarks stream via EventChannel at ~15fps | ✅ |
| TFLite inference runs in Dart (not Kotlin) | ✅ |
| Gesture recognized: hello, thank_you, yes, no, help, iloveyou | ✅ |
| TTS speaks recognized gesture | ✅ |
| Skeleton overlay visible on call screen | ✅ |
| Skeleton fingers point upward (portrait orientation) | ✅ |
| Emulator falls back gracefully (no JNI crash) | ✅ |
| GitHub tag `v0.2.0-phase2-mediapipe` pushed | ✅ |
| Alignment fix commit `960bcf9` pushed | ✅ |

---

## Next Steps (Phase 5)

1. **Vocabulary expansion** — collect dataset for 30+ signs, retrain `gesture_model.tflite`
2. **FCM push notifications** — background call alerts
3. **Production TURN servers** — replace OpenRelay for cellular reliability
4. **User study** — structured usability testing with deaf and hearing participants
5. **Dissertation write-up** — architecture chapters, performance benchmarks, evaluation
