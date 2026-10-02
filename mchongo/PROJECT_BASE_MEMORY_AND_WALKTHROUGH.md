# SignBridge — Master Project Base Memory & Walkthrough
**Document Version:** 1.0.0  
**Target OS Platform:** Android 10+ (API 29+)  
**Focus Area:** WebRTC Mobile Data Connectivity, Video Smoothness, Real-Time Translation & Smart APK Deployment  

---

## 📌 1. Executive Summary & Base Memory

This document serves as the **master operational memory** for the **SignBridge** project. SignBridge is a Flutter-based real-time communication platform designed to bridge the gap between deaf individuals and hearing users through peer-to-peer video calling, real-time sign language gesture recognition, speech-to-text (STT), and text-to-speech (TTS).

To ensure high performance, total user privacy, and zero server infrastructure costs, all media and text translation ride on **WebRTC (DataChannel + MediaStream)**, and all AI processing runs **strictly on-device**.

---

## 🔍 2. Root Cause Analysis Memory: Wi-Fi vs. Mobile Data Connection

### The Symptoms
- On **Wi-Fi**, two physical devices connected and synchronized video smoothly.
- On **Mobile Data (4G/5G Cellular Networks)**, connection attempt failed or remained stuck on "Waiting for peer...".

### Technical Root Causes & Resolution Strategy

| Issue Component | Root Cause on Cellular Networks | Technical Fix Applied in Codebase |
|---|---|---|
| **ICE Transport Protocol** | Mobile carriers enforce **Carrier-Grade NAT (CGNAT)** and Symmetric NAT. STUN alone cannot discover direct P2P paths across CGNAT. | Added **`turns:` (Secure TURN over TLS)** configuration on port 443 in `WebRTCService`. Encapsulates relay media inside TLS/443 so cellular operator firewalls treat it as standard HTTPS traffic. See the **Sep 2026 correction** below — the original credentials were dead and this fix was inert until then. |
| **Unapplied SDP Bitrate & Codec Optimization** | SDP munging functions were inactive, causing WebRTC to default to unoptimized VP8 software codecs with uncapped bandwidth. | Implemented dynamic `_optimizeSdp()` in `WebRTCService`. Automatically prioritizes **H.264** hardware acceleration on Android devices and caps bitrate at **800 kbps** (`b=AS:800` & `b=TIAS:800000`). |
| **Firestore Signaling Latency & Race Conditions** | Cellular latency triggered snapshot updates out of order. Document `update()` threw errors if document fields lagged. | Replaced `docRef.update()` with `docRef.set(..., SetOptions(merge: true))` in `SignalingService` for atomic SDP exchanges. Extended Callee timeout from 10s to 15s. |
| **Android Network Interface Switching** | Android OS restricted network interface probing across cellular data transitions. | Added `ACCESS_WIFI_STATE` and `CHANGE_NETWORK_STATE` permissions in `AndroidManifest.xml`. |

### ⚠️ Correction (Sep 2026) — the TURN fix above was inert

**What was believed:** the ICE row above was recorded as complete, on the reasoning that adding `turns:` on 443 solves CGNAT.

**What was actually wrong:** the configuration was structurally correct but the **credentials were dead**. It used OpenRelay's retired public demo pair:

```dart
'username': 'openrelayproject',
'credential': 'openrelayproject',
```

Metered.ca ended unauthenticated public TURN access; those static credentials are rejected at the auth layer. Nothing in the code looked wrong, which is why this went unnoticed — the failure was entirely at a third-party service.

**Why it presented as "works on Wi-Fi only":** on Wi-Fi both peers share a LAN, so host/STUN candidates connect the call and no relay is needed. On cellular, CGNAT makes every direct path unreachable and a **relay candidate is mandatory**. Every TURN allocation was refused → zero relay candidates → ICE had nothing usable → the UI sat on "Waiting for peer..." indefinitely.

