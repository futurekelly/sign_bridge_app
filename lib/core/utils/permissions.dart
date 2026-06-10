// Centralized runtime permission handling.
// WebRTC needs camera + microphone before peer connection can use them.

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  /// Requests camera + microphone. Returns true if BOTH are granted.
  static Future<bool> requestCallPermissions() async {
    debugPrint('[AppPermissions] requestCallPermissions: Checking current status...');
    final initialCam = await Permission.camera.status;
    final initialMic = await Permission.microphone.status;
    debugPrint('[AppPermissions] requestCallPermissions: Initial status → Camera: $initialCam, Microphone: $initialMic');

    debugPrint('[AppPermissions] requestCallPermissions: Requesting permissions from system OS...');
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraOk = statuses[Permission.camera]?.isGranted ?? false;
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    
    debugPrint('[AppPermissions] requestCallPermissions: Result → Camera Granted: $cameraOk (status: ${statuses[Permission.camera]}), Microphone Granted: $micOk (status: ${statuses[Permission.microphone]})');
    return cameraOk && micOk;
  }

  /// Quick check without re-requesting.
  static Future<bool> hasCallPermissions() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final ok = cam.isGranted && mic.isGranted;
    debugPrint('[AppPermissions] hasCallPermissions query: Camera Granted: ${cam.isGranted} ($cam), Microphone Granted: ${mic.isGranted} ($mic). Overall OK = $ok');
    return ok;
  }
}