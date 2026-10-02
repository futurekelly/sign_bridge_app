import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'landmark_processor.dart';
import 'prediction_stabilizer.dart';

/// Structured result model for TFLite gesture predictions.
class PredictionResult {
  final int index;
  final String label;
  final double confidence;

  const PredictionResult({
    required this.index,
    required this.label,
    required this.confidence,
  });

  @override
  String toString() =>
      'PredictionResult(index: $index, label: "$label", confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// One hand, already normalized into the 42-float shape the deployed model expects.
///
/// The 42-feature model was trained on ONE hand. When MediaPipe sees two we have to
/// choose which to classify, so each detected hand becomes a candidate and the most
/// confident one wins.
class HandCandidate {
  /// MediaPipe hand slot (0 or 1), or -1 when synthesized (e.g. dummy input).
  final int hand;

  /// Whether x was negated to bring a left hand into the right-handed training shape.
  final bool mirrored;

  /// 42 floats: wrist-centred, chirality-canonical, scaled to max |value| == 1.0.
  final List<double> input;

  /// False for the deliberate opposite-chirality probe kept for calibration logging.
  final bool isPrimary;

  const HandCandidate({
    required this.hand,
    required this.mirrored,
    required this.input,
    this.isPrimary = true,
  });

  String get describe => 'hand$hand/${mirrored ? 'mirrored' : 'as-is'}';
}

/// Dedicated TFLite inference service for SignBridge gesture recognition.
/// Maintains clean architecture with zero dependencies on WebRTC, Camera, Translation, or Firebase.
class InferenceManager extends ChangeNotifier {
  // Singleton pattern ensuring a single interpreter instance across the app lifecycle.
  static final InferenceManager _instance = InferenceManager._internal();
  factory InferenceManager([dynamic _]) => _instance;
  InferenceManager._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  /// Returns whether the TFLite interpreter and label map are initialized.
  bool get isInitialized => _isInitialized;

  final LandmarkProcessor _processor = LandmarkProcessor();

  /// Prediction stabilization pipeline service (Milestone 3).
  final PredictionStabilizer stabilizer = PredictionStabilizer();

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // ── Temporal Inference Logic ──
  bool _useTemporalModel = true; 
  bool get useTemporalModel => _useTemporalModel;
  
  static const int _sequenceLength = 15;
  final List<List<double>> _rollingBuffer = [];

  /// Per-hand chirality exactly as MediaPipe reported it: +1 = "Right", -1 = "Left",
  /// 0 = unknown. Indexed by hand slot.
  final List<double> _handedness = [0.0, 0.0];

  // ── Diagnostics ──
  // Last chirality logged, so a change is reported the moment it happens rather than
  // waiting for the next periodic sample.
  double _lastLoggedHandedness0 = double.nan;
  double _lastLoggedHandedness1 = double.nan;

  /// Throttle for the low-confidence feature dump (see [predict]).
  DateTime _lastLowConfDump = DateTime.fromMillisecondsSinceEpoch(0);

  /// Class order of the deployed 42-feature model. Ground truth is the recorder that
  /// built its training set: python_scripts/record_landmarks.py:22 defines
  /// CLASSES = ["hello", "yes", "no", "help", "thank_you"], keyed '0'..'4' to index
  /// 0..4, and python_scripts/class_labels.txt lists the same order. Verified against
  /// keypoint.csv by geometry (class 2 is thumb-DOWN = "no", class 0 is open palm).
  static const List<String> _smallModelLabels = ['hello', 'yes', 'no', 'help', 'thank_you'];

