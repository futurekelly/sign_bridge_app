import 'dart:math';
import 'dart:typed_data';

class HandLandmark {
  final int id;
  final double x;
  final double y;
  final double z;
  HandLandmark(this.id, this.x, this.y, this.z);
  @override
  String toString() => 'LM($id: x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)})';
}

/// LandmarkProcessor
/// Gesture shapes:
///   hello     -> open palm (all extended)
///   yes       -> thumb up (thumb only, tip above wrist)
///   no        -> thumb down (thumb only, tip below wrist)
///   thank_you -> peace sign (index + middle)
///   help      -> closed fist (all curled)
class LandmarkProcessor {
  double _animationAngle = 0.0;
  String activeSimulationLabel = 'idle';

  Future<List<HandLandmark>> extractLandmarks(
    Uint8List frameBytes, {
    required Function(int latencyMs) onLatencyMeasured,
  }) async {
    final sw = Stopwatch()..start();
    await Future.delayed(Duration(milliseconds: 5 + Random().nextInt(5)));
    _animationAngle = (_animationAngle + 0.15) % (2 * pi);

    final landmarks = <HandLandmark>[];
    const double wristX = 0.50;
    const double wristY = 0.65;
    landmarks.add(HandLandmark(0, wristX, wristY, 0.0));

    bool thumbExt  = true;
    bool indexExt  = true;
    bool middleExt = true;
    bool ringExt   = true;
    bool pinkyExt  = true;
    double? thumbAngle;

    final label = activeSimulationLabel;
    if (label == 'hello') {
      thumbExt = indexExt = middleExt = ringExt = pinkyExt = true;
    } else if (label == 'yes') {
      thumbExt = true;
      indexExt = middleExt = ringExt = pinkyExt = false;
      thumbAngle = 0.05;
    } else if (label == 'no') {
      thumbExt = true;
      indexExt = middleExt = ringExt = pinkyExt = false;
      thumbAngle = pi - 0.05;
    } else if (label == 'thank_you') {
      thumbExt = false;
      indexExt = true;
      middleExt = true;
      ringExt = pinkyExt = false;
    } else if (label == 'help') {
      thumbExt = indexExt = middleExt = ringExt = pinkyExt = false;
    } else if (label == 'water') {
      thumbExt = false;
      indexExt = middleExt = ringExt = pinkyExt = true;
    } else if (label == 'good') {
      thumbExt = true;
      indexExt = middleExt = ringExt = pinkyExt = false;
    } else if (label == 'stop') {
      thumbExt = indexExt = middleExt = ringExt = pinkyExt = false;
    } else if (label == 'iloveyou') {
      thumbExt = true; indexExt = true;
      middleExt = ringExt = false; pinkyExt = true;
    } else {
      thumbExt  = true;
      indexExt  = (1.0 - 0.25 * sin(_animationAngle))       > 0.85;
      middleExt = (1.0 - 0.25 * sin(_animationAngle + 0.5)) > 0.85;
      ringExt   = (1.0 - 0.25 * sin(_animationAngle + 1.0)) > 0.85;
      pinkyExt  = (1.0 - 0.25 * sin(_animationAngle + 1.5)) > 0.85;
    }

    const defaultAngles = [-0.55, -0.22, 0.04, 0.30, 0.56];
    const jointLengths  = [0.08,  0.06,  0.05, 0.04];

    int jointId = 1;
    for (int f = 0; f < 5; f++) {
      final double fAngle = (f == 0 && thumbAngle != null) ? thumbAngle : defaultAngles[f];
      final bool isExt = switch (f) {
        0 => thumbExt, 1 => indexExt, 2 => middleExt, 3 => ringExt, _ => pinkyExt,
      };
      final double curl = isExt ? 1.0 : 0.28;
      double prevX = wristX;
      double prevY = wristY;
      for (int j = 0; j < 4; j++) {
        final double len = jointLengths[j];
        prevX = (prevX + len * sin(fAngle) * curl).clamp(0.0, 1.0);
        prevY = (prevY - len * cos(fAngle) * curl).clamp(0.0, 1.0);
        landmarks.add(HandLandmark(jointId++, prevX, prevY, -0.01 * j));
      }
    }

    sw.stop();
    onLatencyMeasured(sw.elapsedMilliseconds);
    return landmarks;
  }
}
