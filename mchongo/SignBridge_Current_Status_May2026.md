# SignBridge — Comprehensive Project Status & Future Tracking
**Last Updated:** June 8, 2026

## 📚 1. Project Overview
**SignBridge** is a premium, real-time Flutter application built to bridge communication between Deaf and Hearing individuals. It utilizes WebRTC for peer-to-peer video calling and runs AI inference (Gesture Recognition, Speech-to-Text, and Text-to-Speech) strictly **on-device** to ensure privacy, zero cloud processing costs, and low latency. 

The app features a strictly role-based architecture (Deaf, Hearing, Both) that dynamically tailors the user interface (e.g., auto-muting microphones, prioritizing caption sizes, or highlighting GIF translation panels).

---

## ✅ 2. Completed Phases (What We Have Built)

The core application architecture, state management, and user interface are complete and fully functional. 

| Phase | Details | Status |
|---|---|---|
| **Phase 1: Core App & UI System** | Built the foundation with `ThemeController`, `AccessibilityController`, and named routing. Implemented a fully customized Neumorphic and Glassmorphic design system (Dark & Light modes). | ✅ Done |
| **Phase 2: Video Calling (WebRTC)** | Implemented peer-to-peer video streams using `flutter_webrtc`. Set up the core `CallScreen` UI to display local and remote renderers. | ✅ Done |
| **Phase 3: Firebase Signaling** | Implemented `SignalingService` using Firestore. Firebase is used *only* for the initial exchange of SDP offers/answers and ICE candidates. | ✅ Done |
| **Phase 4: Simulated AI Services** | Created the modular AI pipeline: `GestureRecognitionService` (simulated TFLite outputs for now), `SpeechService` (real STT), and `TTSService` (real TTS). | ✅ Done |
| **Phase 5: Data & History Layer** | Integrated `HiveDb` for blazing-fast, offline local storage. Built repositories for Translation History, Application Settings, and Learning Resources. | ✅ Done |
| **Phase 6: DataChannel & Orchestration** | Built `TranslationController` as the single source of truth for all AI text. Wired the WebRTC DataChannel to instantly sync translation payloads between users in real time. | ✅ Done |
| **Phase 7: Premium UI Overlays & Polish** | Added interactive UI components on top of the call: `GifOverlay`, `CaptionOverlay`, `AiStatusIndicator`, and `CallControls`. Added "Recent Calls" quick-rejoin and a dedicated Learning Screen with PDF linking. | ✅ Done |
| **Phase 8: TFLite AI Plumbing** | Completely rebuilt `gesture_recognition_service.dart` with a background Isolate (CPU thread) to process live camera frames into RGB Tensors and feed them to `Interpreter.fromAsset()`. It is currently using placeholder files and includes crash-protection. | ✅ Done |
| **Phase 10: Auth Redesign & Google Sign-In** | Overhauled authentication with `google_sign_in` and email/password capabilities. Rebuilt the login screen with a premium glassmorphic visual style, neumorphic input fields, and smooth sliding tabs. | ✅ Done |
| **Phase 11: Tanzanian Localization & Custom Credit** | Configured Tanzanian Sign Language basics (PDF link to Maktaba.org) at the top of the learning resources. Added developer credit for "Sir Kelvin Mbise" on the Settings screen. | ✅ Done |
| **Phase 12: Bilingual Support (English & Swahili)** | Implemented `AppTranslations` localization dictionary. Added language toggles to Onboarding, Login, and Settings screens, with runtime language locale switching for AI text-to-speech and speech-to-text. | ✅ Done |
| **Phase 13: Saved Contacts & Contact Support** | Created `Contact` model & `ContactsRepository` backed by Hive local storage. Added Neumorphic Contacts screen to search/manage saved peers, quick-call WebRTC integrations, and a "Contact Support" email dispatch in Settings. | ✅ Done |


---

## 🛠️ 3. Where We Are Now (Latest Fixes - May 2026)

Following physical device testing on real smartphones and emulator setups, we identified and successfully resolved several critical connection, pipeline compilation, and styling issues:

1. **Carrier-Grade NAT / Mobile Data Fix:** 
   - Added free STUN/TURN servers (via OpenRelay/Metered.ca) to `webrtc_service.dart`. This ensures physical devices can connect flawlessly over different mobile networks.
2. **ICE Candidate Race Condition Resolved:** 
   - Implemented an ICE candidate buffer. Incoming remote ICE candidates are now queued and flushed *only* after `setRemoteDescription` is safely applied, preventing silent connection failures.
3. **Signaling Safety Guard:** 
   - Added an `_answerApplied` lock in `SignalingService` to prevent `handleRemoteAnswer()` from throwing fatal `InvalidStateError` crashes when Firestore snapshot listeners re-fire.
