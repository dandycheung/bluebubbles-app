import 'dart:async';

import 'package:bluebubbles/database/models.dart';

enum QueueType { sendMessage, sendAttachment, sendMultipart }

abstract class QueueItem {
  QueueType type;
  Completer<void>? completer;

  QueueItem({required this.type, this.completer});
}

class OutgoingItem extends QueueItem {
  Chat chat;
  Message message;
  Message? selected;
  String? reaction;
  Map<String, dynamic>? customArgs;

  OutgoingItem({
    required super.type,
    super.completer,
    required this.chat,
    required this.message,
    this.selected,
    this.reaction,
    this.customArgs,
  });
}
