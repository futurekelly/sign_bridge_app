import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'data/local/hive_db.dart';
import 'services/ai/inference_manager.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase (Phase 3)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🆕 Hive (Phase 4) — initialize before any repository is used.
    await HiveDb.init();

    // 🤖 TFLite Milestone 1 — Initialize interpreter safely
    final inferenceManager = InferenceManager();
    try {
      debugPrint('Starting AI Engine...');
      await inferenceManager.initialize();
      debugPrint('AI Engine Initialized.');
    } catch (e) {
      debugPrint('CRITICAL: AI Initialization failed: $e');
    }

    runApp(const SignBridgeApp());
  }, (error, stack) {
    debugPrint('GLOBAL ERROR: $error');
    debugPrint(stack.toString());
  });
}
