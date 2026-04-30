// Centralized runtime permission handling.
// WebRTC needs camera + microphone before peer connection can use them.

import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  /// Requests camera + microphone. Returns true if BOTH are granted.
  static Future<bool> requestCallPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraOk = statuses[Permission.camera]?.isGranted ?? false;
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    return cameraOk && micOk;
  }

  /// Quick check without re-requesting.
  static Future<bool> hasCallPermissions() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    return cam.isGranted && mic.isGranted;
  }
}