  /// Whether MediaPipe's label for [hand] means the signer's LEFT hand.
  ///
  /// The recorder negated x for every LEFT hand so that both hands share one
  /// right-handed training shape (record_landmarks.py:47-49), so inference has to mirror
  /// the same way: mirror a left hand, leave a right hand alone.
  ///
  /// Which raw label means "left" was settled empirically on the Samsung/Huawei pair, not
  /// by reasoning about the pixel path. The first build swapped the label (on the theory
  /// that MediaPipe assumes a mirrored input while the Android buffer is raw); on device
  /// every frame logged `handedness=1.0` and the swapped branch returned a constant
  /// "no@100%" while the unswapped branch correctly tracked what was being signed
  /// (hello@100%, thank_you@97%). So the label is used as reported, with no swap.
  ///
  /// If a future build ever logs a constant label again, this is the first thing to check.
  bool _realHandIsLeft(int hand) => _handedness[hand] < 0;

  /// Switch between GRU (temporal) and Dense (single-frame) models.
  Future<void> switchToModel({required bool temporal}) async {
    if (_useTemporalModel == temporal) return;
    _isInitialized = false;
    await initialize(useDenseBackup: !temporal);
    _rollingBuffer.clear();
    notifyListeners();
  }

  // Performance Stats for UI overlays
  double _fps = 0.0;
  double get fps => _fps;

  int _landmarkLatency = 0;
  int get landmarkLatency => _landmarkLatency;

  int _inferenceLatency = 0;
  int get inferenceLatency => _inferenceLatency;

  int _imageSizeKb = 0;
  int get imageSizeKb => _imageSizeKb;

  // Real-time output data for UI overlay visualization
  Float32List _currentLandmarks = Float32List(0);
  Float32List get currentLandmarks => _currentLandmarks;

  /// TEMP DIAGNOSTIC (remove before release): last raw payload as received from the
  /// native layer, so the feature dump can report the UNCENTRED wrist next to the
  /// normalized vector. If the wrist is not roughly where a hand sits in frame, the
  /// problem is upstream of Dart.
  Float32List _lastRaw = Float32List(0);

  String _prediction = '';
  String get prediction => _prediction;

  double _confidence = 0.0;
  double get confidence => _confidence;

  DateTime? _lastInferenceTime;
  static const int _inferenceIntervalMs = 40; // 🚨 SMOOTHNESS FIX: Allow up to 25 FPS inference

  static const EventChannel _channel = EventChannel('com.example.sign_bridge/landmarks');
  StreamSubscription? _landmarkSub;

  dynamic _track;

  int _frameCount = 0;
  DateTime? _fpsStartTime;

  /// Wrist-centers raw MediaPipe landmarks to match the training contract.
  ///
  /// Both deployed .tflite models were trained on dataset/landmarks_normalized.csv,
  /// where landmark_extractor.py subtracts hand.landmark[0].x/.y from every point
  /// (per hand). So the model expects f0,f1 == 0.0 for each present hand.
  ///
  /// The native EventChannel sends RAW absolute coords (so the overlay painter can
  /// draw at the real screen position). We therefore center here, on a fresh copy,
  /// ONLY for inference — the painter keeps using the absolute values.
  ///
  /// Layout: 84 floats = hand0 (0..41) + hand1 (42..83), each 21 landmarks * (x,y).
  /// A hand whose wrist (its first x,y) is (0,0) is treated as absent and left zero.
  List<double> processRawLandmarks(List<double> rawFloats) {
    if (rawFloats.length != 84) {
      throw ArgumentError(
          'Invalid input length: expected exactly 84 raw coordinates, but received ${rawFloats.length}.');
    }
    final centered = List<double>.filled(84, 0.0);
    for (int h = 0; h < 2; h++) {
      final base = h * 42;
      
      // 🚨 PERSPECTIVE ALIGNMENT:
      // The archived model (gesture_model_old.tflite) was trained on 
      // standard MediaPipe [X, Y] coordinates.
      // Based on UI calibration, rawFloats[base] is lx, rawFloats[base+1] is ly.
      
      final wristX = rawFloats[base];
      final wristY = rawFloats[base + 1];
      
      if (wristX == 0.0 && wristY == 0.0) continue;
      
      for (int i = 0; i < 21; i++) {
        centered[base + i * 2]     = rawFloats[base + i * 2] - wristX;
        centered[base + i * 2 + 1] = rawFloats[base + i * 2 + 1] - wristY;
      }
    }
    return centered;
  }

