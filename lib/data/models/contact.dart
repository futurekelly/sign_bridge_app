import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 2)
class Contact extends HiveObject {
  @HiveField(0)
  final String id; // Peer's unique shortId/ID

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String userRole; // deaf / hearing / both

  Contact({
    required this.id,
    required this.name,
    required this.userRole,
  });
}
