# Walkthrough: Saved Contacts & Contact Support Option

We have successfully implemented the **Saved Contacts** directory and the **Contact Support** features in SignBridge.

## 1. Saved Contacts Directory (Option B)
- **Database Model (`lib/data/models/contact.dart`):** Built a new Hive-annotated `Contact` model supporting `id` (Short ID), `name`, and `userRole`. Ran the build runner code generator to compile the database adapters.
- **Repository (`lib/data/repositories/contacts_repository.dart`):** Built a repository managing saved contacts in Hive, sorted alphabetically by default.
- **Dynamic Options Sheet (`lib/ui/screens/contacts_screen.dart`):** Allows users to search, add, and delete contacts. When a contact is tapped:
  - **Join Call:** Launches the WebRTC video call using the contact's short ID as the session ID.
  - **Create Call:** Launches a new caller session generating a shareable Call ID.
  - **Copy ID:** Instantly copies their peer ID to the clipboard.
- **Dashboard Navigation:** Added a dedicated, Neumorphic **Saved Contacts** navigation card to the Home Dashboard (`home_screen.dart`) that routes directly to `/contacts`.

## 2. Contact Support Menu
- **Support Option (`lib/ui/screens/settings_screen.dart`):** Added a "Contact Support" list item inside the Settings Screen.
- **Email Dispatch:** Tapping "Contact Support" uses `url_launcher` to launch the default system mail client pre-filled with the support recipient `futurekelly360@gmail.com` and default subject line.

## 3. AI Simulator Panel (Step 14)
- **Simulation Injection (`lib/controllers/translation_controller.dart`):** Exposed `simulateLocalGesture(String text)` and `simulateLocalSpeech(String text)` methods. Gestures trigger text translation, TTS vocalized readout locally, and sync GIF/captions remotely. Speech triggers captions & GIF overlays on both ends without TTS audio output.
- **Glassmorphic Testing Panel (`lib/ui/screens/call_screen.dart`):**
  - Wrapped `AiStatusIndicator` in a double-tap `GestureDetector`.
  - Double-tapping the indicator opens a beautiful backdrop-filtered glassmorphic bottom sheet containing English/Swahili action buttons for standard vocabulary (`hello`, `thank_you`, `yes`, `no`, `help`).
- **Localization:** Mapped and added translated titles, categories, and descriptions for the simulator helper in `lib/core/translations.dart` for English and Swahili.

## 4. Verification
- Verified compilation and static analysis with `flutter analyze`, ensuring no compilation errors or warnings exist in the codebase.

