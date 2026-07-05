# SignBridge — Technical Presentation Brief
**Project:** SignBridge — Two-Way Sign Language & Speech Translation System
**Presenter:** Kelvin Mbise
**Date:** 2026-07-06
**Current Build:** `v0.2.0-phase2-mediapipe` + commit `960bcf9`

---

## 1. Executive Summary

SignBridge is a real-time, two-way communication application that bridges the gap between deaf and hearing users during video calls. It uses on-device AI — powered by Google MediaPipe and a custom TensorFlow Lite model — to recognise hand gestures and convert them into speech, while simultaneously converting spoken words into text captions and sign language GIFs. Everything runs locally on the phone with no cloud AI dependency.

---

## 2. Problem Statement

> *"How do a deaf person and a hearing person have a real-time video conversation without a human interpreter?"*

- An estimated **430 million people worldwide** have disabling hearing loss (WHO, 2023)
- Existing video calling apps (WhatsApp, Zoom, Google Meet) have **no native sign language support**
- Professional interpreters are **expensive, scarce, and unavailable 24/7**
- Existing sign language apps are **one-directional** — they either recognise OR synthesise, not both simultaneously
- SignBridge makes the conversation **two-way and automatic**, in real time, on a commodity Android phone

---

## 3. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     DEAF USER DEVICE                        │
│                                                             │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────┐ │
│  │  Camera  │───▶│  MediaPipe   │───▶│  EventChannel     │ │
│  │ (WebRTC  │    │ HandLandmark │    │  (Kotlin → Dart)  │ │
│  │  Track)  │    │  ~15fps      │    │  21 landmarks     │ │
│  └──────────┘    └──────────────┘    └────────┬──────────┘ │
│                                               │             │
│                          ┌────────────────────▼──────────┐ │
│                          │       Dart AI Pipeline        │ │
│                          │  Normalize → TFLite Infer     │ │
│                          │  → Stabilizer → Controller    │ │
│                          └────────┬──────────────────────┘ │
│                                   │                         │
│                       ┌───────────▼────────────┐           │
│                       │   TranslationController │           │
│                       │  TTS.speak("Hello")     │           │
│                       │  DataChannel.send(label)│           │
│                       └───────────┬────────────┘           │
└───────────────────────────────────│─────────────────────────┘
                                    │ WebRTC DataChannel
                  ┌─────────────────▼────────────────────┐
                  │         Firebase Firestore            │
                  │    (WebRTC Signaling / ICE relay)     │
                  └─────────────────┬────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│                     HEARING USER DEVICE                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Receives gesture label via DataChannel             │   │
│  │  → Shows text caption: "Hello"                      │   │
│  │  → Shows sign language GIF                         │   │
│  │  → Microphone → STT → text shown to deaf peer      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Technology Stack

| Layer | Technology | Why Chosen |
|---|---|---|
| **UI Framework** | Flutter (Dart) | Single codebase, Android + iOS, fast rendering |
| **Backend / Auth** | Firebase Auth + Cloud Firestore | Real-time sync, generous free tier, instant scalability |
| **Video Calls** | WebRTC (`flutter_webrtc`) | Industry-standard P2P, low latency, end-to-end encrypted |
| **Native AI** | MediaPipe Tasks Vision (Kotlin) | Google's production hand tracking, runs at 30fps on mobile |
| **ML Inference** | TensorFlow Lite (`tflite_flutter`) | On-device, no internet, <10ms inference latency |
| **Local Storage** | Hive | Fast NoSQL on-device, used for contacts and settings |
| **Bilingual** | Custom static map | English + Swahili, zero dependency, instant switching |
| **TTS** | `flutter_tts` | Text-to-speech for hearing users receiving sign gestures |
| **STT** | `speech_to_text` | Microphone to text for deaf users receiving speech |

---

## 5. Key Technical Milestones

| Phase | Date | Key Achievement |
|---|---|---|
| **Phase 1** | May 2026 | Firebase Auth, unique SignBridge IDs, WebRTC P2P calls, call state machine, vibration alerts |
| **Phase 2** | June 2026 | Bilingual UI, saved contacts, AI simulator panel for E2E testing |
| **Phase 3** | June–July 2026 | Native MediaPipe integration, real landmark streaming via EventChannel, custom TFLite model |
| **Phase 3.1** | July 5, 2026 | Landmark overlay axis correction, detection latency improvements, GitHub milestone tag |

---

## 6. Live Demo Script (5–10 minutes)

> **Setup:** Huawei physical device (Caller/Deaf user) + Android Emulator (Receiver/Hearing user). Both have SignBridge installed.

