// GestureRecognitionService
// ════════════════════════════════════════════════════════════════════
// ⭐ THIS IS THE SOLE TFLITE INTEGRATION POINT IN THE ENTIRE APP. ⭐
//
// Current behavior (Phase 4): SIMULATION
//   → emits random labels from a fixed vocabulary every ~1.2s
//
// Future behavior (drop-in replacement):
//   → load assets/models/gesture_model.tflite
//   → run inference on camera frames
//   → emit TranslationMessage with the predicted label
//
// CONTRACT (must NOT change when real model is added):
//   • start()          : begin emitting
//   • stop()           : pause emitting + free resources
//   • resultStream     : Stream<TranslationMessage>
//   • statusStream     : Stream<AiStatus>
//
// As long as this contract holds, NO code in UI/Controllers needs
// to change when we swap simulation for real TFLite inference.
// ════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';
import '../../core/enums.dart';
import '../../data/models/translation_message.dart';

class GestureRecognitionService {
  // ── Public streams (the contract) ──
  final _resultCtrl = StreamController<TranslationMessage>.broadcast();
  final _statusCtrl = StreamController<AiStatus>.broadcast();

  Stream<TranslationMessage> get resultStream => _resultCtrl.stream;
  Stream<AiStatus> get statusStream => _statusCtrl.stream;

  // ── Internal state ──
  Timer? _simTimer;
  bool _running = false;
  final _rng = Random();

  // Demo vocabulary — must match assets/labels/gesture_labels.txt.
  static const List<String> _vocab = [
    'hello',
    'thank_you',
    'help',
    'yes',
    'no',
  ];

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _statusCtrl.add(AiStatus.recognizing);

    // ────────────────────────────────────────────────────────────────
    // 🔌 REAL MODEL INTEGRATION GOES HERE (FUTURE):
    //
    // final interpreter = await Interpreter.fromAsset(
    //     'assets/models/gesture_model.tflite');
    //
    // 1. Subscribe to camera frame stream (cameraController.startImageStream)
    // 2. For each frame:
    //      - convert YUV/NV21 → RGB tensor
    //      - resize to model input shape (e.g. 224×224)
    //      - normalize
    //      - run interpreter.run(input, output)
    //      - argmax → label
    // 3. Throttle to ~2 fps (architecture spec: 300–1500ms latency)
    // 4. Emit:
    //      _resultCtrl.add(TranslationMessage(
    //         text: label, source: 'gesture',
    //         language: 'en', gifKey: label));
    //
    // The simulation below is REPLACED by that block when the model
    // file is available. Nothing else in the app changes.
    // ────────────────────────────────────────────────────────────────

    _startSimulation();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _simTimer?.cancel();
    _simTimer = null;
    _statusCtrl.add(AiStatus.idle);

    // Future: dispose interpreter + stop camera image stream here.
  }

  Future<void> dispose() async {
    await stop();
    await _resultCtrl.close();
    await _statusCtrl.close();
  }

  // ─────────────────────────────────────────────
  // SIMULATION (Phase 4 only — to be replaced)
  // ─────────────────────────────────────────────

  void _startSimulation() {
    // Emit a fake recognition every ~1.2s, jittered slightly to
    // mimic real model variability (300–1500ms acceptable per spec).
    _simTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!_running) return;
      final label = _vocab[_rng.nextInt(_vocab.length)];
      _resultCtrl.add(TranslationMessage(
        text: label,
        source: 'gesture',
        language: 'en',
        gifKey: label, // mapper will validate the asset key
      ));
    });
  }
}