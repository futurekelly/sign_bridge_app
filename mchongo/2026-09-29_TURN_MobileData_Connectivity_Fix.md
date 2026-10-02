# SignBridge — TURN / Mobile Data Connectivity Fix Session

**Date:** 2026-09-29
**Agent:** Claude Code
**Trigger:** Video calls only succeeded on Wi-Fi. On mobile data (4G/5G) the call stayed stuck on "Waiting for peer..." indefinitely.
**Status:** Fix applied and the new TURN credential is **cryptographically verified working** (see §5). Physical device-to-device cellular test **still pending**.

> **Purpose of this file:** track exactly what this session changed, on which files, and how to undo it — in case the fix is delayed, regresses, or needs to be backed out to test something else. Read §4 before you revert anything; a `git checkout` here will destroy unrelated earlier work.

---

## 1. Summary of what this session touched

| File | Change | Revert risk |
|---|---|---|
| `lib/services/webrtc/webrtc_service.dart` | TURN credential replacement, runtime config builder, remote-SDP munge removal, ICE diagnostics | Medium — **also contains your earlier uncommitted work** |
| `lib/controllers/call_controller.dart` | Failed-state now surfaces an error instead of silently logging | Medium — **also contains your earlier uncommitted work** |
| `mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md` | §2 corrected with a "Correction (Sep 2026)" subsection | Low — doc only |
| *(deleted, not in repo)* `%TEMP%\turn_check.js` | Throwaway TURN Allocate test script | None — held live credentials, so it was deleted |

---

## 2. Root cause (proven, not inferred)

The May 2026 "mobile data fix" was **structurally correct but functionally inert**. It configured TURN properly but used OpenRelay's retired public demo credentials:

```dart
'username': 'openrelayproject',
'credential': 'openrelayproject',
```

Metered.ca ended unauthenticated public TURN access, so those static credentials are rejected at the **auth layer**. Nothing in the code looked wrong — which is exactly why this went unnoticed for months. The defect was entirely in a third-party service.

**Why it manifested as "Wi-Fi only":**

- **On Wi-Fi:** both phones share a LAN, so `host` + `srflx` (STUN) candidates connect the call directly. No relay required → worked.
- **On cellular:** Carrier-Grade NAT makes every direct path unreachable, so a **relay candidate is mandatory**. Every TURN allocation was refused → zero relay candidates → ICE had nothing usable → infinite "Waiting for peer...".

**Ruled out during diagnosis:** the TURN host was reachable (`openrelay.metered.ca` → `188.245.177.56`, TCP 443 **and** 3478 both succeeded). So this was never DNS, firewall, or network reachability — it was authentication.

---

## 3. Exact changes, with the original values (for targeted revert)

Line numbers below are accurate as of 2026-09-29 and will drift as the file evolves. **Anchor on the code snippets, not the numbers.**

### 3.1 `lib/services/webrtc/webrtc_service.dart`

#### Change A — header comment block
Added a `// ── Fix (Sep 2026) ──` section (near line 24) documenting the inert-credential bug. Comment only, no behaviour.

Revert: delete that comment block. Harmless to leave.

#### Change B — the ICE/TURN configuration (the actual fix)
Now at approximately **lines 120–152**: `_turnUsername`, `_turnCredential`, `_forceRelayForDiagnostics`, and `_buildPeerConfig()`.

**ORIGINAL (replace the current block with this to revert):**

```dart
  // ── ICE server configuration ──────────────────────────────────────────
  //
  // STUN (Google free)         — works on same-Wi-Fi & home routers.
  // TURN (OpenRelay/Metered.ca) — MANDATORY for mobile data / CGNAT networks.
  //   Includes TURNS (TLS/443) which bypasses cellular carrier firewalls.
  // ──────────────────────────────────────────────────────────────────────
  static const Map<String, dynamic> _peerConfig = {
    'sdpSemantics': 'unified-plan',
    'iceGatheringPolicy': 'all',
    'bundlePolicy': 'max-compat',
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ],
      },
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:80?transport=udp',
          'turn:openrelay.metered.ca:80?transport=tcp',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp',
          'turns:openrelay.metered.ca:443',
          'turns:openrelay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };
```

