# SignBridge — Complete Walkthrough

**Written:** 2026-10-02
**Covers:** 2026-04-30 (first commit) → 2026-10-02 (HEAD `666e7a5`)
**Author:** Claude Code, at the request of Kelvin Mbise
**Purpose:** one document that says what SignBridge is, everything that has been
built and when, what actually works today, and what the realistic path is to
making it a real product. Written to be read by you in six months, by another
AI tool, or by your supervisor.

> **Read this first if you read nothing else:** §3 is what actually works today,
> and §3.4 lists the things that *look* finished but are not. Two of them
> (GIFs, notifications) matter a great deal for what you want to do next.

---

## 1. What SignBridge is

A Flutter app that lets a **deaf** and a **hearing** person hold a video call
without an interpreter in the room. Two directions:

| direction | what happens |
|---|---|
| **Deaf → Hearing** | the deaf user signs at the camera; on-device hand tracking + a TFLite model turn the sign into a word; the phone **speaks** it aloud (TTS) and shows it as a caption |
| **Hearing → Deaf** | the hearing user talks; **speech-to-text** (STT) turns it into a caption, and a **GIF** of the sign is shown so the deaf user sees it in their own language |

Roles are selectable — `deaf`, `hearing`, `both` — and the whole UI reconfigures
around the choice (`lib/core/utils/accessibility.dart`): a deaf device turns TTS
*off* and vibration/captions/flash *on*; a hearing device does the reverse.

Everything runs **on the device**. No cloud AI, no per-minute cost. That is a
deliberate design decision: it works on a slow connection, it costs nothing to
run, and the video never leaves the two phones except as peer-to-peer WebRTC.

**Target context:** Tanzania. The UI is bilingual English/Kiswahili, the app has
Tanzanian Sign Language learning links, and the whole thing is built to run on
cheap Android hardware — the two test phones are a Huawei JNY-LX1 (Kirin 710)
and a Samsung A51 (Exynos 9611), both 2019-era mid-range.

---

## 2. Everything built so far, in order

41 commits, 2026-04-30 → 2026-10-02. Grouped into six eras. Dates are commit
dates; the tag column is the release marker if one was cut.

### Era 1 — Foundation (30 Apr – 1 May 2026)

| date | commit | what |
|---|---|---|
| 2026-04-30 | `8311db6` | **SignBridge v1.0.0** — first working setup, "up to level 3". 150 files, 6,954 lines: a stock Flutter scaffold plus the first real app structure. |
| 2026-05-01 | `6442018` | **v2.0.0** — anonymous login, Firebase database wired in, first call-screen bug fixed. |
| 2026-05-01 | `e0320b9`, `bc901c2` | README for the v2.0.0 stack. |

**At the end of Era 1:** an app that could sign a user in anonymously and place
a call. No AI, no bilingual support, no role model.

### Era 2 — Role architecture and the UI overhaul (19 May 2026) — tag `v0.2.0-phase2-mediapipe` later

| date | commit | what |
|---|---|---|
| 2026-05-19 | `5fae6ad`, `4f95746` | **"Massive v2.9.9 UI/UX overhaul and role-based architecture."** Two commits, the largest single change in the project. Introduced the Deaf/Hearing/Both role model, the accessibility engine, the design language (neumorphic containers, glass cards, the `AppColors` palette in `lib/core/theme.dart`) that everything since has been built on. |

**At the end of Era 2:** the app had its identity — roles, palette, accessibility
settings. This is the era that most of the current UI still comes from.

### Era 3 — Bilingual, contacts, and a working call (8–10 Jun 2026) — tag `v1.0-pre-ai-model`

| date | commit | what |
|---|---|---|
| 2026-06-08 | `2eb36b8` | Bilingual support (EN/SW) + **saved contacts** directory with contact-support options. |
| 2026-06-08 | `2753ae4` | Caller's own ID used as the room ID; speech-service deprecations resolved. |
| 2026-06-08 | `68263ef`, `f89b88c`, `c6211eb` | Docs: Phase 13 testing guide, deferred-AI clarification, **`Project_Master_Plan.md`**. |
| 2026-06-10 | `3c41e2a` | Signalling, vibration overlay, bilingual support, saved contacts, **AI Simulator Panel**, end-to-end WebRTC handshake fixes. |
| 2026-06-10 | `d70803f` | Docs reorganized into `docs/`. |

**At the end of Era 3:** two phones could hold a real WebRTC call, in two
languages, with contacts and incoming-call alerts. **The AI was still not real
yet** — the tag name `v1.0-pre-ai-model` says so plainly.

### Era 4 — The AI pipeline (22 Jun – 5 Jul 2026) — tags `v1.1-first-ai-model`, then `v0.2.0-phase2-mediapipe`

