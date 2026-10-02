# SignBridge — Vision Fix, APK Slimming & Accessibility Session

**Date:** 2026-10-02
**Agent:** Claude Code
**Trigger:** Three separate issues, worked in sequence: (1) every sign returned a confident wrong word on device; (2) the release APK was 137.7 MB; (3) vibration and TTS behaviour was wrong for the deaf role.
**Status:** All three fixed, pushed to `origin/main`, and **verified on both physical phones**.

> **Purpose of this file:** track exactly what this session changed, on which files, and how to undo it. Read §5 before reverting anything — the APK work changed the installed `versionCode`, which changes how a rollback has to be performed.

---

## 1. Commits in this session

| SHA | Summary | Pushed |
|---|---|---|
| `015acd7` | fix(vision): turn the capture frame upright, the root cause of every sign failing | ✅ |
| `3f2bb30` | build(android): split per ABI and drop the unused Flex delegate | ✅ |
| `d9b34be` | feat(a11y): real vibration patterns, and silence TTS on the deaf device | ✅ |

Tag `v1.2-working-5-signs` was already on the remote and still points at the pre-session working state.

**Devices used throughout:**

| Device | Serial | Model | Role | User |
|---|---|---|---|---|
| Huawei | `EPHUT20820010780` | JNY-LX1 | **Deaf** | mbise |
| Samsung | `R58N74Y4K8V` | SM-A515F | **Hearing** | hexa |

Both are `arm64-v8a`. A third adb entry, `adb-R58N74Y4K8V-Oup49n._adb-tls-connect._tcp`, is the *same Samsung* over wireless debugging — targeting it as well installs twice to one phone.

---

## 2. Summary of files touched

| File | Change | Revert risk |
|---|---|---|
| `android/app/src/main/kotlin/.../HandLandmarkerHelper.kt` | Rotate capture upright before MediaPipe; `setNumHands(2)` → `1` | **High** — this is the fix for the whole multi-session failure |
| `lib/ui/screens/call_screen.dart` | Landmark painter axis fix; `isDeaf` gate on message vibration | Medium |
| `android/app/build.gradle.kts` | Removed hardcoded `abiFilters`; removed the Flex delegate dependency | Medium — reverting the Flex removal re-adds 68 MB |
| `android/app/src/main/AndroidManifest.xml` | Added `android.permission.VIBRATE` | Low |
| `lib/services/accessibility/vibration_service.dart` | Rewritten: real platform vibration patterns | Low |
| `lib/controllers/accessibility_controller.dart` | `ttsEnabled` derived from role; deaf default silent | **Medium** — see §3.5 on why the default alone was not enough |
| `lib/ui/widgets/incoming_call_overlay.dart` | `isDeaf` gate on call vibration | Low |
| `lib/ui/screens/settings_screen.dart` | TTS switch hidden on a deaf device | Low |
| `pubspec.yaml` / `pubspec.lock` | Added `vibration: ^3.2.1` | Low |
| `diagnostics/verify_no_flex_ops.py` | New — proves the deployed model needs no Flex op | None — read-only |
| `assets/models/gesture_model_dense.tflite` | **Was untracked**; committed in `015acd7` | None — a fresh clone previously could not run inference at all |
| `lib/services/accessibility/torch_service.dart` | **Was untracked**; committed in `015acd7` | None — a fresh clone previously could not compile |

---

## 3. What was wrong, and what changed

### 3.1 The vision failure (`015acd7`) — the root cause

Every sign was returning a confident wrong word (`no@100%`, `yes@100%`), which is why it was chased as a model fault across several sessions. It was not the model.

**The defect:** MediaPipe was handed a **landscape** capture buffer (`src=640x360 rotation=270 bitmap=480x270`) together with `setRotationDegrees(rotation)`, and still returned landmarks a **quarter turn off upright**. Measured from the raw device vectors: the four knuckles came back stacked along **y** (x pinned near −0.43, y running −0.48 → +0.18) with fingers extending along **−x**, whereas every `keypoint.csv` row has knuckles spread along **x** and fingers running up **−y**.

**Why it looked like a model bug:** the deployed model is **chirality-invariant but strongly rotation-sensitive**, measured through the `.tflite` itself over 1500 labelled rows (`diagnostics/check_chirality.py`):

