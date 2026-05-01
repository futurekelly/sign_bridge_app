// CallController (Phase 5 → Phase 6)
// ─────────────────────────────────────────────────────────────
// Owns the WebRTC call lifecycle + the TranslationController.
// Phase 6: DataChannel is now wired for real-time translation sync.

import 'package:flutter/foundation.dart';
import '../services/auth/auth_service.dart';
import '../services/webrtc/webrtc_service.dart';
import '../services/webrtc/signaling_service.dart';
import '../core/utils/permissions.dart';
import 'translation_controller.dart';

enum CallState { idle, connecting, inCall, ended, error }

class CallController extends ChangeNotifier {
  final WebRTCService webrtc = WebRTCService();
  final AuthService _auth = AuthService();

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

  /// True once the remote peer's video stream has been received.
  /// The UI uses this instead of checking renderer.srcObject directly,
  /// which doesn't trigger rebuilds.
  bool _remoteConnected = false;
  bool get remoteConnected => _remoteConnected;

  /// Guard to prevent double-dispose / double-end.
  bool _disposed = false;

  // ─────────────────────────────────────────────
  // ENTRY POINTS
  // ─────────────────────────────────────────────

  Future<String?> startAsCaller() async {
    final ok = await _bootstrap();
    if (!ok) return null;
    try {
      _signaling = SignalingService(
        webrtc: webrtc,
        selfId: _auth.currentUser!.uid,
      );
      _callId = await _signaling!.createCall();
      _setState(CallState.inCall);
      _startTranslation();
      return _callId;
    } catch (e) {
      _fail('Failed to create call: $e');
      return null;
    }
  }

  Future<bool> startAsCallee(String callId) async {
    final ok = await _bootstrap();
    if (!ok) return false;
    try {
      _signaling = SignalingService(
        webrtc: webrtc,
        selfId: _auth.currentUser!.uid,
      );
      await _signaling!.joinCall(callId);
      _callId = callId;
      _setState(CallState.inCall);
      _startTranslation();
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

      // Listen for the remote stream and notify UI when it arrives.
      webrtc.onRemoteStreamAdded = () {
        _remoteConnected = true;
        notifyListeners();
      };

      return true;
    } catch (e) {
      _fail('Setup failed: $e');
      return false;
    }
  }

  /// Starts the AI pipeline and wires DataChannel (Phase 6).
  void _startTranslation() {
    // Phase 6: wire DataChannel ↔ TranslationController.
    webrtc.onDataChannelMessage = translation.handleIncomingPeerJson;
    translation.onOutgoing = webrtc.sendDataChannelMessage;

    translation.start();
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

  /// Ends the call safely. Sets state BEFORE disposing resources
  /// so the UI can react and stop rendering WebRTC views first.
  Future<void> endCall() async {
    if (_disposed) return;
    _disposed = true;

    // 1) Signal UI to stop rendering immediately.
    _setState(CallState.ended);

    // 2) Stop AI pipeline.
    try { await translation.stop(); } catch (_) {}

    // 3) End signaling.
    try { await _signaling?.endCall(); } catch (_) {}

    // 4) Dispose WebRTC resources last (renderers, streams, connection).
    try { await webrtc.dispose(); } catch (_) {}
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
    // If endCall wasn't called explicitly, clean up now.
    if (!_disposed) {
      _disposed = true;
      _signaling?.dispose();
      translation.dispose();
      webrtc.dispose();
    }
    super.dispose();
  }
}