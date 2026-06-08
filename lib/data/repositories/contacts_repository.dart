// ContactsRepository — persists and retrieves saved contacts.

import '../local/hive_db.dart';
import '../models/contact.dart';

class ContactsRepository {
  Future<void> save(Contact contact) async {
    final box = HiveDb.contacts;
    // Upsert by contact id (peer's unique shortId)
    await box.put(contact.id, contact);
  }

  List<Contact> getAll() {
    final list = HiveDb.contacts.values.toList();
    // Sort alphabetically by name
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> delete(String contactId) async {
    await HiveDb.contacts.delete(contactId);
  }

  Future<void> clear() async {
    await HiveDb.contacts.clear();
  }
}