| transform applied to real training hands | accuracy | confidence |
|---|---|---|
| none | **100.0%** | 100.0% |
| mirror x | **100.0%** | 100.0% |
| rotate 90° | 3.5% | 97.4% |
| rotate 180° | 0.0% | 96.7% |
| rotate 270° | 20.4% | 99.5% |

A sideways hand is reported as a *different word*, at **~97% confidence**. Confidently wrong is exactly what was observed.

**The fix** — rotate the pixels, not the landmarks:

```kotlin
val upright = if (rotation == 0) bitmap else rotateUpright(bitmap, rotation)
// then:
.setRotationDegrees(0)
```

plus:

```kotlin
private fun rotateUpright(src: Bitmap, degrees: Int): Bitmap {
    val m = Matrix()
    m.postRotate(degrees.toFloat())
    return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
}
```

**Also in the same commit:** `setNumHands(2)` → **`setNumHands(1)`**. The deployed model consumes a single 42-float hand, so the second hand could only mislead — Dart scores every hand and keeps the most *confident* primary, and a capture exists where the resting hand won at `no@100%`. The 88-float payload is unchanged: it is now effectively 42 + zeros.

**And the overlay:** the painter was still undoing the old landscape frame. Corrected to:

```dart
points.add(Offset((1.0 - lx) * size.width, ly * size.height));
```

The horizontal flip **stays** — the local preview renders with `mirror: true` while MediaPipe measures the unmirrored buffer, so screen x is the mirror of landmark x.

### 3.2 The APK was 137.7 MB (`3f2bb30`)

Two independent causes, both measured.

**(a) A hardcoded ABI list.** `android/app/build.gradle.kts` set `ndk { abiFilters }` to all three ABIs. This is worse than merely being redundant — with it present, Gradle **refuses to configure a split build at all**:

```
Conflicting configuration : 'armeabi-v7a,arm64-v8a,x86_64' in ndk abiFilters
cannot be present when splits abi filters are set
```

The block was removed. Flutter chooses the ABI set itself, so both build modes still work.

**(b) The Flex delegate was dead weight.** `org.tensorflow:tensorflow-lite-select-tf-ops:2.16.1` shipped `libtensorflowlite_flex_jni.so` at **68,177,576 bytes** for arm64-v8a — larger than every other file in the APK combined:

| entry | uncompressed |
|---|---|
| `libtensorflowlite_flex_jni.so` | **68,177,576** |
| `libmediapipe_tasks_vision_jni.so` | 14,340,440 |
| `libjingle_peerconnection_so.so` | 12,069,912 |
| `libflutter.so` | 11,317,712 |

It existed for a GRU model that **is not in the build**: `InferenceManager.initialize()` defaults to `_useTemporalModel = true` and requests `assets/models/gesture_model_gru.tflite`, which does not exist (only `gesture_model_gru_experimental.tflite` does), so the load always throws and always falls back to the dense model.

**Verified by reading the deployed model's own op list**, not by reasoning that a small model "probably doesn't" need Flex — `diagnostics/verify_no_flex_ops.py`:

| model | ops | Flex? |
|---|---|---|
| `gesture_model_dense.tflite` **(deployed)** | `FULLY_CONNECTED`, `SOFTMAX`, `DELEGATE` | **no** |
| `gesture_model_dense_experimental.tflite` | `FULLY_CONNECTED`, `SOFTMAX`, `DELEGATE` | no |
| `gesture_model_gru_experimental.tflite` | + `FlexTensorListReserve`, `FlexTensorListStack`, `WHILE` | **yes** |
| `gesture_model.tflite` | cannot load at all (`FULLY_CONNECTED version 12` too new for TF 2.16.1) | — |

**Result:**

| build | arm64 APK |
|---|---|
| fat, all 3 ABIs (before) | **137.7 MB** |
| `--split-per-abi` only | 56.3 MB |
| split + Flex removed | **34.4 MB** |

### 3.3 ⚠️ The versionCode side-effect — read this before rolling back

`--split-per-abi` does more than split the APK: AGP assigns each split its own `versionCode` as `base × 1000 + abiIndex`, while a plain fat build keeps the raw base.

