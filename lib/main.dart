import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'data/local/hive_db.dart';
import 'services/ai/inference_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (Phase 3)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🆕 Hive (Phase 4) — initialize before any repository is used.
  await HiveDb.init();

  // 🤖 TFLite Milestone 1 — Initialize interpreter & run dummy prediction test
  final inferenceManager = InferenceManager();
  await inferenceManager.initialize();
  await inferenceManager.runDummyPrediction();

  runApp(const SignBridgeApp());
}