// WebRTCService
// ─────────────────────────────────────────────────────────────
// Owns the WebRTC PeerConnection and the two streams that ride
// on top of it:
//
//   • MediaStream  → audio + video ONLY  (architecture rule #2)
//   • DataChannel  → translation text ONLY (rule #3)
//
// Signaling (offer/answer/ICE) is delegated to a callback interface
// so this service does NOT depend on Firebase. Phase 3 plugs in
// SignalingService through these callbacks.
//
// This file is intentionally framework-agnostic about signaling.
//
// ── Fix (May 2026) ──────────────────────────────────────────
// • Added TURN relay servers (OpenRelay/Metered.ca free tier)
//   so connections work on real mobile networks, not just Wi-Fi.
// • Added sdpSemantics: unified-plan for cross-platform correctness.
// • Added ICE candidate buffering: candidates received before
//   setRemoteDescription is called are queued and flushed
//   immediately after the remote description is applied.
//   Without this, candidates silently fail on the caller side
//   because the callee generates them before the answer arrives.
//
// ── Fix (Sep 2026) ──────────────────────────────────────────
// • The May 2026 TURN work was INERT: it used OpenRelay's retired
//   public demo credentials (username/credential both
//   "openrelayproject"), which are now rejected at the auth
//   layer. Structurally the config was fine, which is why it went
//   unnoticed. Replaced with a real Metered credential
//   (host: standard.relay.metered.ca, NOT openrelay.metered.ca).
//   See mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md §2.
// • _peerConfig is now built at runtime by _buildPeerConfig() so
//   the credential set can later be swapped without touching call
//   sites.
// • handleRemoteAnswer() no longer runs _optimizeSdp() on the
//   peer's answer — munging a remote description can disagree
//   with what the other side negotiated.
// • Added candidate-type diagnostics (localCandidateTypes /
//   hasRelayCandidate) so a relay path is verifiable from logcat.
//
// ── Fix (Sep 2026, video-only call) ─────────────────────────
// • The call no longer requests an audio track.
//
//   Root cause it fixes: since Android 10, only ONE app may hold
//   the microphone at a time, and this WebRTC session was holding
//   it. Android's SpeechRecognizer runs in a DIFFERENT process
//   (Google's, or Huawei's), so it captured silence and failed
//   with `error_speech_timeout, permanent: true` — which is
//   exactly why spoken words never reached the deaf peer.
//
//   Dropping audio costs this app nothing: the deaf peer cannot
//   hear it, and the hearing peer hears TTS locally, synthesized
//   from the gesture message that arrives over the DataChannel.
//   Freeing the mic is what makes hearing→deaf work at all.
//
// • sendDataChannelMessage() now logs and BUFFERS instead of
//   silently dropping when the channel is not open yet.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Callback contract used by the signaling layer (Phase 3).
typedef SdpCallback = Future<void> Function(RTCSessionDescription sdp);
typedef IceCallback = Future<void> Function(RTCIceCandidate candidate);

class WebRTCService {
  // ── Peer connection & streams ──
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCDataChannel? _dataChannel;

  /// Expose the local video track for camera frame capture by the AI pipeline.
  MediaStreamTrack? get localVideoTrack => _localStream?.getVideoTracks().firstOrNull;

  // ── Dispose guard ──
  bool _disposed = false;

  // ── Outbound DataChannel buffer ──
  // The AI pipeline can produce a result before the DataChannel finishes
  // negotiating (the callee's channel only exists once the offer is applied).
  // Anything produced in that window is queued here and flushed on open,
  // instead of being dropped without trace.
  final List<String> _outboundBuffer = [];
  static const int _outboundBufferLimit = 50;

  // ── ICE candidate buffer ──
  // Candidates received before setRemoteDescription is called are held
  // here and flushed once the remote description is applied.
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

  // ── Diagnostics ──
  /// Types of local ICE candidates gathered this session, in order
  /// (e.g. ['host', 'srflx', 'relay']). Exposed so the UI or logcat can
  /// confirm a relay path exists without reading raw SDP.
  final List<String> _candidateTypes = [];
  List<String> get localCandidateTypes => List.unmodifiable(_candidateTypes);
  bool get hasRelayCandidate => _candidateTypes.contains('relay');

  /// Extracts the ICE candidate type ("host", "srflx", "prflx", "relay")
  /// from a raw candidate string.
  static String _candidateType(String candidate) {
    final match = RegExp(r' typ (\w+)').firstMatch(candidate);
    return match?.group(1) ?? 'unknown';
  }