| artifact | versionCode |
|---|---|
| `app-armeabi-v7a-release.apk` | 1001 |
| `app-arm64-v8a-release.apk` | **2001** ← installed on both phones |
| `app-x86_64-release.apk` | 4001 |
| `app-release.apk` (fat) | 1 |
| `signbridge-v1.2-working-5-signs.apk` (Desktop backup) | **1** |

Android refuses to install a lower `versionCode` over a higher one, so restoring the fat Desktop APK the normal way now fails with `INSTALL_FAILED_VERSION_DOWNGRADE`. It needs:

```bash
adb install -r -d signbridge-v1.2-working-5-signs.apk
```

**Consequence for the next release:** stay on `--split-per-abi` and bump the pubspec build number. Current `version: 1.0.0+1` yields 2001, so the next release needs **`+3` or higher** to outrank what is installed.

### 3.4 Vibration (`d9b34be`)

Both alerts used `HapticFeedback.vibrate()` — the system's ~50 ms UI tick, identical for an incoming call and an arriving message, and the strongest that call can ever be, since `HapticFeedback` exposes no duration or amplitude to raise.

`VibrationService` now drives the platform vibrator via the `vibration` package:

- **Incoming call** — `[0, 700, 250, 700]`, re-issued every 1.8 s until answered
- **Message** — `[0, 120, 100, 120]`, fired once

