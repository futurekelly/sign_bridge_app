# SignBridge — Next Moves Plan

**Date:** 2026-10-02
**Agent:** Claude Code
**Status:** Living document — update the checkpoint table in §2 after every completed step.
**Companion file:** `mchongo/2026-10-02_Vision_Fix_APK_Slimming_Accessibility.md` (what the last session changed, and how to undo it).

> **Purpose of this file:** one place that answers "what is the next move, what exactly is in scope, and how do we know it worked." §5 is written so it can be pasted into Antigravity or Gemini as a self-contained brief.

---

## 1. Where we are right now (verified)

| | |
|---|---|
| **Working state** | All five signs — `hello`, `yes`, `no`, `help`, `thank_you` — recognise correctly on both physical phones |
| **APK size** | **34.4 MB** per phone (arm64-v8a), down from 137.7 MB |
| **Installed build** | versionCode **2001**, debug-signed, arm64-v8a |
| **Branch** | `main`, clean except the untracked doc in `mchongo/` |
| **Remote** | `https://github.com/futurekelly/sign_bridge_app.git` |
| **Last tag** | `v1.2-working-5-signs` |
| **Model** | `assets/models/gesture_model_dense.tflite` — 7,472 B, md5 `ac621f9c…` |
| **Backups** | `backup_apk/` (3 rollback APKs, gitignored) + Desktop `signbridge-v1.2-working-5-signs.apk` |

The app is **demo-ready today**. Everything below is polish for the supervisor demo and the final submission, not repair.

---

## 2. Checkpoint table — tick as we go

| # | Step | Blocked by | Done |
|---|---|---|---|
| 0 | Documentation (this file + the walkthrough) | — | ☐ |
| 1 | **Logo artwork** — decide the source image | user decision | ☐ |
| 2 | App launcher icon (all densities + adaptive) | step 1 | ☐ |
| 3 | Splash / launch screen | step 1 | ☐ |
| 4 | Branded loading animation (Master Plan Step 15) | step 1 | ☐ |
| 5 | Strip the TEMP DIAGNOSTIC blocks | — | ☐ |
| 6 | Neon glow UI polish (Master Plan Step 16) — *optional* | — | ☐ |
| 7 | Release build + GitHub Release | steps 2–5 | ☐ |
| 8 | AI Simulator Panel (Master Plan Step 14) — *optional* | — | ☐ |

---

## 3. The one real blocker: there is no logo

This is worth stating plainly, because it gates three separate items.

`android/app/src/main/res/mipmap-*/ic_launcher.png` are still the **stock Flutter icons** — 442 B to 1,443 B, dated **27 April**, unchanged since `flutter create`. And a survey of the whole repo finds **no candidate logo**:

- `assets/` contains only `gifs/`, `labels/`, `models/` — no images at all
- The only 1024×1024 PNGs are the stock Flutter iOS and macOS icons
- `emulator_app.png`, `emulator_screen.png`, `screenshot.png` are emulator captures, not artwork
- `flutter_launcher_icons` and `flutter_native_splash` are **not** in `pubspec.yaml`

**So step 1 is a decision only you can make.** Three ways forward:

| Option | What it means | Effort |
|---|---|---|
| **A. You supply artwork** | You drop a **1024×1024 PNG** (no transparency needed for the Android adaptive foreground, but it must have a clear subject with margin) into the repo. Best outcome — it is your project, and a supervisor will recognise a considered mark. | minutes of your time |
| **B. I generate a mark** | The venv has Pillow (matplotlib depends on it). I can draw a flat vector-style mark programmatically — e.g. a stylised hand and bridge-span glyph on a gradient, in the app's `AppColors.primary` palette — and export 1024×1024 plus every density. Fast, consistent, free, and easy to iterate on. It will look clean and deliberate rather than hand-designed. | ~1 exchange |
| **C. Combination** | I generate option B as a placeholder now so steps 2–4 are unblocked, and you swap the real artwork in later — `flutter_launcher_icons` makes the swap a one-command re-run. | best of both |

**C is my recommendation.** It gets the icon, splash and loading animation done this session instead of stalling on artwork, and nothing is wasted when real artwork arrives.

---

## 4. The steps, with scope and acceptance criteria

### Step 2 — App launcher icon

**Scope:** add `flutter_launcher_icons`, generate all Android densities. Include the **adaptive icon** (Android 8+): a separate background layer plus a foreground layer with a 33% safe margin, so the mark is not clipped by the circular/squircle mask. Also set `android:roundIcon`.

**Acceptance:** `flutter clean && flutter build apk --split-per-abi --release`; install; the icon appears correctly in the launcher, in the app switcher, and **not clipped** under a round mask. APK stays under 40 MB.

**Watch out:** `mipmap-anydpi-v26/ic_launcher.xml` does not exist yet — it has to be created for the adaptive icon. If it is missing, Android silently falls back to the legacy square PNG and the icon looks dated on Android 8+.

### Step 3 — Splash / launch screen