| date | commit | what |
|---|---|---|
| 2026-06-22 | `434750c` | Onboarding profile setup, call-ended dialog, and the **Python ML pipeline** — the first landmark recorder and trainer. |
| 2026-06-29 | `8e5e5cf` | **First gesture-recognition model trained.** Tag `v1.1-first-ai-model`. |
| 2026-06-30 | `a920c0d` | Quick-sign toolbar, accessibility controls, TTS toggle. |
| 2026-06-30 | `6fb0dfb` | Replaced the visible toolbar with **invisible preview tap gestures** — a demo-driven change so the UI looks clean in front of an audience. |
| 2026-06-30 | `9f28554` | Presence self-healing; auto-reset to idle when a call ends. |
| 2026-06-30 | `61ef011` | Second-device call lock, Google-login profile-setup skip, missing translation assets, TTS defaults, **visual screen-flash alerts**. |
| 2026-06-30 | `776a9f3` | A **rule-based TSL finger-state classifier** (before the model was trusted), animated landmark morphing. |
| 2026-06-30 | `72cfcef` | `hasProfile` adjusted to stop sending returning users back to profile setup. |
| 2026-06-30 | `801921d` | Removed premature WebRTC failure handling; silenced idle "coordinate gesture" false positives. |
| 2026-06-30 | `e576bfd` | **TFLite model connected to the live pipeline**; caption bilingual mapping fixed; vocabulary **trimmed to 5 words**. |
| 2026-06-30 | `88184d6` | Full translation pipeline fires on tap; **STT auto-restart** for demo stability. |
| 2026-07-05 | `1a40c11` | **Native MediaPipe pipeline** — camera frames intercepted on the native Android layer, 21 landmarks streamed to Dart over an `EventChannel`. Tag `v0.2.0-phase2-mediapipe`. |
| 2026-07-05 | `960bcf9` | Fixed `HandLandmarksPainter` axis orientation for portrait. |
| 2026-07-05 | `df6063e` | Stabilizer latency and frame-skip tuning. |

**At the end of Era 4:** real, live, on-device sign recognition working end to
end. The vocabulary was deliberately cut to 5 words (`hello`, `yes`, `no`,
`help`, `thank_you`) because those were the ones that actually worked.

### Era 5 — The bigger model attempt (15–18 Jul 2026)

| date | commit | what |
|---|---|---|
| 2026-07-15 | `9850f16` | Academic report blueprint + prompt file. |
| 2026-07-18 | `247615e` | **84-feature dual-hand TFLite model, 47 classes.** |

**This is the most misunderstood commit in the project.** It built a 47-word,
two-handed, 84-feature model — and it **is not the model that runs**. See §3.4.

Then there is a **2.5-month gap** (19 Jul → 2 Oct). Nothing was committed. That
is the university break and, from the phone timestamps, a period when the app
sat on the two devices being used rather than developed.

### Era 6 — The October repair and polish session (2 Oct 2026)

This is the session most of the recent documentation covers. It began as "the
app is broken, every sign gives a wrong word" and ended with the app shipped,
branded and slimmed.

| date | commit | what |
|---|---|---|
| 2026-10-02 | `015acd7` | **The root cause of every sign failing: the capture frame was quarter-turned.** The camera frame was rotated 90° before MediaPipe saw it, so every hand was presented sideways and the model confidently returned the *wrong word*. Fixed by rotating the bitmap upright in `HandLandmarkerHelper.kt` and setting `setRotationDegrees(0)`. Also reduced to one hand. |
| 2026-10-02 | `3f2bb30` | Split per ABI; **removed the unused Flex delegate** (a 68 MB native library for a model that is not in the build). APK **137.7 MB → 34.4 MB**. |
| 2026-10-02 | `d9b34be` | Real vibration patterns (not the 50 ms system tick), and **TTS silenced on the deaf device**. |
| 2026-10-02 | `7c23d28` | Documentation of the above. |
| 2026-10-02 | `9b3efed` | **Launcher icon generated from the app's own sign glyph** — a hand on a blue→emerald gradient, drawn programmatically. |
| 2026-10-02 | `aab44cc` | Icon + branded splash wired into the build, all densities, adaptive icon for Android 8+. App label `sign_bridge` → **`SignBridge`**. |
| 2026-10-02 | `8b2859d`, `ba18604` | Docs; duplicate-icon issue found and resolved. |
| 2026-10-02 | `1b4bc6a` | **Signed-in users no longer see the login form** (`BootGate`); in-app brand mark unified with the icon. |
| 2026-10-02 | `666e7a5` | Docs, including the arm64-only finding. |

Tag: **`v1.2-working-5-signs`**.

---

## 3. Where it stands today — verified, not assumed

### 3.1 What genuinely works

- **All five signs** — `hello`, `yes`, `no`, `help`, `thank_you` — recognise
  correctly on both physical phones. Verified by hand, not inferred.
- **Two-way calling** over WebRTC, signalled through Firestore, peer-to-peer
  media, with a data channel carrying the translations.
- **G→S direction:** sign → word → **spoken aloud** on the hearing phone + caption.
- **S→G direction:** speech → **caption** on the deaf phone (+ a GIF slot — see §3.4).
- **Roles** fully wired and gating real behaviour.
- **Bilingual UI** — **149 English keys, 149 Swahili keys, complete 1:1.**
- **Calling flow:** ring → accept/reject → connect → end, with presence
  self-healing and stale-state recovery on relaunch.
- **Saved contacts**, **translation history** (Hive, offline), **learning
  resources**.
