import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

class CustomGroupActions {
  static Future<int> create(dynamic data) async {
    final name = data['name'] as String;
    // Dedupe so a repeated guid in the input can't create duplicate rows in
    // the group<->chat relation.
    final chatGuids = (data['chatGuids'] as List).cast<String>().toSet();
    return Database.runInTransaction(TxMode.write, () {
      final group = CustomGroup(name: name);
      final matchedChats = chatGuids
          .map((guid) => Database.chats.query(Chat_.guid.equals(guid)).build().findFirst())
          .whereType<Chat>()
          .toList();
      group.chats.addAll(matchedChats);
      try {
        return Database.customGroups.put(group);
      } on UniqueViolationException catch (_) {
        Logger.warn('Duplicate custom group name — skipping', tag: 'CustomGroupActions');
        rethrow;
      }
    });
  }

  static Future<int> rename(dynamic data) async {
    final id = data['id'] as int;
    final name = data['name'] as String;
    return Database.runInTransaction(TxMode.write, () {
      final group = Database.customGroups.get(id)!;
      group.name = name;
      try {
        return Database.customGroups.put(group);
      } on UniqueViolationException catch (_) {
        Logger.warn('Duplicate custom group name — skipping', tag: 'CustomGroupActions');
        rethrow;
      }
    });
  }

  static Future<int> updateChats(dynamic data) async {
    final id = data['id'] as int;
    // Dedupe so a repeated guid in the input can't create duplicate rows in
    // the group<->chat relation.
    final chatGuids = (data['chatGuids'] as List).cast<String>().toSet();
    return Database.runInTransaction(TxMode.write, () {
      final group = Database.customGroups.get(id)!;
      final matchedChats = chatGuids
          .map((guid) => Database.chats.query(Chat_.guid.equals(guid)).build().findFirst())
          .whereType<Chat>()
          .toList();
      group.chats.clear();
      group.chats.addAll(matchedChats);
      group.chats.applyToDb();
      return group.id!;
    });
  }

  static Future<List<int>> getAllIds(dynamic data) async {
    return Database.runInTransaction(
        TxMode.read, () => Database.customGroups.getAll().map((g) => g.id!).toList());
  }

  static Future<void> delete(dynamic data) async {
    final id = data['id'] as int;
    Database.runInTransaction(TxMode.write, () => Database.customGroups.remove(id));
  }
}