  // ── Renderers (owned by the UI but lifecycle managed here for safety) ──
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // ── Public callbacks (signaling layer wires these in Phase 3) ──
  SdpCallback? onLocalSdpReady;        // emit our SDP to peer via Firebase
  IceCallback? onLocalIceCandidate;    // emit our ICE candidate to peer
  void Function(String message)? onDataChannelMessage; // Phase 6 hook

  /// Fired when a remote media stream is received from the peer.
  /// CallController uses this to set remoteConnected = true and
  /// trigger a UI rebuild so the Call ID banner hides and remote video shows.
  VoidCallback? onRemoteStreamAdded;
  void Function(RTCPeerConnectionState)? onConnectionStateChanged;

  // ── ICE server configuration ──────────────────────────────────────────
  //
  // STUN (Metered + Google) — works on same-Wi-Fi & home routers.
  // TURN (Metered)          — MANDATORY for mobile data / CGNAT networks.
  //   `turns:` on 443 is TURN over TLS, which is indistinguishable from
  //   ordinary HTTPS traffic, so carrier firewalls pass it where bare
  //   UDP is dropped.
  //
  // Credentials below are the Metered.ca "signbridge-test" credential
  // (free tier: 20 GB/month, quota resets on the 29th).
  //   Rotate: Metered dashboard → TURN Server → Remove → Add Credential.
  //
  // ⚠ These are STATIC credentials and ship inside the APK, so anyone who
  //   extracts a release build can read them. Acceptable for development;
  //   a production build should fetch short-lived backend-minted
  //   credentials at connect time instead. See
  //   mchongo/PROJECT_BASE_MEMORY_AND_WALKTHROUGH.md §2.
  //
  // Built at runtime rather than `static const` so the credential set can
  // be swapped for a fetched/dynamic one without touching call sites.
  // ──────────────────────────────────────────────────────────────────────
  static const String _turnUsername = '086b7e28c17087d402dbe4b9';
  static const String _turnCredential = 'dWBhJP9k29jVIj7P';

  /// Diagnostic switch. When true, only relay (TURN) candidates are used,
  /// forcing every call through the relay regardless of network — the fastest
  /// way to prove the TURN path works end-to-end inside the app.
  ///
  /// Enabled at BUILD TIME, not by editing this file, so it can never be left
  /// on by accident in a normal build:
  ///
  ///   flutter build apk --dart-define=FORCE_RELAY=true
  ///
  /// Defaults to false, which is what every normal build gets.
  static const bool _forceRelayForDiagnostics =
      bool.fromEnvironment('FORCE_RELAY');

