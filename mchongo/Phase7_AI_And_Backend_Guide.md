# 🚀 SignBridge — Progress, AI Integration & Free Architecture Guide
**Date**: May 19, 2026

---

## 1️⃣ What We Have Done So Far

We have completely modernized the SignBridge app, transforming it from a basic prototype into a professional, role-based accessibility platform.

### ✅ Completed Milestones:
1. **Role-Based Architecture**: Implemented `Deaf`, `Hearing`, and `Both` user roles that dynamically alter the UI (muting mics by default, showing visual alerts, sizing GIF panels).
2. **Modern UI/UX Redesign**: Applied a premium Neumorphic and Glassmorphic design language across all screens (`AppTheme`, `GlassCard`, `NeumorphicContainer`).
3. **Advanced Call Screen Overlays**: Built the `GifOverlay`, `CaptionOverlay`, and `AiStatusIndicator` that sit beautifully on top of the WebRTC video feed.
4. **Local Data Persistence**: Upgraded `HiveDb` to store Application Settings, Translation History, and a new **Recent Calls** feature.
5. **Rich History & Learning**: Replaced flat lists with rich `ConversationCard`s and built a brand new **Learning Resources** section with PDF linking.

---

## 2️⃣ What Should Be Implemented Next

The core UI and state management are solid. The next focus shifts to the **Backend** and **AI Pipeline**:
1. **Integrate the Real AI Model**: Replace the mock `GestureRecognitionService` with an actual TensorFlow Lite (`tflite_flutter`) model.
2. **Real Authentication**: Move from Anonymous login to Email/Google login.
3. **Populate Assets**: Add the actual `.gif` files to `assets/gifs/`.
4. **STUN/TURN Configuration**: Ensure WebRTC works across different mobile networks, not just local Wi-Fi.

---

## 3️⃣ AI Integration & GIF Best Practices

### Where and When to Tie the Model
- **Where**: The AI logic belongs purely inside `lib/services/ai/gesture_recognition_service.dart`. The UI (`CallScreen`) and Orchestrator (`TranslationController`) are already built to listen to this service. You do not need to change the UI to add the model.
- **When**: The model should only be loaded into memory when a call starts, and disposed of when the call ends to save RAM. WebRTC frames (from the local camera) should be sampled (e.g., 5-10 frames per second) and fed into the TFLite model.

### Best Practices for Sign Language Models
1. **On-Device Processing**: Use **TensorFlow Lite (TFLite)** or **MediaPipe**. Never send video frames to a cloud server for recognition. Cloud processing costs money and has high latency. On-device is 100% **FREE** and instant.
2. **GIF Mapping**: Bundle GIFs in the app (`assets/gifs`). Our `GestureMapperService` currently maps text to a GIF asset key. By bundling them, they load instantly without internet.

---

## 4️⃣ How to Keep Everything 100% FREE

You can build and scale this app to thousands of users without paying a dime. Here is the architecture:

### 1. AI & Machine Learning = FREE
*   **Gesture Recognition**: TFLite runs on the user's phone CPU/NPU. Cost: **$0**.
*   **Speech-to-Text (STT)**: The `speech_to_text` package uses the native Android/iOS speech recognizer. Cost: **$0**.
*   **Text-to-Speech (TTS)**: The `flutter_tts` package uses the native OS voice engine. Cost: **$0**.

### 2. Video Calling (WebRTC) = FREE
*   WebRTC is Peer-to-Peer. Video data goes directly from Phone A to Phone B. It does not go through a server. Cost: **$0**.
*   *Note on TURN servers*: Sometimes Wi-Fi firewalls block P2P. You need a TURN server as a fallback. Use a service like **Metered.ca** which gives you 50GB of TURN data for FREE every month.

### 3. Database & Signaling = FREE (Firebase or Supabase)
*   **Signaling**: You only need the database for 5 seconds to connect User A and User B. After that, they communicate directly.
*   **Firebase Free Tier (Spark)**: 50k reads/20k writes per day. Plenty for thousands of calls.
*   **Supabase Free Tier**: An excellent open-source alternative to Firebase. Gives you a free Postgres database, unlimited Auth users, and 500MB of storage.

---

## 5️⃣ Moving from Anonymous to Actual Login (Firebase vs Supabase)

Currently, we use `signInAnonymously()`.

### Using Firebase
1.  Go to Firebase Console -> Authentication -> Sign-in Method -> Enable **Email/Password** or **Google**.
2.  In `AuthService`, replace the anonymous call with:
    ```dart
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: p);
    ```

### Moving to Supabase (Recommended Free Alternative)
Supabase is highly recommended if you want a powerful SQL database for free.
1.  Create a free project at supabase.com.
2.  Replace `firebase_auth` and `cloud_firestore` in `pubspec.yaml` with `supabase_flutter`.
3.  Rewrite `SignalingService` to use Supabase Realtime (WebSockets) instead of Firestore documents.

---

## 6️⃣ Feedback Section & Email Collection (Best Practices)

**Can I attach my email on authentication or feedback?**
**Yes, absolutely.** It is highly recommended.

### How to do it properly:
1.  **Authentication**: When a user registers, store their email in a `users` table (Firestore or Supabase). This allows you, the Admin, to contact them.
2.  **Feedback Section**: Create a `FeedbackScreen`. Because the user is logged in, you automatically know their email. When they submit feedback, save a document to a `feedback` collection:
    ```json
    {
      "userId": "123",
      "email": "user@example.com",
      "message": "The GIF for 'Hello' is lagging",
      "timestamp": "2026-05-19"
    }
    ```
3.  **Admin Dashboard**: You can later build a simple free web dashboard (hosted on Vercel) to view this feedback and email users back.

### Summary of Next Steps
If you are ready to proceed, we should:
1. Build a **Feedback Screen** to capture user issues.
2. Update the **Login Screen** to take actual Emails and Passwords.
3. Configure the **Firebase Auth** logic for real accounts.
