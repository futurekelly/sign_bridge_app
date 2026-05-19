# 🔧 SignBridge — Full Upgrade Plan
**Date**: May 19, 2026  
**Status**: Ready to implement  

---

## 📊 PART 1: EXISTING FEATURES AUDIT

### ✅ Already Implemented (DO NOT REBUILD)

| # | Feature | File(s) |
|---|---------|---------|
| 1 | Firebase Anonymous Auth + display name + short ID | `services/auth/auth_service.dart` |
| 2 | Onboarding (3-page, skip, Hive flag) | `ui/screens/onboarding_screen.dart` |
| 3 | Login screen (name entry, guest, auto-skip) | `ui/screens/login_screen.dart` |
| 4 | Home screen (welcome, ID card, Create/Join/History) | `ui/screens/home_screen.dart` |
| 5 | WebRTC video call (offer/answer/ICE/Firestore signaling) | `services/webrtc/webrtc_service.dart`, `signaling_service.dart` |
| 6 | Call screen (remote/local video, status pill, controls) | `ui/screens/call_screen.dart` |
| 7 | Call controls widget (mute, end, switch cam) | `ui/widgets/call_controls.dart` |
| 8 | AI — Gesture recognition (simulated TFLite stub) | `services/ai/gesture_recognition_service.dart` |
| 9 | AI — Speech-to-Text (real plugin) | `services/ai/speech_service.dart` |
| 10 | AI — Text-to-Speech (real plugin) | `services/ai/tts_service.dart` |
| 11 | AI — GIF mapper (text → asset key) | `services/ai/gesture_mapper_service.dart` |
| 12 | Translation controller (orchestrates AI, 3 streams, DataChannel) | `controllers/translation_controller.dart` |
| 13 | Translation history (Hive, basic list) | `ui/screens/history_screen.dart`, `data/repositories/history_repository.dart` |
| 14 | TranslationMessage model (Hive + JSON) | `data/models/translation_message.dart` |
| 15 | Light theme (Material 3, blue primary) | `core/theme.dart` |
| 16 | Named routes (5 routes) | `core/routes.dart` |
| 17 | Camera + mic permissions | `core/utils/permissions.dart` |
| 18 | Hive local DB init | `data/local/hive_db.dart` |
| 19 | CallModel (Firestore doc shape) | `data/models/call_model.dart` |
| 20 | FirestoreService (signaling paths) | `services/firebase/firestore_service.dart` |

### ⚠️ Partial / Stub

| Feature | Issue |
|---------|-------|
| GIF playback | Mapper exists but NO rendering widget on call screen |
| AI status indicator | `statusStream` exists but NO UI widget consumes it |
| Real-time subtitles | `liveResultStream` exists but NO caption overlay |

---

## ❌ PART 2: MISSING FEATURES

1. **Dark theme** — only `lightTheme` exists
2. **Theme toggle** — no switching mechanism
3. **Settings screen** — does not exist
4. **User role system** (Deaf/Hearing/Both) — no concept at all
5. **GIF overlay widget** on call screen
6. **Caption/subtitle overlay** on call screen
7. **AI status badge** on call screen
8. **Visual notifications** for deaf users
9. **Recent Calls** storage and quick-rejoin
10. **Enhanced history** (conversation cards, search, filters, participant info)
11. **Learning Resources** screen
12. **Neumorphism/Glassmorphism** styling
13. **Consistent spacing system**
14. **Google Fonts** typography
15. **Bottom navigation**

---

## 🐛 PART 3: ISSUES TO FIX

1. `CallRole` + `CallArgs` defined inside `home_screen.dart` — other files import it awkwardly → move to `core/enums.dart`
2. No app-level `Provider` — only `CallController` is scoped to `CallScreen` → need `MultiProvider` at root
3. `withOpacity()` used everywhere → deprecated in newer Flutter, use `withValues()`
4. No `Semantics` wrappers on any widget → add for TalkBack/screen reader
5. Only 1 reusable widget (`CallControls`) → extract more shared components
6. `assets/gifs/` declared in pubspec but empty — no actual GIF files

---

