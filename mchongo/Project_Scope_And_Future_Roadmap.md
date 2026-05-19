# SignBridge — Comprehensive Project Scope & Future Roadmap

**Context for AI Assistants:** This document serves as the master blueprint for the SignBridge project. It details exactly what has been successfully implemented so far and outlines the strict architectural and design requirements for all future features. 

---

## 🏗️ 1. Current State of the Project (What We Have Built)

SignBridge is a Flutter application designed for **Two-Way Sign Language Recognition and Speech Translation**. It facilitates communication between Deaf and Hearing individuals via WebRTC video calls, augmented by on-device AI.

### Core Architecture & Features Implemented:
*   **Role-Based Accessibility Engine**: Users select their role (Deaf, Hearing, Both). The UI dynamically adapts based on this role (e.g., muting the mic by default for Deaf users, enabling/disabling GIF panels, prioritizing captions).
*   **WebRTC P2P Calling**: Full video calling implementation using `flutter_webrtc`. Firestore is used purely for signaling (exchanging SDP offers/answers and ICE candidates).
*   **Real-Time Call Overlays**: Custom UI overlays that sit on top of the video feed:
    *   `GifOverlay`: Pops up to show sign language GIFs based on recognized text.
    *   `CaptionOverlay`: Real-time glassmorphic subtitle bar.
    *   `AiStatusIndicator`: A pulsing pill showing the AI state (Listening, Recognizing, etc.).
*   **Local Storage (Hive)**: Heavy usage of Hive for blazing-fast, offline-first data storage. We store App Settings, Recent Calls, and Translation History locally.
*   **State Management**: `Provider` handles app-wide states (`ThemeController`, `AccessibilityController`) and scoped states (`CallController`).
*   **Premium UI/UX System**: A completely custom design language featuring:
    *   **Neumorphism**: Soft shadow containers that adapt to both Light and Dark themes.
    *   **Glassmorphism**: Frosted glass effects (blur + opacity) used for call overlays and modals.

---

## 🚀 2. Future Implementation Roadmap (The Next Steps)

The following 6 features are the next priorities. Any AI assisting with this project should adhere to these guidelines to maintain the project's premium aesthetic and clean architecture.

### 2.1. AI Gesture Model & GIF Mapping
**Goal**: Translate speech to GIF animations for Deaf users, and translate camera gestures to text/speech for Hearing users.
*   **How it works**: 
    1. **Speech-to-GIF**: When the Hearing user speaks, the `SpeechService` converts audio to text (e.g., "climb"). The `GestureMapperService` intercepts this text, maps it to a local asset (`assets/gifs/climb.gif`), and pushes it to the `GifOverlay`.
    2. **Gesture-to-Text**: The local camera feed is passed frame-by-frame to a trained TensorFlow Lite (`tflite_flutter`) model. The model outputs a text label (e.g., "Hello"). The app displays this text on the `CaptionOverlay` and uses `flutter_tts` to speak it out loud.
*   **Next Action**: Collect/Train a TFLite model and place the corresponding `.gif` files in the `assets/gifs/` directory.

### 2.2. Bilingual Support (English & Swahili)
**Goal**: Make the entire app available in both English (default) and Swahili.
*   **Implementation Strategy**: Use the `easy_localization` or native `flutter_localizations` package.
*   **UI Placement**: Instead of creating a blank new page just for language selection (which adds friction), **embed a sleek Language Toggle at the top right of the very first Onboarding Screen**. We will also add a language toggle inside the Settings screen for returning users.
*   **AI Requirement**: The STT (Speech-to-Text) and TTS engines must dynamically switch locales based on the selected language (`en_US` vs `sw_TZ`).

### 2.3. Rate & Feedback System
**Goal**: Allow users to submit feedback directly to `futurekelly360@gmail.com`.
*   **Implementation Strategy**: 
    1. Do not clutter the "About Us" section. Feedback deserves its own dedicated, beautiful **Glassmorphic Modal Popup** triggered from the Settings screen.
    2. **Data Flow**: The feedback should be saved to a `feedbacks` collection in Firebase Firestore. You can then write a simple Firebase Cloud Function that automatically emails `futurekelly360@gmail.com` whenever a new document is added. 
    3. Alternatively, for a completely free no-backend setup, use the `url_launcher` package to open the user's email app with a pre-filled `mailto:` template.

### 2.4. OAuth Integration (Google Login)
**Goal**: Move away from Anonymous Login to secure, permanent accounts.
*   **Why it's necessary**: Anonymous accounts are lost if the user uninstalls the app or clears app data. Real OAuth allows users to sync their settings across devices, allows for password resets, and enables you to send them email updates.
*   **Implementation Strategy**: Integrate `google_sign_in` alongside `firebase_auth`. Update the Login Screen to feature a beautifully styled Neumorphic "Continue with Google" button. 

### 2.5. Custom Logo Loading Animations
**Goal**: Replace standard loading spinners with a highly polished, branded loading animation.
*   **Implementation Strategy**: We should take the SignBridge logo (the gradient hands) and create a **breathing/pulsing animation** using Flutter's `AnimationController`. 
*   This animation should be used on the Login Screen when authenticating, and when waiting for the AI model to load into RAM. This vastly elevates the "premium" feel of the app.

### 2.6. Neon Glow UI Effects
**Goal**: Add modern "Cyberpunk/Neon" hover and active state effects to specific texts and buttons.
*   **Implementation Strategy**: We can achieve a Neon effect purely in Flutter using `BoxShadow` (for containers) or `Shadow` (for text) with high blur radiuses and vibrant colors.
*   **Example**: 
    ```dart
    // Neon Text Effect snippet
    Text(
      'About SignBridge',
      style: TextStyle(
        color: Colors.white,
        shadows: [
          Shadow(color: AppColors.primary, blurRadius: 10),
          Shadow(color: AppColors.primaryLight, blurRadius: 20),
        ],
      ),
    )
    ```
*   We will apply this selectively—for example, on the "Get Started" button or when a user's role is actively highlighted, keeping it subtle enough so it doesn't clash with the Neumorphism.

---

## 🛠️ 3. Tech Stack Reference
*   **Framework**: Flutter (Dart)
*   **Realtime Comm**: `flutter_webrtc`
*   **Backend**: Firebase (Auth, Firestore for Signaling)
*   **Local DB**: Hive
*   **AI / ML**: `tflite_flutter` (Gesture), `speech_to_text` (STT), `flutter_tts` (TTS)
*   **State Management**: `provider`
*   **Styling**: Custom Neumorphism/Glassmorphism (No heavy UI packages)
