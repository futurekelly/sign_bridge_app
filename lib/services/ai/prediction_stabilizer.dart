import 'dart:async';
import 'package:flutter/foundation.dart';
import 'inference_manager.dart';

/// Service responsible for stabilizing raw TFLite gesture predictions.
/// Enforces consecutive frame validation, confidence thresholding, and duplicate cooldown suppression.
class PredictionStabilizer {
  final StreamController<PredictionResult> _stableStreamCtrl =
      StreamController<PredictionResult>.broadcast();

  /// Stream emitting only validated, stabilized gesture predictions.
  Stream<PredictionResult> get stablePredictionStream => _stableStreamCtrl.stream;

  // Configuration thresholds
  static const int requiredConsecutiveFrames = 3;
  static const double minConfidenceThreshold = 0.80;
  static const Duration cooldownDuration = Duration(seconds: 1);

  // Consecutive candidate state tracking
  String? _candidateLabel;
  int _candidateCount = 0;

  // Cooldown & emission state tracking
  String? _lastEmittedLabel;
  DateTime? _lastEmittedTime;

  /// Processes an incoming raw prediction result from InferenceManager.
  void processPrediction(PredictionResult result) {
    // 1. Confidence Validation (Requirement 4)
    if (result.confidence < minConfidenceThreshold) {
      _candidateLabel = null;
      _candidateCount = 0;
      return;
    }

    // 2. Consecutive Prediction Tracking (Requirement 2)
    if (result.label == _candidateLabel) {
      _candidateCount++;
    } else {
      _candidateLabel = result.label;
      _candidateCount = 1;
    }

    final displayCount = _candidateCount > requiredConsecutiveFrames
        ? requiredConsecutiveFrames
        : _candidateCount;
    debugPrint('[PredictionStabilizer] Candidate: ${result.label} ($displayCount/$requiredConsecutiveFrames)');

    // 3. Evaluate if consecutive frame threshold is satisfied
    if (_candidateCount >= requiredConsecutiveFrames) {
      final now = DateTime.now();
      final isDuplicate = (result.label == _lastEmittedLabel);
      bool isCooldownActive = false;

      if (isDuplicate && _lastEmittedTime != null) {
        if (now.difference(_lastEmittedTime!) < cooldownDuration) {
          isCooldownActive = true;
        }
      }

      // 4. Handle Cooldown & Emission (Requirements 3 & 5)
      if (isCooldownActive) {
        debugPrint('[PredictionStabilizer] Cooldown active...');
      } else {
        _lastEmittedLabel = result.label;
        _lastEmittedTime = now;
        debugPrint('[PredictionStabilizer] Stable prediction emitted: ${result.label}');
        _stableStreamCtrl.add(result);
      }
    }
  }

  /// Resets all stabilizer counters and cooldown states.
  void reset() {
    _candidateLabel = null;
    _candidateCount = 0;
    _lastEmittedLabel = null;
    _lastEmittedTime = null;
  }

  /// Closes stream resources safely.
  void dispose() {
    _stableStreamCtrl.close();
  }
}
