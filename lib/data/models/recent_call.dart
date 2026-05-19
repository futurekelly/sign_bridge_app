// RecentCall — Hive model for storing recently joined call IDs.
// Allows quick rejoin from the home screen.

import 'package:hive/hive.dart';

part 'recent_call.g.dart';

@HiveType(typeId: 1)
class RecentCall extends HiveObject {
  @HiveField(0)
  final String callId;

  @HiveField(1)
  final String? partnerName;

  /// Stored as "deaf" / "hearing" / "both" or null.
  @HiveField(2)
  final String? partnerRole;

  /// ISO-8601 timestamp of when the call started.
  @HiveField(3)
  final String timestamp;

  /// Duration of the call in seconds (null if unknown).
  @HiveField(4)
  final int? durationSeconds;

  RecentCall({
    required this.callId,
    this.partnerName,
    this.partnerRole,
    String? timestamp,
    this.durationSeconds,
  }) : timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  /// Human-readable duration string.
  String get durationLabel {
    if (durationSeconds == null) return '--:--';
    final m = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