- **Accessibility:** vibration patterns, torch flash, captions, font scaling.
- **Branding:** launcher icon, adaptive icon, light/dark splash, correct name.

### 3.2 The numbers

| | |
|---|---|
| APK (arm64-v8a, what both phones run) | **34.7 MB** (from 137.7 MB) |
| versionCode | **2001** |
| Deployed model | `assets/models/gesture_model_dense.tflite`, 7,472 B, md5 `ac621f9c…` |
| Vocabulary | **5 words** |
| Input features | **42** (one hand × 21 landmarks × x,y) |
| Labels file | `assets/labels/gesture_labels.txt` — **47 words** (see §3.4) |
| Firebase plan | **Spark (free)** — no Cloud Functions, no Blaze |
| Signing | **debug keystore** — fine for sideloading, not for Play |
| Device floor | **64-bit ARM, Android 8.0+** |

### 3.3 The two test devices

| device | serial | user | role |
|---|---|---|---|
| Huawei JNY-LX1 (Kirin 710) | `EPHUT20820010780` | **mbise** / `mbis333` | **Deaf** |
| Samsung SM-A515F (Exynos 9611) | `R58N74Y4K8V` | **hexa** / `h3xa` | **Hearing** |

The Huawei matters more than it looks: it has **no Google Mobile Services**. Any
future feature that assumes Play Services — including Firebase Cloud Messaging —
will not work on the single most important device in the project. See §5.3.

### 3.4 What *looks* finished but is not

This is the most valuable section in this document. Each of these reads as a
completed feature in the README or in old docs, and each is actually a stub.

**1. The GIF feature does not work at all.**
`assets/gifs/` holds five files — `hello.gif`, `help.gif`, `no.gif`,
`thank_you.gif`, `yes.gif` — and **every one is 42 bytes and byte-identical**
(md5 `d89746888da2d9510b64a9f031eaecd5`). They are 1×1 transparent GIF89a
placeholders. They contain no animation and no image. Worse, the widget named
`gif_overlay.dart` **does not display GIFs** — it renders an emoji in a `Text`
widget — and it is **never instantiated anywhere**; `call_screen.dart` uses
`TranslationOverlay` instead. So: the deaf user never sees a sign GIF. What they
see is an **emoji** (👋👍✋🆘🙏). The only place a GIF path is even reached is the
history replay dialog, which loads one of those five empty files.

**2. There are no notifications of any kind.**
No `firebase_messaging`, no `flutter_local_notifications`, no notification
channel, no `POST_NOTIFICATIONS` permission, no receiver. Incoming calls are
handled by an **in-app overlay** that only appears if the app is already open
and foregrounded. If the app is closed, **the call never arrives.**

**3. There is no home-screen widget.**
No `AppWidgetProvider`, no `res/xml/` directory, no `<receiver>` in the
manifest.

**4. There is no user profile screen.**
Only the one-time `ProfileSetupScreen`. After that, `settings_screen.dart` shows
a **read-only** section with a `CircleAvatar` containing the first letter of the
name. **No avatar upload, no editing.** (`firebase_storage` is already a
dependency and unused for this.)

**5. The 47-word model is not running, and the label file is misleading.**
`assets/labels/gesture_labels.txt` lists **47 words** and the app logs
`Labels loaded: 47` at startup — but the deployed model has **5 outputs**. The
code handles this correctly (`inference_manager.dart:347`:
`numClasses == 5 ? _smallModelLabels : _labels`), so recognition is right. The
47-word `gesture_model.tflite` (69,504 B) sits in `assets/models/` and **is
never loaded by any code path.** Anyone reading the logs would reasonably
conclude 47 words are supported. They are not.

**6. The temporal (GRU) model never loads — by accident.**
`InferenceManager.initialize()` defaults to `_useTemporalModel = true` and asks
for `assets/models/gesture_model_gru.tflite`, which **does not exist** (only
`gesture_model_gru_experimental.tflite` does). So every launch throws, prints
*"GRU load failed (likely missing Flex Delegate)"*, and falls back to the dense
model. **The error message is wrong** — there is no Flex problem; the file is
simply missing. Slightly lucky: this is the only reason the working 5-word model
is the one that runs.

**7. Several widgets are dead code.**
`GifOverlay` and `CaptionOverlay` are both defined and both never instantiated.
`TranslationOverlay` is what actually renders.

**8. Three APKs are built; two cannot launch.**
MediaPipe ships arm64-v8a **only**. The `armeabi-v7a` and `x86_64` APKs crash
before drawing a frame (`UnsatisfiedLinkError`). **Ship arm64 only.** Also: an
Android emulator cannot run this app, which invalidates the demo script in
`docs/presentation_brief.md` (§8.2).

**9. The README is badly out of date.**
It opens `# SignBridge App (v0.2.0-phase2-mediapipe)` and says the model is
`gesture_model.tflite` supporting **6 signs including `goodbye` and
`I_love_you`**. Reality: tag `v1.2-working-5-signs`, model
`gesture_model_dense.tflite`, **5 signs**, and neither `goodbye` nor `I_love_you`
is in any label set.

---

## 4. The hard-won lessons

Each of these cost real time to find. They are rules now.