  /// Builds the 42-float input for one hand, replicating
  /// python_scripts/record_landmarks.py::normalize_landmarks() — the exact contract the
  /// deployed model was trained under:
  ///
  ///   1. translate: subtract the hand's own wrist (landmark 0)
  ///   2. mirror:    negate x for a LEFT hand, so both hands share one shape
  ///   3. scale:     divide by max |value| so the largest magnitude becomes 1.0
  ///
  /// Step 3 is load-bearing, not cosmetic: every row of keypoint.csv has max|coord| ==
  /// 1.0 exactly. Feeding unscaled image coordinates (a hand spans ~0.2 of the frame)
  /// drives the Dense layers into their bias regime, which is why one class used to win
  /// ~55% of all frames regardless of the sign.
  ///
  /// Returns null when the hand is absent — Kotlin zero-fills, leaving its wrist at (0,0).
  List<double>? _normalizeHand(Float32List raw, int hand, {required bool mirror}) {
    final base = hand * 42;
    final wristX = raw[base];
    final wristY = raw[base + 1];
    if (wristX == 0.0 && wristY == 0.0) return null;

    final out = List<double>.filled(42, 0.0);
    double maxAbs = 0.0;
    for (int i = 0; i < 21; i++) {
      double x = raw[base + i * 2] - wristX;
      final double y = raw[base + i * 2 + 1] - wristY;
      if (mirror) x = -x;
      out[i * 2] = x;
      out[i * 2 + 1] = y;

      final double ax = x.abs();
      if (ax > maxAbs) maxAbs = ax;
      final double ay = y.abs();
      if (ay > maxAbs) maxAbs = ay;
    }

    if (maxAbs > 0) {
      for (int i = 0; i < 42; i++) {
        out[i] /= maxAbs;
      }
    }
    return out;
  }

  /// Turns the two raw hand slots into one normalized candidate per hand.
  ///
  /// Each hand contributes its training-canonical chirality as primary, plus the
  /// deliberate opposite as a non-primary probe. That probe is only ever logged: the
  /// model answers off-chirality input with high confidence but the wrong class (a
  /// mirrored fist scores 1.000 on the wrong label), so confidence cannot be used to
  /// choose a chirality. Logging both is how the handedness convention gets confirmed
  /// against what was actually signed.
  List<HandCandidate> _buildHandCandidates(Float32List raw) {
    final candidates = <HandCandidate>[];
    for (int h = 0; h < 2; h++) {
      final bool mirror = _realHandIsLeft(h);
      final canonical = _normalizeHand(raw, h, mirror: mirror);
      if (canonical == null) continue;

      candidates.add(HandCandidate(hand: h, mirrored: mirror, input: canonical));

      final probe = _normalizeHand(raw, h, mirror: !mirror);
      if (probe != null) {
        candidates.add(HandCandidate(
          hand: h,
          mirrored: !mirror,
          input: probe,
          isPrimary: false,
        ));
      }
    }
    return candidates;
  }