⚠️ Reverting this restores the **dead credentials**, i.e. re-breaks mobile data. Only do it to isolate a different variable.

**Current values (the working ones, for reference):**

```dart
  static const String _turnUsername = '086b7e28c17087d402dbe4b9';
  static const String _turnCredential = 'dWBhJP9k29jVIj7P';
```

Host is **`standard.relay.metered.ca`** — note this is *not* `openrelay.metered.ca`, and not the `global.` host either. Replace all four TURN URLs as a set if you rotate credentials.

#### Change C — call site (line ~197)
```dart
// now
_peerConnection = await createPeerConnection(_buildPeerConfig(), _sdpConstraints);
// original
_peerConnection = await createPeerConnection(_peerConfig, _sdpConstraints);
```

#### Change D — `handleRemoteAnswer()` (line ~293)
Removed the `_optimizeSdp()` call that was being applied to the **peer's answer**. Munging a *remote* description can contradict what the other side actually negotiated (payload ordering / bitrate), causing a codec mismatch. Local SDP only now.

**ORIGINAL (to revert):**
```dart
  Future<void> handleRemoteAnswer(RTCSessionDescription answer) async {
    final optimizedSdp = _optimizeSdp(answer.sdp ?? '');
    final optimizedAnswer = RTCSessionDescription(optimizedSdp, answer.type);
    await _peerConnection!.setRemoteDescription(optimizedAnswer);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }
```

#### Change E — ICE candidate diagnostics
Added the `_candidateTypes` list, `localCandidateTypes` / `hasRelayCandidate` getters, and `_candidateType()` helper (lines ~70–82). `onIceCandidate` (line ~215) now records and logs each candidate's type.

This is **observability only** — it changes no negotiation behaviour. Safe to keep even if you revert B–D.

#### Change F — `_forceRelayForDiagnostics` (line ~127)
Defaults to **`false`**. Leave it false. See §6.

### 3.2 `lib/controllers/call_controller.dart`

#### Change G — `RTCPeerConnectionStateFailed` (line ~244)
**ORIGINAL (to revert):**
```dart
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            debugPrint('[CallController] WebRTC connection failed (waiting for auto-recovery)');
            break;
```

**Current:** captures `webrtc.hasRelayCandidate`, logs the gathered candidate types, and calls `_fail(...)` with a message that names the missing-relay case when no relay candidate exists.

Rationale: the old code logged *"waiting for auto-recovery"* and did nothing. A failed negotiation therefore looked identical to a slow one, which is precisely why the original bug presented as a permanent hang with no error. Reverting this restores the silent infinite wait.

### 3.3 `mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md`

- §2 table row **ICE Transport Protocol** (line 26) — annotated to point at the correction below.
- New **§2 "Correction (Sep 2026)"** subsection (line 31) — records what was believed, what was actually wrong, the evidence, the fix, the credential caveat, and the outstanding ICE-restart gap.
- **"Verifying the relay path"** subsection (line 143) under the logcat section.

Doc-only. Revert by deleting those additions.

---

## 4. ⚠️ Revert warning — do NOT blanket-`git checkout` these files

**Read this before reverting.**

`webrtc_service.dart` and `call_controller.dart` already had **uncommitted modifications from your own debugging session yesterday**, before this session started. Measured against `HEAD`:

```
lib/controllers/call_controller.dart           |  48 ++++--
lib/services/webrtc/webrtc_service.dart        | 196 ++++++++++++++++++++-----
```

Those totals include *both* your earlier work and this session's changes — they are commingled in the working tree.

**Consequence:** `git checkout -- lib/services/webrtc/webrtc_service.dart lib/controllers/call_controller.dart` would discard **your earlier debugging work as well**, silently and unrecoverably.

