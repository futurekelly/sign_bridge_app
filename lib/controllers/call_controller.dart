// CallController (Phase 6 + Upgrade)
// Owns the WebRTC call lifecycle + TranslationController.
// Now saves recent calls on end.
//
// ── Fix (May 2026) ──────────────────────────────────────────
// • Translation pipeline now starts ONLY after the remote peer's
//   video stream arrives (onRemoteStreamAdded callback), NOT at
//   call setup time. This ensures:
//     - Mic (STT) is not active while "Waiting for peer..." screen shows
//     - Camera gesture pipeline is not running before P2P is confirmed
//     - No spurious AI output before both users are connected
// • Added _translationStarted guard so the pipeline can't start twice
//   even if onRemoteStreamAdded fires more than once (e.g. on
//   track renegotiation).
// • DataChannel callbacks are wired in _bootstrap() (early), so
//   incoming peer messages are never missed once the DataChannel opens.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/auth/auth_service.dart';
import '../services/webrtc/webrtc_service.dart';
import '../services/webrtc/signaling_service.dart';
import '../core/utils/permissions.dart';
import '../data/models/recent_call.dart';
import '../data/repositories/recent_calls_repository.dart';
import 'translation_controller.dart';
import '../services/webrtc/call_manager.dart';
import '../services/ai/inference_manager.dart';

enum CallState { idle, connecting, inCall, ended, error }

class CallController extends ChangeNotifier {
  final WebRTCService webrtc = WebRTCService();
  final AuthService _auth = AuthService();
  final RecentCallsRepository _recentRepo = RecentCallsRepository();

  // AI orchestrator owned by the call.
  final TranslationController translation = TranslationController();

  /// Exposes the InferenceManager for UI access to performance stats and hand landmarks
  InferenceManager get inferenceManager => translation.inferenceManager;

  SignalingService? _signaling;

  CallState _state = CallState.idle;
  CallState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _callId;
  String? get callId => _callId;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _remoteConnected = false;
  bool get remoteConnected => _remoteConnected;

  String? _peerUid;
  String? get peerUid => _peerUid;

  bool _disposed = false;

  /// Language code for AI services ('en' or 'sw').
  String _languageCode = 'en';

  /// Tracks when the call started for duration calculation.
  DateTime? _callStartTime;

  /// Guard: ensures translation.start() is called exactly once,
  /// even if onRemoteStreamAdded fires multiple times.
  bool _translationStarted = false;

  /// Whether the current user initiated the call.
  bool _isCaller = false;
  bool get isCaller => _isCaller;

  StreamSubscription? _callDocSub;