  /// Loads the TFLite model and label text map once into memory.
  Future<void> initialize({bool useDenseBackup = false}) async {
    _useTemporalModel = !useDenseBackup;
    
    try {
      final modelFile = _useTemporalModel 
          ? 'assets/models/gesture_model_gru.tflite' 
          : 'assets/models/gesture_model_dense.tflite';
          
      debugPrint('[InferenceManager] Attempting to load: $modelFile');
      _interpreter = await Interpreter.fromAsset(modelFile);
      debugPrint('[InferenceManager] Model loaded successfully: $modelFile');
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('[InferenceManager] ERROR loading model: $e');
      
      if (_useTemporalModel) {
        debugPrint('[InferenceManager] GRU load failed (likely missing Flex Delegate). FALLING BACK TO DENSE...');
        await initialize(useDenseBackup: true);
        return;
      }
      rethrow;
    }

    try {
      // 2. Load gesture_labels.txt from assets
      final labelsData = await rootBundle.loadString('assets/labels/gesture_labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      
      debugPrint('[InferenceManager] Labels loaded: ${_labels.length}');
      debugPrint('[InferenceManager] Interpreter fully initialized');
    } catch (e) {
      debugPrint('[InferenceManager] Error loading labels: $e');
    }
  }

  /// Runs gesture classification inference.
  /// Handles both single-frame [84] and temporal [15, 84] inputs.
  ///
  /// For the 42-feature one-hand model, pass [candidates] from [_buildHandCandidates]
  /// so every detected hand is scored and the most confident primary wins.
  PredictionResult predict(List<double> landmarks, {List<HandCandidate>? candidates}) {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('Interpreter is not initialized.');
    }

    final stopwatch = Stopwatch()..start();

    if (_useTemporalModel && _rollingBuffer.length < _sequenceLength) {
      // GRU Input: [1, 15, 84] — the window is not full yet, nothing to classify.
      return const PredictionResult(index: 0, label: '', confidence: 0.0);
    }

    // 🔍 DYNAMIC SHAPE FIX: Detect model structure
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;

    final int inputFeatures = inputShape[1]; // 42 or 84
    final int numClasses = outputShape[1];   // 5 or 47

    // Use the 5-word order for the small model; else the 47-label WLASL list.
    final List<String> activeLabels = numClasses == 5 ? _smallModelLabels : _labels;

    // ── One-hand (42-feature) model: score each detected hand ──
    if (inputFeatures == 42) {
      final pool = (candidates != null && candidates.isNotEmpty)
          ? candidates
          : <HandCandidate>[
              // No hand metadata available (dummy input, or an 84-float payload from an
              // older native build). Fall back to slot 0 unmirrored and unscaled.
              HandCandidate(hand: -1, mirrored: false, input: landmarks.sublist(0, 42)),
            ];

      HandCandidate? best;
      PredictionResult bestResult =
          const PredictionResult(index: 0, label: '', confidence: 0.0);
      final probeLog = <String>[];

      for (final candidate in pool) {
        final result = _runInterpreter(
          [candidate.input], outputShape, numClasses, activeLabels,
        );
        probeLog.add('${candidate.describe}=${result.label}'
            '@${(result.confidence * 100).toStringAsFixed(0)}%');
        if (candidate.isPrimary && result.confidence > bestResult.confidence) {
          best = candidate;
          bestResult = result;
        }
      }

      stopwatch.stop();
      _inferenceLatency = stopwatch.elapsedMilliseconds;

      // Chirality, reported the instant it changes. This is what answers "does
      // MediaPipe's label actually track the hand I am signing with?".
      if (_handedness[0] != _lastLoggedHandedness0 ||
          _handedness[1] != _lastLoggedHandedness1) {
        _lastLoggedHandedness0 = _handedness[0];
        _lastLoggedHandedness1 = _handedness[1];
        debugPrint('[InferenceManager] handedness CHANGED -> '
            '(${_handedness[0]}, ${_handedness[1]})');
      }

      if (_frameCount % 40 == 0) {
        debugPrint('[InferenceManager] handedness=(${_handedness[0]}, ${_handedness[1]}) '
            '${probeLog.join("  ")}  -> chose ${best?.describe ?? "none"}');
      }

      // When the model is unsure, dump the exact vector it was shown. That allows an
      // on-device gesture to be compared against the training CSV offline, which is how
      // a genuine model weakness gets told apart from a gesture that was simply recorded
      // as a different shape. Throttled so a held low-confidence pose cannot flood the log.
      // TEMP DIAGNOSTIC (remove before release): dump EVERY prediction, not only the
      // unsure ones. A constant `no@100%` never trips the < 0.85 gate below, so the
      // original dump is blind to exactly the failure being chased here.
      if (best != null) {
        final now = DateTime.now();
        if (now.difference(_lastLowConfDump).inMilliseconds > 700) {
          _lastLowConfDump = now;
          final vec = best.input.map((v) => v.toStringAsFixed(3)).join(',');
          final w0x = _lastRaw.isNotEmpty ? _lastRaw[0].toStringAsFixed(4) : 'n/a';
          final w0y = _lastRaw.length > 1 ? _lastRaw[1].toStringAsFixed(4) : 'n/a';
          final w1x = _lastRaw.length > 42 ? _lastRaw[42].toStringAsFixed(4) : 'n/a';
          final w1y = _lastRaw.length > 43 ? _lastRaw[43].toStringAsFixed(4) : 'n/a';
          debugPrint('[DIAG] label=${bestResult.label} '
              'conf=${bestResult.confidence.toStringAsFixed(3)} '
              'wrist0=($w0x,$w0y) wrist1=($w1x,$w1y) '
              'handedness=(${_handedness[0]},${_handedness[1]}) '
              'hand=${best.describe} v=[$vec]');
        }
      }
      return bestResult;
    }

    // ── Two-hand (84-feature) model ──
    final Object finalInput = _useTemporalModel ? [_rollingBuffer] : [landmarks];
    final result = _runInterpreter(finalInput, outputShape, numClasses, activeLabels);

    stopwatch.stop();
    _inferenceLatency = stopwatch.elapsedMilliseconds;
    return result;
  }