## 5. Phase 1: SignBridge ID & Direct Signaling Core (Completed)
- **Database Unique Registry:** Configured the `/usernames/{lowercase_username}` collection. Checked and double-written via Firestore transactions to guarantee username uniqueness at the database level.
- **Atomic Registration Flow:** Updated [auth_service.dart](file:///c:/Users/FutureTech/sign_bridge/lib/services/auth/auth_service.dart) and [login_screen.dart](file:///c:/Users/FutureTech/sign_bridge/lib/ui/screens/login_screen.dart) to prompt, sanitize, and validate unique usernames (SignBridge IDs) on account creation.
- **Dialing Lock Service:** Created [call_manager.dart](file:///c:/Users/FutureTech/sign_bridge/lib/services/webrtc/call_manager.dart) to orchestrate atomic call initiation. Checks callee `status == idle`, sets caller and callee to `busy`, and generates unique `/calls/{callId}` records.
- **Signaling Revisions:** Updated [signaling_service.dart](file:///c:/Users/FutureTech/sign_bridge/lib/services/webrtc/signaling_service.dart) and [call_controller.dart](file:///c:/Users/FutureTech/sign_bridge/lib/controllers/call_controller.dart) to hook into dynamic call IDs and peer UIDs.
- **Automatic purging:** Programmed CallManager to completely clear ICE candidate sub-collections and calls documents on rejection, disconnect, or timeout to avoid storage accumulation.
- **Security rules:** Wrote a production-ready [firestore.rules](file:///c:/Users/FutureTech/sign_bridge/firestore.rules) layout enforcing uniqueness, write-once entries, and call-log permissions.

## 6. Phase 2: Ring Alert UI & Deaf Vibration Engine (Completed)
- **Overlay Manager Safety:** Enforced an initialization gate (`if (_entry != null) return`) in `IncomingCallOverlay` preventing duplicate screen insertions.
- **Vibration Service:** Created [vibration_service.dart](file:///c:/Users/FutureTech/sign_bridge/lib/services/accessibility/vibration_service.dart) exposing `startIncomingCallVibration()` and `stopVibration()`. It uses a periodic haptic timer to loop device vibrations continuously, providing accessibility for deaf users.
- **Overlay Integration:** Linked the haptic alert triggers directly to the overlay's life-cycle (`initState()` and `dispose()`), guaranteeing that vibration terminates instantly when answering, declining, or if the overlay widget is disposed.

## 7. Refined Calling Machine & History Logger (Completed)
- **Ringing Presence:** Configured call dialing to transition caller status to `busy` and callee status to `ringing` dynamically while the overlay rings. Statuses are set to `busy` for both only after callee accept occurs.
- **Dynamic Call History Loggers:** Programmed `saveCallHistory()` inside `CallManager` to write structured record objects (`incoming`, `outgoing`, `missed`, `declined`) under Firestore `/users/{uid}/call_history` collections upon calls completing, timing out, or being rejected.
- **Overlay State Listeners:** Attached real-time document listeners to incoming dials so that if the caller hangs up or the call times out on Caller's 30s timer, the Callee's overlay is dismissed instantly.

## 8. Phase 2 Completion & E2E Testing Guide
- Prepared a comprehensive validation and testing guide for two Android devices: [phase_2_validation_and_testing_guide.md](file:///C:/Users/FutureTech/.gemini/antigravity/brain/963da5ed-14dd-478a-8689-d790b8abe943/phase_2_validation_and_testing_guide.md).
- Verified full workflow: SignBridge ID lookup, direct dialing, overlay integration, acceptance/rejection flow, connection checks, and history log creation.
- Created pre-testing validation report and Go/No-Go assessment: [pre_testing_validation_report.md](file:///C:/Users/FutureTech/.gemini/antigravity/brain/963da5ed-14dd-478a-8689-d790b8abe943/pre_testing_validation_report.md).

## 9. Bug Fix: Calling State & Registration Permission Errors (Completed)
- **Problem 1 (Registration):** Sign-up attempts on physical devices were failing with a `[cloud_firestore/permission-denied]` error during username pre-check queries.
- **Problem 2 (Calling Status):** Call creation failed when updating the callee's status because of strict write permissions on `/users/{uid}`.
- **Problem 3 (Bootstrap Auth Bypass):** During `_bootstrap()`, the app unconditionally ran `_auth.signInAnonymously()`. If a caller was already logged in (e.g. `zubery_123`), this call signed them out and authenticated them as a new anonymous guest. This changed their Firebase UID, causing subsequent Firestore writes (like writing call history records) to fail with a `permission-denied` error since they were no longer authenticated under their registered account.
- **Problem 4 (Overlay Context Exception):** When an incoming call was received, resolving the overlay context via `Overlay.of(AppRoutes.navigatorKey.currentContext)` threw an `Unhandled Exception: Null check operator used on a null value`. This occurred because the context retrieved from the global `navigatorKey` points to the `Navigator` itself, and `Overlay` is a child of the `Navigator`, not an ancestor.
- **Solution:** 
  - Updated `firestore.rules` to allow public reads on `/usernames`, and allowed authenticated users to update another user's document ONLY for the `'status'` field.
  - Modified `_bootstrap()` in `lib/controllers/call_controller.dart` to check if a user is already logged in before running `signInAnonymously()`.
  - Updated `IncomingCallOverlay` to directly access the overlay state from the navigator state via `AppRoutes.navigatorKey.currentState?.overlay`, and added a safety try-catch block to `OverlayEntry.remove()`.
  - Updated `firebase.json` and deployed all security rules successfully using the Firebase CLI.
- **Verification:** Verified that call creation does not disrupt the user's logged-in identity and that the call state proceeds correctly.


