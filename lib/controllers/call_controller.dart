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

import 'package:flutter/foundation.dart';
import '../services/auth/auth_service.dart';
import '../services/webrtc/webrtc_service.dart';
import '../services/webrtc/signaling_service.dart';
import '../core/utils/permissions.dart';
import '../data/models/recent_call.dart';
import '../data/repositories/recent_calls_repository.dart';
import 'translation_controller.dart';

enum CallState { idle, connecting, inCall, ended, error }

class CallController extends ChangeNotifier {
  final WebRTCService webrtc = WebRTCService();
  final AuthService _auth = AuthService();
  final RecentCallsRepository _recentRepo = RecentCallsRepository();

  // AI orchestrator owned by the call.
  final TranslationController translation = TranslationController();

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

  bool _disposed = false;

  /// Language code for AI services ('en' or 'sw').
  String _languageCode = 'en';

  /// Tracks when the call started for duration calculation.
  DateTime? _callStartTime;

  /// Guard: ensures translation.start() is called exactly once,
  /// even if onRemoteStreamAdded fires multiple times.
  bool _translationStarted = false;

  // ─────────────────────────────────────────────
  // ENTRY POINTS
  // ─────────────────────────────────────────────

  Future<String?> startAsCaller({String languageCode = 'en'}) async {
    _languageCode = languageCode;
    final ok = await _bootstrap();
    if (!ok) return null;
    try {
      _signaling = SignalingService(
        webrtc: webrtc,
        selfId: _auth.currentUser!.uid,
      );
      _callId = await _signaling!.createCall();
      _callStartTime = DateTime.now();
      _setState(CallState.inCall);
      // Translation starts only when the peer connects (see _bootstrap).
      return _callId;
    } catch (e) {
      _fail('Failed to create call: $e');
      return null;
    }
  }

  Future<bool> startAsCallee(String callId, {String languageCode = 'en'}) async {
    _languageCode = languageCode;
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
      // Translation starts only when the peer connects (see _bootstrap).
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
      await _auth.signInAnonymously();
      await webrtc.initialize();
      await webrtc.createPeerConnection_();

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
          translation.start(languageCode: _languageCode);
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

    // Save to recent calls before cleanup.
    await _saveRecentCall();

    // 1) Signal UI to stop rendering immediately.
    _setState(CallState.ended);

    // 2) Stop AI pipeline.
    try { await translation.stop(); } catch (_) {}

    // 3) End signaling.
    try { await _signaling?.endCall(); } catch (_) {}

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

  void _fail(String msg) {
    _errorMessage = msg;
    _setState(CallState.error);
  }

  void _setState(CallState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _signaling?.dispose();
      translation.dispose();
      webrtc.dispose();
    }
    super.dispose();
  }
}