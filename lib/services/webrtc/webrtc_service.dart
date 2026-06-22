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

  // ── ICE candidate buffer ──
  // Candidates received before setRemoteDescription is called are held
  // here and flushed once the remote description is applied.
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

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
  // STUN (Google free)        — works on same-Wi-Fi & most home routers.
  // TURN (OpenRelay free tier) — required for mobile data / CGNAT networks.
  //   Credentials are the public OpenRelay project credentials.
  //   Replace with your own Metered.ca API key for production.
  //
  // sdpSemantics: unified-plan — required for correct multi-track behavior
  //   on modern Android/iOS (avoids plan-b deprecation issues).
  // ──────────────────────────────────────────────────────────────────────
  static const Map<String, dynamic> _peerConfig = {
    'sdpSemantics': 'unified-plan',
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
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

    // Acquire local audio + video.
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user', // front camera by default
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
    });

    localRenderer.srcObject = _localStream;
  }

  /// Creates the RTCPeerConnection and wires all event handlers.
  Future<void> createPeerConnection_() async {
    _peerConnection = await createPeerConnection(_peerConfig, _sdpConstraints);

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
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
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
  /// (DataChannel must be created BEFORE the offer.)
  Future<void> createOffer() async {
    // Create outgoing data channel (text-only — see architecture rule #3).
    _dataChannel = await _peerConnection!.createDataChannel(
      'translation', // channel label
      RTCDataChannelInit()..ordered = true,
    );
    _bindDataChannelHandlers();

    final offer = await _peerConnection!.createOffer(_sdpConstraints);
    await _peerConnection!.setLocalDescription(offer);
    await onLocalSdpReady?.call(offer);
  }

  // ─────────────────────────────────────────────
  // CALL FLOW (callee side)
  // ─────────────────────────────────────────────

  /// Callee receives the offer, creates an answer.
  Future<void> handleRemoteOffer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    // Now that remote description is set, flush any buffered candidates.
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();

    final answer = await _peerConnection!.createAnswer(_sdpConstraints);
    await _peerConnection!.setLocalDescription(answer);
    await onLocalSdpReady?.call(answer);
  }

  /// Caller receives the answer back.
  Future<void> handleRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection!.setRemoteDescription(answer);
    // Now that remote description is set, flush any buffered candidates.
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
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
    _dataChannel?.onMessage = (RTCDataChannelMessage msg) {
      onDataChannelMessage?.call(msg.text);
    };
  }

  /// Send a JSON-serialized TranslationMessage to peer.
  /// (Called by TranslationController via onOutgoing callback.)
  void sendDataChannelMessage(String json) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(json));
    }
  }

  // ─────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────

  /// Idempotent dispose — safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingCandidates.clear();

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