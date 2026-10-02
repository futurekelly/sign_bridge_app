# SignBridge — Auth Gate and Brand Mark

**Date:** 2026-10-02
**Commit:** `1b4bc6a`
**Agent:** Claude Code
**Preceded by:** `2026-10-02_Vision_Fix_APK_Slimming_Accessibility.md` (`7c23d28`, `aab44cc`, `ba18604`)

> Two changes, both reported by the user from the phones. §5 records a third
> finding that fell out of testing and was **not** caused by either change.

---

## 1. What the user reported

> *"i want when the user is login already then he/she dont have to see login
> form again untill he/she loged out but currently i can see when app lauches it
> direct to the login then it verify credential then login instead of just
> moving to dashboard faster also i dont think you have removed old icon of
> landing page (before registering) as they act as user manual on app"*

---

## 2. The login-form flash — root cause

Two separate causes, both real, and they compounded.

**Cause 1 — the login screen was always the entry point.**
`lib/app.dart` set `initialRoute = AppRoutes.login` unconditionally, so
`LoginScreen` was built and painted even for a signed-in user. The route was
never going to be a login screen; it just did not know that yet.

**Cause 2 — two sequential network reads before it would leave.**
`LoginScreen._checkExistingUser()` then awaited `hasProfile()` (a Firestore
read) and, if that returned true, `_syncRoleAndGoHome()` awaited
`getUserProfile()` (a second Firestore read) before navigating. Two round-trips
between "app opened" and "dashboard shown", both inside a screen the user
should never have seen.

**Cause 3 — a latent bug that would have bitten later.**
`_checkExistingUser()` ran once, from `initState`, and tested
`_auth.currentUser` synchronously. If the SDK had not finished restoring the
persisted session at that instant, the method did nothing at all — no retry, no
listener — and the signed-in user was left on the login form permanently. This
was not the reported symptom, but it was in there.

---

## 3. The fix — `BootGate`

New `lib/ui/widgets/boot_gate.dart`, wired in as `home:` so the decision is
made **before** any screen is built.

| | |
|---|---|
| **Fast path** | `FirebaseAuth.instance.currentUser`, read synchronously. After `Firebase.initializeApp()` the session is normally already restored from disk, so a returning user is routed on the first frame and the login form is never constructed. |
| **Slow path** | If `currentUser` is null, await `authStateChanges().first` — the SDK's authoritative first answer — instead of assuming signed-out. This is the fix for cause 3. |
| **Profile check** | `AuthService.hasProfileCached()` — a Hive read in the common case, Firestore only on a cache miss. |
| **Role re-sync** | Moved **after** navigation. It used to block the dashboard; now it runs in the background. |

`AuthService.hasProfileCached()` caches "this uid has a complete profile" in
Hive (key `profileCompleteUid` in the `app_settings` box), **keyed by uid**.
Keying by uid is the important part: a different account signing in on the same
phone will not match the stored uid and so re-checks, rather than inheriting
the previous user's answer. Only a `true` is ever cached, so the failure mode
is a stale "complete", never a stale "incomplete".

The cache is cleared in `signOut()`. **It is called after `_auth.signOut()`,
not before, and wrapped in try/catch.** The first version ran it before
`signOut()` unguarded, which meant a Hive failure would have left the user
permanently unable to log out. Caught in review before the build.

`BootGate` also guards the profile read: on any failure it falls back to the
dashboard rather than leaving the user on the loading screen forever. A
signed-in user is better served by a dashboard that loads its own data with its
own error handling than by a permanent splash.

### Why not just fix `initialRoute`?

Because `initialRoute` cannot express "signed out, but the SDK has not said so
yet". A gate that can await the authoritative answer is the only thing that
closes cause 3 as well as causes 1 and 2.

---

## 4. The brand mark

The user's phrase "old icon of landing page (before registering)" resolved to
two concrete sites, and the guess in the previous plan — that it meant the
onboarding slides — was wrong:

| file | line | what it was |
|---|---|---|
| `lib/ui/screens/login_screen.dart` | 437 | logo: `[AppColors.primary, AppColors.primaryLight]` |
| `lib/ui/screens/profile_setup_screen.dart` | 324 | setup icon: same gradient |

Both hand-rolled the **old blue-on-blue** gradient, while the launcher icon
introduced in `aab44cc` is **blue → emerald** (`primary` → `secondary`). The
same logo therefore looked like two different logos depending on whether you
were looking at the home screen or inside the app.