---

### Step 1 — Introduction (30 seconds)
*Say:* "SignBridge is an Android app that allows a deaf person and a hearing person to have a video call with real-time AI translation — no interpreter needed. Let me show you how it works."

---

### Step 2 — App Launch & Login (1 minute)
- Open SignBridge on the **Huawei device**
- Show the onboarding screen briefly — *"This explains the app's purpose to a new user"*
- Log in with the deaf user account
- Point out the **SignBridge ID** on the home screen
- *Say:* "Every user gets a unique ID — like a phone number. This is how you find and call someone."

---

### Step 3 — Start a Call (1 minute)
- On the **emulator**, tap **Create Call** — a unique Call ID is generated
- Enter that Call ID on the **Huawei device** to join
- Both devices connect via WebRTC — show the live camera feed on both screens
- *Say:* "The call is peer-to-peer — no video goes through our servers. Firebase only handles the 3-second connection handshake."

---

### Step 4 — Sign Language → Speech (2 minutes)
- On the **Huawei device**, hold your hand in front of the camera
- Point out the **hand landmark skeleton** on screen
- *Say:* "MediaPipe tracks 21 key points on the hand — fingertips, knuckles, and wrist — at 15 frames per second"
- Show the **"Hello"** gesture (open palm, wave) — TTS speaks "Hello"
- Point to the **emulator** showing the caption — *"The hearing user sees it as text too"*
- Try **"Help"** (closed fist) and **"Yes"** (thumbs up)
- *Say:* "From gesture to speech in under 200 milliseconds — entirely on-device, no internet needed"

---

### Step 5 — Speech → Text (1 minute)
- On the **emulator**, speak a sentence into the microphone
- Show the text caption appearing on the **Huawei device**
- *Say:* "Communication is two-way. The hearing user speaks, the deaf user reads."

---

### Step 6 — Architecture Highlight (1 minute)
- *Say:* "Under the hood: MediaPipe sends 21 landmark coordinates through an EventChannel to Dart. A TensorFlow Lite neural network — which we trained ourselves — classifies the gesture in under 10ms. A stabilizer confirms it over 2 consecutive frames to filter noise. Then TTS speaks it."

---

### Step 7 — Close & Future Work (30 seconds)
- *Say:* "We currently support 6 signs. Phase 3 expands to 30+. We'll also add FCM push notifications and production TURN servers for full cellular reliability."

---

## 7. Anticipated Q&A

---

**Q1: Why Flutter instead of native Android?**

> Flutter gives a single Dart codebase for Android and iOS. The performance-critical code — MediaPipe, WebRTC — is native Kotlin anyway. Flutter handles the UI where cross-platform matters, and its `MethodChannel`/`EventChannel` APIs give clean Kotlin↔Dart communication.

---

**Q2: Why MediaPipe instead of training your own hand detector?**

> Training a hand detector requires millions of labelled images and significant compute. MediaPipe gives us Google's production model in a single `.task` file — 21 accurate 3D landmarks at 30fps on a mobile CPU. We used that as a foundation and focused our training effort on the *gesture classification* problem, which is our actual research contribution.

---

**Q3: Why on-device AI instead of a cloud API?**

> Three reasons: **Latency** — cloud round-trips add 200–500ms per frame. **Privacy** — camera frames never leave the device. **Cost and resilience** — cloud inference at 15fps per user would be expensive and breaks without internet. On-device inference is <10ms.

---

**Q4: How does WebRTC work? What does Firebase do?**

> WebRTC is peer-to-peer — once connected, media streams directly between devices. To *establish* the connection, peers exchange offers, answers, and ICE candidates via Firebase Firestore as a signaling server. Once the handshake completes, Firebase is no longer involved in the media stream.

---

**Q5: Explain the 21 landmark coordinate system.**

> MediaPipe defines landmark 0 as the wrist, 1–4 as the thumb (base to tip), 5–8 index finger, 9–12 middle, 13–16 ring, 17–20 pinky. Each has normalised x, y, z in `[0.0, 1.0]`. We feed all 63 values (21 × 3) as the TFLite model's input vector, after wrist-centred normalisation and scale normalisation.

---

**Q6: Why did you need to swap axes in the skeleton overlay?**

> MediaPipe processes the raw landscape bitmap (640×480) with rotation metadata. But the output coordinates remain in **landscape axis order** — x across the 640px width, y across 480px height. On a portrait display, landscape-x is the vertical axis and landscape-y is the horizontal axis. Without swapping, the skeleton was rotated 90°. Fix: `screen_x = (1-lm.y)×W`, `screen_y = (1-lm.x)×H`.