**Do this instead, before anything else — snapshot the current state so any revert is always possible:**

```bash
git stash push -m "pre-TURN-fix snapshot 2026-09-29" -- lib/services/webrtc/webrtc_service.dart lib/controllers/call_controller.dart
git stash apply          # keep working copy as-is, but now there's a recoverable snapshot
```

Or, lower-risk and non-mutating — just make a branch and commit the current state:

```bash
git checkout -b turn-fix-2026-09-29
git add lib/services/webrtc/webrtc_service.dart lib/controllers/call_controller.dart mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md
git commit -m "fix(webrtc): replace dead OpenRelay TURN credentials with Metered"
```

The branch+commit route is the safest: nothing is lost, the fix is reviewable, and `git checkout main` returns you to the exact prior state instantly.

---

## 5. Verification evidence

The credential was tested directly against the live TURN server — a real RFC 5766 Allocate, not a guess:

```
Phase 1: challenged with 401 (expected 401) — realm="metered.ca"
Phase 2: ALLOCATE SUCCEEDED — relay reserved at 165.66.66.220:28782
RESULT: credentials are VALID. The TURN path works.
```

This proves: the realm/nonce handshake works, long-term credential auth succeeds, and a relay was actually reserved. Combined with `openrelay.metered.ca` being reachable by TCP, it conclusively separates "auth failure" from "network failure".

Also verified: `flutter analyze` on both changed Dart files → **No issues found**.

---

## 6. How to verify on device (next step)

**Decision taken 2026-09-29:** connection first, model work after. So this section is the gate —
do not start on the AI pipeline until Stage 2 passes.

### Stage 1 — prove the relay works inside the app (Wi-Fi, relay-forced)

This isolates TURN from any cellular weirdness. It forces *all* traffic through the relay, so a
successful call here proves the credential + URL set + app wiring are all correct.

```bash
flutter build apk --debug --dart-define=FORCE_RELAY=true
```

Install on **both** phones, keep both on **Wi-Fi**, place a call.

- **Pass:** the call connects and you see `type=relay` in the log.
- **Fail:** the call fails *even on Wi-Fi*. That points squarely at TURN — credentials, URL set, or
  the 20 GB quota — not at the cellular network.

Note `--dart-define` is read at build time only. There is nothing to edit and nothing to remember to
change back: a normal build without the flag gets `false`. (This replaced an earlier
`_forceRelayForDiagnostics = true` source-edit approach, which risked being left on by accident.)

### Stage 2 — the real scenario (Wi-Fi ↔ mobile data)

```bash
flutter build apk --debug          # normal build, no flag
```

Install on both, put **one on Wi-Fi and one on mobile data**, place a call.

```bash
adb logcat -s WebRTC:V Signaling:V CallController:V CallManager:V
```

**Success looks like:** `[WebRTC] local ICE candidate → type=relay`

**Important:** on Wi-Fi you'll see `host` / `srflx` only — that is normal and does **not** prove TURN
works, because the LAN gives a direct path. You need `type=relay` **while on cellular**.

**If it still fails,** the new code tells you why:
```
[CallController] WebRTC connection FAILED. Local candidate types gathered: [...]
```
and the UI now shows a real error naming the missing-relay case — no more silent hang.

Until Stage 2 passes on two real devices, treat this fix as **unconfirmed in production
conditions**, despite the credential being proven valid at the protocol level (§5).

---

## 7. Rollback procedures

**A. Targeted revert (recommended).** Use the ORIGINAL snippets in §3 to restore individual changes. Note that reverting Change B alone re-breaks mobile data by restoring dead credentials.

**B. Full revert to pre-session state.** Only if you committed the snapshot in §4:

```bash
git checkout main                  # if you worked on the branch
# or, to undo just this session's commit:
git revert <commit-sha>
```

**C. If you did NOT snapshot first:** revert manually using §3. Do not use `git checkout` — it will take your earlier work with it.

---