## 🏗️ PART 4: IMPLEMENTATION PHASES

---

### PHASE A: Core Infrastructure

**Goal**: Enums, spacing tokens, theme system, accessibility helpers

#### [MODIFY] `lib/core/enums.dart`
```dart
// ADD:
enum UserRole { deaf, hearing, both }

// MOVE from home_screen.dart:
enum CallRole { caller, callee }

class CallArgs {
  final CallRole role;
  final String? callId;
  const CallArgs({required this.role, this.callId});
}
```

#### [NEW] `lib/core/spacing.dart`
```dart
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}
```

#### [MODIFY] `lib/core/theme.dart`
- Add `AppColors` class (light + dark variants, blue/white palette)
- Add `darkTheme` getter
- Add neumorphic shadow helpers: `neumorphicLight()`, `neumorphicDark()`
- Add glassmorphic decoration: `glassMorphicDecoration()`
- Update text theme with proper scale

#### [NEW] `lib/core/utils/accessibility.dart`
```dart
class AccessibilityHelper {
  static bool shouldShowGifPanel(UserRole role) => role != UserRole.hearing;
  static bool shouldShowCaptions(UserRole role) => role != UserRole.hearing;
  static bool shouldEnableTTS(UserRole role) => role != UserRole.deaf;
  static bool shouldShowMicControls(UserRole role) => role != UserRole.deaf;
  static double fontScale(UserRole role) => role == UserRole.deaf ? 1.2 : 1.0;
  static bool useVisualNotifications(UserRole role) => role != UserRole.hearing;
}
```

---

### PHASE B: State Management

**Goal**: App-level controllers + new Hive boxes

#### [NEW] `lib/controllers/theme_controller.dart`
- `ThemeController extends ChangeNotifier`
- Reads/writes `themeMode` to Hive `app_settings` box
- Exposes `ThemeMode get themeMode` and `void toggleTheme()`

#### [NEW] `lib/controllers/accessibility_controller.dart`
- `AccessibilityController extends ChangeNotifier`
- Stores: `UserRole`, `captionsEnabled`, `fontScale`, `visualNotifications`
- All persisted to Hive `app_settings` box

#### [MODIFY] `lib/data/local/hive_db.dart`
- Register `RecentCallAdapter`
- Open `recent_calls` box

#### [NEW] `lib/data/models/recent_call.dart`
```dart
@HiveType(typeId: 1)
class RecentCall extends HiveObject {
  @HiveField(0) final String callId;
  @HiveField(1) final String? partnerName;
  @HiveField(2) final String? partnerRole;  // "deaf"/"hearing"/"both"
  @HiveField(3) final String timestamp;
  @HiveField(4) final int? durationSeconds;
}
```

#### [NEW] `lib/data/repositories/recent_calls_repository.dart`
- `save(RecentCall)`, `getAll()` (max 20, sorted by recency), `delete(callId)`

#### [NEW] `lib/data/models/learning_resource.dart`
- Model: `title`, `description`, `pdfUrl`, `category`, `iconName`

#### [NEW] `lib/data/repositories/learning_repository.dart`
- Hardcoded curated resources list
- Hive-persisted favorites set

---

### PHASE C: App Shell (Providers + Routing)

**Goal**: Wire providers at root, add new routes

#### [MODIFY] `lib/app.dart`
```dart
// Wrap MaterialApp in MultiProvider:
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeController()),
    ChangeNotifierProvider(create: (_) => AccessibilityController()),
  ],
  child: Consumer<ThemeController>(
    builder: (_, theme, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      ...
    ),
  ),
)
```

#### [MODIFY] `lib/core/routes.dart`
- Add: `static const String settings = '/settings';`
- Add: `static const String learning = '/learning';`
- Register both in routes map

#### [MODIFY] `lib/main.dart`
- Initialize new Hive boxes in `HiveDb.init()`

---

### PHASE D: Settings Screen

**Goal**: Full settings with role selection, theme toggle, accessibility prefs

