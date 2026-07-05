# SignBridge App (v0.2.0-phase2-mediapipe)

SignBridge is a highly accessible, AI-powered Flutter application designed to bridge communication between Deaf and Hearing individuals. It provides real-time WebRTC video calls, native sign language gesture recognition (using MediaPipe and TensorFlow Lite), and bidirectional speech-to-text / text-to-speech translation.

---

## 💡 Motivation
Daily communication between deaf and hearing individuals often requires physical interpreters or writing notes back and forth. SignBridge aims to democratize this interaction by running a lightweight, local, and bidirectional translation pipeline directly on standard mobile hardware—eliminating the need for high-bandwidth cloud video translation services or internet connectivity for AI processing.

---

## 🚀 Current Implementation Status (Phase 2 Completed)

We have successfully completed **Phase 2 (Landmark Stream Integration)**. 
* **Native Frame Interception:** The app intercepts camera frames directly from the WebRTC local stream on the native Android layer.
* **Native MediaPipe Landmark Extraction:** A custom C++ and Java VideoSink offloads NV21 image conversions and Google MediaPipe Tasks Vision landmark detection asynchronously to high-performance native threads.
* **Continuous EventChannel Stream:** The 21 hand joints are serialized and streamed continuously over an Android `EventChannel` to the Dart AI pipeline.
* **On-Device TFLite Inference:** Dart processes the raw landmark coordinates, normalizes them, runs inference locally using `tflite_flutter` with `gesture_model.tflite`, and stabilizes output predictions before displaying visual overlays and speaking words aloud via TTS.

---

## ✨ Features Currently Implemented

* **Bilingual Support (English & Swahili):** Real-time toggling of Kiswahili and English translations across onboarding, login, call UI, settings, and learning screens, persisted offline using `Hive`.
* **Dynamic Accessibility Engine:** Automatically adapts the call interface, captions, font size, visual flash notifications, and vibration patterns based on the user's selected role (Deaf, Hearing, or Both).
* **Two-Way WebRTC Video Calling:** High-quality peer-to-peer audio/video streaming using Firestore as a signaling channel.
* **On-Device Gesture Recognition:** Real-time translation of hand gestures directly from the user's physical camera preview.
* **Bilingual Translation Overlays:**
  * `CaptionOverlay`: Real-time glassmorphic subtitle drawer.
  * `GifOverlay`: Pops up instantly to show sign language GIFs based on spoken words.
  * `AiStatusIndicator`: Live pipeline state monitor (idle, thinking, speaking, error).
* **Mock Presentation Toolbar:** A secondary manual mock gesture panel exists in absolute isolation for demonstration and presentation purposes, coexisting harmoniously with the real-time camera tracking.
* **Offline History & Resources:** Local database storage for recent calls, translation cards, and a PDF library of sign language learning resources.

---

## 🏗️ System Architecture

```
[Local Camera VideoTrack]
           │
           ▼
[MainActivity VideoSink Bridge]
           │ (addSink)
           ▼
[HandLandmarkVideoSink.onFrame()]  ── (YUV I420 to NV21 & Bitmap)
           │
           ▼
[HandLandmarkerHelper.detectAsync()] ── (Background Thread)
           │
           ▼
     [EventChannel]  ── (List<Map<String, double>> of 21 joints)
           │
           ▼
  [InferenceManager] ── (Dart coordinate receiver)
           │
           ▼
  [normalizeLandmarks()] ── (Translation & scale invariant 42-float tensor)
           │
           ▼
[gesture_model.tflite Inference]
           │ (PredictionResult)
           ▼
 [PredictionStabilizer] ── (Absence timeouts & consecutive frame confirmation)
           │
           ▼
 [TranslationController] ── (State updater & WebRTC DataChannel transmitter)
         ┌─┴────────────────────────┐
         ▼                          ▼
 [TranslationOverlay UI]   [Text-to-Speech Engine]
```

---

## 🛠️ Technology Stack

* **Cross-Platform UI:** Flutter (Dart)
* **P2P Streaming & Signaling:** `flutter_webrtc` & Cloud Firebase Firestore
* **Offline Database:** Hive & Hive Flutter (Local encryption and settings storage)
* **Native Vision Engine:** Google MediaPipe Tasks Vision (Android C++ / Java bindings)
* **Model Inference Engine:** TensorFlow Lite (using `tflite_flutter` bindings)
* **Speech Services:** Android SpeechRecognizer / `speech_to_text` (with muted fallbacks for Huawei HMS-only devices)

