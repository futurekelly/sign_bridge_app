import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:torch_light/torch_light.dart';

/// TorchService
/// ─────────────────────────────────────────────────────────────
/// Real camera-LED (flashlight) strobe for deaf-accessibility alerts.
///
/// IMPORTANT: the LED is a shared hardware resource. During an active video
/// call the camera owns it, so this service is intended for the INCOMING-CALL
/// screen (camera not yet started). In-call alerts should use the on-screen
/// white flash instead — see CallScreen._showFlash.
///
/// Every method is defensive: if the device has no torch, or another owner
/// holds the camera, calls are swallowed so a missing LED never crashes or
/// blocks the alert (the screen flash + vibration still fire).
class TorchService {
  static final TorchService instance = TorchService._internal();
  TorchService._internal();

  Timer? _strobeTimer;
  bool _on = false;
  bool _available = false;
  bool _checked = false;

  /// Whether a torch was detected on this device. Cached after first check.
  Future<bool> get isAvailable async {
    if (_checked) return _available;
    try {
      _available = await TorchLight.isTorchAvailable();
    } catch (_) {
      _available = false;
    }
    _checked = true;
    return _available;
  }

  Future<void> _enable() async {
    try {
      await TorchLight.enableTorch();
      _on = true;
    } catch (e) {
      debugPrint('[TorchService] enableTorch failed (LED busy/unavailable): $e');
    }
  }

  Future<void> _disable() async {
    try {
      await TorchLight.disableTorch();
    } catch (e) {
      debugPrint('[TorchService] disableTorch failed: $e');
    }
    _on = false;
  }

  /// Starts a repeating on/off torch strobe for an incoming-call alert.
  /// No-op (silently) if no torch is available.
  Future<void> startIncomingCallStrobe() async {
    if (_strobeTimer != null) return;
    if (!await isAvailable) {
      debugPrint('[TorchService] No torch on this device — skipping LED strobe.');
      return;
    }

    // ~1.4 Hz strobe: on 250 ms, off 450 ms.
    await _enable();
    _strobeTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_on) {
        await _disable();
      } else {
        await _enable();
        // Auto-off partway through the cycle for a clear blink.
        Future.delayed(const Duration(milliseconds: 250), () {
          if (_on) _disable();
        });
      }
    });
  }

  /// Stops the strobe and guarantees the LED is left OFF.
  Future<void> stop() async {
    _strobeTimer?.cancel();
    _strobeTimer = null;
    if (_on) await _disable();
  }
}