**Scope:** `flutter_native_splash`. The current `LaunchTheme` in `styles.xml` is stock Flutter.

**Acceptance:** cold start shows the brand background and logo, no white flash, no visible jump between the native splash and the first Flutter frame.

**Watch out:** the splash background must match `NormalTheme`'s background, or there is a visible flicker at hand-off. Both light and dark.

### Step 4 — Branded loading animation (Master Plan Step 15)

**Scope:** a reusable `BrandedLoader` widget used by the AI-init and call-connecting states. Suggest a subtle scale/opacity pulse rather than a spinner. Must respect `MediaQuery.disableAnimations` (accessibility — and this app has a deaf user, so someone running the device with animations off is a realistic case).

**Acceptance:** no jank on either phone (Kirin 710, Exynos 9611 — neither is fast); `flutter analyze` clean; the widget is disposed correctly with no leaked `AnimationController`.

**Watch out:** an `AnimationController` that repeats forever and is not disposed will keep the widget alive after navigation. This is the most common bug in this step.

### Step 5 — Strip the TEMP DIAGNOSTIC blocks

**Scope:** four marked sites, all tagged `TEMP DIAGNOSTIC (remove before release)`:

| file | line |
|---|---|
| `lib/services/ai/inference_manager.dart` | 146 |
| `lib/services/ai/inference_manager.dart` | 398 |
| `lib/services/ai/inference_manager.dart` | 628 |
| `android/app/src/main/kotlin/com/example/sign_bridge/HandLandmarkerHelper.kt` | 169 |

**Acceptance:** no `[DIAG]` output in logcat during a full sign; recognition still works; `flutter analyze` clean.

**Watch out:** `_lastRaw` at line 628 is referenced by the dump at 398. Removing one without the other breaks the build — remove them together, and check whether `_lastRaw` has any other reader before deleting the field itself.

**Do this before the release build, not after.** Debug printing per frame is real cost on a 2019 mid-range phone during a live demo.

### Step 6 — Neon glow polish (optional)

Master Plan Step 16. Cosmetic. Only worth doing if steps 2–5 are done and the demo still needs visual weight.

### Step 7 — Release

**Scope:** version bump, both APKs, GitHub Release with assets and notes.

**Acceptance — the release checklist:**

- [ ] pubspec `version:` set to **`1.0.0+3` or higher**. This is not cosmetic: `+1` produces versionCode **2001**, exactly what is already installed, and Android will refuse to update over it. `+2` → 2002 also works; `+3` is safer if any intermediate build was ever installed.
- [ ] Both TEMP DIAGNOSTIC blocks removed
- [ ] `flutter build apk --split-per-abi --release` — **stay on split-per-abi**
- [ ] `flutter analyze` clean
- [ ] Sign-test on **both** phones, all five signs, plus one call, plus vibration, plus that the deaf device stays silent
- [ ] Copy the arm64 APK into `backup_apk/` **before** uploading anything
- [ ] `git tag` the release commit and push the tag
- [ ] Release notes state the Android version floor (`minSdk 26` = Android 8.0)

**Two things to decide at this step:**

1. **Signing.** The app is currently signed with the **debug keystore** (`signingConfig = signingConfigs.getByName("debug")`; no `key.properties`, no `.jks` anywhere). Fine for sideloading and for the demo. **Not** acceptable for Play, and a debug-signed release is a red flag if a marker inspects it. Creating a real keystore is a five-minute job — but it means anyone with the old build must **uninstall before installing** the newly-signed one, because signatures cannot be mixed. Given the standing rule about not uninstalling from either phone, do this **only** on a third device or at the very end. My recommendation: **keep debug signing for the demo, note it in the report, and switch at hand-in.**
2. **Where the release notes live.** Suggest a `CHANGELOG.md` at the repo root, which is also good evidence of process for the report.

### Step 8 — AI Simulator Panel (optional)

Master Plan Step 14. A debug-only panel that injects synthetic landmark payloads so the UI can be tested without a hand in front of the camera. Genuinely useful for a demo if the supervisor asks "what if the model is wrong?" — but it is a testing aid, not a feature. Lower priority than a shipped icon.

---

## 5. Handoff brief — paste into Antigravity or Gemini

> Copy the block below verbatim. It is written to be self-contained: it assumes no knowledge of this project's history.

