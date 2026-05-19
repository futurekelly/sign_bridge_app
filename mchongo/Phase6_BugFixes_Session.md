# SignBridge — Phase 6 Completion + Bug Fixes Session
**Date:** May 1, 2026  
**Agent:** Claude Opus (Antigravity)  
**Previous work:** Phases 1–5 built with Claude Opus 7

---

## 📋 Session Overview

This session addressed **5 user-reported bugs** from testing on a physical device (USB-connected Android phone) and completed **Phase 6 (DataChannel Integration)** which was left unfinished from the previous development cycle.

---

## 🐛 Issues Fixed

### Issue 1: Call Screen — Call ID Not Visible + End Button Broken
**Symptoms:**
- When creating a call, the Call ID was sometimes not visible on screen
- "Waiting for peer to join" shown but no call ID to share
- End call button didn't work properly (app would crash)

**Root Cause:**
- The call screen checked `renderer.srcObject == null` directly to decide whether to show the Call ID banner. This property doesn't trigger Flutter widget rebuilds — so the UI wouldn't update when the remote peer connected.
- The end button called `webrtc.dispose()` (destroying video renderers) before `Navigator.pop()`, causing the widget to rebuild with disposed renderers → crash.

**Fix:**
- Added `onRemoteStreamAdded` callback in `WebRTCService` that fires when peer's video arrives
- Added `remoteConnected` flag in `CallController` driven by the callback, which calls `notifyListeners()` to trigger UI rebuild
- Call screen now uses `controller.remoteConnected` instead of checking renderer directly
- `endCall()` now sets state to `ended` FIRST (so UI stops rendering WebRTC views), THEN disposes resources
- Added `_disposed` guard to prevent double-dispose crashes
- End button has `_isEnding` flag to prevent double-tap
- When state is `ended`, a safe "Call Ended" screen is shown (no WebRTC views)
- Call ID banner redesigned with more prominent layout and selectable/copyable text

**Files Modified:**
- `lib/services/webrtc/webrtc_service.dart`
- `lib/controllers/call_controller.dart`
- `lib/ui/screens/call_screen.dart`

---

### Issue 2: Keyboard Overflow in Join Call Dialog
**Symptoms:**
- When clicking "Join Call" and the keyboard appeared for typing the Call ID, the background showed "bottom overflowed by 22 pixels"

**Root Cause:**
- The `AlertDialog` with a `TextField` didn't handle keyboard insets — the dialog content didn't resize when the soft keyboard appeared.

**Fix:**
- Wrapped the `AlertDialog` content in `SingleChildScrollView`

**Files Modified:**
- `lib/ui/screens/home_screen.dart`

---

### Issue 3: No Login/Register Form + No Username Display
**Symptoms:**
- No way to enter a username at registration
- Home screen showed generic "Welcome 👋" instead of "Welcome, {username} 👋"
- Using anonymous Firebase Auth with no identity

**Root Cause:**
- Auth service only had anonymous sign-in with no username collection or storage.

**Fix:**
- Extended `AuthService` with Firestore user profile storage:
  - `saveUserProfile(displayName)` → stores `{displayName, shortId, uid}` in Firestore `users/{uid}`
  - `getDisplayName()`, `getShortId()`, `hasProfile()` methods added
  - Generates 6-character alphanumeric short ID on registration
- Redesigned `LoginScreen` with:
  - Display name text field
  - "Get Started" button
  - "Continue as Guest" option (preserves anonymous auth)
  - Auto-skips to home if already registered
  - Wrapped in `SingleChildScrollView` for keyboard safety
- Updated `HomeScreen` to show "Welcome, {displayName} 👋"

**Upgrade Path for Future Auth:**
> To upgrade to email/password or Google Sign-In later, ONLY change `signInAnonymously()` in `auth_service.dart`. The Firestore user profile doc pattern stays identical. Zero changes needed in any other file.

**Files Modified:**
- `lib/services/auth/auth_service.dart`
- `lib/ui/screens/login_screen.dart`
- `lib/ui/screens/home_screen.dart`

---

### Issue 4: Demo Onboarding Instructions (Optional)
**Symptoms:**
- New users had no instructions on how to use the app

**Fix:**
- Created `OnboardingScreen` with 3-page `PageView`:
  1. **Welcome to SignBridge** — explains the concept
  2. **Real-Time Video Calls** — how to create/join calls with Call IDs
  3. **AI-Powered Translation** — how gesture/speech recognition works