1. **The capture frame must be rotated upright *before* MediaPipe sees it.**
   A 90°-rotated hand is reported as a *different word at ~97% confidence* — it
   never looks like an error. This was the single most expensive bug in the
   project.
2. **One hand, not two.** `setNumHands(1)`. With two, the resting hand
   occasionally won (`no` at 100%) while the signing hand was ignored.
3. **`--split-per-abi` multiplies the versionCode** (`base×1000 + abiIndex`), so
   a plain APK can't install over a split one, and the next release needs `+3`.
4. **Never add `ndk { abiFilters }`** — Gradle then refuses to configure a split
   build at all.
5. **Vibration is deliberate.** `VibrationService` gives patterns and amplitude;
   `HapticFeedback.vibrate()` is a weak 50 ms tick. Don't "simplify" it back.
6. **`ttsEnabled` is derived:** `_ttsEnabled && !isDeaf`. A deaf device must
   stay silent. Do not make it a plain stored preference.
7. **Verify with the real artefact, not by inference.** The rotated frame and the
   68 MB Flex library were both only nailed by measuring the thing itself.
8. **Firebase stays on Spark.** No feature may require Blaze.
9. **Never uninstall the app from either phone**, and back the APK up before
   replacing it. `backup_apk/` holds the rollback chain.

---

## 5. Next: the polish tier

### 5.1 Particle loading animation

**What you asked for:** animated particles on the loading screen.

**Where it goes.** `BootGate` already has a loading state — the blue/emerald
full-screen moment between the native splash and the first real screen — and the
call-connecting state needs one too. Both should use one reusable widget.

**How to build it.** A `CustomPainter` with an `AnimationController`, not a
package. Concretely:

- **30–40 particles maximum.** Both phones are 2019 mid-range; 200 particles at
  60 fps will drop frames, and the first thing a marker notices is stutter.
- **One `AnimationController`, `repeat()`ed, disposed in `dispose()`.** The
  single most common bug in this kind of widget is a forever-repeating
  controller that is never disposed, which keeps the widget — and its ticker —
  alive after navigation.
- **Wrap the painter in `RepaintBoundary`** so particle repaints don't dirty the
  rest of the tree.
- **No `MaskFilter.blur` or `saveLayer` per particle.** Both are expensive on
  Mali/Adreno GPUs of this vintage. Fake the glow with a radial gradient.
- **Respect `MediaQuery.disableAnimations`.** Not optional here: this is an
  accessibility app aimed at a deaf user, and someone running the phone with
  animations off is a realistic case. When it's set, render a static frame.
- Keep it on the **UI isolate**. Don't reach for an isolate or a `Timer.periodic`
  per particle.

**Effort:** half a day. **Risk:** low. It touches no recognition code.

**Suggested shape:** particles drifting upward from the brand glyph, tinted
`AppColors.primary` → `AppColors.secondary`, with a gentle opacity pulse — so it
reads as the same blue→emerald identity as the icon, splash and in-app mark.

### 5.2 User profile

**Today:** a one-time setup screen, then a read-only row in Settings. No view, no
edit, no avatar.

**What "done" looks like:**

- A real **Profile screen**, reachable from Settings and from the home avatar.
- **Editable**: display name, SignBridge ID, role, language.
- **Avatar**: `firebase_storage` is already a dependency; add `image_picker`,
  upload to `users/{uid}/avatar.jpg`, cache the URL in Hive so the dashboard
  doesn't flash a placeholder on every launch. Fall back to the initial-letter
  circle that exists today.
- **Careful with the SignBridge ID.** It is the call-routing key — other people
  dial it. Editing it silently breaks saved contacts on other phones. Either
  make it immutable after setup, or update contacts on change and warn the user.
  This is the kind of thing that looks trivial and causes a demo failure.

**Effort:** 1–2 days. **Risk:** medium — the ID-rename trap above.

### 5.3 Notifications — read this before choosing a technology

**Today:** nothing. If the app is closed, an incoming call is **missed
entirely**.

**The trap:** the obvious answer is Firebase Cloud Messaging. **FCM does not work
on the Huawei.** That phone has no Google Play Services, and it is your deaf
user's device — the one that most needs to know a call is coming. Choosing FCM
would mean the deaf side of the demo silently doesn't ring.

**What to do instead, in order:**

1. **`flutter_local_notifications` + a foreground service.** The app already
   listens to Firestore for incoming calls (`CallManager.startListening()`).
   Keep that listener alive with an Android **foreground service** (a persistent
   notification plus a wakelock) and post a **full-screen intent notification**
   when a call arrives. Works on Huawei, Samsung, everywhere. No Google, no
   server, no cost. This is the right answer for the project as it stands.
2. **Battery-optimisation caveat.** Huawei and Samsung both aggressively kill
   background apps. You must ask the user for the battery-optimisation
   exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) and explain why, or the
   service will be killed within minutes. Test with the screen off, for ten
   minutes, on the Huawei specifically.
3. **FCM only as a later addition** for Play-Store Android devices, if you ever
   ship there — never as the primary path.

