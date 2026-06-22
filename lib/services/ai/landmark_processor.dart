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

  /// Processes raw image bytes and returns a list of 21 extracted hand landmarks.
  /// Measures execution latency for performance validation.
  Future<List<HandLandmark>> extractLandmarks(Uint8List frameBytes, {required Function(int latencyMs) onLatencyMeasured}) async {
    final stopwatch = Stopwatch()..start();

    // 1. Simulating image parsing (YUV/RGBA dimensions checks)
    // Normally, we would decode or extract metadata from the byte list here.
    // We add a small mock delay (e.g. 5-10ms) to simulate native decoding overhead.
    await Future.delayed(Duration(milliseconds: 5 + Random().nextInt(5)));

    // 2. Generating 21 landmarks mapping the hand joints
    // We animate them dynamically to represent a hand open/close or tracing wave
    _animationAngle += 0.15;
    if (_animationAngle > 2 * pi) {
      _animationAngle -= 2 * pi;
    }

    final List<HandLandmark> landmarks = [];
    
    // Hand Center (Wrist - Joint 0)
    final double wristX = 0.5 + 0.1 * sin(_animationAngle);
    final double wristY = 0.6 + 0.05 * cos(_animationAngle * 1.5);
    landmarks.add(HandLandmark(0, wristX, wristY, 0.0));

    // Generate 5 fingers (4 joints each: 1-4 thumb, 5-8 index, 9-12 middle, 13-16 ring, 17-20 pinky)
    // We model them spreading out from the wrist
    final fingerAngles = [-0.6, -0.2, 0.1, 0.4, 0.7]; // angles for each finger relative to wrist
    int jointId = 1;

    for (int f = 0; f < 5; f++) {
      final double fAngle = fingerAngles[f] + 0.05 * sin(_animationAngle * 2.0);
      double prevX = wristX;
      double prevY = wristY;
      
      // Joint length scales down as we go to the tip
      final jointLengths = [0.08, 0.06, 0.05, 0.04];

      for (int j = 0; j < 4; j++) {
        final double len = jointLengths[j];
        // Dynamic finger curling
        final double curlFactor = 1.0 - 0.2 * sin(_animationAngle + (f * 0.5));
        
        final double dx = len * sin(fAngle) * curlFactor;
        final double dy = -len * cos(fAngle) * curlFactor;
        
        final double x = (prevX + dx).clamp(0.0, 1.0);
        final double y = (prevY + dy).clamp(0.0, 1.0);
        final double z = -0.02 * j * sin(_animationAngle);

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
