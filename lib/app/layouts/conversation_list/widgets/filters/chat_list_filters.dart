/// Independent, combinable filter dimensions for the conversation list.
/// Each dimension is single-select within itself (e.g. "Unread" vs "All" for
/// read status), but the dimensions combine with AND semantics — e.g.
/// "Unread" + "Group Chats" shows only unread group chats.
library;

enum ChatReadFilter { all, unread }

enum ChatSenderFilter { all, known, unknown }

enum ChatTypeFilter { all, group, direct }

enum ChatMuteFilter { all, muted, unmuted }

enum ChatServiceFilter { all, iMessage, other }

// Future dimension, pending Message.isServiceMessage / Message.isSpam:
// enum ChatCategoryFilter { all, twoFactor, spam, promotions, transactions }

/// Bundles the current selection for every conversation-list filter
/// dimension. Immutable — use [copyWith] to change one dimension at a time.
class ChatListFilters {
  final ChatReadFilter readFilter;
  final ChatSenderFilter senderFilter;
  final ChatTypeFilter typeFilter;
  final ChatMuteFilter muteFilter;
  final ChatServiceFilter serviceFilter;

  const ChatListFilters({
    this.readFilter = ChatReadFilter.all,
    this.senderFilter = ChatSenderFilter.all,
    this.typeFilter = ChatTypeFilter.all,
    this.muteFilter = ChatMuteFilter.all,
    this.serviceFilter = ChatServiceFilter.all,
  });

  bool get hasActiveFilter =>
      readFilter != ChatReadFilter.all ||
      senderFilter != ChatSenderFilter.all ||
      typeFilter != ChatTypeFilter.all ||
      muteFilter != ChatMuteFilter.all ||
      serviceFilter != ChatServiceFilter.all;

  ChatListFilters copyWith({
    ChatReadFilter? readFilter,
    ChatSenderFilter? senderFilter,
    ChatTypeFilter? typeFilter,
    ChatMuteFilter? muteFilter,
    ChatServiceFilter? serviceFilter,
  }) {
    return ChatListFilters(
      readFilter: readFilter ?? this.readFilter,
      senderFilter: senderFilter ?? this.senderFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      muteFilter: muteFilter ?? this.muteFilter,
      serviceFilter: serviceFilter ?? this.serviceFilter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatListFilters &&
      other.readFilter == readFilter &&
      other.senderFilter == senderFilter &&
      other.typeFilter == typeFilter &&
      other.muteFilter == muteFilter &&
      other.serviceFilter == serviceFilter;

  @override
  int get hashCode => Object.hash(readFilter, senderFilter, typeFilter, muteFilter, serviceFilter);
}