**Evidence gathered:**
- `openrelay.metered.ca` was reachable (TCP 443 and 3478 both open) — so the failure was *authentication*, not reachability or firewall.
- A live TURN Allocate against the new credential returned `200` and reserved a relay — credentials authenticate.

**Fix applied:**
1. Replaced with real Metered credentials (`signbridge-test`, free tier 20 GB/month, quota resets on the 29th). Note the host is `standard.relay.metered.ca`, **not** `openrelay.metered.ca`.
2. `_peerConfig` converted from `static const` to a runtime-built `_buildPeerConfig()` so the credential set can later be swapped for a fetched/dynamic one without touching call sites.
3. `_optimizeSdp()` is no longer applied to the peer's *answer* — munging a remote description can disagree with what the other side negotiated and cause a codec mismatch. Local SDP only.
4. `RTCPeerConnectionStateFailed` no longer a silent no-op. It previously logged *"waiting for auto-recovery"* and did nothing, so a failed negotiation looked identical to a slow one. It now surfaces a real error, and names the missing-relay case specifically.
5. Added `localCandidateTypes` / `hasRelayCandidate` diagnostics on `WebRTCService`, logging each candidate's type (`host`/`srflx`/`relay`) so the relay path is verifiable from logcat.
6. Added `_forceRelayForDiagnostics` switch — forces `iceTransportPolicy: 'relay'` to isolate the TURN path in one test run. **Must stay `false` for normal use.**

**Known credential caveat:** these are static credentials and ship inside the APK, so anyone who extracts a release build can read them. Acceptable for development. A production build should fetch short-lived backend-minted credentials at connect time — note that the Firebase-native way to do this (Cloud Functions) is **unavailable on the Spark plan**, so it would need a non-Firebase endpoint (e.g. a free Cloudflare Worker) or self-hosted coturn.

**Still outstanding:** ICE restart on mid-call network handover is *not* implemented. Adding it is not just a WebRTC change — `SignalingService.joinCall()` applies the offer exactly once (its temp listener cancels after the first offer), so there is currently no path for a re-offer to reach the callee. Proper ICE restart needs renegotiation support in the signaling layer first.

---

## 🏗️ 3. Full Project Architecture Walkthrough

```
               ┌──────────────────────────────────────────────┐
               │              Firebase Firestore              │
               │   (Signaling Only: SDP Offers/Answers/ICE)   │
               └──────────────────────┬───────────────────────┘
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
        ┌────────────────────┐                 ┌────────────────────┐
        │   Device A (Deaf)  │ ◄─ WebRTC ────► │ Device B (Hearing) │
        └──────────┬─────────┘   P2P Media     └──────────┬─────────┘
                   │             DataChannel              │
                   ▼                                      ▼
      ┌─────────────────────────┐            ┌─────────────────────────┐
      │  Local AI Pipeline      │            │  Local AI Pipeline      │
      │  - TFLite Isolate       │            │  - Speech-To-Text (STT) │
      │  - Landmark Processing  │            │  - Text-To-Speech (TTS) │
      │  - Gesture Recognition  │            │  - GIF Rendering       │
      └─────────────────────────┘            └─────────────────────────┘
```

### Core Architecture Layers
1. **Layer 1: Signaling (Firestore)**
   - Used strictly for bootstrapping calls (`/calls/{callId}`).
   - Exchanges SDP offers/answers and ICE candidate sub-collections (`callerCandidates`, `calleeCandidates`).
   - Disconnects signaling listeners once WebRTC state transitions to `RTCPeerConnectionStateConnected`.

2. **Layer 2: Media Stream (WebRTC)**
   - Streams local camera (`480x360` ideal @ 20–30 FPS) and audio.
   - Applies H.264 hardware acceleration and 800 kbps cellular bitrate capping.

3. **Layer 3: DataChannel (`RTCDataChannel`)**
   - Separate, ultra-low-latency channel dedicated exclusively to real-time translation text payloads (`TranslationMessage` JSON).