#### [NEW] `lib/ui/screens/settings_screen.dart`
Sections:
1. **Profile** — display name, short ID, edit button
2. **Accessibility Role** — segmented button: Deaf / Hearing / Both
3. **Theme** — toggle: Light / Dark / System
4. **Captions** — enable/disable, font size slider
5. **Notifications** — visual vs audio preference
6. **About** — app version, tagline

Design: neumorphic section cards, Material 3 controls

---

### PHASE E: Reusable UI Components

**Goal**: Build shared neumorphic/glassmorphic widgets

#### [NEW] `lib/ui/widgets/glass_card.dart`
- Blurred semi-transparent container
- Adapts to light/dark theme
- Configurable blur, opacity, border radius

#### [NEW] `lib/ui/widgets/neumorphic_container.dart`
- Soft shadow container (light: light shadows, dark: dark shadows)
- Press state animation

#### [NEW] `lib/ui/widgets/gif_overlay.dart`
- Shows animated GIF for latest translation
- Glassmorphic panel background
- Auto-hides after 5s
- Subscribes to `TranslationController.liveResultStream`
- Size adapts per user role (larger for Deaf)

#### [NEW] `lib/ui/widgets/caption_overlay.dart`
- Bottom-positioned subtitle bar
- Semi-transparent glassmorphic background
- Source icon: 🤟 gesture / 🎤 speech
- Adjustable font size
- Fades after 8s of silence

#### [NEW] `lib/ui/widgets/ai_status_indicator.dart`
- Pill badge: green=listening, blue=recognizing, gray=idle, red=error
- Animated pulse effect
- Subscribes to `TranslationController.statusStream`

#### [NEW] `lib/ui/widgets/role_badge.dart`
- Small colored badge showing user role
- Deaf=blue, Hearing=green, Both=purple

#### [NEW] `lib/ui/widgets/conversation_card.dart`
- Rich card for history entries
- Shows: source icon, text, participant, role badge, timestamp, GIF thumbnail
- Replay animation button
- Neumorphic/glassmorphic styling

---

### PHASE F: Screen Redesigns

**Goal**: Modernize all screens, add role-based behavior

#### [MODIFY] `lib/ui/screens/home_screen.dart`
- Remove `CallRole`/`CallArgs` (now in enums)
- Redesign action cards → neumorphic/glassmorphic
- Add Settings icon in AppBar
- Add **Recent Calls** section (below Join Call)
- Add **Learning Resources** card
- Show role badge next to username
- Bottom navigation bar: Home, History, Learning, Settings
- Import `CallRole`/`CallArgs` from `core/enums.dart`

#### [MODIFY] `lib/ui/screens/login_screen.dart`
- Add **role selection** step after name entry
- Neumorphic cards, glassmorphic input fields
- Dark/light theme support

#### [MODIFY] `lib/ui/screens/onboarding_screen.dart`
- Add 4th page about accessibility features
- Modern glassmorphic backgrounds
- Smooth transitions

#### [MODIFY] `lib/ui/screens/call_screen.dart`
- **Add GIF overlay** (visible for Deaf/Both roles)
- **Add caption overlay** (visible for Deaf/Both roles)
- **Add AI status indicator**
- Role-based defaults:
  - Deaf: mic muted by default, larger GIF, prominent captions, visual ring
  - Hearing: mic/speaker prominent, optional captions
  - Both: everything visible
- On call end → save to `RecentCallsRepository`

#### [MODIFY] `lib/ui/screens/history_screen.dart`
- Replace flat list with **conversation cards** (neumorphic)
- Add **search bar** at top
- Add **filter chips**: by role, date, source type
- Add **replay GIF** button per entry
- Group messages by call session if possible
- Show participant name, ID, duration, role

#### [MODIFY] `lib/ui/widgets/call_controls.dart`
- Role-based visibility (hide mic for deaf if preferred)
- Neumorphic button styling

---

### PHASE G: Enhanced Join Call

**Goal**: Recent calls with quick rejoin

#### Changes in `home_screen.dart`
- "Recent Calls" expandable section
- Shows last 10 calls with: call ID (truncated), partner name, role badge, timestamp
- One-tap rejoin button
- Swipe to delete

#### Changes in `call_controller.dart`
- On `endCall()`: save call metadata to `RecentCallsRepository`
- Read partner name from Firestore call document

