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

  Timer? _loopTimer;
  dynamic _track;

  int _frameCount = 0;
  DateTime? _fpsStartTime;
  bool _isCapturing = false;
  Uint8List? _cachedFrameBytes;

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

    double dist(HandLandmark a, HandLandmark b) {
      return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
    }

    final wrist = landmarks[0];

    // Thumb TIP (4) vs IP joint (2) and MCP (3)
    final thumbTip = landmarks[4];
    final thumbJoint2 = landmarks[2];
    final thumbJoint3 = landmarks[3];
    bool thumbExtended = dist(thumbTip, thumbJoint2) > dist(thumbJoint3, thumbJoint2) * 1.1;

    // Index TIP (8) vs PIP joint (6)
    bool indexExtended = dist(landmarks[8], wrist) > dist(landmarks[6], wrist) * 1.05;

    // Middle TIP (12) vs PIP joint (10)
    bool middleExtended = dist(landmarks[12], wrist) > dist(landmarks[10], wrist) * 1.05;

    // Ring TIP (16) vs PIP joint (14)
    bool ringExtended = dist(landmarks[16], wrist) > dist(landmarks[14], wrist) * 1.05;

    // Pinky TIP (20) vs PIP joint (18)
    bool pinkyExtended = dist(landmarks[20], wrist) > dist(landmarks[18], wrist) * 1.05;

    // Determine TSL gesture label matching the student's counterpart rules
    String label = 'unknown';
    int index = 0;

    if (thumbExtended && indexExtended && middleExtended && ringExtended && pinkyExtended) {
      label = 'hello';
      index = 1;
    } else if (!thumbExtended && indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      label = 'yes';
      index = 2;
    } else if (!thumbExtended && indexExtended && middleExtended && !ringExtended && !pinkyExtended) {
      label = 'no';
      index = 3;
    } else if (!thumbExtended && indexExtended && middleExtended && ringExtended && !pinkyExtended) {
      label = 'help';
      index = 4;
    } else if (!thumbExtended && indexExtended && middleExtended && ringExtended && pinkyExtended) {
      label = 'water';
      index = 5;
    } else if (thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      label = 'good';
      index = 6;
    } else if (!thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      label = 'stop';
      index = 7;
    } else if (!thumbExtended && !indexExtended && !middleExtended && !ringExtended && pinkyExtended) {
      label = 'iloveyou';
      index = 8;
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

  /// Optional loop start hook for UI overlay compatibility.
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
    _isCapturing = false;
    _cachedFrameBytes = null;

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _captureAndProcessFrame();
    });
    debugPrint('[InferenceManager] AI Pipeline loop started (100ms loop).');
    notifyListeners();
  }

  /// Stops the frame loop and resets states.
  void stop() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _isProcessing = false;
    _currentLandmarks = [];
    _prediction = '';
    _cachedFrameBytes = null;
    _isCapturing = false;
    stabilizer.reset();
    debugPrint('[InferenceManager] AI Pipeline loop stopped.');
    notifyListeners();
  }

  Future<void> _captureAndProcessFrame() async {
    if (!_isProcessing) return;

    try {
      _frameCount++;

      if (_track != null && !_isCapturing && (_frameCount % 20 == 0 || _cachedFrameBytes == null)) {
        _isCapturing = true;
        try {
          final dynamic frameBuffer = await _track.captureFrame();
          final bytes = (frameBuffer as dynamic).asUint8List() as Uint8List;
          if (bytes.isNotEmpty) {
            _cachedFrameBytes = bytes;
            _imageSizeKb = bytes.length ~/ 1024;
          }
        } catch (e) {
          debugPrint('[InferenceManager] Non-blocking captureFrame error: $e');
        } finally {
          _isCapturing = false;
        }
      }

      final Uint8List activeBytes = _cachedFrameBytes ?? Uint8List(0);

      final now = DateTime.now();
      if (_fpsStartTime != null) {
        final elapsed = now.difference(_fpsStartTime!).inSeconds;
        if (elapsed >= 2) {
          _fps = _frameCount / elapsed;
          _frameCount = 0;
          _fpsStartTime = now;
        }
      }

      // 1. Extract landmarks from active frame using single landmark processor source
      final landmarks = await _processor.extractLandmarks(activeBytes, onLatencyMeasured: (lat) {
        _landmarkLatency = lat;
      });

      _currentLandmarks = landmarks;

      // 2. Deterministic rule-based gesture classification matching web counterpart
      if (landmarks.isNotEmpty) {
        final result = classifyGesture(landmarks);
        if (result.label != 'unknown') {
          _prediction = result.label;
          stabilizer.processPrediction(result);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[InferenceManager] Error in processing loop: $e');
    }
  }

  @override
  void dispose() {
    stop();
    stabilizer.dispose();
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('[InferenceManager] Interpreter disposed cleanly.');
    super.dispose();
  }
}
