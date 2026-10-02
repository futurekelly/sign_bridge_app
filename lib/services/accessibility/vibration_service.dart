import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Tactile alerts for the deaf user.
///
/// Everything here has to work through a pocket, because the deaf user cannot hear the
/// phone. The two events it reports are very different things to be interrupted by, so
/// they must be tellable apart by feel alone rather than by looking at the screen.
///
/// Before this the service fired `HapticFeedback.vibrate()` for both events: the system's
/// UI tick, roughly 50ms, with no pattern and no amplitude, identical for a call and for a
/// message. That call is also the strongest it can ever be -- `HapticFeedback` exposes no
/// duration or intensity to turn up. Real patterns need the platform vibrator, which is why
/// this uses the `vibration` package and why AndroidManifest.xml now requests
/// android.permission.VIBRATE.
///
/// This is a deaf-only channel. Callers are expected to have checked the role -- see the
/// `a11y.isDeaf` gates in CallScreen and IncomingCallOverlay.
class VibrationService {
  static final VibrationService instance = VibrationService._internal();
  VibrationService._internal();

  /// Gap between rings while a call is incoming. Long enough to read as separate rings
  /// rather than one continuous buzz.
  static const Duration _ringInterval = Duration(milliseconds: 1800);

  /// Incoming call: a long double-buzz, repeated until answered or declined. Deliberately
  /// heavy -- it is the one alert that must not be missed.
  static const List<int> _callPattern = <int>[0, 700, 250, 700];

  /// Message: a short double-tick, fired once. Much lighter and much shorter than the call
  /// pattern, so the two are never confused for one another.
  static const List<int> _messagePattern = <int>[0, 120, 100, 120];

  Timer? _vibrationTimer;
  bool _isVibrating = false;

  /// Whether the incoming-call alert is currently looping.
  bool get isVibrating => _isVibrating;

  /// Starts the looping incoming-call alert. Runs until [stopVibration] is called.
  ///
  /// A timer re-issues the pattern rather than handing `repeat` to the platform: an
  /// indefinite native repeat is what OEM battery managers (Huawei's especially) like to
  /// cut short, whereas a pattern re-issued every 1.8s keeps going.
  Future<void> startIncomingCallVibration() async {
    if (_isVibrating) return;
    _isVibrating = true;

    await _pulse(_callPattern);

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(_ringInterval, (timer) => _pulse(_callPattern));
  }

  /// A single short alert for a message arriving mid-call. Fires once, not on a loop.
  Future<void> messageAlert() => _pulse(_messagePattern);

  /// Stops any active alert loop. Safe to call when nothing is vibrating.
  Future<void> stopVibration() async {
    _isVibrating = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    // Cancel the pattern already playing too; otherwise the current buzz rings on to its
    // end after the call has been answered.
    try {
      await Vibration.cancel();
    } catch (_) {
      // Nothing running, or no vibrator on this device. Either way there is nothing to
      // cancel, so this must not be allowed to throw into the caller.
    }
  }

  /// Plays [pattern] once, degrading in steps rather than failing silently.
  ///
  /// A device that cannot take a custom pattern still gets a plain vibration of the pattern's
  /// total length, and a device with no usable vibrator at all gets the UI tick. An alert
  /// that does nothing is worse than a weak one.
  Future<void> _pulse(List<int> pattern) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (await Vibration.hasCustomVibrationsSupport()) {
          await Vibration.vibrate(pattern: pattern);
        } else {
          await Vibration.vibrate(
            duration: pattern.fold<int>(0, (sum, ms) => sum + ms),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('[VibrationService] vibrator unusable, falling back to haptic: $e');
    }

    await HapticFeedback.vibrate();
  }
}