```text
PROJECT: SignBridge — Flutter app, two-way sign-language recognition and speech
translation, aimed at deaf and hearing users in Tanzania. Repository root is a
Flutter project on branch `main`.

GOAL FOR THIS TASK: <pick one step from mchongo/NEXT_MOVES_PLAN.md §4 and paste it here>

CONTEXT YOU MUST NOT BREAK — these are hard-won and were expensive to find:

1. The camera capture frame is rotated upright in
   android/app/src/main/kotlin/com/example/sign_bridge/HandLandmarkerHelper.kt
   BEFORE MediaPipe sees it (`rotateUpright(bitmap, rotation)` and then
   `.setRotationDegrees(0)`). MediaPipe must also be given `.setNumHands(1)`.
   The deployed model is rotation-sensitive: a hand turned 90 degrees is
   reported as a DIFFERENT WORD at ~97% confidence. Do not "simplify" this
   rotation, and do not raise numHands back to 2.

2. The gesture model is assets/models/gesture_model_dense.tflite.
   It is 7,472 bytes, md5 ac621f9cdd30433fb44253751fabaea8, and its label order
   is exactly ["hello","yes","no","help","thank_you"]. Do not replace, retrain,
   re-quantise or re-export this file. Other .tflite files in that folder are
   experiments and are not loaded at runtime.

3. Do NOT re-add the dependency
   `org.tensorflow:tensorflow-lite-select-tf-ops`. It ships a 68 MB native
   library for a GRU model that is not in the build. Removing it took the APK
   from 137.7 MB to 34.4 MB. The deployed model contains no Flex ops — this was
   verified by reading its own op list, and then confirmed on a physical phone.

4. Do NOT add an `ndk { abiFilters }` block to android/app/build.gradle.kts.
   Gradle refuses to configure a --split-per-abi build when one is present.

5. Android release builds use --split-per-abi. This makes the versionCode
   base*1000 + abiIndex (arm64-v8a => 2001), NOT the pubspec build number.
   A plain fat APK cannot be installed over a split one without `adb install -r -d`.

6. `AccessibilityController.ttsEnabled` is deliberately DERIVED:
   `bool get ttsEnabled => _ttsEnabled && !isDeaf;`
   TTS is the Deaf -> Hearing direction. A deaf device must stay silent.
   The stored Hive preference is intentionally ignored for the deaf role.

7. Vibration goes through lib/services/accessibility/vibration_service.dart and
   is gated on `a11y.isDeaf && a11y.vibrationEnabled`. Do not replace it with
   HapticFeedback.vibrate() — that is the weak 50ms system tick it replaced.

CONVENTIONS TO FOLLOW:
- Match surrounding code style; the project uses Provider for state.
- Run `flutter analyze` and make sure it is clean before saying you are done.
- Do not commit or push. Leave changes in the working tree for review.
- Write no documentation files; report what you changed in your reply instead.

VERIFY BEFORE YOU CLAIM DONE:
- `flutter analyze` clean.
- If you changed anything under android/, run:
  `flutter build apk --split-per-abi --release`
  and report the actual final line of Gradle output, not a summary.
  Note: piping to `tail` hides a Gradle failure, because tail's exit code
  becomes the pipeline's. Write the log to a file and check the exit code.
```

**Extra note for the receiving AI:** if given a task that is *not* in §4, ask it to confirm the task does not conflict with the seven rules above before starting.

---

## 6. Standing rules

1. **Never uninstall the app from either phone.** Both hold a working build and the user's data.
2. **Never overwrite the working build** without copying the current APK into `backup_apk/` first.
3. **The two phones:**
   - Huawei `EPHUT20820010780` (JNY-LX1) — role **Deaf**, user mbise
   - Samsung `R58N74Y4K8V` (SM-A515F) — role **Hearing**, user hexa
   - `adb-R58N74Y4K8V-Oup49n._adb-tls-connect._tcp` is the **same Samsung** over wireless debugging. Never target it alongside the USB serial — it installs twice to one phone.
4. **Always test on both phones.** A change that fixes the deaf side can break the hearing side; the TTS split is exactly that shape.
5. **The toolchain paths on this machine** (`adb` is not on the Git Bash PATH):
   - adb: `C:\Users\FutureTech\AppData\Local\Android\Sdk\platform-tools\adb.exe`
   - aapt2: `...\Android\Sdk\build-tools\37.0.0\aapt2.exe`
   - Python (TF 2.16.1): `C:\Users\FutureTech\sign_bridge\python_scripts\venv\Scripts\python.exe`
   - `python` alone is a Windows Store alias and will not work.
6. **Firebase is on the Spark (free) plan.** Do not introduce anything that needs Blaze.
7. **Verify with the real artifact, not by inference.** The two most expensive bugs in this project (the rotated frame, the Flex delegate) were both nailed only by measuring the thing itself.

---

## 7. My recommendation for the next move

**Do steps 0 → 1 → 2 → 3 → 4 in this session, picking option C in §3 if you have no artwork ready.**

Rationale: the icon, splash and loading animation are all blocked on one asset and nothing else — they are the only remaining items that a supervisor will *see* immediately, they are low-risk, and they touch nothing in the recognition pipeline. Bundle them into one commit (`feat(ui): app icon, splash screen and branded loader`) and one APK, so there is a single review point and a single rollback.

Then step 5 (diagnostics) immediately before the release build, since that is the last code change and it should not invalidate device testing.

Steps 6 and 8 are genuinely optional. Step 7 is the finish line.

**What I need from you to start step 1:** say **"use option A"** and drop a 1024×1024 PNG in the repo, or say **"use option C"** and I will generate the mark and carry straight through steps 2–4 in one pass.