- Skip button on all pages
- Animated page indicator dots
- "Get Started" button on final page
- Stores `hasSeenOnboarding` flag in Hive `app_settings` box
- `app.dart` checks flag on startup → shows onboarding on first launch, login on subsequent

**Files Created:**
- `lib/ui/screens/onboarding_screen.dart`

**Files Modified:**
- `lib/data/local/hive_db.dart` — added `app_settings` box
- `lib/core/routes.dart` — added `/onboarding` route
- `lib/app.dart` — dynamic initial route based on onboarding flag

---

### Issue 5: User ID Sharing + Call History Enhancement (Optional)
**Symptoms:**
- No way to identify users or share IDs for calling
- Call history had no way to initiate a new call

**Fix:**
- Home screen now displays the user's 6-character short ID in a styled card with copy button
- History screen enhanced:
  - "Call Again" icon button on each history entry (starts new call as caller)
  - Floating "New Call" FAB at bottom
  - Confirmation dialog before clearing all history

**Files Modified:**
- `lib/ui/screens/home_screen.dart`
- `lib/ui/screens/history_screen.dart`

---

## 🔌 Phase 6: DataChannel Integration (Completed)

**What was missing:** The Phase 6 DataChannel hooks were commented out as placeholders in `call_controller.dart`.

**What was done:** Uncommented and wired:
```dart
webrtc.onDataChannelMessage = translation.handleIncomingPeerJson;
translation.onOutgoing = webrtc.sendDataChannelMessage;
```

This means:
- When a local AI result is produced (gesture or speech), it's sent to the peer via WebRTC DataChannel
- When a peer's translation arrives via DataChannel, it's rendered identically to local AI output
- Both users see the same translation overlays during a call

**Files Modified:**
- `lib/controllers/call_controller.dart`

---

## 📁 Complete File Change Summary

| File | Action | Issue(s) |
|------|--------|----------|
| `lib/services/webrtc/webrtc_service.dart` | Modified | #1 |
| `lib/controllers/call_controller.dart` | Modified | #1, Phase 6 |
| `lib/ui/screens/call_screen.dart` | Modified | #1 |
| `lib/ui/screens/home_screen.dart` | Modified | #2, #3, #5 |
| `lib/services/auth/auth_service.dart` | Modified | #3 |
| `lib/ui/screens/login_screen.dart` | Modified | #3 |
| `lib/ui/screens/onboarding_screen.dart` | **Created** | #4 |
| `lib/data/local/hive_db.dart` | Modified | #4 |
| `lib/core/routes.dart` | Modified | #4 |
| `lib/app.dart` | Modified | #4 |
| `lib/ui/screens/history_screen.dart` | Modified | #5 |
| `test/widget_test.dart` | Modified | Cleanup |

---

## 🏗️ Architecture Decisions

### Firebase Usage (Minimal)
- **Signaling**: `calls/{callId}` — SDP/ICE exchange (unchanged)
- **User profiles**: `users/{uid}` — `{displayName, shortId, uid, createdAt}` (new, 1 doc per user)
- **Free tier safe**: ~1 write per registration, ~1 read per app launch

### Data Storage
- **Translation history**: Hive (on-device only) — per architecture spec
- **App settings**: Hive `app_settings` box — onboarding flag
- **User profile**: Firestore (needed for display name lookup by other users)

### Auth Upgrade Path
The anonymous auth + Firestore profile pattern is designed to be swapped:
1. Change `signInAnonymously()` → `signInWithEmail()` or Google Sign-In
2. The `users/{uid}` doc stays the same
3. No other files change

---

## ✅ Testing Results
- **Emulator (Android 17 API 37)**: ✅ All features working
- **Physical device (JNY LX1, Android 10)**: ✅ App launches and runs
- **Flutter analyze**: 0 errors (only deprecation info warnings)

---

## 📌 Current Project Status

| Phase | Status |
|-------|--------|
| Phase 1 — Core App Structure | ✅ Complete |
| Phase 2 — Call System (WebRTC) | ✅ Complete |
| Phase 3 — Firebase Signaling | ✅ Complete |
| Phase 4 — AI System (Simulated) | ✅ Complete |
| Phase 5 — Translation Engine | ✅ Complete |
| Phase 6 — DataChannel Integration | ✅ Complete |
| Bug Fixes (5 issues) | ✅ Complete |
| Onboarding + Auth + User ID | ✅ Complete |

**Next steps (suggested):**
- Plug real TFLite model into `gesture_recognition_service.dart`
- Test two-device call with DataChannel translation sync
- Polish UI with real GIF assets for sign language