## 8. Known limitations / deliberately not done

**ICE restart is NOT implemented.** It was scoped and then correctly abandoned mid-session, because it is not a WebRTC-only change:

- `SignalingService.joinCall()` applies the offer **exactly once** — when it waits for an offer, its temporary listener calls `tempSub?.cancel()` after the first one, and there is no other handler for a re-offer.
- So a restarted offer from the caller would **never reach the callee**, and the call would hang *harder* rather than recover.

Proper ICE restart needs renegotiation support in the signaling layer first (a persistent offer listener that can apply a second offer and route the second answer back). Noted as outstanding in the walkthrough doc.

**Consequence:** mid-call network handover (Wi-Fi ↔ cellular) is still not survivable. A call that starts on one network must stay on it.

**Credential exposure:** the Metered credentials are static and ship inside the APK, so anyone who extracts a release build can read them. Acceptable for development. Production should fetch short-lived backend-minted credentials at connect time — note the Firebase-native way (Cloud Functions) is **unavailable on the Spark plan**, so it needs a non-Firebase endpoint (e.g. a free Cloudflare Worker) or self-hosted coturn.

**Rotation:** Metered dashboard → TURN Server → **Remove** → **Add Credential**. Then update `_turnUsername` / `_turnCredential` and all four TURN URLs in `_buildPeerConfig()`. Allow up to **2 minutes** for propagation; a brand-new credential is rejected until it propagates.

**Quota:** free tier is 20 GB/month, resetting on the 29th. Over-quota behaviour is a hard stop, **not** a billable overage — confirmed on the dashboard (`$0` overage). At the 800 kbps cap this is roughly 25–50 hours of relayed video.

---

## 9. Follow-ups (in priority order)

1. **Run Stage 1 then Stage 2 of §6** — the one thing that actually closes this out.
2. Clean up candidate subcollections on call end. `SignalingService.endCall()` sets `status: 'ended'` but never deletes `callerCandidates` / `calleeCandidates`, so they accumulate forever against Spark's 1 GiB. Each candidate is also one write + one snapshot read against the daily quota.
3. If reaching production: move to dynamic short-lived TURN credentials.
4. ICE restart, once signaling renegotiation exists.

---

## 10. APPENDIX — Separate finding: the AI pipeline is not running the trained model

**Discovered 2026-09-29 while investigating the connection issue. NOT FIXED in this session — no AI
code was touched.** Recorded here so the finding is not lost. Investigate after §6 passes.

### 10.1 The app loads the legacy 5-class model, not the 47-class one

The load chain in `lib/services/ai/inference_manager.dart`:

1. `initialize()` defaults to `useDenseBackup: false` → `_useTemporalModel = true` → attempts
   `assets/models/gesture_model_gru.tflite` (**line 144**).
2. **That file does not exist.** The artefact on disk is
   `gesture_model_gru_experimental.tflite`. The `_experimental` suffix broke the reference.
3. The load throws, is caught (line 152), and falls back to `initialize(useDenseBackup: true)`.
4. That loads `assets/models/gesture_model_dense.tflite` (**line 145**) — which is **byte-identical to
   the archived legacy model**:

```
0893c68c34482ad74024c6496387e397 *gesture_model_dense.tflite
0893c68c34482ad74024c6496387e397 *archive/gesture_model_old.tflite
```

`predict()` even has a dedicated branch for it: `if (numClasses == 5)` → hardcoded
`['hello','help','no','thank_you','yes']` (line 233-238) — matching the 5 GIFs in `assets/gifs/`.

**Conclusion: every launch silently falls back to the legacy 5-class single-hand model.** All
47-class training artefacts are on disk and never loaded:

| App file | Size | Training source | Loaded? |
|---|---|---|---|
| `gesture_model.tflite` | 69,504 | `signbridge_model.tflite` (dense 47-class, 86.00% test) | No |
| `gesture_model_dense_experimental.tflite` | 64,232 | `signbridge_model_optimized.tflite` (Aug 4) | No |
| `gesture_model_gru_experimental.tflite` | 150,944 | `signbridge_model_gru_final.tflite` | No |
| `gesture_model_dense.tflite` | 7,944 | **`archive/gesture_model_old.tflite`** (5-class) | **Yes** |

