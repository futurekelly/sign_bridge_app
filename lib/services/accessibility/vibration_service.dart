import 'dart:async';
import 'package:flutter/services.dart';

class VibrationService {
  static final VibrationService instance = VibrationService._internal();
  VibrationService._internal();

  Timer? _vibrationTimer;
  bool _isVibrating = false;

  /// Returns true if the service is currently vibrating.
  bool get isVibrating => _isVibrating;

  /// Starts a looping vibration alert designed for deaf accessibility.
  /// Fires a haptic vibration pulse periodically.
  void startIncomingCallVibration() {
    if (_isVibrating) return;
    _isVibrating = true;

    // Trigger immediately
    HapticFeedback.vibrate();

    // Trigger periodically (vibrate every 500ms to produce a continuous ringing pattern)
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      HapticFeedback.vibrate();
    });
  }

  /// Stops any active haptic vibration loop.
  void stopVibration() {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }
}