  /// Runs the interpreter once and reduces one softmax row to a [PredictionResult].
  PredictionResult _runInterpreter(
    Object input,
    List<int> outputShape,
    int numClasses,
    List<String> activeLabels,
  ) {
    // Prepare Output: match the model's head count and class count.
    final int outerDim = outputShape[0];
    final Object outputBuffer = List.generate(
      outerDim,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    // Execute TFLite model inference
    _interpreter!.run(input, outputBuffer);

    final List<double> probabilities = (outputBuffer as List<List<double>>)[0];

    int maxIndex = 0;
    double maxConfidence = probabilities[0];

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    final label = (maxIndex >= 0 && maxIndex < activeLabels.length) ? activeLabels[maxIndex] : 'unknown';

    return PredictionResult(
      index: maxIndex,
      label: label,
      confidence: maxConfidence,
    );
  }

  /// Expose method to change simulated gesture landmark patterns
  void setSimulationLabel(String label) {
    _processor.activeSimulationLabel = label;
    notifyListeners();
  }

  PredictionResult classifyGesture(Float32List landmarks) {
    if (landmarks.isEmpty || _processor.activeSimulationLabel == 'idle') {
      return const PredictionResult(index: 0, label: 'unknown', confidence: 0.0);
    }

    double dist(double x1, double y1, double x2, double y2) =>
        sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));

    final wristX    = landmarks[0];
    final wristY    = landmarks[1];
    final thumbTipX = landmarks[4 * 2]; 
    final thumbTipY = landmarks[4 * 2 + 1]; 

    // ── Extension detection ──────────────────────────────────
    final thumbExtended  = dist(thumbTipX, thumbTipY, landmarks[2 * 2], landmarks[2 * 2 + 1]) > dist(landmarks[3 * 2], landmarks[3 * 2 + 1], landmarks[2 * 2], landmarks[2 * 2 + 1]) * 1.1;
    final indexExtended  = dist(landmarks[8 * 2], landmarks[8 * 2 + 1], wristX, wristY) > dist(landmarks[6 * 2], landmarks[6 * 2 + 1], wristX, wristY) * 1.05;
    final middleExtended = dist(landmarks[12 * 2], landmarks[12 * 2 + 1], wristX, wristY) > dist(landmarks[10 * 2], landmarks[10 * 2 + 1], wristX, wristY) * 1.05;
    final ringExtended   = dist(landmarks[16 * 2], landmarks[16 * 2 + 1], wristX, wristY) > dist(landmarks[14 * 2], landmarks[14 * 2 + 1], wristX, wristY) * 1.05;
    final pinkyExtended  = dist(landmarks[20 * 2], landmarks[20 * 2 + 1], wristX, wristY) > dist(landmarks[18 * 2], landmarks[18 * 2 + 1], wristX, wristY) * 1.05;

