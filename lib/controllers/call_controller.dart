// CallController (Phase 3)
// ─────────────────────────────────────────────────────────────
// Now wires WebRTCService + SignalingService together.
// Two entry points:
//   • startAsCaller()  → creates call doc, returns callId to share
//   • startAsCallee(id)→ joins existing call by ID

import 'package:flutter/foundation.dart';
import '../services/auth/auth_service.dart';
import '../services/webrtc/webrtc_service.dart';
import '../services/webrtc/signaling_service.dart';
import '../core/utils/permissions.dart';

enum CallState { idle, connecting, inCall, ended, error }

class CallController extends ChangeNotifier {
  final WebRTCService webrtc = WebRTCService();
  final AuthService _auth = AuthService();

  SignalingService? _signaling;

  CallState _state = CallState.idle;
  CallState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _callId;
  String? get callId => _callId;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

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
      return true;
    } catch (e) {
      _fail('Failed to join call: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // SHARED BOOTSTRAP
  // ─────────────────────────────────────────────

  Future<bool> _bootstrap() async {
    try {
      _setState(CallState.connecting);

      // Permissions
      final granted = await AppPermissions.requestCallPermissions();
      if (!granted) {
        _fail('Camera & microphone permissions are required.');
        return false;
      }

      // Ensure auth (anonymous)
      await _auth.signInAnonymously();

      // WebRTC init
      await webrtc.initialize();
      await webrtc.createPeerConnection_();

      return true;
    } catch (e) {
      _fail('Setup failed: $e');
      return false;
    }
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

  Future<void> endCall() async {
    await _signaling?.endCall();
    await webrtc.dispose();
    _setState(CallState.ended);
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
    _signaling?.dispose();
    webrtc.dispose();
    super.dispose();
  }
}