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
  List<HandLandmark> _currentLandmarks = [];
  List<HandLandmark> get currentLandmarks => _currentLandmarks;

  String _prediction = '';
  String get prediction => _prediction;

  static const EventChannel _channel = EventChannel('com.example.sign_bridge/landmarks');
  StreamSubscription? _landmarkSub;

  dynamic _track;

  int _frameCount = 0;
  DateTime? _fpsStartTime;

  /// Normalizes 21 2D hand landmarks matching the Python dataset recording logic.
  /// Performs wrist translation (landmark 0) and max-distance scaling to output 42 floats.
  List<double> normalizeLandmarks(List<HandLandmark> landmarks, {bool isLeft = false}) {
    if (landmarks.isEmpty) return [];

    // 1. Base translation relative to wrist (landmark 0)
    final double basePointerX = landmarks[0].x;
    final double basePointerY = landmarks[0].y;

    final List<double> translatedX = [];
    final List<double> translatedY = [];

    for (final lm in landmarks) {
      double relX = lm.x - basePointerX;
      double relY = lm.y - basePointerY;

      // 2. Left-hand horizontal flip trick (mirror x to look like right hand)
      if (isLeft) {
        relX = relX * -1.0;
      }

      translatedX.add(relX);
      translatedY.add(relY);
    }

    // 3. Scale landmarks by maximum absolute coordinate value
    double maxVal = 0.0;
    for (int i = 0; i < landmarks.length; i++) {
      final double absX = translatedX[i].abs();
      final double absY = translatedY[i].abs();
      if (absX > maxVal) maxVal = absX;
      if (absY > maxVal) maxVal = absY;
    }

    // 4. Flatten to 1D array of 42 parameters
    final List<double> normalized = [];
    for (int i = 0; i < landmarks.length; i++) {
      normalized.add(maxVal != 0 ? (translatedX[i] / maxVal) : 0.0);
      normalized.add(maxVal != 0 ? (translatedY[i] / maxVal) : 0.0);
    }

    return normalized;
  }

  /// Loads the TFLite model and label text map once into memory.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load gesture_model.tflite from assets
      _interpreter = await Interpreter.fromAsset('assets/models/gesture_model.tflite');
      debugPrint('[InferenceManager] Gesture model loaded successfully');

      // 2. Load gesture_labels.txt from assets
      final labelsData = await rootBundle.loadString('assets/labels/gesture_labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      debugPrint('[InferenceManager] Labels loaded successfully');

      _isInitialized = true;
      debugPrint('[InferenceManager] Interpreter initialized');
      debugPrint('[InferenceManager] Number of labels: ${_labels.length}');

      if (_interpreter != null) {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        debugPrint('[InferenceManager] Model input shape: ${inputTensor.shape}');
        debugPrint('[InferenceManager] Model output shape: ${outputTensor.shape}');
      }
    } catch (e) {
      debugPrint('[InferenceManager] Error initializing TFLite interpreter: $e');
      rethrow;
    }
  }

  /// Runs gesture classification inference on exactly 42 normalized landmark float coordinates.
  PredictionResult predict(List<double> landmarks) {
    // Validate input length
    if (landmarks.length != 42) {
      throw ArgumentError(
          'Invalid input length: expected exactly 42 landmark coordinates, but received ${landmarks.length}.');
    }

    if (!_isInitialized || _interpreter == null) {
      throw StateError(
          'Interpreter is not initialized. Call initialize() before calling predict().');
    }

    final stopwatch = Stopwatch()..start();

    // Prepare input tensor of shape [1, 42]
    final input = [landmarks];

    // Prepare output tensor of shape [1, 5]
    final output = List.generate(
        1, (_) => List<double>.filled(_labels.isNotEmpty ? _labels.length : 5, 0.0));

    // Execute TFLite model inference
    _interpreter!.run(input, output);

    stopwatch.stop();
    _inferenceLatency = stopwatch.elapsedMilliseconds;

    // Process output probabilities to find highest confidence match (argmax)
    final probabilities = output[0];
    int maxIndex = 0;
    double maxConfidence = probabilities[0];

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    final label = (maxIndex >= 0 && maxIndex < _labels.length) ? _labels[maxIndex] : 'unknown';

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

  PredictionResult classifyGesture(List<HandLandmark> landmarks) {
    if (landmarks.isEmpty || _processor.activeSimulationLabel == 'idle') {
      return const PredictionResult(index: 0, label: 'unknown', confidence: 0.0);
    }

    double dist(HandLandmark a, HandLandmark b) =>
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));

    final wrist    = landmarks[0];
    final thumbTip = landmarks[4]; // thumb tip

    // ── Extension detection ──────────────────────────────────
    // Thumb extended: tip far from IP joint (idx 2)
    final thumbExtended  = dist(thumbTip, landmarks[2]) > dist(landmarks[3], landmarks[2]) * 1.1;
    final indexExtended  = dist(landmarks[8],  wrist) > dist(landmarks[6],  wrist) * 1.05;
    final middleExtended = dist(landmarks[12], wrist) > dist(landmarks[10], wrist) * 1.05;
    final ringExtended   = dist(landmarks[16], wrist) > dist(landmarks[14], wrist) * 1.05;
    final pinkyExtended  = dist(landmarks[20], wrist) > dist(landmarks[18], wrist) * 1.05;

    // ── Thumb direction (used for yes vs no) ─────────────────
    // y=0 is screen top; lower y = higher on screen = pointing up.
    final thumbPointingUp   = thumbTip.y < wrist.y - 0.04;
    final thumbPointingDown = thumbTip.y > wrist.y + 0.04;

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
      label = 'thank_you'; index = 3;
    } else if (!thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      label = 'help';      index = 4;
    }

    return PredictionResult(
      index: index,
      label: label,
      confidence: label != 'unknown' ? 1.0 : 0.0,
    );
  }

  /// Debug method to verify TFLite execution by feeding a dummy 42-element float array.
  Future<PredictionResult> runDummyPrediction() async {
    if (!_isInitialized) {
      await initialize();
    }
    final dummyLandmarks = List<double>.filled(42, 0.0);
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
    _currentLandmarks = [];
    _prediction = '';
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

      final List<dynamic> list = data as List<dynamic>;
      final List<HandLandmark> landmarks = list.map((item) {
        final Map<dynamic, dynamic> map = item as Map<dynamic, dynamic>;
        return HandLandmark(
          map['id'] as int,
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
          (map['z'] as num).toDouble(),
        );
      }).toList();

      _currentLandmarks = landmarks;

      if (landmarks.isNotEmpty) {
        final normalized = normalizeLandmarks(landmarks);
        if (normalized.isNotEmpty) {
          final result = predict(normalized);
          _prediction = result.label;
          stabilizer.processPrediction(result);
        }
      } else {
        _prediction = '';
      }
      notifyListeners();
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
