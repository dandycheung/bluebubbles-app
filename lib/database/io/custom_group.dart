import 'package:bluebubbles/database/models.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class CustomGroup {
  int? id;

  @Index(type: IndexType.value)
  @Unique()
  String name;

  /// Manual ordering for display in the settings list (lowest first).
  int sortOrder;

  /// Owning side of the N:M relation — a group has many chats, a chat can
  /// belong to many groups (see `Chat.customGroups` backlink).
  final chats = ToMany<Chat>();

  CustomGroup({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory CustomGroup.fromMap(Map<String, dynamic> json) => CustomGroup(
        id: json["id"] as int?,
        name: json["name"] as String,
        sortOrder: json["sortOrder"] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "sortOrder": sortOrder,
      };
}
