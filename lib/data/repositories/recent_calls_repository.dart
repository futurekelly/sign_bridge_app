// RecentCallsRepository — persists and retrieves recent call entries.
// Caps at 20 entries to keep local storage lean.

import '../local/hive_db.dart';
import '../models/recent_call.dart';

class RecentCallsRepository {
  static const int _maxEntries = 20;

  Future<void> save(RecentCall call) async {
    final box = HiveDb.recentCalls;
    // Upsert by callId — update if exists, insert if not.
    await box.put(call.callId, call);
    // Trim oldest entries if over limit.
    if (box.length > _maxEntries) {
      final all = getAll();
      final toRemove = all.sublist(_maxEntries);
      for (final entry in toRemove) {
        await box.delete(entry.callId);
      }
    }
  }

  /// Returns recent calls sorted newest-first.
  List<RecentCall> getAll() {
    final list = HiveDb.recentCalls.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> delete(String callId) async {
    await HiveDb.recentCalls.delete(callId);
  }

  Future<void> clear() async {
    await HiveDb.recentCalls.clear();
  }
}
