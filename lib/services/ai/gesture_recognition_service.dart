import 'dart:async';
import 'dart:math';
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
  
  int _ticksCount = 0;

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
  Future<String> classifyGesture(List<HandLandmark> landmarks, {required Function(int latencyMs) onLatencyMeasured}) async {
    final stopwatch = Stopwatch()..start();

    if (landmarks.isEmpty) {
      stopwatch.stop();
      onLatencyMeasured(0);
      return '';
    }

    // 1. Data Preprocessing & Normalization
    // Normalize coordinates relative to wrist (Landmark 0)
    final wrist = landmarks[0];
    final List<double> relativeCoords = [];
    
    for (final lm in landmarks) {
      relativeCoords.add(lm.x - wrist.x);
      relativeCoords.add(lm.y - wrist.y);
      relativeCoords.add(lm.z - wrist.z);
    }

    // Scale coordinates to fit unit box [-1.0, 1.0]
    double maxVal = 0.0;
    for (final coord in relativeCoords) {
      if (coord.abs() > maxVal) {
        maxVal = coord.abs();
      }
    }

    final List<double> normalizedCoords = [];
    if (maxVal > 0) {
      for (final coord in relativeCoords) {
        normalizedCoords.add(coord / maxVal);
      }
    } else {
      normalizedCoords.addAll(relativeCoords);
    }

    // 2. Simulated Keras/TFLite Classifier Inference
    // Mocking model execution overhead (TFLite typically takes 2-4ms for MLP keypoint inference)
    await Future.delayed(Duration(milliseconds: 2 + Random().nextInt(3)));

    // Pick a prediction dynamically based on joint movements
    _ticksCount++;
    final String predictedClass;
    if (wrist.x < 0.45) {
      predictedClass = 'hello';
    } else if (wrist.x > 0.55) {
      predictedClass = 'thank_you';
    } else {
      // Rotate between confirmative states
      final idx = (_ticksCount ~/ 25) % 3; // every 25 ticks, cycle Yes/No/Help
      predictedClass = ['yes', 'no', 'help'][idx];
    }

    stopwatch.stop();
    onLatencyMeasured(stopwatch.elapsedMilliseconds);

    return predictedClass;
  }
}