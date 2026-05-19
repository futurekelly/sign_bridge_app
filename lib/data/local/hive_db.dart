// HiveDb — initializes Hive and opens boxes used by the app.
// Call once on app startup before any repository is used.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/translation_message.dart';
import '../models/recent_call.dart';

class HiveDb {
  static const String historyBox    = 'translation_history';
  static const String settingsBox   = 'app_settings';
  static const String recentCallBox = 'recent_calls';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(TranslationMessageAdapter());
    Hive.registerAdapter(RecentCallAdapter());

    // Open boxes
    await Hive.openBox<TranslationMessage>(historyBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox<RecentCall>(recentCallBox);
  }

  static Box<TranslationMessage> get history =>
      Hive.box<TranslationMessage>(historyBox);

  static Box<RecentCall> get recentCalls =>
      Hive.box<RecentCall>(recentCallBox);

  static Box get settings => Hive.box(settingsBox);
}