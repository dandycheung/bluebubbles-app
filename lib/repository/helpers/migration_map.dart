import 'package:collection/collection.dart';

class MigrationItem {
  int? oldId;
  int? newId;

  MigrationItem({ this.oldId, this.newId });
}

class MigrationMap {
  Map<String, MigrationItem> map = {};

  MigrationItem set(String guid, { int? oldId, int? newId }) {
    if (!map.containsKey(guid)) {
      map[guid] = MigrationItem();
    }

    if (oldId != null) map[guid]!.oldId = oldId;
    if (newId != null) map[guid]!.newId = newId;

    return map[guid]!;
  }

  MigrationItem? get({ String? guid, int? oldId }) {
    if (guid != null) return map[guid];
    if (oldId != null) return map.values.firstWhereOrNull((e) => e.oldId == oldId);
    return null;
  }

  void remove(String guid) {
    if (map.containsKey(guid)) {
      map.remove(guid);
    }
  }

  int size() {
    return map.length;
  }
}