**Effort:** 2–3 days, most of it fighting OEM battery management. **Risk:** high
— background execution on Huawei is genuinely hostile, and this is the feature
most likely to work in testing and fail in the demo.

### 5.4 Home-screen widget

**Today:** none.

**Use the `home_widget` package** rather than hand-writing Kotlin. It handles the
`AppWidgetProvider`, the `RemoteViews` bridge and the data handoff.

**What is worth putting on a widget:**
- **Your SignBridge ID**, large — so someone can read it out to a hearing
  colleague without opening the app. This is the single most useful thing, and
  it's the one your users will actually use.
- **A call button** and **recent contacts** for one-tap dialling.
- **Status** — available / busy.

**The constraint to know:** an App Widget is rendered by the **Android
launcher**, not by Flutter. `RemoteViews` supports a very limited set of views
and cannot host Flutter. So the widget is a **native layout** populated from
shared preferences via `home_widget`. You will be writing Android XML for it.

**Effort:** 1–2 days for the ID widget; more for anything interactive.
**Priority: lower than notifications.** A widget is a nice-to-have; a missed call
is a broken product.

---

## 6. Next: becoming a real app

### 6.1 More vocabulary — the honest picture

**Where it is:** **5 words.** `hello`, `yes`, `no`, `help`, `thank_you`.

**Why so few:** not architecture. The pipeline works. The dataset is one
recording per word, and the model has memorised those recordings. Your own
WLASL analysis put it plainly: *"One recording per word = severe overfitting —
the model memorizes pixel coordinates, not sign shape."* Weak classes in the
47-word experiment were exactly the ones with the fewest samples (`woman` 0.29
with 3 samples, `walk` 0.33 with 4, `safe` 0.50 with 3).

**The pipeline already exists:**

```
python_scripts/record_landmarks.py   →  captures webcam landmarks
                                     →  keypoint.csv
python_scripts/train_model.py        →  Keras MLP → gesture_classifier.tflite
                                     →  copy to assets/models/gesture_model_dense.tflite
                                     →  update _smallModelLabels in inference_manager.dart:102
                                     →  add a GIF for the word
```

Three edits per new word, and it's a data problem, not a code problem.

**Concrete plan:**

1. **Pick the next 5–10 words for maximum conversational value**, not novelty.
   Words that combine into sentences beat isolated nouns. Candidate additions:
   `please`, `sorry`, `stop`, `water`, `eat`, `name`, `friend`, `come`, `go`,
   `more`. Ten words that combine is a far better demo than thirty that don't.
2. **30–50 recordings per word**, minimum — the current 5 words work because
   they have the most data. Vary: distance from camera, hand position in frame,
   lighting, signer speed.
3. **Recruit a second signer** if you possibly can. A model that only works for
   the person who recorded it is not a product, and a supervisor will ask exactly
   this question.
4. **Validate per-class accuracy ≥ 90% before deploying.** Report the confusion
   matrix — it is the most convincing single artefact you can put in a report.
5. **Watch APK size.** It is not a problem at this scale (the model is 7 KB),
   but the Flex-delegate mistake is a reminder to check.

**Effort:** the recording is the bottleneck — a long afternoon per 10 words, plus
a re-train. **Risk:** low technically, but accuracy will fall as vocabulary
grows. Ten words at 90% is a better outcome than thirty at 60%.

**For the report:** *"recognises N signs at X% per-class accuracy across M
signers"* is a real result. The current honest number is 5 signs, one signer,
85–90%.

### 6.2 Two-handed signs

**Today:** deliberately one hand. `setNumHands(2)` was a *fix*, not a
limitation — with two hands enabled, the resting hand sometimes won
(`no` at 100%) while the actual signing hand was ignored.

**The good news: the Dart code already handles both.** `predict()` in
`inference_manager.dart` branches on input size — 42 features (one hand) or 84
(two hands, 21 landmarks × 2 dims × 2 hands, zero-padded when only one hand is
present). The native side already sends 88 floats (84 + 4 metadata). **So
two-handed support is a model problem, not a code problem.**

**What to do:**

1. Retrain on **84-feature** input with genuine two-handed signs in the set —
   signs that are *defined* by both hands, not one-hand signs recorded twice.
2. Switch the recorder to `max_num_hands=2`.
3. Flip `setNumHands(2)` — and **only** then. With the current model it must
   stay at 1.
4. Re-test that the resting-hand problem doesn't return. Mitigations if it does:
   prefer the hand with the higher MediaPipe confidence *and* the larger
   bounding box, and require both hands to be stable across the stabilizer
   window before accepting a two-handed sign.

**Effort:** 2–4 days including recording. **Risk:** medium — the resting-hand
regression is real and was observed once already.

**Scope honesty:** most Tanzanian Sign Language everyday vocabulary is
one-handed. Two-handed support is worth doing, but it is not the thing that
makes the app useful — more *words* is.

### 6.3 Wrist rotation — the real research gap

Two different problems are hiding under the word "wrist", and it matters which
one you mean.

**Wrist centring — already done.** Each hand is translated so the wrist
(landmark 0) is the origin, mirrored for the left hand, then scaled to
max|value| = 1. That gives **translation and scale invariance**. Good.

