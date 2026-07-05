import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('captureFrame Performance and Format Benchmark', (WidgetTester tester) async {
    print('==================================================');
    print('STARTING CAPTURE_FRAME EMPIRICAL BENCHMARK ON DEVICE');
    print('==================================================');

    // 1. Initialize WebRTC Media Stream
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });
      print('Camera stream initialized successfully.');
    } catch (e) {
      print('FAIL: Failed to initialize camera stream: $e');
      expect(true, false);
      return;
    }

    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) {
      print('FAIL: No video tracks found.');
      expect(true, false);
      return;
    }

    final track = tracks.first;
    print('Target video track: ${track.id}, enabled: ${track.enabled}');

    // Warm-up call
    try {
      await track.captureFrame();
      print('Warm-up frame capture successful.');
    } catch (e) {
      print('WARNING: Warm-up capture failed: $e');
    }

    final List<int> durations = [];
    final List<int> sizes = [];
    final List<String> formats = [];
    int successCount = 0;
    int failureCount = 0;
    String? firstException;

    Uint8List? sampleBytes;

    print('Starting 100 consecutive frame captures...');
    final totalSw = Stopwatch()..start();

    for (int i = 0; i < 100; i++) {
      final frameSw = Stopwatch()..start();
      try {
        final dynamic buffer = await track.captureFrame();
        frameSw.stop();

        if (buffer == null) {
          failureCount++;
          continue;
        }

        final Uint8List bytes = (buffer as dynamic).asUint8List() as Uint8List;
        successCount++;
        durations.add(frameSw.elapsedMilliseconds);
        sizes.add(bytes.length);

        if (sampleBytes == null && bytes.isNotEmpty) {
          sampleBytes = bytes;
        }

        // Identify format from header bytes
        String format = 'UNKNOWN';
        if (bytes.length > 4) {
          if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
            format = 'JPEG';
          } else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
            format = 'PNG';
          } else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
            format = 'GIF';
          } else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
            format = 'BMP';
          }
        }
        formats.add(format);

      } catch (e) {
        frameSw.stop();
        failureCount++;
        firstException ??= e.toString();
      }

      // Small delay to simulate loop pacing (like InferenceManager's 100ms loop)
      await Future.delayed(const Duration(milliseconds: 10));
    }

    totalSw.stop();

    print('Captures finished in ${totalSw.elapsedMilliseconds} ms.');
    print('Successful frames: $successCount');
    print('Failed frames: $failureCount');
    if (firstException != null) {
      print('First exception encountered: $firstException');
    }

    if (successCount == 0) {
      print('FAIL: No frames successfully captured.');
      await stream.dispose();
      expect(true, false);
      return;
    }

    // Calculate metrics
    final double avgTime = durations.reduce((a, b) => a + b) / durations.length;
    final int minTime = durations.reduce((a, b) => a < b ? a : b);
    final int maxTime = durations.reduce((a, b) => a > b ? a : b);

    final double avgSize = sizes.reduce((a, b) => a + b) / sizes.length;
    final int minSize = sizes.reduce((a, b) => a < b ? a : b);
    final int maxSize = sizes.reduce((a, b) => a > b ? a : b);

    final String resolvedFormat = formats.first;

    print('\n--- PHASE 1: captureFrame() Metrics ---');
    print('Success Rate: ${(successCount / 100 * 100).toStringAsFixed(1)}%');
    print('Returned Object Type: ByteBuffer / Uint8List');
    print('Average Execution Time: ${avgTime.toStringAsFixed(2)} ms');
    print('Min Execution Time: $minTime ms');
    print('Max Execution Time: $maxTime ms');
    print('Average Byte Length: ${avgSize.toStringAsFixed(1)} bytes (${(avgSize / 1024).toStringAsFixed(1)} KB)');
    print('Min Byte Length: $minSize bytes');
    print('Max Byte Length: $maxSize bytes');
    print('Detected Image Format: $resolvedFormat');

    // --- PHASE 2: Image Compatibility & Decoding Verification ---
    print('\n--- PHASE 2: Decoding Compatibility Verification ---');
    if (sampleBytes != null) {
      print('Attempting to decode sample frame bytes in Dart...');
      final decodeSw = Stopwatch()..start();
      try {
        final decodedImage = img.decodeImage(sampleBytes);
        decodeSw.stop();
        if (decodedImage != null) {
          print('SUCCESS: Frame decoded successfully.');
          print('Image Dimensions: ${decodedImage.width} x ${decodedImage.height}');
          print('Dart Decoding Time: ${decodeSw.elapsedMilliseconds} ms');
        } else {
          print('FAIL: Dart decoder returned null.');
        }
      } catch (e) {
        decodeSw.stop();
        print('FAIL: Exception during Dart decoding: $e');
      }
    } else {
      print('FAIL: No sample bytes available for decoding check.');
    }

    await stream.dispose();
    print('==================================================');
    print('BENCHMARK COMPLETE');
    print('==================================================');
    expect(successCount, greaterThan(0));
  });
}