Both now use a new shared `lib/ui/widgets/brand_mark.dart`, whose
`BrandMark.gradient` is the single source of truth. It is byte-identical to the
gradient in `tools/generate_brand_icon.py`:

```
generate_brand_icon.py:  C_DEAF = (0x25, 0x63, 0xEB)   C_HEARING = (0x10, 0xB9, 0x81)
BrandMark:               AppColors.primary 0xFF2563EB   AppColors.secondary 0xFF10B981
```

**If you change one, change both** — there is a comment in each file saying so.

Rendered before/after to confirm (widget-test golden, so the glyph shows as a
box — that is the Ahem test font, not a rendering fault):

- **before:** blue (top-left) → lighter blue (bottom-right)
- **after:** blue (top-left) → emerald (bottom-right)

---

## 5. Unrelated finding — two of the three split APKs cannot run

Found while trying to reach the signed-out screens on an emulator.

```
FATAL EXCEPTION: pool-4-thread-1
Process: com.example.sign_bridge
java.lang.UnsatisfiedLinkError: dlopen failed:
    library "libmediapipe_tasks_vision_jni.so" not found
    at com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker.<clinit>
    at com.example.sign_bridge.HandLandmarkerHelper._init_$lambda$0(HandLandmarkerHelper.kt:111)
```

Checking which native libraries each split APK actually carries:

| APK | size | `libmediapipe_tasks_vision_jni.so` |
|---|---|---|
| `app-arm64-v8a-release.apk` | 34.7 MB | ✅ present |
| `app-armeabi-v7a-release.apk` | 26.9 MB | ❌ **missing** |
| `app-x86_64-release.apk` | 31.1 MB | ❌ **missing** |

MediaPipe's `tasks-vision` AAR ships **only** arm64-v8a. So:

- **arm64-v8a is the only usable APK** — which is what both phones run, so
  nothing is broken in practice today.
- The other two are built, backed up and (if we are not careful) would be
  uploaded on release day, and both **crash on launch** on any device they
  install to.
- On an x86_64 emulator the crash happens inside `main()`'s
  `await InferenceManager().initialize()`, so **the app never draws a frame**.
  `main.dart` does wrap that call in try/catch, but the failure surfaces on a
  background executor thread and kills the process before the catch can see it.
  This is why the emulator was abandoned as a test target.

**Action for step 7:** ship the arm64 APK only, or build with
`flutter build apk --target-platform android-arm64`. Do **not** reach for an
`ndk { abiFilters }` block to "fix" it — rule 4 in the plan: Gradle refuses to
configure a `--split-per-abi` build when one is present.

Worth a line in the report as a known limitation: **the app requires a 64-bit
ARM device.** Every phone from the last several years qualifies, but a 32-bit
Android Go device would not.

---

## 6. Verification

`flutter analyze` — clean apart from one pre-existing `unused_import` warning in
`lib/services/ai/performance_monitor.dart`, which arrived with `015acd7` and is
untouched here. `flutter test` — green.

**On the phones**, cold launch (`am force-stop` then `am start`, 9s wait):

| phone | user | role | result |
|---|---|---|---|
| Samsung `R58N74Y4K8V` | hexa / `h3xa` | Hearing | dashboard, full call history |
| Huawei `EPHUT20820010780` | mbise / `mbis333` | Deaf | dashboard, full call history |

Neither user was logged out and no data was cleared — the installs used
`adb install -r`. Logcat confirms `[CallManager] startListening invoked` exactly
once per launch, which only happens in `HomeScreen.initState` — i.e. the
dashboard was reached directly, with no intermediate login screen.

**Not verified: the logged-out half of the flow.** It could not be exercised
without logging out a real user, and the emulator cannot run this app (§5). The
sign-out path itself is unchanged except for the added, guarded cache clear. A
device with no account on it is the way to check the onboarding → login →
profile-setup run end to end.

---

## 7. Rollback

The APK on both phones is backed up at
`backup_apk/v1.5-arm64-bootgate-2001.apk` (md5 `8a6aa84b98457b36ee5d8b74d47039da`).
The build being replaced is `backup_apk/v1.4-arm64-icon-splash-2001.apk`
(md5 `9804da99a84f169d5f5ee6bb8399c40a`).

Both are versionCode **2001**, so rolling back is a plain
`adb install -r` of the older file — no downgrade flag needed.

To revert in source: `git revert 1b4bc6a`. The change is self-contained;
`BootGate` and `BrandMark` are new files and `app.dart` returns to a single
`initialRoute` line.