4. **Layer 4: Local AI Engine & UI State**
   - **Deaf Mode**: Live video frame capture -> TFLite Isolate / Landmark Processor -> Gesture Recognition -> Sent via DataChannel -> Spoken by peer TTS.
   - **Hearing Mode**: Mic audio captured by STT -> Speech-to-Text -> Sent via DataChannel -> Rendered as Captions & Animated GIFs on peer screen.

---

## 📱 4. Android 10+ (API 29+) Device Optimization Blueprint

To ensure maximum smoothness and compatibility across modern physical Android devices:

1. **Hardware Accelerated Encoding**:
   - H.264 codec payload ordering ensures low CPU usage on Qualcomm, MediaTek, Exynos, and Kirin SoCs.
2. **Camera Frame Throttling**:
   - Gesture recognition frame processor samples camera feed at 3–5 FPS without choking the main UI isolate thread.
3. **Memory Management**:
   - Video renderers (`RTCVideoRenderer`) and AI Isolates are safely disposed when calls end, preventing memory leaks or camera lockouts.

---

## 🛠️ 5. Physical Device Testing & Debugging Manual

### Testing Matrix (Cross-Network Verification)
- [ ] **Scenario A**: Device 1 on Wi-Fi <--> Device 2 on Mobile Data (4G/5G)
- [ ] **Scenario B**: Device 1 on Mobile Data (Carrier X) <--> Device 2 on Mobile Data (Carrier Y)
- [ ] **Scenario C**: Device 1 behind Strict Firewall/CGNAT <--> Device 2 on Mobile Data

### ADB Logcat Command Filters
To inspect real-time connection status on connected physical devices:

```bash
# Filter WebRTC, Signaling, and CallManager log tags
adb logcat -s WebRTC:V Signaling:V CallManager:V CallController:V
```

### Expected Log Sequence for Successful Connection
1. `[CallManager] initiateCall SUCCESS: Call created at calls/{id}`
2. `[WebRTC] ICE gathering state → RTCIceGatheringStateGathering`
3. `[WebRTC] local ICE candidate → type=relay` ← **the line that proves TURN works**
4. `[Signaling] Received answer SDP — applying to peer connection`
5. `[WebRTC] connection state → RTCPeerConnectionStateConnected`
6. `[CallController] P2P confirmed — waiting for video before starting AI...`
7. `[CallController] Starting AI pipeline.`

### Verifying the relay path (do this on mobile data)
Watch the `local ICE candidate → type=` lines. On Wi-Fi you will see `host` and `srflx`, which is
normal and does **not** prove TURN works — the LAN provides a direct path.

On cellular you must see `type=relay`. If you only ever see `host`/`srflx` and then the call fails,
`[CallController] WebRTC connection FAILED. Local candidate types gathered: [...]` will list what
was actually gathered, and the error surfaced in the UI names the missing-relay case.

To isolate TURN in a single run, set `_forceRelayForDiagnostics = true` in `WebRTCService`. That
forces `iceTransportPolicy: 'relay'`, so **all** traffic goes through the relay. If calls then fail
on Wi-Fi too, TURN is the problem. **Set it back to `false` afterwards.**

---

## 📦 6. Smart APK Build & Deployment Instructions

When building the release binary for physical Android 10+ phones:

### 1. Clean Build Environment
```bash
flutter clean
flutter pub get
```

### 2. Build Split-ABI Universal Release APKs
Splitting by ABI produces smaller, faster-loading APK binaries tailored to modern 64-bit ARM architectures:

```bash
flutter build apk --release --split-per-abi
```

Generated APK Outputs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (For 95%+ of modern Android 10+ devices)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (For older 32-bit devices)

---

## 🗓️ 7. Project Memory Maintenance Rule

> **Developer Rule**: Whenever changes are made to WebRTC configuration, network security settings, AI models, or signaling logic, this file (`mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md`) must be updated to preserve project history and ensure future development continuity.