Training project is at `C:\Users\FutureTech\Desktop\WLASL-master`. Its
`output/dense_vs_gru_comparison.txt` reports the GRU at **91.81% test accuracy / F1 0.9258** vs dense
86.00% — so the best model is the one that never loads. `tensorflow-lite-select-tf-ops:2.16.1` is
already present in `android/app/build.gradle.kts`, so the Flex delegate the GRU needs is available.

### 10.2 Cause of "sometimes it predicts correctly, sometimes not" — RESOLVED by inspection

`processRawLandmarks()` (line 111) **unconditionally wrist-centers** by subtracting each hand's wrist
x/y. The function carries two *contradictory* comments about whether that is right:

- Docstring, line 99–103: *"Both deployed .tflite models were trained on
  `dataset/landmarks_normalized.csv`, where landmark_extractor.py subtracts hand.landmark[0].x/.y
  from every point."* → centering is **correct**.
- Inline, line 120–123: *"The archived model (gesture_model_old.tflite) was trained on standard
  MediaPipe [X, Y] coordinates."* → centering is **wrong**.

**Both are true, and that is the whole bug.** Verified against the training project:

```
builder/landmark_extractor.py:9    OUTPUT = ROOT / "dataset" / "landmarks_normalized.csv"
builder/landmark_extractor.py:58   wrist = hand.landmark[0]
builder/landmark_extractor.py:59   wX, wY = wrist.x, wrist.y

builder/train_model.py:14           CSV_PATH = ... "landmarks_normalized.csv"   ← dense 47-class
builder/train_model_temporal.py:13  CSV_PATH = ... "landmarks_normalized.csv"   ← GRU
```

So **both the 47-class dense model and the GRU were trained on wrist-centred data**, and centering is
the correct preprocessing for them. Only the *legacy* 5-class model expects raw coordinates.

Since the app currently runs the legacy model (§10.1) while centering its input, the legacy model is
being fed shifted coordinates. Accuracy therefore becomes **position-dependent**: a hand centred in
frame classifies, a hand off-centre does not. That matches the reported symptom far better than
random noise would.

**Important consequence:** fixing the model wiring in §10.1 is very likely to *also* fix the
intermittency — because the 47-class models were trained on exactly the preprocessing the app already
applies. This makes §10.1 a higher-value single fix than it first appeared: one change to the model
reference may resolve both the "wrong model" and the "sometimes wrong" symptoms.

**Caveat:** this is inference from the training scripts, not yet confirmed on-device. The empirical
check chosen by the user (feed known samples through each `.tflite` and inspect behaviour) is still
worth running before committing to a model — but the expected outcome is now known, which makes that
check a confirmation rather than an open question.

### 10.3 Vocabulary/assets gap

`assets/gifs/` contains exactly 5 files: `hello, help, no, thank_you, yes`.

The 47-class training vocabulary contains hello, help, no, yes — but **not `thank_you`**. So:

- The 47-class model can never trigger `thank_you.gif`.
- 43 of its 47 words have no GIF at all, so the "deaf user sees a GIF" half of the feature only
  works for 4 words under that model.

This is the main reason the 47-class path is a poor fit for a demo, and why a focused
~10-word vocabulary (dual-hand, higher accuracy) was raised as the likely direction once the
connection is confirmed.

### 10.4 Model scope decision — deferred

Deferred until §6 passes. Stated preference: **one hand vs two hands, ~10 words, prioritising
accuracy.** The GRU is the strongest candidate on paper (91.81% vs 86.00%) at the cost of ~93 ms
inference latency vs ~2.5 ms for dense — acceptable at the 3–5 FPS sampling rate the pipeline
already uses.