    // ── Thumb direction (used for yes vs no) ─────────────────
    final thumbPointingUp   = thumbTipY < wristY - 0.04;
    final thumbPointingDown = thumbTipY > wristY + 0.04;

    // ── Classification (matches new LandmarkProcessor shapes) ─
    //   hello     → all 5 extended
    //   yes       → thumb only, tip above wrist (👍 thumb up)
    //   no        → thumb only, tip below wrist (👎 thumb down)
    //   thank_you → index + middle (✌️ peace sign)
    //   help      → all curled fist
    String label = 'unknown';
    int    index = 0;

    if (thumbExtended && indexExtended && middleExtended && ringExtended && pinkyExtended) {
      label = 'hello';     index = 0;
    } else if (thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended && thumbPointingUp) {
      label = 'yes';       index = 1;
    } else if (thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended && thumbPointingDown) {
      label = 'no';        index = 2;
    } else if (!thumbExtended && indexExtended && middleExtended && !ringExtended && !pinkyExtended) {
      label = 'thank_you'; index = 4;
    } else if (!thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      label = 'help';      index = 3;
    }

    return PredictionResult(
      index: index,
      label: label,
      confidence: label != 'unknown' ? 1.0 : 0.0,
    );
  }

  /// Debug method to verify TFLite execution by feeding a dummy 84-element float array.
  Future<PredictionResult> runDummyPrediction() async {
    if (!_isInitialized) {
      await initialize();
    }
    final dummyLandmarks = List<double>.filled(84, 0.0);
    final result = predict(dummyLandmarks);
    debugPrint('[InferenceManager] Debug dummy prediction executed successfully: $result');
    return result;
  }

  /// Start native MediaPipe landmark subscription.
  void start([dynamic track]) {
    if (track == null && _track == null) {
      debugPrint('[InferenceManager] Aborting start: Local video track is null.');
      return;
    }
    if (track != null) _track = track;
    _isProcessing = true;
    _frameCount = 0;
    _fpsStartTime = DateTime.now();
    _fps = 0.0;
    _landmarkLatency = 0;
    _inferenceLatency = 0;
    _imageSizeKb = 0;

    // Log stabilized predictions and gesture end events for runtime debugging
    stabilizer.stablePredictionStream.listen((res) {
      debugPrint('[InferenceManager] Stabilized label: ${res.label} (${(res.confidence * 100).toStringAsFixed(1)}%)');
    });
    stabilizer.gestureEndStream.listen((_) {
      debugPrint('[InferenceManager] Gesture ended (stabilizer)');
      // Clear UI prediction when stabilizer reports gesture end
      _prediction = '';
      notifyListeners();
    });

    _landmarkSub?.cancel();
    _landmarkSub = _channel.receiveBroadcastStream().listen((data) {
      _processNativeLandmarks(data);
    }, onError: (e) {
      debugPrint('[InferenceManager] Landmark stream error: $e');
    });
    debugPrint('[InferenceManager] Native landmark EventChannel stream started.');
    notifyListeners();
  }

  /// Stops the landmark subscription and resets states.
  void stop() {
    _landmarkSub?.cancel();
    _landmarkSub = null;
    _isProcessing = false;
    _currentLandmarks = Float32List(0);
    _prediction = '';
    _rollingBuffer.clear();
    stabilizer.reset();
    debugPrint('[InferenceManager] Native landmark EventChannel stream stopped.');
    notifyListeners();
  }