  static Map<String, dynamic> _buildPeerConfig() => {
        'sdpSemantics': 'unified-plan',
        'iceGatheringPolicy': 'all',
        'bundlePolicy': 'max-compat',
        if (_forceRelayForDiagnostics) 'iceTransportPolicy': 'relay',
        'iceServers': [
          {
            'urls': [
              'stun:stun.relay.metered.ca:80',
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
          {
            'urls': [
              'turn:standard.relay.metered.ca:80',
              'turn:standard.relay.metered.ca:80?transport=tcp',
              'turn:standard.relay.metered.ca:443',
              'turns:standard.relay.metered.ca:443?transport=tcp',
            ],
            'username': _turnUsername,
            'credential': _turnCredential,
          },
        ],
      };

  // SDP constraints — receive both audio and video from peer.
  static const Map<String, dynamic> _sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // ─────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────

  /// Initializes renderers + acquires local media stream.
  /// Call before any offer/answer logic.
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    // Acquire local VIDEO ONLY — deliberately no audio.
    //
    // Requesting audio here makes this process the microphone owner, and
    // Android 10+ allows only one app to capture at a time. The speech
    // recognizer (a separate process) then hears silence and dies with
    // ERROR_SPEECH_TIMEOUT, so the hearing peer's words never arrive.
    // See the "video-only call" note in the file header.
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 480, 'max': 640},
        'height': {'ideal': 360, 'max': 480},
        'frameRate': {'ideal': 20, 'max': 30},
      },
    });

    localRenderer.srcObject = _localStream;
  }

  /// Creates the RTCPeerConnection and wires all event handlers.
  Future<void> createPeerConnection_() async {
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    _peerConnection = await createPeerConnection(_buildPeerConfig(), _sdpConstraints);

    // Attach local tracks to the connection (this is what gets sent).
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // ── Remote stream handling ──
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
        // Notify the controller so it can trigger a UI rebuild.
        onRemoteStreamAdded?.call();
      }
    };

    // ── ICE candidates (forwarded to signaling layer) ──
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      final c = candidate.candidate;
      if (c != null && c.isNotEmpty) {
        // Log the candidate type. "host"/"srflx" mean direct paths (fine on
        // Wi-Fi); "relay" means a TURN allocation succeeded, which is what
        // mobile data / CGNAT actually requires. If you never see "relay"
        // here while on cellular, the TURN credentials or URLs are wrong.
        final type = _candidateType(c);
        _candidateTypes.add(type);
        debugPrint('[WebRTC] local ICE candidate → type=$type '
            '(gathered so far: ${_candidateTypes.length})');
        onLocalIceCandidate?.call(candidate);
      }
    };

    // ── Connection state monitoring ──
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] connection state → $state');
      onConnectionStateChanged?.call(state);
    };

    // ── ICE connection state monitoring ──
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state → $state');
    };

    // ── ICE gathering state ──
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('[WebRTC] ICE gathering state → $state');
    };

    // ── DataChannel (incoming, set up by remote peer) ──
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _bindDataChannelHandlers();
    };
  }

  // ─────────────────────────────────────────────
  // CALL FLOW (caller side)
  // ─────────────────────────────────────────────

  /// Caller creates the offer and the DataChannel.
  Future<void> createOffer() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'translation',
      RTCDataChannelInit()..ordered = true,
    );
    _bindDataChannelHandlers();

    final rawOffer = await _peerConnection!.createOffer(_sdpConstraints);
    final optimizedSdp = _optimizeSdp(rawOffer.sdp ?? '');
    final offer = RTCSessionDescription(optimizedSdp, rawOffer.type);

    await _peerConnection!.setLocalDescription(offer);
    await onLocalSdpReady?.call(offer);
  }

  /// Callee receives the offer, creates an answer.
  Future<void> handleRemoteOffer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();

    final rawAnswer = await _peerConnection!.createAnswer(_sdpConstraints);
    final optimizedSdp = _optimizeSdp(rawAnswer.sdp ?? '');
    final answer = RTCSessionDescription(optimizedSdp, rawAnswer.type);

    await _peerConnection!.setLocalDescription(answer);
    await onLocalSdpReady?.call(answer);
  }

  /// Caller receives the answer back.
  ///
  /// NOTE: the peer's answer is applied verbatim. Do NOT run _optimizeSdp()
  /// on it — munging a *remote* description can disagree with what the other
  /// side actually negotiated (its m= payload ordering, its bitrate) and
  /// produce a codec mismatch. Only our own SDP gets optimized.
  Future<void> handleRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection!.setRemoteDescription(answer);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  /// Optimizes SDP for mobile networks & hardware acceleration:
  /// 1. Prioritizes H.264 codec for hardware acceleration on mobile devices.
  /// 2. Injects bitrate caps (800 kbps) for smooth video streaming over cellular networks.
  String _optimizeSdp(String sdp) {
    final lines = sdp.split('\r\n');
    final newLines = <String>[];

    // Find H264 payload types in SDP
    final h264Payloads = <String>[];
    final rtpmapRegExp = RegExp(r'^a=rtpmap:(\d+)\s+H264/90000', caseSensitive: false);
    for (final line in lines) {
      final match = rtpmapRegExp.firstMatch(line);
      if (match != null) {
        h264Payloads.add(match.group(1)!);
      }
    }

    for (var line in lines) {
      if (line.startsWith('m=video ')) {
        if (h264Payloads.isNotEmpty) {
          final parts = line.split(' ');
          if (parts.length > 3) {
            final header = parts.sublist(0, 3);
            final existingPayloads = parts.sublist(3);
            final remainingPayloads = existingPayloads.where((p) => !h264Payloads.contains(p)).toList();
            line = [...header, ...h264Payloads, ...remainingPayloads].join(' ');
          }
        }
        newLines.add(line);
        // Inject bitrate limits for mobile cellular data stability
        newLines.add('b=AS:800'); // 800 kbps maximum limit
        newLines.add('b=TIAS:800000');
        continue;
      }
      newLines.add(line);
    }
    return newLines.join('\r\n');
  }

  /// Either side: incoming ICE candidate from the peer.
  /// If remote description isn't set yet, the candidate is buffered
  /// and will be applied once it is set.
  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    if (!_remoteDescriptionSet) {
      debugPrint('[WebRTC] Buffering ICE candidate (remote desc not set yet)');
      _pendingCandidates.add(candidate);
      return;
    }
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('[WebRTC] addCandidate error (non-fatal): $e');
    }
  }

  /// Applies all buffered ICE candidates in order and clears the buffer.
  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty) return;
    debugPrint('[WebRTC] Flushing ${_pendingCandidates.length} buffered ICE candidates');
    for (final c in _pendingCandidates) {
      try {
        await _peerConnection!.addCandidate(c);
      } catch (e) {
        debugPrint('[WebRTC] addCandidate (buffered) error (non-fatal): $e');
      }
    }
    _pendingCandidates.clear();
  }

  // ─────────────────────────────────────────────
  // MEDIA CONTROLS
  // ─────────────────────────────────────────────

  /// Mute or unmute the outgoing audio track.
  ///
  /// NOTE: the call is video-only (see the header), so there is normally no
  /// audio track here and this is a no-op. The UI mic button is wired to the
  /// speech pipeline instead (CallController.toggleMute → STT pause), so
  /// "mute" still means something to the user: it stops caption capture.
  /// Kept so that re-introducing an audio track needs no call-site changes.
  void toggleMute(bool muted) {
    final audioTracks = _localStream?.getAudioTracks();
    audioTracks?.forEach((t) => t.enabled = !muted);
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  // ─────────────────────────────────────────────
  // DATA CHANNEL
  // ─────────────────────────────────────────────

  void _bindDataChannelHandlers() {
    final channel = _dataChannel;
    if (channel == null) {
      debugPrint('[WebRTC] _bindDataChannelHandlers: no channel to bind');
      return;
    }

    debugPrint('[WebRTC] Binding DataChannel "${channel.label}" '
        '(state: ${channel.state})');

    channel.onMessage = (RTCDataChannelMessage msg) {
      debugPrint('[WebRTC] DataChannel RX (${msg.text.length}B)');
      onDataChannelMessage?.call(msg.text);
    };

    // Without this, a channel that never opens looks identical in logcat to
    // a channel that opens fine — the single most confusing failure mode for
    // "the other phone shows nothing".
    channel.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('[WebRTC] DataChannel state → $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _flushOutboundBuffer();
      }
    };
  }

  /// Send a JSON-serialized TranslationMessage to peer.
  /// (Called by TranslationController via onOutgoing callback.)
  ///
  /// A message produced before the channel opens is BUFFERED, not dropped.
  /// The old implementation returned silently on a closed channel, which made
  /// "the deaf phone never shows the caption" undiagnosable from logs.
  void sendDataChannelMessage(String json) {
    final state = _dataChannel?.state;

    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(json));
      debugPrint('[WebRTC] DataChannel TX (${json.length}B): ${_preview(json)}');
      return;
    }

    debugPrint('[WebRTC] DataChannel TX DROPPED — '
        '${_dataChannel == null ? 'no channel object yet' : 'channel state is $state'}. '
        'Buffering (${_outboundBuffer.length + 1} pending).');

    if (_outboundBuffer.length >= _outboundBufferLimit) {
      _outboundBuffer.removeAt(0);
    }
    _outboundBuffer.add(json);
  }

  /// Sends anything queued while the channel was still negotiating.
  void _flushOutboundBuffer() {
    if (_outboundBuffer.isEmpty) return;
    debugPrint('[WebRTC] DataChannel open — flushing '
        '${_outboundBuffer.length} buffered message(s)');
    final pending = List<String>.from(_outboundBuffer);
    _outboundBuffer.clear();
    for (final json in pending) {
      try {
        _dataChannel?.send(RTCDataChannelMessage(json));
      } catch (e) {
        debugPrint('[WebRTC] buffered send error (non-fatal): $e');
      }
    }
  }

  static String _preview(String json) =>
      json.length > 80 ? '${json.substring(0, 80)}…' : json;

  // ─────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────

  /// Idempotent dispose — safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingCandidates.clear();
    _outboundBuffer.clear();

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _dataChannel?.close();
      await _peerConnection?.close();
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (_) {/* swallow on dispose */}
  }
}

// Small extension used above.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}