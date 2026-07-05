import 'dart:async';
import 'package:flutter/foundation.dart';
import 'inference_manager.dart';

/// PredictionStabilizer
/// Gates raw predictions to prevent UI noise.
/// New: gestureEndStream fires 700 ms after last prediction (hand removed).
class PredictionStabilizer {
  final StreamController<PredictionResult> _stableCtrl =
      StreamController<PredictionResult>.broadcast();
  Stream<PredictionResult> get stablePredictionStream => _stableCtrl.stream;

  final StreamController<void> _endCtrl = StreamController<void>.broadcast();
  Stream<void> get gestureEndStream => _endCtrl.stream;

  static const int      requiredConsecutiveFrames = 2;    // was 3 — faster trigger
  static const double   minConfidenceThreshold    = 0.65; // was 0.75 — fewer resets
  static const Duration cooldownDuration          = Duration(milliseconds: 1500); // was 2s
  static const Duration gestureEndTimeout         = Duration(milliseconds: 500);  // was 700ms

  String?   _candidateLabel;
  int       _candidateCount   = 0;
  String?   _lastEmittedLabel;
  DateTime? _lastEmittedTime;
  Timer?    _gestureEndTimer;

  void processPrediction(PredictionResult result) {
    _gestureEndTimer?.cancel();
    _gestureEndTimer = Timer(gestureEndTimeout, _onGestureEnded);

    if (result.confidence < minConfidenceThreshold) {
      _candidateLabel = null;
      _candidateCount = 0;
      return;
    }

    if (result.label == _candidateLabel) {
      _candidateCount++;
    } else {
      _candidateLabel = result.label;
      _candidateCount = 1;
    }

    final displayed = _candidateCount.clamp(1, requiredConsecutiveFrames);
    debugPrint('[Stabilizer] Candidate: ${result.label} ($displayed/$requiredConsecutiveFrames)');

    if (_candidateCount >= requiredConsecutiveFrames) {
      final now         = DateTime.now();
      final isDuplicate = result.label == _lastEmittedLabel;
      final inCooldown  = isDuplicate && _lastEmittedTime != null &&
          now.difference(_lastEmittedTime!) < cooldownDuration;

      if (inCooldown) {
        debugPrint('[Stabilizer] Cooldown active for ${result.label}');
        return;
      }

      _lastEmittedLabel = result.label;
      _lastEmittedTime  = now;
      debugPrint('[Stabilizer] Emitted: ${result.label} (${(result.confidence * 100).toStringAsFixed(0)}%)');
      _stableCtrl.add(result);
    }
  }

  void _onGestureEnded() {
    if (_lastEmittedLabel != null) {
      debugPrint('[Stabilizer] Gesture ended');
      _endCtrl.add(null);
    }
    _lastEmittedLabel = null;
    _candidateLabel   = null;
    _candidateCount   = 0;
  }

  void reset() {
    _gestureEndTimer?.cancel();
    _gestureEndTimer  = null;
    _candidateLabel   = null;
    _candidateCount   = 0;
    _lastEmittedLabel = null;
    _lastEmittedTime  = null;
  }

  void dispose() {
    _gestureEndTimer?.cancel();
    _stableCtrl.close();
    _endCtrl.close();
  }
}