**Wrist rotation — not handled, and it is the model's biggest fragility.** The
deployed model is **rotation-sensitive**: turn a hand 90° and it reports a
*different word at ~97% confidence*. There is no rotation normalisation at all.

**Why this is the most interesting item on your list:** it is a genuine,
defensible research contribution, and it maps directly onto a real-world
failure. A deaf user signing while lying down, or holding the phone at an angle,
gets confident nonsense — the worst possible failure mode, because the app
doesn't say "I'm not sure", it says the wrong word confidently.

**Two ways to fix it, in order of value:**

1. **Rotation augmentation in training (cheap, effective).** Rotate every
   training sample through, say, −30°…+30° in 10° steps, and add those as extra
   samples. The model learns that a rotated `hello` is still `hello`. Roughly ten
   lines in the training script, and it multiplies your dataset by 7× for free.
   Start here.
2. **Normalise rotation in the feature vector (principled, more work).** Compute
   the wrist→middle-finger-MCP vector and rotate all landmarks so that vector
   points "up" before feeding the model. Then rotation is removed by
   construction and the model never sees it. This is the more elegant answer and
   is worth a section in a dissertation — but it removes *deliberate* orientation
   information too, which some signs genuinely use, so it needs care.

**Effort:** augmentation is a day; normalisation is 3–4 days plus re-recording.
**Risk:** low for augmentation, medium for normalisation.

**Suggested framing for the report:** *"we identified orientation sensitivity as
the dominant failure mode of coordinate-based gesture classifiers on mobile, and
evaluated rotation augmentation against explicit rotation normalisation."* That
is a real contribution and it comes straight out of a bug you actually hit.

### 6.4 Real GIFs instead of emoji

**Today:** see §3.4 — the five "GIFs" are 42-byte empty placeholders, the widget
that would show them is never instantiated, and the deaf user actually sees an
**emoji**.

**This is the biggest gap between what the app claims and what it does.** The
hearing→deaf direction is supposed to show the sign as a GIF. It shows 👍.

**The work has two halves:**

**A. The code path (half a day).** Instantiate the GIF widget from
`call_screen.dart` in place of the emoji for `shouldShowGifPanel` roles, load
`assets/gifs/{word}.gif`, and keep the emoji as the fallback in `errorBuilder`
so a missing GIF degrades instead of breaking. Do this **after** real GIFs exist,
or you will ship a working player for empty files.

**B. The assets (the real work).** You need a genuine, licence-cleared GIF or
short video loop per word. Options:

- **Record them yourself** with a fluent signer, and convert to GIF. Best for
  accuracy and for the report — it is your data, and you can say so.
- **Use an open sign-language resource**, but **check the licence** and check
  that the sign is the right one for your region.

**Two warnings, both serious:**

1. **A wrong GIF is worse than no GIF.** If the deaf user sees the wrong sign,
   the app is actively misleading them — a much worse failure than the current
   emoji, which is at least honestly useless. Every GIF must be checked by a
   deaf signer before it ships.
2. **GIF is a poor format for this.** Sign language is 3D, and GIF is 256 colours
   and no audio, no pause, no scrub. Consider a silent looping **MP4** via
   `video_player` instead — similar cost, much better quality, and the user can
   pause it. Also note that you may need a **written consent/credit** for whoever
   appears in the recordings.

**Effort:** code is half a day; assets are days, and depend on a signer.
**Risk:** high on accuracy/ethics, low on technology.

### 6.5 Swahili — better than you'd think, with one real gap

**Good news: the UI is complete.** `lib/core/translations.dart` holds **149
English keys and 149 Swahili keys, matched 1:1.** Language switching is wired
through Settings, profile setup and onboarding, persisted in Hive, and applied
everywhere via `a11y.t('key')`.

**The gaps, in order of importance:**

1. **Swahili STT/TTS depends on the device, not on your code.** The locale is
   switched correctly (`sw_TZ` for STT, `sw-TZ` for TTS in
   `translation_controller.dart:135-139`), but if the phone has no Swahili
   speech pack installed, recognition silently falls back or fails.
   `speech_service.dart` already logs available locales — **check this on both
   phones before the demo.** On the Huawei especially, Swahili TTS may simply
   not exist. Have a fallback to English, and know about it in advance rather
   than discovering it live.
2. **Some Swahili is hardcoded outside the translation map** —
   `caption_overlay.dart` (`Habari`, `Ndiyo`, `Hapana`, `Msaada`, `Asante`) and
   `call_screen.dart` quick phrases. Move them into `translations.dart` or they
   will drift.
3. **The signs themselves are not Swahili — and cannot be, yet.** The 5 words are
   English glosses, and the app says so honestly: *"Signs are gesture-based, not
   language-specific."* Real **Tanzanian Sign Language** recognition would need a
   TSL dataset, and **none exists** — not in this repo, and not publicly in any
   form you could train on. Today TSL appears only as a **PDF link** to
   Maktaba.org in the learning resources.

**The honest position for your report:** the app localises its *interface,
speech and captions* into Kiswahili; the *gesture vocabulary* is language-neutral
and derived from ASL glosses. Claiming TSL recognition would be overclaiming, and
a supervisor who knows the field will spot it. Framing it as "a TSL dataset is
the key missing piece, and building one is the obvious next research project"
turns a weakness into a stated contribution.

