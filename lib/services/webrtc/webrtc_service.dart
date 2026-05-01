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

  // ── Dispose guard ──
  bool _disposed = false;

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

  // ── Standard ICE servers (free Google STUN; TURN optional later) ──
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
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
    _peerConnection = await createPeerConnection(_iceConfig, _sdpConstraints);

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
      onLocalIceCandidate?.call(candidate);
    };

    // ── Connection state monitoring (useful for debugging) ──
    _peerConnection!.onConnectionState = (state) {
      // ignore: avoid_print
      print('[WebRTC] connection state: $state');
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
    final answer = await _peerConnection!.createAnswer(_sdpConstraints);
    await _peerConnection!.setLocalDescription(answer);
    await onLocalSdpReady?.call(answer);
  }

  /// Caller receives the answer back.
  Future<void> handleRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection!.setRemoteDescription(answer);
  }

  /// Either side: incoming ICE candidate from the peer.
  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
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