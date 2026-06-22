import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'landmark_processor.dart';
import 'gesture_recognition_service.dart';

class InferenceManager extends ChangeNotifier {
  final LandmarkProcessor _processor = LandmarkProcessor();
  final GestureRecognitionService _classifier;

  InferenceManager(this._classifier);

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Performance Stats
  double _fps = 0.0;
  double get fps => _fps;

  int _landmarkLatency = 0;
  int get landmarkLatency => _landmarkLatency;

  int _inferenceLatency = 0;
  int get inferenceLatency => _inferenceLatency;

  int _imageSizeKb = 0;
  int get imageSizeKb => _imageSizeKb;

  // Real-time output data
  List<HandLandmark> _currentLandmarks = [];
  List<HandLandmark> get currentLandmarks => _currentLandmarks;

  String _prediction = '';
  String get prediction => _prediction;

  Timer? _loopTimer;
  MediaStreamTrack? _track;

  // FPS calculation helper variables
  int _frameCount = 0;
  DateTime? _fpsStartTime;

  // Debounce state to avoid flooding translation stream
  String _lastEmittedPrediction = '';

  // Concurrency guard and caching for non-blocking frame capture
  bool _isCapturing = false;
  Uint8List? _cachedFrameBytes;

  /// Starts the frame capture and inference loop on the local video track.
  void start(MediaStreamTrack? track) {
    if (track == null) {
      debugPrint('[InferenceManager] Aborting start: Local video track is null.');
      return;
    }
    _track = track;
    _isProcessing = true;
    _frameCount = 0;
    _fpsStartTime = DateTime.now();
    _fps = 0.0;
    _landmarkLatency = 0;
    _inferenceLatency = 0;
    _imageSizeKb = 0;
    _lastEmittedPrediction = '';
    _isCapturing = false;
    _cachedFrameBytes = null;
    
    // Run the main AI pipeline loop at 10 FPS (100ms intervals) for smooth UI landmarks.
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _captureAndProcessFrame();
    });
    debugPrint('[InferenceManager] AI Pipeline skeleton started (100ms loop).');
    notifyListeners();
  }

  /// Stops the frame loop and resets states.
  void stop() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _isProcessing = false;
    _currentLandmarks = [];
    _prediction = '';
    _lastEmittedPrediction = '';
    _cachedFrameBytes = null;
    _isCapturing = false;
    debugPrint('[InferenceManager] AI Pipeline skeleton stopped.');
    notifyListeners();
  }

  Future<void> _captureAndProcessFrame() async {
    if (!_isProcessing) return;

    try {
      _frameCount++;

      // Asynchronously trigger a native camera frame capture every 20 ticks (~2 seconds)
      // to validate the Method Channel and update frame size without blocking the UI thread.
      if (_track != null && !_isCapturing && (_frameCount % 20 == 0 || _cachedFrameBytes == null)) {
        _isCapturing = true;
        _track!.captureFrame().then((frameBuffer) {
          final bytes = frameBuffer.asUint8List();
          if (bytes.isNotEmpty) {
            _cachedFrameBytes = bytes;
            _imageSizeKb = bytes.length ~/ 1024;
          }
          _isCapturing = false;
        }).catchError((e) {
          debugPrint('[InferenceManager] Non-blocking captureFrame error: $e');
          _isCapturing = false;
        });
      }

      final Uint8List activeBytes = _cachedFrameBytes ?? Uint8List(0);

      // Update FPS calculations every 2 seconds
      final now = DateTime.now();
      if (_fpsStartTime != null) {
        final elapsed = now.difference(_fpsStartTime!).inSeconds;
        if (elapsed >= 2) {
          _fps = _frameCount / elapsed;
          _frameCount = 0;
          _fpsStartTime = now;
        }
      }

      // 1. MediaPipe Landmark Extraction (fast simulation)
      final landmarks = await _processor.extractLandmarks(activeBytes, onLatencyMeasured: (lat) {
        _landmarkLatency = lat;
      });

      _currentLandmarks = landmarks;

      // 2. TFLite Gesture Classification (fast simulation)
      final pred = await _classifier.classifyGesture(landmarks, onLatencyMeasured: (lat) {
        _inferenceLatency = lat;
      });

      _prediction = pred;

      // Debounce and emit predictions to the TranslationController's stream
      if (pred.isNotEmpty && pred != _lastEmittedPrediction) {
        _lastEmittedPrediction = pred;
        _classifier.emitPrediction(pred);
      } else if (pred.isEmpty) {
        _lastEmittedPrediction = '';
      }

      notifyListeners();

    } catch (e) {
      debugPrint('[InferenceManager] Error in processing loop: $e');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