  void _listenToCallDoc(String callId) {
    debugPrint('[CallController] Subscribing to call document lifecycle: /calls/$callId');
    _callDocSub?.cancel();
    _callDocSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        if (_state == CallState.inCall || _state == CallState.connecting) {
          debugPrint('[CallController] Call doc /calls/$callId deleted. Transitioning to CallState.ended.');
          _setState(CallState.ended);
        }
      } else {
        final data = snap.data();
        if (data != null) {
          final status = data['status'];
          debugPrint('[CallController] Call doc status update: $status');
          if (status == 'ended' || status == 'rejected' || status == 'caller_cancelled') {
            if (_state == CallState.inCall || _state == CallState.connecting) {
              debugPrint('[CallController] Call document status is $status. Transitioning to CallState.ended.');
              _setState(CallState.ended);
            }
          }
        }
      }
    }, onError: (err) {
      debugPrint('[CallController] Call doc listener error: $err');
    });
  }

  // ─────────────────────────────────────────────
  // ENTRY POINTS
  // ─────────────────────────────────────────────

  Future<bool> startAsCaller(String callId, String calleeUid, {String languageCode = 'en'}) async {
    _isCaller = true;
    _languageCode = languageCode;
    _peerUid = calleeUid;
    _callId = callId;

    _setState(CallState.connecting);

    // Listen for Callee call status transition (accepted, rejected, timed_out)
    final docRef = FirebaseFirestore.instance.collection('calls').doc(callId);
    StreamSubscription? docSub;

    docSub = docRef.snapshots().listen((snap) async {
      if (!snap.exists) {
        docSub?.cancel();
        _fail('Call ended or was declined');
        return;
      }

      final data = snap.data()!;
      final status = data['status'];

      if (status == 'accepted') {
        docSub?.cancel();
        final ok = await _bootstrap();
        if (!ok) return;

        try {
          _signaling = SignalingService(
            webrtc: webrtc,
            selfId: _auth.currentUser!.uid,
          );
          await _signaling!.createCall(callId);
          _callStartTime = DateTime.now();
          _setState(CallState.inCall);
          _listenToCallDoc(callId); // Start listening to call doc changes during call
        } catch (e) {
          _fail('Failed to connect: $e');
        }
      } else if (status == 'rejected') {
        docSub?.cancel();
        _fail('Call was declined');
      } else if (status == 'timed_out') {
        docSub?.cancel();
        _fail('No answer');
      }
    });

    // Ringing Timeout (30 seconds)
    Timer(const Duration(seconds: 30), () async {
      if (state == CallState.connecting) {
        docSub?.cancel();
        try {
          await CallManager.instance.timeoutCall(callId, calleeUid, _auth.currentUser!.uid);
        } catch (_) {}
        _fail('No answer');
      }
    });

    return true;
  }

  Future<bool> startAsCallee(String callId, String callerUid, {String languageCode = 'en'}) async {
    _isCaller = false;
    _languageCode = languageCode;
    _peerUid = callerUid;
    final ok = await _bootstrap();
    if (!ok) return false;
    try {
      _signaling = SignalingService(
        webrtc: webrtc,
        selfId: _auth.currentUser!.uid,
      );
      await _signaling!.joinCall(callId);
      _callId = callId;
      _callStartTime = DateTime.now();
      _setState(CallState.inCall);
      _listenToCallDoc(callId); // Start listening to call doc changes during call
      return true;
    } catch (e) {
      _fail('Failed to join call: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // BOOTSTRAP & TRANSLATION WIRING
  // ─────────────────────────────────────────────

  Future<bool> _bootstrap() async {
    try {
      _setState(CallState.connecting);
      final granted = await AppPermissions.requestCallPermissions();
      if (!granted) {
        _fail('Camera & microphone permissions are required.');
        return false;
      }
      if (_auth.currentUser == null) {
        debugPrint('[CallController] No authenticated user. Signing in anonymously...');
        await _auth.signInAnonymously();
      } else {
        debugPrint('[CallController] User already authenticated: UID = ${_auth.currentUser!.uid}');
      }
      await webrtc.initialize();
      await webrtc.createPeerConnection_();

      webrtc.onConnectionStateChanged = (RTCPeerConnectionState state) {
        debugPrint('[CallController] WebRTC connection state: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            _setState(CallState.connecting);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setState(CallState.inCall);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _fail('WebRTC Connection disconnected');
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _fail('WebRTC Connection failed');
            break;
          default:
            break;
        }
      };

      // Wire DataChannel callbacks early so no messages are missed
      // once the DataChannel opens (which can happen before remote
      // video arrives on the callee side).
      _wireDataChannel();

      // Start the AI translation pipeline ONLY when the remote peer's
      // video stream has actually arrived — i.e. P2P is confirmed.
      webrtc.onRemoteStreamAdded = () {
        _remoteConnected = true;
        notifyListeners();

        if (!_translationStarted) {
          _translationStarted = true;
          debugPrint('[CallController] P2P confirmed — starting translation pipeline (lang: $_languageCode)');
          translation.start(
            languageCode: _languageCode,
            localVideoTrack: webrtc.localVideoTrack,
          );
        }
      };

      return true;
    } catch (e) {
      _fail('Setup failed: $e');
      return false;
    }
  }

  /// Wires the DataChannel message callbacks without starting the AI pipeline.
  /// Called early in _bootstrap so peer messages received via DataChannel
  /// are always routed to the TranslationController, regardless of when
  /// the remote stream arrives.
  void _wireDataChannel() {
    webrtc.onDataChannelMessage = translation.handleIncomingPeerJson;
    translation.onOutgoing = webrtc.sendDataChannelMessage;
  }

  // ─────────────────────────────────────────────
  // CONTROLS
  // ─────────────────────────────────────────────

  void toggleMute() {
    _isMuted = !_isMuted;
    webrtc.toggleMute(_isMuted);
    notifyListeners();
  }

  Future<void> switchCamera() async => webrtc.switchCamera();

  /// Ends the call safely and saves to recent calls.
  Future<void> endCall() async {
    if (_disposed) return;
    _disposed = true;

    _callDocSub?.cancel();
    _callDocSub = null;

    // Save to recent calls before cleanup.
    await _saveRecentCall();

    // 1) Signal UI to stop rendering immediately.
    _setState(CallState.ended);

    // 2) Stop AI pipeline.
    try { await translation.stop(); } catch (_) {}

    // 3) End signaling via CallManager to handle status updates & Purge
    if (_callId != null && _peerUid != null) {
      final myUid = _auth.currentUser!.uid;
      final caller = _isCaller ? myUid : _peerUid!;
      final callee = _isCaller ? _peerUid! : myUid;
      if (_isCaller && _state == CallState.connecting) {
        try {
          await CallManager.instance.cancelCall(_callId!, caller, callee);
        } catch (_) {}
      } else {
        int duration = 0;
        if (_callStartTime != null) {
          duration = DateTime.now().difference(_callStartTime!).inSeconds;
        }
        try {
          await CallManager.instance.endCall(_callId!, callee, caller, durationSeconds: duration);
        } catch (_) {}
      }
    }

    try { await _signaling?.dispose(); } catch (_) {}

    // 4) Dispose WebRTC resources last.
    try { await webrtc.dispose(); } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // RECENT CALLS
  // ─────────────────────────────────────────────

  Future<void> _saveRecentCall() async {
    if (_callId == null) return;
    try {
      int? duration;
      if (_callStartTime != null) {
        duration = DateTime.now().difference(_callStartTime!).inSeconds;
      }
      await _recentRepo.save(RecentCall(
        callId: _callId!,
        partnerName: null, // Could be fetched from Firestore call doc
        partnerRole: null,
        durationSeconds: duration,
      ));
    } catch (_) { /* best-effort */ }
  }

  // ─────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────

  Future<void> _fail(String msg) async {
    _callDocSub?.cancel();
    _callDocSub = null;

    _errorMessage = msg;
    _setState(CallState.error);

    // Perform cleanup without setting state to ended
    if (_disposed) return;
    _disposed = true;

    await _saveRecentCall();
    
    try { await translation.stop(); } catch (_) {}

    if (_callId != null && _peerUid != null) {
      final myUid = _auth.currentUser!.uid;
      final caller = _isCaller ? myUid : _peerUid!;
      final callee = _isCaller ? _peerUid! : myUid;
      
      if (_isCaller && _state == CallState.connecting) {
        try {
          await CallManager.instance.cancelCall(_callId!, caller, callee);
        } catch (_) {}
      } else {
        int duration = 0;
        if (_callStartTime != null) {
          duration = DateTime.now().difference(_callStartTime!).inSeconds;
        }
        try {
          await CallManager.instance.endCall(_callId!, callee, caller, durationSeconds: duration);
        } catch (_) {}
      }
    }

    try { await _signaling?.dispose(); } catch (_) {}
    try { await webrtc.dispose(); } catch (_) {}
  }

  void _setState(CallState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _callDocSub?.cancel();
      _signaling?.dispose();
      translation.dispose();
      webrtc.dispose();
    }
    super.dispose();
  }
}