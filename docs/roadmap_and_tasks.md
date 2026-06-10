# SignBridge Development Journey & Task Tracker

This document tracks all features built, debugged, and validated, as well as the remaining production improvements.

## 1. Project Tech Stack
* **Framework**: Flutter (Dart)
* **Backend**: Firebase (Auth, Cloud Firestore)
* **Real-time Media**: WebRTC (`flutter_webrtc` package)
* **Local Storage**: Hive (for settings, translations preference, and saved contacts)
* **Vibration/Haptics**: `permission_handler` + `vibration` (Deaf alert system)

---

## 2. Completed Milestones

### Core Signaling & Security (Phase 1)
- [x] **SignBridge ID Uniqueness**: Lowercase unique IDs registry via Firestore transactions on `/usernames` and profile writes under `/users/{uid}`.
- [x] **Double-Write Rollbacks**: Automatically deletes Firebase Auth accounts if the transaction database profile write fails.
- [x] **Direct Dialing Locks**: Caller atomically checks if callee is `'idle'`, locks statuses to `'busy'`/`'ringing'`, and creates the WebRTC signaling document.
- [x] **Firestore Security Rules**: Deployed tight security rules restricting writes to owning users, except permitting authenticated status updates and call history logging.

### Ring UI & Deaf Vibration Alerts (Phase 2)
- [x] **Incoming Call Overlay**: Implemented system alert overlay with animated glassmorphic design and green/red Accept/Decline action buttons.
- [x] **Vibration Engine**: Integrates a periodic haptic timer that loops device vibrations continuously for deaf callee roles until answered or declined.
- [x] **Overlay Life-cycle Sync**: Attached document listeners so the overlay is automatically dismissed if the caller hangs up or times out (30s timer).

### Bilingual & Refinement (Phase 3)
- [x] **Bilingual Support**: Dynamic, fully localized Swahili (Kiswahili) and English language translations mapped across the onboarding, login, settings, calling, and history screens.
- [x] **Saved Contacts Directory**: Alphabetically sorted Hive directory allowing users to add, search, delete, copy, and dial contacts.
- [x] **Contact Support**: Automated mail launch dispatch inside settings to `futurekelly360@gmail.com`.
- [x] **AI Simulator Panel**: Hidden glassmorphic panel opened via double-tapping the AI icon in the calling screen, facilitating simulation of hand gestures/vocalized translations for E2E validation.

### Testing & E2E Handshake Bug Fixes (Completed)
- [x] **Permission Error Fixes**: Resolved Firestore permission-denied crashes during username check.
- [x] **Bootstrap Auth Fix**: Prevented calls from signing out registered users and converting them to anonymous guests mid-call.
- [x] **Overlay Context Fix**: Replaced `Overlay.of(context)` with `AppRoutes.navigatorKey.currentState?.overlay` to avoid null-check crashes.
- [x] **Handshake Race Condition Fix**: Programmed the callee to listen and wait for the caller's WebRTC offer to arrive in Firestore if the callee answers before the caller's camera initializes.

---

## 3. What Remains (Production Roadmap)

- [ ] **Paid TURN Servers**: Replace the free OpenRelay configuration (`openrelay.metered.ca`) with paid production TURN servers in `webrtc_service.dart` to guarantee connectivity on restricted cellular data networks.
- [ ] **FCM Push Notifications**: Integrate Firebase Cloud Messaging so that incoming call alerts wake up the callee's device even if the app is in the background or killed (currently, Firestore listeners require the app to be active).
- [ ] **Real-time AI Integration**: Replace the AI Simulation Panel triggers with live local on-device ML model gesture detection.