**Effort:** items 1–2 are half a day. Item 3 is a research project.

### 6.6 STT — working, but the least reliable link

**Today:** `speech_to_text: ^7.0.0`, dictation mode with partial results, 30 s
listen window, 5 s pause, and **auto-restart** (added in `88184d6` specifically
so a demo doesn't stall).

**Known constraints — be aware of these before demoing:**

- **It uses the platform recogniser** (Google's, on Samsung). Accuracy for
  Swahili is materially worse than English, and on the Huawei without GMS the
  behaviour may differ or be unavailable.
- **It is a separate process.** The call is intentionally **video-only** — no
  audio track is requested — precisely so the microphone is free for the
  recogniser. Do not "fix" the missing audio track without understanding this.
- **Latency is the weak point** in the hearing→deaf direction. It is the
  platform's, not yours.

**What is worth doing:**

1. **Show partial results as they arrive** (already enabled) and label the
   caption as still-in-progress — it makes the perceived latency far shorter.
2. **Add a confidence gate.** Below a threshold, don't show a GIF at all rather
   than showing a confidently wrong one. Same principle as §6.4.
3. **Consider an offline recogniser** (Vosk has small Swahili/English models).
   That removes the GMS dependency and the network — a genuinely strong
   improvement for a Tanzanian context with patchy data, and a good report
   section. It is also a substantial piece of work.

**Effort:** items 1–2 are a day. Item 3 is weeks.

---

## 7. Suggested order

Ordered by *(value ÷ risk)*, not by how interesting the work is.

| # | item | effort | value | risk | why here |
|---|---|---|---|---|---|
| 1 | **Particle loading animation** | ½ day | Medium | Low | Finishes the branding you started; touches nothing critical. Already half-designed. |
| 2 | **Strip the TEMP DIAGNOSTIC blocks** | 1 hr | Low | Low | Four sites, already marked. Real cost per frame on a Kirin 710 during a live demo. |
| 3 | **Notifications (local, not FCM)** | 2–3 days | **High** | High | A missed call is a broken product. Do it early so there's time to fight the Huawei. |
| 4 | **More vocabulary (5 → 10–15)** | 2–4 days | **High** | Medium | The single biggest step from "demo" to "app". Data-bound, so start recording early. |
| 5 | **Real GIFs (or MP4)** | 2–5 days | **High** | High | Closes the biggest claim-vs-reality gap. Needs a signer, so start that conversation now. |
| 6 | **User profile screen** | 1–2 days | Medium | Medium | Expected of any real app; careful with the ID rename. |
| 7 | **Rotation augmentation** | 1 day | **High** | Low | Cheap, and it kills the worst failure mode (confident wrong answers). |
| 8 | **Swahili STT/TTS verification** | ½ day | Medium | Low | Just check both phones have the speech packs. Cheap insurance before a demo. |
| 9 | **Two-handed signs** | 2–4 days | Medium | Medium | Valuable but not what makes the app useful. Most everyday TSL is one-handed. |
| 10 | **Home-screen widget** | 1–2 days | Low–Med | Low | Genuinely nice. Do it after the things that make the app *work*. |
| 11 | **Release: signing, keystore, CHANGELOG** | ½ day | — | Medium | Needed before Play, and before a marker inspects the build. |
| 12 | **Neon glow polish** | 1 day | Low | Low | Cosmetic. Only if everything above is done. |

**If you only do three things:** notifications (#3), vocabulary (#4), and real
GIFs (#5). Those three are the difference between a demo and something a deaf
person could actually use daily.

**Start the data collection today even if you build other things first.** The
recording is the long pole — it needs a signer, a quiet room and an afternoon,
and it can't be compressed by better code.

---

## 8. For the supervisor and the report

### 8.1 What the contribution actually is

Not MediaPipe — that's a Google library you're a consumer of. **The contribution
is the classification layer and the accessibility architecture around it:** a
lightweight, fully on-device, bidirectional pipeline that runs at usable speed on
2019 mid-range hardware at zero marginal cost, with the whole UI reconfiguring
around Deaf/Hearing roles.

### 8.2 ⚠️ Your demo script is broken as written

`docs/presentation_brief.md` scripts the live demo with the **Huawei as the deaf
caller and an Android emulator as the hearing receiver**. **The emulator cannot
run this app** — MediaPipe ships no x86_64 native library, so it crashes with
`UnsatisfiedLinkError` before drawing a frame (§3.4, item 8).

**Use the two physical phones instead.** They are already set up and both work:
Huawei = mbise/Deaf, Samsung = hexa/Hearing. This is in the brief's own
"Known Limitations" spirit — it just needs updating.

### 8.3 Other stale claims to fix before presenting

| where | says | reality |
|---|---|---|
| `README.md` | v0.2.0-phase2-mediapipe | `v1.2-working-5-signs`, versionCode 2001 |
| `README.md`, `presentation_brief.md`, `roadmap_and_tasks.md` | **6 signs**, incl. `goodbye` / `I_love_you` | **5 signs**; neither word is in any label set |
| `presentation_brief.md` | 30+ signs in the next phase | More realistic: **10–15**, at ≥90% per-class |
| `presentation_brief.md` | emulator in the demo | **impossible** — use two phones |
| old docs | `gesture_model.tflite`, 6 classes | deployed is `gesture_model_dense.tflite`, 5 classes |
| `Phase8`/`Phase9` guides | image CNN, 224×224×3 | the pipeline is landmark-based MLP on 42 floats |

### 8.4 Numbers you can defend

- **34.7 MB** APK (from 137.7 MB) — a 75% reduction, with evidence.
- **All on-device:** no cloud inference, no per-minute cost, works offline for
  recognition.
- **5 signs at ~85–90%** per sign, single signer, on two mid-range 2019 phones.
- **149/149** bilingual UI key coverage.
- **Under 200 ms** sign→speech, per the brief's measurement.
- **Zero recurring cost** on Firebase Spark.

### 8.5 Charts worth making

1. **Confusion matrix** for the current 5 words — proves you understand your own
   failure modes.
2. **Accuracy vs. samples per word** — the direct evidence for the data-not-
   architecture argument, and your justification for the recording plan.
3. **APK size before/after** the Flex removal — 137.7 → 34.4 → 34.7 MB.
4. **Rotation sensitivity:** accuracy at 0°, 30°, 45°, 90° — the chart that
   motivates §6.3 and is genuinely novel.

---

## 9. Appendix

### 9.1 Where things live

```
lib/
  core/            theme, routes, enums, translations.dart (EN+SW, 149 keys)
  controllers/     accessibility, theme, translation, call
  services/
    ai/            inference_manager, speech_service (STT), tts_service,
                   prediction_stabilizer
    auth/          auth_service (Firebase Auth + Firestore profile)
    webrtc/        webrtc_service, signaling_service, call_manager
    accessibility/ vibration_service, torch_service
  ui/
    screens/       onboarding, login, profile_setup, home, call,
                   history, contacts, settings        (9 screens)
    widgets/       brand_mark, boot_gate, translation_overlay,
                   gif_overlay*, caption_overlay*, incoming_call_overlay, ...
  data/local/      hive_db (app_settings, translation_history,
                   recent_calls, saved_contacts)

android/app/src/main/kotlin/com/example/sign_bridge/
  HandLandmarkerHelper.kt   ← the upright-rotation fix lives here
  MainActivity.kt

python_scripts/    record_landmarks.py, train_model.py, keypoint.csv
assets/            models/, labels/, gifs/*, branding/
backup_apk/        the rollback chain (gitignored)
mchongo/           this file + the session walkthroughs + the plan
```

`*` = defined but never instantiated (§3.4).

### 9.2 Toolchain paths on this machine

`adb` is **not** on the Git Bash PATH.

```
adb     C:\Users\FutureTech\AppData\Local\Android\Sdk\platform-tools\adb.exe
aapt2   C:\Users\FutureTech\AppData\Local\Android\Sdk\build-tools\37.0.0\aapt2.exe
python  C:\Users\FutureTech\sign_bridge\python_scripts\venv\Scripts\python.exe
```

`python` on its own is a Windows Store alias and will not work.

### 9.3 Reading order for the existing docs

| file | what it is | trust |
|---|---|---|
| **this file** | everything, April → October | current |
| `NEXT_MOVES_PLAN.md` | the live plan and handoff brief | current |
| `2026-10-02_Auth_Gate_and_Brand_Mark.md` | the most recent session | current |
| `2026-10-02_Vision_Fix_APK_Slimming_Accessibility.md` | the rotation fix, APK slimming | current |
| `2026-09-29_TURN_MobileData_Connectivity_Fix.md` | the connectivity session | current |
| `PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md` | operational memory | mostly current |
| `WLASL_TRAINING_PROJECT_ANALYSIS.md` | dataset/training analysis | current, and the key doc for §6.1 |
| `Project_Master_Plan.md` | the 14–17 master plan | **stale** |
| `Phase7`/`Phase8`/`Phase9` guides | 224×224 image CNN approach | **obsolete** — never the path taken |
| `SignBridge_Current_Status_May2026.md` | status snapshot | **stale** |
| `docs/presentation_brief.md` | demo script, Q&A | **stale + demo broken** (§8.2) |
| `README.md` | public face | **stale** (§3.4 item 9) |

### 9.4 Standing rules

1. Never uninstall the app from either phone.
2. Never overwrite the working build without copying the current APK into
   `backup_apk/` first.
3. Always test on **both** phones — a change that fixes the deaf side can break
   the hearing side.
4. `adb-R58N74Y4K8V-Oup49n._adb-tls-connect._tcp` is the **same Samsung** over
   wireless debugging. Never target it alongside the USB serial.
5. Firebase stays on **Spark**. Nothing that needs Blaze.
6. Ship **arm64 only**. The other two APKs cannot launch.
7. Verify with the real artefact, not by inference.

---

*Written 2026-10-02 against HEAD `666e7a5`. If you are reading this much later,
check §3.4 first — the gap between what the app claims and what it does is where
the surprises live.*
