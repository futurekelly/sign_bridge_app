import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Required before async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. Without this, no Auth/Firestore call works.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SignBridgeApp());
}