---

### PHASE H: Learning Resources Screen

**Goal**: Sign language learning library

#### [NEW] `lib/ui/screens/learning_screen.dart`
- Grid of resource cards
- Categories: Alphabet, Common Phrases, Greetings, Emergency Signs
- Each card: title, description, category badge, download icon
- Tap → open PDF via `url_launcher` (external) or in-app viewer
- Download button for offline (via `path_provider` + HTTP download)
- Favorite toggle (heart icon, persisted in Hive)
- Search bar at top
- Neumorphic/glassmorphic card design

---

## 📦 PART 5: NEW DEPENDENCIES

```yaml
# Add to pubspec.yaml
dependencies:
  google_fonts: ^6.1.0          # Modern typography (Inter/Outfit)
  url_launcher: ^6.2.5          # Open PDF links
  shimmer: ^3.0.0               # Loading skeletons
```

---

## 📁 PART 6: NEW FILE INVENTORY

| # | Path | Type |
|---|------|------|
| 1 | `lib/core/spacing.dart` | NEW |
| 2 | `lib/core/utils/accessibility.dart` | NEW |
| 3 | `lib/controllers/theme_controller.dart` | NEW |
| 4 | `lib/controllers/accessibility_controller.dart` | NEW |
| 5 | `lib/data/models/recent_call.dart` | NEW |
| 6 | `lib/data/models/recent_call.g.dart` | GENERATED |
| 7 | `lib/data/models/learning_resource.dart` | NEW |
| 8 | `lib/data/repositories/recent_calls_repository.dart` | NEW |
| 9 | `lib/data/repositories/learning_repository.dart` | NEW |
| 10 | `lib/ui/screens/settings_screen.dart` | NEW |
| 11 | `lib/ui/screens/learning_screen.dart` | NEW |
| 12 | `lib/ui/widgets/glass_card.dart` | NEW |
| 13 | `lib/ui/widgets/neumorphic_container.dart` | NEW |
| 14 | `lib/ui/widgets/gif_overlay.dart` | NEW |
| 15 | `lib/ui/widgets/caption_overlay.dart` | NEW |
| 16 | `lib/ui/widgets/ai_status_indicator.dart` | NEW |
| 17 | `lib/ui/widgets/role_badge.dart` | NEW |
| 18 | `lib/ui/widgets/conversation_card.dart` | NEW |

**Modified files**: `enums.dart`, `theme.dart`, `hive_db.dart`, `app.dart`, `routes.dart`, `main.dart`, `home_screen.dart`, `login_screen.dart`, `onboarding_screen.dart`, `call_screen.dart`, `history_screen.dart`, `call_controls.dart`, `call_controller.dart`

---

## ✅ PART 7: VERIFICATION CHECKLIST

- [ ] `flutter analyze` — zero errors
- [ ] `dart run build_runner build` — regenerate Hive adapters
- [ ] `flutter build apk --debug` — compiles clean
- [ ] Theme toggle works on all screens
- [ ] Role selection persists across app restart
- [ ] Deaf role: GIF panel visible, captions on, mic muted default
- [ ] Hearing role: mic/speaker prominent, captions optional
- [ ] Both role: all features active
- [ ] Recent calls save and rejoin works
- [ ] History search and filters work
- [ ] Learning screen loads, resources open
- [ ] Dark mode looks good on all screens
- [ ] Neumorphic/glassmorphic styling consistent

---

## ⚡ IMPLEMENTATION ORDER (Afternoon Session)

```
A → B → C → D → E → F → G → H
```

Each phase builds on the previous. A-C are foundation, D-H are features.
Estimated: ~4-5 hours for full implementation.

---

## ❓ DECISIONS NEEDED BEFORE START

1. **GIF assets**: Generate 5 placeholder GIFs for hello/thank_you/help/yes/no?
2. **Google Fonts**: Add `google_fonts` package for Inter font, or keep system defaults?
3. **PDF resources**: Use placeholder URLs or do you have specific PDFs?
4. **Role selection**: During login only, or also changeable in Settings? (Plan: both)
