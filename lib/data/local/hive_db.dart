// HiveDb — initializes Hive and opens boxes used by the app.
// Call once on app startup before any repository is used.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/translation_message.dart';

class HiveDb {
  static const String historyBox = 'translation_history';
  static const String settingsBox = 'app_settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TranslationMessageAdapter());
    await Hive.openBox<TranslationMessage>(historyBox);
    // General-purpose settings box (stores onboarding flag, etc.)
    await Hive.openBox(settingsBox);
  }

  static Box<TranslationMessage> get history =>
      Hive.box<TranslationMessage>(historyBox);
}