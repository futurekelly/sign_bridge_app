import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/enums.dart';
import '../../data/models/translation_message.dart';
import 'landmark_processor.dart';
import 'inference_manager.dart';

class GestureRecognitionService {
  // ── Public streams (the contract) ──
  final _resultCtrl = StreamController<TranslationMessage>.broadcast();
  final _statusCtrl = StreamController<AiStatus>.broadcast();

  Stream<TranslationMessage> get resultStream => _resultCtrl.stream;
  Stream<AiStatus> get statusStream => _statusCtrl.stream;

  // ── Internal state ──
  bool _running = false;
  bool get isRunning => _running;
  // InferenceManager coordinates the frame capture loop and landmark pipeline
  late final InferenceManager inferenceManager;

  GestureRecognitionService() {
    inferenceManager = InferenceManager(this);
    debugPrint('[GestureAI] GestureRecognitionService initialized.');
  }

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  Future<void> start({MediaStreamTrack? localVideoTrack}) async {
    if (_running) return;
    _running = true;
    _statusCtrl.add(AiStatus.recognizing);
    debugPrint('[GestureAI] Starting AI pipeline skeleton...');

    // Start frame loop on the provided video track
    inferenceManager.start(localVideoTrack);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _statusCtrl.add(AiStatus.idle);
    debugPrint('[GestureAI] Stopping AI pipeline skeleton...');

    // Stop frame loop
    inferenceManager.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _resultCtrl.close();
    await _statusCtrl.close();
    debugPrint('[GestureAI] GestureRecognitionService disposed.');
  }

  // Helper for InferenceManager to publish predictions
  void emitPrediction(String prediction) {
    if (!_running) return;
    debugPrint('[GestureAI] Emitting prediction: $prediction');
    _resultCtrl.add(TranslationMessage(
      text: prediction,
      source: 'gesture',
      language: 'en', // default language
      gifKey: prediction, // mapped at translation controller
    ));
  }

  // Helper for InferenceManager to publish status changes
  void emitStatus(AiStatus status) {
    if (!_running) return;
    _statusCtrl.add(status);
  }

  /// Takes hand landmarks, normalizes them, and runs gesture classification.
  /// Measures classifier latency for performance validation.
  ///
  /// Note: Real-time inference is now handled by InferenceManager loop.
  /// This method is kept for legacy compatibility if needed.
  Future<String> classifyGesture(List<HandLandmark> landmarks, {required Function(int latencyMs) onLatencyMeasured}) async {
    final stopwatch = Stopwatch()..start();

    if (landmarks.isEmpty) {
      stopwatch.stop();
      onLatencyMeasured(0);
      return '';
    }

    final result = inferenceManager.classifyGesture(landmarks);
    
    stopwatch.stop();
    onLatencyMeasured(stopwatch.elapsedMilliseconds);

    return result.label;
  }
}