A timer re-issues the pattern rather than handing `repeat` to the platform, because an indefinite native repeat is what OEM battery managers (Huawei's especially) tend to cut short. Devices without custom-pattern support get a plain vibration of the pattern's total length; a device with no vibrator falls back to the old haptic tick. No path is silent.

Both call sites now gate on `a11y.isDeaf` **as well as** the preference, so a hearing device cannot start buzzing because a toggle was left on from an earlier role.

### 3.5 TTS is silent on the deaf device (`d9b34be`)

TTS is the Deaf → Hearing direction and belongs on the **hearing** device: `TranslationController.handleIncomingPeerJson` speaks the deaf user's sign on the peer's phone. The deaf device repeating its owner's own sign back at them is sound they cannot use.

**The trap:** `AccessibilityController.setRole(deaf)` previously wrote `ttsEnabled: true` into Hive deliberately ("keep TTS voice enabled by default for presentation"). Changing only that default would therefore have left **every already-configured deaf device still talking** — including the two this was written for — because `_load()` reads the persisted value back.

So it is **derived from the role** instead of read straight from the preference:

```dart
bool get ttsEnabled => _ttsEnabled && !isDeaf;
```

No migration, nothing to re-select. The TTS switch is hidden in Settings on a deaf device, since with the getter derived it would read as off and refuse to turn on.

---

## 4. Verification evidence

**Vision:** user confirmed all five words (`hello`, `yes`, `no`, `help`, `thank_you`) recognise correctly, and the landmark overlay points the right way.

**Flex removal — proven, not assumed.** Logcat from the Huawei on the installed build:

```
[InferenceManager] Attempting to load: assets/models/gesture_model_gru.tflite
[InferenceManager] ERROR loading model: Unable to load asset: "assets/models/gesture_model_gru.tflite".
[InferenceManager] GRU load failed (likely missing Flex Delegate). FALLING BACK TO DENSE...
[InferenceManager] Attempting to load: assets/models/gesture_model_dense.tflite
[InferenceManager] Model loaded successfully: assets/models/gesture_model_dense.tflite
[InferenceManager] Interpreter fully initialized
AI Engine Initialized.
tflite : Initialized TensorFlow Lite runtime.
tflite : Created TensorFlow Lite XNNPACK delegate for CPU.
```

Note what is **absent**: `Created TensorFlow Lite delegate for select TF ops`, the line the Python run prints when Flex *is* available. The interpreter builds on the real phone without it. No `FATAL EXCEPTION`, no `UnsatisfiedLinkError`, no `MissingPluginException` (the last confirming the `vibration` plugin registered).

**`flutter analyze`** on every changed Dart file: No issues found.

**Artifact identities:**

| artifact | identity |
|---|---|
| `assets/models/gesture_model_dense.tflite` | 7,472 B, md5 `ac621f9cdd30433fb44253751fabaea8` |
| `build/.../app-arm64-v8a-release.apk` | 36,108,532 B, md5 `f5e196d04958ff04ce59b0f5fbd087ab` |

---

## 5. Rollback procedures

**A. Roll back the app on the phones.**

| rollback APK | versionCode | command |
|---|---|---|
| `backup_apk/v1.2-arm64-withflex-2001.apk` | 2001 | `adb install -r` ✅ simplest |
| `backup_apk/v1.2-arm64-noflex-2001.apk` | 2001 | `adb install -r` |
| `backup_apk/v1.3-arm64-vibration-tts-2001.apk` | 2001 | `adb install -r` (current build) |
| Desktop `signbridge-v1.2-working-5-signs.apk` | 1 | `adb install -r -d` ⚠️ downgrade |

`backup_apk/` is gitignored, so these live only on this machine.

**B. Roll back the source.** Each commit is self-contained:

```bash
git revert d9b34be   # vibration + TTS only
git revert 3f2bb30   # APK slimming only
git revert 015acd7   # vision fix (re-breaks all five words — diagnose first)
```

Reverting `3f2bb30` restores the hardcoded `abiFilters` **and** the 68 MB Flex library. Reverting `015acd7` restores the failure where every sign returns a confident wrong word.

**C. Do not `git checkout` these files blindly** — they carry this session's work mixed with earlier work.

---

## 6. Known limitations / deliberately not done

**The GRU load failure message is misleading.** It reads *"GRU load failed (likely missing Flex Delegate)"* but the real cause is `Unable to load asset` — the file `gesture_model_gru.tflite` does not exist. If a GRU is ever added back, that message will send you chasing the wrong problem. Not corrected in this session; out of scope.

**`both` role gets no vibration.** The gate is `isDeaf`, so a device set to the **Both** role will not vibrate even though its stored `vibrationEnabled` is `true`. Neither phone uses that role. One-word change if wanted.

**`assets/models/` ships everything.** `pubspec.yaml` lists the whole directory, so `gesture_model.tflite` (69 KB), `gesture_model_dense.tflite.bak`, `gesture_model_dense_experimental.tflite` and `gesture_model_gru_experimental.tflite` are all bundled (~350 KB). `gesture_model.tflite` cannot even load on this runtime. Trivial size, but these are exactly the files `.gitignore` warns are traps.

**No `.bak` is a backup of the deployed model.** `gesture_model_dense.tflite.bak` is the 64 KB model under a misleading name.

**Signing is still the debug keystore.** `android/app/build.gradle.kts` uses `signingConfig = signingConfigs.getByName("debug")`, and there is no `key.properties` or `.jks` anywhere. Fine for development and for a demo; **not** acceptable for a public release, and it means the app cannot be published to Play in this state.

---

## 7. Follow-ups (in priority order)

1. **App launcher icon** — still the default Flutter icon (1.4 KB, dated April). `flutter_launcher_icons` is not installed and **no source logo artwork exists in the repo**. This is the gating dependency.
2. **Loading animation (Master Plan Step 15)** — needs the same logo asset.
3. **Release** — after the icon. Bump the build number to `+3` or higher, keep `--split-per-abi`, and decide on a real signing key.
4. **Delete the two TEMP DIAGNOSTIC blocks before any release build** — the `[DIAG]` 42-float dump in `inference_manager.dart` and the `geometry` `Log.i` in `HandLandmarkerHelper.kt`. Both are marked `TEMP DIAGNOSTIC (remove before release)`.
5. Add more/easier sign words (Master Plan Step 17 mechanism).
6. Consider `strip`ping the unused model assets from the bundle.

---

## 8. APPENDIX — Corrections to earlier docs

Two claims in `2026-09-29_TURN_MobileData_Connectivity_Fix.md` §10 are now superseded:

- **§10.1** concluded the app "silently falls back to the legacy 5-class single-hand model" and that `gesture_model_dense.tflite` was "byte-identical to `archive/gesture_model_old.tflite`" (md5 `0893c68c…`). That is **no longer true**. The deployed model is 7,472 B, md5 `ac621f9c…`, and is a mirror-augmented 5-class model with label order `['hello','yes','no','help','thank_you']`. The archived `0893c68c` model now sits in `assets/models/archive/`.
- **§10.2** reasoned that the intermittency came from wrist-centring being applied to a model that expected raw coordinates. The actual root cause of the failure was the **rotated capture frame** (§3.1). The centring is correct for the deployed model.

The **conclusion in §10.1 that the GRU never loads is still correct** — and is exactly why the Flex delegate could be removed.
