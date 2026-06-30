import 'dart:math';
import 'package:flutter/foundation.dart';

class HandLandmark {
  final int id;
  final double x; // Normalized 0.0 to 1.0 (relative to frame width)
  final double y; // Normalized 0.0 to 1.0 (relative to frame height)
  final double z; // Normalized relative depth

  HandLandmark(this.id, this.x, this.y, this.z);

  @override
  String toString() => 'LM($id: x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)})';
}

class LandmarkProcessor {
  // Angle used to simulate coordinate movements over time
  double _animationAngle = 0.0;
  String activeSimulationLabel = 'idle';

  /// Processes raw image bytes and returns a list of 21 extracted hand landmarks.
  /// Measures execution latency for performance validation.
  Future<List<HandLandmark>> extractLandmarks(Uint8List frameBytes, {required Function(int latencyMs) onLatencyMeasured}) async {
    final stopwatch = Stopwatch()..start();

    // 1. Simulating image parsing (YUV/RGBA dimensions checks)
    await Future.delayed(Duration(milliseconds: 5 + Random().nextInt(5)));

    // 2. Generating 21 landmarks mapping the hand joints
    _animationAngle += 0.15;
    if (_animationAngle > 2 * pi) {
      _animationAngle -= 2 * pi;
    }

    final List<HandLandmark> landmarks = [];
    
    // Hand Center (Wrist - Joint 0)
    const double wristX = 0.5;
    const double wristY = 0.65;
    landmarks.add(HandLandmark(0, wristX, wristY, 0.0));

    // Determine finger extensions based on active simulation label (Milestone 2/3 TSL vocabulary)
    bool thumbExt = true;
    bool indexExt = true;
    bool middleExt = true;
    bool ringExt = true;
    bool pinkyExt = true;

    if (activeSimulationLabel == 'hello') {
      thumbExt = indexExt = middleExt = ringExt = pinkyExt = true;
    } else if (activeSimulationLabel == 'yes') {
      thumbExt = middleExt = ringExt = pinkyExt = false;
      indexExt = true;
    } else if (activeSimulationLabel == 'no') {
      thumbExt = ringExt = pinkyExt = false;
      indexExt = middleExt = true;
    } else if (activeSimulationLabel == 'help') {
      thumbExt = pinkyExt = false;
      indexExt = middleExt = ringExt = true;
    } else if (activeSimulationLabel == 'water') {
      thumbExt = false;
      indexExt = middleExt = ringExt = pinkyExt = true;
    } else if (activeSimulationLabel == 'good') {
      thumbExt = true;
      indexExt = middleExt = ringExt = pinkyExt = false;
    } else if (activeSimulationLabel == 'stop') {
      thumbExt = indexExt = middleExt = ringExt = pinkyExt = false;
    } else if (activeSimulationLabel == 'iloveyou') {
      thumbExt = indexExt = middleExt = ringExt = false;
      pinkyExt = true;
    } else {
      // Idle animated curl
      thumbExt = true;
      indexExt = (1.0 - 0.25 * sin(_animationAngle)) > 0.85;
      middleExt = (1.0 - 0.25 * sin(_animationAngle + 0.5)) > 0.85;
      ringExt = (1.0 - 0.25 * sin(_animationAngle + 1.0)) > 0.85;
      pinkyExt = (1.0 - 0.25 * sin(_animationAngle + 1.5)) > 0.85;
    }

    // Generate 5 fingers (4 joints each)
    // Angles relative to wrist base
    final fingerAngles = [-0.65, -0.25, 0.05, 0.35, 0.65];
    int jointId = 1;

    for (int f = 0; f < 5; f++) {
      final double fAngle = fingerAngles[f];
      double prevX = wristX;
      double prevY = wristY;
      
      final jointLengths = [0.08, 0.06, 0.05, 0.04];
      bool isExt = true;
      if (f == 0) {
        isExt = thumbExt;
      } else if (f == 1) {
        isExt = indexExt;
      } else if (f == 2) {
        isExt = middleExt;
      } else if (f == 3) {
        isExt = ringExt;
      } else if (f == 4) {
        isExt = pinkyExt;
      }

      final double curlFactor = isExt ? 1.0 : 0.35;

      for (int j = 0; j < 4; j++) {
        final double len = jointLengths[j];
        final double dx = len * sin(fAngle) * curlFactor;
        final double dy = -len * cos(fAngle) * curlFactor;
        
        final double x = (prevX + dx).clamp(0.0, 1.0);
        final double y = (prevY + dy).clamp(0.0, 1.0);
        final double z = -0.01 * j;

        landmarks.add(HandLandmark(jointId++, x, y, z));
        prevX = x;
        prevY = y;
      }
    }

    stopwatch.stop();
    onLatencyMeasured(stopwatch.elapsedMilliseconds);

    return landmarks;
  }
}
