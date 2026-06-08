import 'dart:async';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/enums.dart';
import '../../data/models/translation_message.dart';

// Message passing structure for the Isolate
class _IsolateData {
  final SendPort sendPort;
  final List<Uint8List> planes;
  final int width;
  final int height;
  final String format; // 'yuv420' or 'bgra8888'

  _IsolateData({
    required this.sendPort,
    required this.planes,
    required this.width,
    required this.height,
    required this.format,
  });
}

class GestureRecognitionService {
  final _resultCtrl = StreamController<TranslationMessage>.broadcast();
  final _statusCtrl = StreamController<AiStatus>.broadcast();

  Stream<TranslationMessage> get resultStream => _resultCtrl.stream;
  Stream<AiStatus> get statusStream => _statusCtrl.stream;

  bool _running = false;
  Interpreter? _interpreter;
  List<String> _labels = [];
  CameraController? _cameraCtrl;
  bool _isProcessingFrame = false;

  // Isolate state
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _isolateReceivePort;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _statusCtrl.add(AiStatus.recognizing);

    try {
      // 1. Load labels
      final labelData = await rootBundle.loadString('assets/labels/gesture_labels.txt');
      _labels = labelData.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // 2. Load model (wrapped in try-catch because empty placeholder file will throw)
      try {
        _interpreter = await Interpreter.fromAsset('assets/models/gesture_model.tflite');
        await _spawnIsolate();
      } catch (e) {
        debugPrint('[GestureAI] Placeholder/Empty model detected. Bypassing TFLite inference: $e');
        _startSimulation();
        return; // Skip camera setup if model is invalid (since WebRTC uses it)
      }

      // 3. Setup Camera
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, 
                                          orElse: () => cameras.first);
      
      _cameraCtrl = CameraController(frontCam, ResolutionPreset.low, enableAudio: false);
      await _cameraCtrl!.initialize();

      // 4. Start image stream (throttle to ~3 fps)
      int frameCount = 0;
      _cameraCtrl!.startImageStream((CameraImage image) async {
        if (!_running || _isProcessingFrame) return;
        
        frameCount++;
        if (frameCount % 10 != 0) return; // Process ~1 in 10 frames

        _isProcessingFrame = true;
        await _processFrame(image);
        _isProcessingFrame = false;
      });

    } catch (e) {
      debugPrint('[GestureAI] Setup failed (Camera likely in use by WebRTC): $e');
      debugPrint('[GestureAI] Falling back to simulation mode.');
      _startSimulation();
    }
  }

  // --- Isolate Setup ---
  Future<void> _spawnIsolate() async {
    _isolateReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(_imageProcessingIsolate, _isolateReceivePort!.sendPort);

    // Listen for responses from the Isolate
    _isolateReceivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is List) {
        // message is the RGB Tensor output from the Isolate
        _runInference(message);
      }
    });
  }

  // --- Background Isolate Entry Point ---
  static void _imageProcessingIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort); // Send port back to main thread

    receivePort.listen((message) {
      if (message is _IsolateData) {
        // TODO: Convert YUV420/BGRA8888 planes to a 224x224x3 RGB float array
        // using the 'image' package. For this placeholder phase, we instantly 
        // return a dummy tensor of 0s to prove the Isolate communication works.
        final dummyTensor = List.generate(1, (i) => 
                              List.generate(224, (j) => 
                                List.generate(224, (k) => 
                                  List.generate(3, (l) => 0.0))));
        message.sendPort.send(dummyTensor);
      }
    });
  }

  // --- Frame Pipeline ---
  Future<void> _processFrame(CameraImage image) async {
    if (_isolateSendPort == null) return;

    final format = image.format.group == ImageFormatGroup.yuv420 ? 'yuv420' : 'bgra8888';
    final planes = image.planes.map((p) => p.bytes).toList();

    // Send raw bytes to background isolate
    final responsePort = ReceivePort();
    _isolateSendPort!.send(_IsolateData(
      sendPort: responsePort.sendPort,
      planes: planes,
      width: image.width,
      height: image.height,
      format: format,
    ));

    // Wait for the processed RGB Tensor
    final rgbTensor = await responsePort.first;
    _runInference(rgbTensor as List);
  }

  void _runInference(List rgbTensor) {
    if (_interpreter == null || _labels.isEmpty) return;
    try {
      // Run TFLite
      var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(rgbTensor, output);

      // Argmax
      List<double> probabilities = (output[0] as List).cast<double>();
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      final label = _labels[maxIndex];
      _resultCtrl.add(TranslationMessage(
        text: label,
        source: 'gesture',
        language: 'en',
        gifKey: label,
      ));

    } catch (e) {
      debugPrint('[GestureAI] Inference error: $e');
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _statusCtrl.add(AiStatus.idle);

    _simTimer?.cancel();
    _simTimer = null;
    
    if (_cameraCtrl != null) {
      if (_cameraCtrl!.value.isStreamingImages) {
        await _cameraCtrl!.stopImageStream();
      }
      await _cameraCtrl!.dispose();
      _cameraCtrl = null;
    }
    
    _isolate?.kill();
    _isolate = null;
    _interpreter?.close();
    _interpreter = null;
  }

  Future<void> dispose() async {
    await stop();
    await _resultCtrl.close();
    await _statusCtrl.close();
  }

  // --- Simulation Fallback ---
  Timer? _simTimer;
  final _rng = Random();

  void _startSimulation() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!_running) return;
      final vocab = _labels.isNotEmpty ? _labels : ['hello', 'thank_you', 'help', 'yes', 'no'];
      final label = vocab[_rng.nextInt(vocab.length)];
      _resultCtrl.add(TranslationMessage(
        text: label,
        source: 'gesture',
        language: 'en',
        gifKey: label, // mapper will validate the asset key
      ));
    });
  }
}