---

## 📂 Project Folder Structure

```
sign_bridge/
├── android/
│   └── app/
│       ├── build.gradle.kts (Page-size alignment & MediaPipe dependencies)
│       └── src/main/
│           ├── AndroidManifest.xml (Native library auto-extract flags)
│           ├── assets/
│           │   └── hand_landmarker.task (MediaPipe JNI model binary)
│           └── kotlin/com/example/sign_bridge/
│               ├── MainActivity.kt (EventChannel bridge & VideoTrack reflection)
│               ├── HandLandmarkVideoSink.kt (Native WebRTC frame capturer)
│               └── HandLandmarkerHelper.kt (MediaPipe thread manager)
├── diagnostics/
│   └── capture_frame_benchmark.dart (Empirical captureFrame format benchmarks)
├── lib/
│   ├── controllers/ (Accessibility, Call, and Translation state machines)
│   ├── core/ (Themes, Enums, and bilingual translation maps)
│   ├── services/
│   │   ├── ai/
│   │   │   ├── inference_manager.dart (Dart coordinate pipeline manager)
│   │   │   ├── landmark_processor.dart (Simulated joint generators)
│   │   │   ├── prediction_stabilizer.dart (State machine filtering)
│   │   │   └── speech_service.dart (Huawei safe TTS fallback)
│   │   └── webrtc/ (RTC connection and peer logic)
│   └── ui/
│       ├── screens/ (Dashboard, Call, Settings, History, and Learn)
│       └── widgets/ (Bilingual glassmorphic overlays)
└── assets/
    └── models/
        └── gesture_model.tflite (On-device gesture classifier)
```

---

## ⚙️ Installation & Setup

### Prerequisites
* Flutter SDK (3.22.x or higher)
* Android SDK (API Level 24 or higher)
* A physical Android device (ARM64) connected via USB Debugging. *(Note: MediaPipe JNI task files are not packaged for x86_64 emulator architectures; the app automatically falls back to call-only mode on emulators).*

### Steps
1. Clone the repository to your local directory.
2. Initialize Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Connect your Android device and verify connection:
   ```bash
   adb devices
   ```
4. Build and install the profile package to your device:
   ```bash
   flutter run --profile
   ```

---

## 🤖 Gesture Recognition Pipeline & Vocabulary

1. **Normalized Coordinates:** MediaPipe produces 21 points in `[0.0, 1.0]` portrait space. Dart translates the origin to the wrist (landmark 0) and divides by the maximum joint distance, generating a translation-invariant and scale-invariant **42-float tensor**.
2. **Current Vocabulary:** The on-device `gesture_model.tflite` model supports the following gestures:
   * `hello`
   * `thank_you`
   * `yes`
   * `no`
   * `goodbye`
   * `I_love_you`
3. **Stabilization Rules:** To prevent false positives, `PredictionStabilizer` requires **3 consecutive matching frames** to emit a gesture, enforces a **2-second cooldown** between identical signs, and triggers an **absence timeout (700 ms)** of no-hands before resetting the stream.

---

## 🗺️ Future Roadmap

* **Phase 3: Vocabulary Expansion:** Expand classifier labels from 6 signs to 30+ commonly used Swahili/English conversational sign shapes.
* **Phase 4: Model Optimization:** Train custom light-weight ML architectures and apply quantisation to the `.tflite` classifier to reduce JNI-to-Dart latency below 50 ms.
* **Phase 5: Release Build & Deployment:** Package final bilingual application for release onto physical hardware stores.

---

## ⚖️ Model Licensing & Redistribution (Notice)

The [hand_landmarker.task](file:///android/app/src/main/assets/hand_landmarker.task) file bundled under `android/app/src/main/assets/` is a pre-trained hand landmarks model provided by Google LLC under the **Apache License 2.0**. 

You may redistribute this binary in public repositories under the conditions of the Apache 2.0 license:
* **Attribution:** The binary is the property of Google LLC (MediaPipe project).
* **Warranty Disclaimer:** The model is provided "AS IS", without warranties of any kind.
* The full Apache 2.0 License can be read at: http://www.apache.org/licenses/LICENSE-2.0

---

## 🤝 Developed by FutureTech

**Core Technical Developers:**
* Kelvin E. Mbise  
  📞 +255 616 802 135  
  📧 futurekelly360@gmail.com  
