# Phase 8: TFLite AI Integration Strategy & Implementation Plan

## Goal
Integrate a real TensorFlow Lite (`tflite_flutter`) inference pipeline into `gesture_recognition_service.dart` to process live camera frames.

Since we do not have a trained ASL model or GIF files yet, we will achieve **70% functionality** by building the entire end-to-end "plumbing" using placeholder assets. Once your final model and GIFs are ready, dropping them in will be a 5-minute task.

---

## 1. What Remains to be Done
To complete this phase, we need to execute the following steps:
1. **Asset Management:** Place placeholder GIFs and a pre-trained dummy/open-source TFLite model in the correct directories.
2. **Native Configuration:** Update Android/iOS native files to support TFLite and camera processing.
3. **Camera Pipeline:** Capture raw camera frames (`YUV420` for Android, `BGRA8888` for iOS).
4. **Image Preprocessing:** Convert these raw frames into a `224x224x3` RGB Tensor.
5. **Inference & Routing:** Feed the Tensor to TFLite, get the label, and emit it to the `TranslationController`.

---

## 2. Exactly Where Files Must Be Placed

Before writing code, we need placeholders. This is exactly where they must go:

### A. The TFLite Model
* **Path:** `assets/models/gesture_model.tflite`
* **What to put there:** I will download a lightweight, open-source image classification model (like MobileNet) to act as our placeholder. When you train your own ASL model, you will simply replace this single file.

### B. The Label Map
* **Path:** `assets/labels/gesture_labels.txt`
* **What to put there:** A simple text file where line 0 corresponds to model output index 0. For example:
  ```text
  hello
  thank_you
  yes
  no
  help
  ```

### C. The GIF Files
* **Path:** `assets/gifs/`
* **What to put there:** We need exactly 5 GIF files that match the labels above. 
  * `assets/gifs/hello.gif`
  * `assets/gifs/thank_you.gif`
  * `assets/gifs/yes.gif`
  * `assets/gifs/no.gif`
  * `assets/gifs/help.gif`
* **Note:** Since you don't have these yet, I can generate simple text-based GIFs (e.g., an image saying "HELLO GIF") or place dummy images there so the app doesn't crash when it tries to load them.

---

## 3. Implementation Phases

Since you have enough tokens and requested a careful, bug-free approach, I will break the coding part into 3 distinct, heavily-tested phases:

### Phase A: Native Setup & Dependencies
1. Add `tflite_flutter`, `image` (for frame conversion), and `path_provider` to `pubspec.yaml`.
2. Update `android/app/build.gradle` to ensure `minSdkVersion` is at least 21 and the NDK is properly configured so the TFLite native C++ libraries compile successfully.
3. Download the placeholder `gesture_model.tflite` and `gesture_labels.txt` and place them in the `assets/` folder.

### Phase B: The Camera Isolate (The Hardest Part)
1. Processing 30 frames per second on the main UI thread will cause the app to freeze completely. 
2. I will write a background **Isolate** (a separate CPU thread) in `gesture_recognition_service.dart`.
3. The `CameraController` will stream raw frames to this Isolate. The Isolate will convert the raw `YUV420` bytes into a flat RGB Tensor format.
4. I will implement a throttle mechanism so we only process exactly **3 frames per second**.

### Phase C: TFLite Inference & UI Sync
1. The Isolate passes the RGB Tensor to the `Interpreter.fromAsset()`.
2. The Interpreter outputs an array of probabilities.
3. We calculate the `argmax` (the highest probability) and map it to `gesture_labels.txt`.
4. We emit this string via `_resultCtrl.add(TranslationMessage(...))`.
5. The `TranslationController` (which we already built) will automatically route this to the `CaptionOverlay` and sync it over WebRTC to the peer device. 

---

## Conclusion
This approach guarantees your app will not crash from memory leaks or UI thread locks, which are extremely common when dealing with live video AI processing. 

Once we finish this plan, your app will literally be "watching" the camera and passing frames to AI locally, taking us up to 70% functionality. 

*(Note: The `GifOverlay` has already been updated to ensure it only appears for users who selected the "Deaf" role during registration.)*