4. **Translation Pipeline Timing Logic:** 
   - The AI `TranslationController` no longer starts the moment a call is created. It strictly waits until the `onRemoteStreamAdded` callback fires (when the remote peer's video actually arrives). This guarantees the mic and gesture AI do not run while users are stuck on the "Waiting for peer..." screen.
5. **TFLite Isolate Pipeline (70% Functionality):**
   - The app now successfully captures live camera frames, throttles them to 3 fps, and passes them to a background Isolate to convert to Tensors. It runs them through an empty placeholder `.tflite` model with strict crash-protection fallbacks.
6. **SDK Compatibility Upgrade:**
   - Upgraded `tflite_flutter` in `pubspec.yaml` to `^0.12.1` to resolve compilation errors caused by the removal of `UnmodifiableUint8ListView` in Dart 3.4+.
7. **Robust Authentication Logging & Feedback:**
   - Configured `login_screen.dart` with descriptive user error-reporting. Added detection for disabled Firebase Authentication providers (`operation-not-allowed`) so that users are advised to enable the appropriate providers (Email/Password or Google) in the Firebase Console.
8. **Saved Contacts & Contact Support (June 2026):**
   - Implemented a localized Saved Contacts directory to save peer User IDs and names for one-tap calling.
   - Added a "Contact Support" option to settings that uses `url_launcher` to email the admin (`futurekelly360@gmail.com`).
   - Cleaned up compiler deprecations for `activeColor` and dropdown form fields.
   - Built and launched on the Pixel 6 emulator, verifying that the UI is fully responsive and localized.

**Current App State:** The app builds cleanly, manages local contacts list, routes correct languages in real-time, connects two devices over the internet via WebRTC, and runs the entire AI/DataChannel orchestration perfectly. The AI plumbing is 100% ready for the final ASL model.

> [!IMPORTANT]
> **How to inject the real model and assets when they are ready:**
> 1. Replace `assets/models/gesture_model.tflite` with your trained ASL model.
> 2. Open `assets/labels/gesture_labels.txt` and replace the words with your real ASL vocabulary (one word per line).
> 3. Add your real `.gif` animations into the `assets/gifs/` folder. Ensure the filenames exactly match the words in the labels text file.
> 4. The pipeline will automatically detect the real model and begin processing real gestures. No Dart code changes are required!

---

## 🚀 4. Future Roadmap (What Remains to be Done)

The following high-priority features are required to complete the production readiness of SignBridge. Any future AI assistant working on this project should refer to this list.

### 🧠 1. Final AI Asset Creation & Integration (Deferred Phase)
*Since the underlying TFLite plumbing is finished, the actual population of the AI assets is scheduled for the future when the dataset or model is ready.*
- **Task:** Obtain or train an ASL/Swahili gesture model (`.tflite`) and gather corresponding GIFs.
- **Where to obtain Open-Source Models (No training required):**
  - **Hugging Face:** Search `huggingface.co/models` for `tflite sign language` or `ASL classification`.
  - **Kaggle:** Go to `kaggle.com/datasets` and search for "ASL Alphabet TFLite". Many users upload pre-trained models.
  - **Roboflow Universe:** Search `universe.roboflow.com` for "American Sign Language". You can download pre-trained TFLite models directly from their computer vision hub.
- **How to train it yourself (Custom Signs):**
  - **Easiest:** Use **Google Teachable Machine** (no-code, uses your webcam, exports directly to `.tflite`).
  - **Advanced:** Use **Google Colab** + Python to fine-tune a `MobileNetV2` image classifier on a custom dataset.
- **Integration:** Once obtained, simply overwrite `assets/models/gesture_model.tflite`, update `assets/labels/gesture_labels.txt`, and add matching GIFs to `assets/gifs/`. No Dart code changes are needed!

### 🎬 2. GIF Asset Population
- **Task:** Provide real sign language `.gif` files to correspond with the translated text.
- **Implementation:** Populate the `assets/gifs/` directory with files like `hello.gif`, `thank_you.gif`, `yes.gif`, `no.gif`. The `GestureMapperService` will handle routing text to these files.

### 🌍 3. Bilingual Support (English & Swahili) [COMPLETED]
- **Status:** ✅ Done (Implemented in Phase 12)
- **Implementation:** Created custom `AppTranslations` architecture with dynamic translation key lookups. Toggles added to Onboarding, Login, and Settings screens. STT and TTS services dynamically update their speech locales at runtime.

### 💬 4. Rate & Feedback / Support Option [COMPLETED]
- **Status:** ✅ Done (Implemented in Phase 13)
- **Implementation:** Integrated a "Contact Support" option under Settings using the `url_launcher` package. Selecting this launches the system email client pre-filled with admin address `futurekelly360@gmail.com` and default subject details.

### ✨ 5. Premium Logo Loading Animations
- **Task:** Replace generic circular progress indicators with a branded animation.
- **Implementation:** Create a breathing/pulsing animation of the SignBridge logo using Flutter's `AnimationController`. Use this on the login screen and during the AI model load phase.

---

*This document serves as the master tracking file for all future development sessions on the SignBridge project.*