---

**Q7: What is the PredictionStabilizer?**

> Raw per-frame inference is noisy — the model can briefly misclassify during a hand transition. The stabilizer requires the **same label in 2 consecutive frames at ≥65% confidence** before emitting. It also enforces a 1.5s cooldown to prevent repeat TTS firing.

---

**Q8: How accurate is the model?**

> In controlled testing with good lighting, per-sign accuracy is approximately 85–90%. In poor lighting or with partial occlusion, it degrades. We trained on our own dataset — this is an honest limitation of a research prototype. Phase 3 addresses it with a larger, more diverse dataset.

---

**Q9: What are the limitations?**

> Six-sign vocabulary, single hand only, lighting sensitivity, no background call alerts, free TURN servers may fail on cellular, and general signs not mapped to a specific national sign language (e.g. KSL).

---

**Q10: How will Phase 3 expand the vocabulary?**

> Record 30+ samples per new sign using our built-in landmark recorder, retrain the MLP in Python, validate per-class accuracy ≥90%, replace `gesture_model.tflite` in assets and rebuild. The pipeline already exists — it's a data problem, not an architecture problem.

---

**Q11: How does TTS help the deaf-to-hearing flow?**

> When the stabilizer emits a confirmed gesture, `TranslationController` calls `FlutterTts.speak(word)` — the device's native Google TTS vocalises it for the hearing user. Simultaneously the label is sent over the WebRTC DataChannel so the hearing peer also sees a text caption and GIF.

---

**Q12: What if the hand leaves the frame?**

> MediaPipe fires the callback with an empty list. `InferenceManager` clears the prediction. The stabilizer starts a 500ms countdown. If no hand reappears, `gestureEndStream` fires and the overlay clears. Detection resumes immediately when a hand re-enters.

---

**Q13: How is SignBridge different from Live Transcribe or Ava?**

> Live Transcribe and Ava are **speech-only** — they transcribe spoken words for deaf users but cannot translate sign language to speech. SignBridge is **bidirectional**: sign → speech AND speech → text in a single real-time call.

---

**Q14: Is the video stream encrypted?**

> Yes. WebRTC uses **DTLS-SRTP** by default — all media is end-to-end encrypted between the two peers. Firestore signaling data is protected by Security Rules restricting access to authenticated call participants.

---

**Q15: How do you handle Huawei HMS (no Google Play)?**

> MediaPipe JNI libraries require Google Play Services. On Huawei, `UnsatisfiedLinkError` is caught at init time in `HandLandmarkerHelper`. The app falls back to `AiStatus.idle` and continues as a normal video call app — no crash.

---

## 8. Known Limitations

| Limitation | Current Impact | Plan |
|---|---|---|
| 6-sign vocabulary | Proof-of-concept only | Phase 3: 30+ signs |
| Single hand | Excludes two-handed signs | Phase 5: `setNumHands(2)` |
| Lighting sensitivity | Accuracy drops | Diverse dataset in Phase 3 |
| No background call alerts | Missed calls if app closed | FCM in Phase 4 |
| Free TURN servers | May fail on cellular | Paid TURN in Phase 4 |
| General signs, not KSL/BSL | Accessibility gap | Deaf community partnership |

---

## 9. Future Roadmap

| Phase | Focus |
|---|---|
| **Phase 3 (Next)** | 30+ sign vocabulary, model retraining, per-class validation ≥90% |
| **Phase 4** | FCM push notifications, production TURN servers |
| **Phase 5** | Two-handed signs, adaptive frame rate, background MediaPipe |
| **Phase 6** | User study with deaf participants, formal benchmarks |
| **Phase 7** | App Store submission, dissertation final evaluation chapter |

---

## 10. Quick-Fire One-Liners

| If asked… | Say… |
|---|---|
| "What problem does it solve?" | "Deaf and hearing people video calling with no human interpreter." |
| "What AI does it use?" | "Google MediaPipe for hand tracking, our own TFLite MLP for gesture classification." |
| "Online or offline?" | "AI is fully offline — on device. Only call setup uses internet." |
| "How many signs?" | "Six now. Phase 3 targets 30+." |
| "What language?" | "UI is bilingual — English and Swahili. Signs are gesture-based, not language-specific." |
| "How fast?" | "Under 200ms from gesture to speech." |
| "Did you train the model?" | "Yes — we recorded our own dataset, labelled it, and trained in Python." |
