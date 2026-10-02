import 'dart:async';
import 'package:flutter/foundation.dart';
import 'inference_manager.dart';

/// PredictionStabilizer
/// Gates raw predictions to prevent UI noise using a temporal voting window.
/// Optimized to minimize object allocations during high-frequency inference.
class PredictionStabilizer {
  final StreamController<PredictionResult> _stableCtrl =
      StreamController<PredictionResult>.broadcast();
  Stream<PredictionResult> get stablePredictionStream => _stableCtrl.stream;

  final StreamController<void> _endCtrl = StreamController<void>.broadcast();
  Stream<void> get gestureEndStream => _endCtrl.stream;

  // ── Configuration ──
  static const int      windowSize                = 4;    // Number of frames to look back
  static const int      minVotesRequired          = 2;    // Majority threshold in the window
  static const double   defaultConfidenceThreshold = 0.70; // Global floor before a frame may vote
  static const double   highConfidenceBypass      = 0.92; // If > 92%, trigger faster
  static const Duration cooldownDuration          = Duration(milliseconds: 1200);
  static const Duration gestureEndTimeout         = Duration(milliseconds: 400);

  // ── Per-label confidence gates ──
  // On-device logs showed a few classes act as a "junk drawer": when the hand
  // pose is transitional/ambiguous the model emits e.g. `book` at ~60-90%, which
  // used to pass the flat 0.55 floor and hijack the caption. We gate those
  // classes HIGH so only confident frames vote, and gate the simple demo signs
  // a little LOWER so they trigger readily. Anything not listed uses the default.
  //
  // The deployed model is the 5-word one (see InferenceManager._smallModelLabels:
  // hello, yes, no, help, thank_you), so only those five can actually be produced.
  // The lower entries are kept because the 47-class WLASL model can still be swapped
  // back in via switchToModel(). All five demo signs must be listed — thank_you was
  // missing, so it alone fell through to the stricter default gate.
  static const Map<String, double> _labelThresholds = {
    // Priority demo signs — reliable, so let them fire a touch earlier.
    'hello':     0.60,
    'yes':       0.60,
    'no':        0.60,
    'help':      0.60,
    'thank_you': 0.60,
    'stop':      0.60,
    'please':    0.65,
    'sorry':     0.65,
    // Over-firing / ambiguous classes seen in logs — demand high confidence.
    'book':    0.90,
    'bread':   0.85,
    'student': 0.85,
    'woman':   0.85,
  };

  double _thresholdFor(String label) =>
      _labelThresholds[label] ?? defaultConfidenceThreshold;


  // ── State ──
  // Using a fixed-length list as a circular buffer to avoid Queue/List growth allocations
  final List<PredictionResult?> _window = List.filled(windowSize, null);
  int _windowIdx = 0;
  int _windowCount = 0;

  String?   _lastEmittedLabel;
  DateTime? _lastEmittedTime;
  Timer?    _gestureEndTimer;

  // Reusable map for voting to reduce per-frame object churn
  final Map<String, int> _voteBuffer = {};
  final Map<String, double> _confBuffer = {};

  void processPrediction(PredictionResult result) {
    _gestureEndTimer?.cancel();
    _gestureEndTimer = Timer(gestureEndTimeout, _onGestureEnded);

    // 1. Update circular buffer
    _window[_windowIdx] = result;
    _windowIdx = (_windowIdx + 1) % windowSize;
    if (_windowCount < windowSize) _windowCount++;

    // 2. Tally votes using reused buffers
    _voteBuffer.clear();
    _confBuffer.clear();
    
    for (int i = 0; i < _windowCount; i++) {
      final res = _window[i];
      if (res == null || res.confidence < _thresholdFor(res.label)) continue;
      
      _voteBuffer[res.label] = (_voteBuffer[res.label] ?? 0) + 1;
      _confBuffer[res.label] = (_confBuffer[res.label] ?? 0.0) + res.confidence;
    }

    if (_voteBuffer.isEmpty) return;

    // 3. Find the winner
    String bestLabel = 'unknown';
    int maxVotes = 0;
    _voteBuffer.forEach((label, count) {
      if (count > maxVotes) {
        maxVotes = count;
        bestLabel = label;
      }
    });

    final double sumConf = _confBuffer[bestLabel] ?? 0.0;
    final double avgConf = maxVotes > 0 ? sumConf / maxVotes : 0.0;

    // 4. Verification Logic
    // Single-frame bypass is only allowed for labels at/below the default gate.
    // Junk-drawer classes (raised gates) must win by votes, never on one frame.
    final bypassAllowed = _thresholdFor(result.label) <= defaultConfidenceThreshold;
    final isStrongWinner = maxVotes >= minVotesRequired ||
                          (bypassAllowed &&
                           result.label == bestLabel &&
                           result.confidence > highConfidenceBypass);

    if (isStrongWinner && bestLabel != 'unknown') {
      final now         = DateTime.now();
      final isDuplicate = bestLabel == _lastEmittedLabel;
      final inCooldown  = isDuplicate && _lastEmittedTime != null &&
          now.difference(_lastEmittedTime!) < cooldownDuration;

      if (inCooldown) return;

      _lastEmittedLabel = bestLabel;
      _lastEmittedTime  = now;
      
      _stableCtrl.add(PredictionResult(
        index: result.index,
        label: bestLabel,
        confidence: avgConf,
      ));
      
      debugPrint('[Stabilizer] Emitted: $bestLabel (${(avgConf * 100).toStringAsFixed(0)}%) votes: $maxVotes');
    }
  }

  void _onGestureEnded() {
    if (_lastEmittedLabel != null) {
      debugPrint('[Stabilizer] Gesture ended');
      _endCtrl.add(null);
    }
    _lastEmittedLabel = null;
    // _window is a fixed-length List.filled(...); calling .clear() on it throws
    // UnsupportedError. Reset it in place instead (same as reset()).
    _window.fillRange(0, windowSize, null);
    _windowIdx = 0;
    _windowCount = 0;
  }

  void reset() {
    _gestureEndTimer?.cancel();
    _gestureEndTimer  = null;
    _window.fillRange(0, windowSize, null);
    _windowIdx = 0;
    _windowCount = 0;
    _lastEmittedLabel = null;
    _lastEmittedTime  = null;
  }

  void dispose() {
    _gestureEndTimer?.cancel();
    _stableCtrl.close();
    _endCtrl.close();
  }
}