  void _processNativeLandmarks(dynamic data) {
    if (!_isProcessing) return;

    try {
      _frameCount++;
      final now = DateTime.now();
      if (_fpsStartTime != null) {
        final elapsed = now.difference(_fpsStartTime!).inSeconds;
        if (elapsed >= 2) {
          _fps = _frameCount / elapsed;
          _frameCount = 0;
          _fpsStartTime = now;
        }
      }

      // Consume native stream. Current native build sends 88 floats — 84 raw x,y
      // coordinates plus 4 metadata floats (per-hand chirality and score). An older
      // build sent a bare 84; accept both so the app still runs against it.
      final Float32List payload = data as Float32List;

      if (payload.length != 84 && payload.length != 88) {
        debugPrint('[InferenceManager] Invalid data length: ${payload.length}');
        return;
      }

      final Float32List rawFloats =
          payload.length == 88 ? Float32List.sublistView(payload, 0, 84) : payload;

      if (payload.length == 88) {
        _handedness[0] = payload[84];
        _handedness[1] = payload[85];
      } else {
        _handedness[0] = 0.0;
        _handedness[1] = 0.0;
      }

      // 🔍 FINALIST DEBUG: Log receiving landmarks
      if (_frameCount % 20 == 0) {
        debugPrint('[InferenceManager] Received landmarks: Hand presence = ${rawFloats[0] != 0.0}');
      }

      // Painter uses ABSOLUTE coords (real screen position).
      _currentLandmarks = rawFloats;
      _lastRaw = rawFloats; // TEMP DIAGNOSTIC (remove before release)

      // If the input is all zeros → no hands present.
      final bool allZeros = rawFloats.every((v) => v == 0.0);
      if (allZeros) {
        _rollingBuffer.clear(); // Reset temporal memory if hands disappear
        
        final timeSinceLast = _lastInferenceTime == null 
            ? _inferenceIntervalMs + 1 
            : now.difference(_lastInferenceTime!).inMilliseconds;
        
        if (timeSinceLast >= _inferenceIntervalMs) {
          try {
            stabilizer.reset();
          } catch (_) {}
          _prediction = '';
          _confidence = 0.0;
          _lastInferenceTime = now;
          notifyListeners();
        }
        return;
      }

      // Model needs WRIST-CENTERED coords (training contract). Center a copy;
      // painter keeps the absolute values above.
      final centered = processRawLandmarks(rawFloats);

      // Update Rolling Buffer (centered frames for the temporal model).
      _rollingBuffer.add(centered);
      if (_rollingBuffer.length > _sequenceLength) {
        _rollingBuffer.removeAt(0);
      }

      // ── Inference Throttling (10 FPS) ──
      final timeSinceLast = _lastInferenceTime == null 
          ? _inferenceIntervalMs + 1 
          : now.difference(_lastInferenceTime!).inMilliseconds;
      
      final shouldRunInference = timeSinceLast >= _inferenceIntervalMs;

      if (shouldRunInference) {
        // One-hand model: score every detected hand and keep the most confident, so a
        // resting hand in frame cannot shadow the one actually signing.
        final result = predict(centered, candidates: _buildHandCandidates(rawFloats));
        
        // Handle window cold-start
        if (_useTemporalModel && _rollingBuffer.length < _sequenceLength) {
          notifyListeners();
          return;
        }

        _prediction = result.label;
        _confidence = result.confidence;
        _lastInferenceTime = now;
        debugPrint('[InferenceManager] Predicted: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
        stabilizer.processPrediction(result);
        notifyListeners();
      } else {
        // Just update landmarks for visual smoothness even if not inferring
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InferenceManager] Error processing native landmarks: $e');
    }
  }

  @override
  void dispose() {
    _landmarkSub?.cancel();
    stop();
    stabilizer.dispose();
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('[InferenceManager] Interpreter disposed cleanly.');
    super.dispose();
  }
}
