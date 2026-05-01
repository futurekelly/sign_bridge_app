// HistoryRepository — persists TranslationMessage entries via Hive.
// Used by the History screen and by TranslationController in Phase 5.

import '../local/hive_db.dart';
import '../models/translation_message.dart';

class HistoryRepository {
  Future<void> save(TranslationMessage msg) async {
    await HiveDb.history.put(msg.id, msg);
  }

  List<TranslationMessage> getAll() {
    final list = HiveDb.history.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
    return list;
  }

  Future<void> clear() async => HiveDb.history.clear();
}