import 'dart:async';
import 'package:flutter/foundation.dart';

/// PerformanceMonitor
/// Research-grade metric collector for SignBridge.
/// Tracks Latency, FPS, and Connection speeds for dissertation data.
class PerformanceMonitor extends ChangeNotifier {
  static final PerformanceMonitor instance = PerformanceMonitor._internal();
  PerformanceMonitor._internal();

  // ── Connection Metrics ──
  int _iceConnectionTimeMs = 0;
  int get iceConnectionTimeMs => _iceConnectionTimeMs;

  // ── Inference Metrics ──
  double _inferenceFps = 0.0;
  double get inferenceFps => _inferenceFps;

  int _lastInferenceLatencyMs = 0;
  int get lastInferenceLatencyMs => _lastInferenceLatencyMs;

  // ── End-to-End Latency (Gesture to remote TTS) ──
  // Key research metric: How long for a Deaf user's sign to become Hearing user's speech.
  final List<int> _e2eLatencies = [];
  double get avgE2ELatencyMs => _e2eLatencies.isEmpty 
      ? 0.0 
      : _e2eLatencies.reduce((a, b) => a + b) / _e2eLatencies.length;

  // ── Recording state (for Day 2 dataset building) ──
  bool _isRecordingSession = false;
  bool get isRecordingSession => _isRecordingSession;

  void setIceConnectionTime(int ms) {
    _iceConnectionTimeMs = ms;
    debugPrint('[Perf] ICE Connection established in ${ms}ms');
    notifyListeners();
  }

  void updateInferenceStats(double fps, int latencyMs) {
    _inferenceFps = fps;
    _lastInferenceLatencyMs = latencyMs;
    notifyListeners();
  }

  /// Records a "Glass-to-Glass" latency sample.
  void recordE2ELatency(int ms) {
    _e2eLatencies.add(ms);
    if (_e2eLatencies.length > 50) _e2eLatencies.removeAt(0);
    debugPrint('[Perf] E2E Latency: ${ms}ms (Avg: ${avgE2ELatencyMs.toStringAsFixed(1)}ms)');
    notifyListeners();
  }

  void startRecordingSession() {
    _isRecordingSession = true;
    notifyListeners();
  }

  void stopRecordingSession() {
    _isRecordingSession = false;
    notifyListeners();
  }

  void clearMetrics() {
    _e2eLatencies.clear();
    _iceConnectionTimeMs = 0;
    _inferenceFps = 0.0;
    _lastInferenceLatencyMs = 0;
    notifyListeners();
  }
}
