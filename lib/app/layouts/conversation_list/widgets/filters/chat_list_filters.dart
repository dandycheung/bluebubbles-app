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

  static const _keyRead = 'read';
  static const _keySender = 'sender';
  static const _keyType = 'type';
  static const _keyMute = 'mute';
  static const _keyService = 'service';

  /// Decodes a [Settings.savedChatFilters]-style map (dimension name -> enum
  /// name). Unknown/missing keys fall back to [ChatListFilters]'s defaults —
  /// safe to call on a map from an older app version missing newer keys.
  factory ChatListFilters.fromSettingsMap(Map<String, String> map) {
    return ChatListFilters(
      readFilter: chatReadFilterFromName(map[_keyRead] ?? ''),
      senderFilter: chatSenderFilterFromName(map[_keySender] ?? ''),
      typeFilter: chatTypeFilterFromName(map[_keyType] ?? ''),
      muteFilter: chatMuteFilterFromName(map[_keyMute] ?? ''),
      serviceFilter: chatServiceFilterFromName(map[_keyService] ?? ''),
    );
  }

  /// Encodes this selection into a [Settings.savedChatFilters]-style map.
  Map<String, String> toSettingsMap() => {
        _keyRead: readFilter.name,
        _keySender: senderFilter.name,
        _keyType: typeFilter.name,
        _keyMute: muteFilter.name,
        _keyService: serviceFilter.name,
      };

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

/// Looks up an enum value by its [Enum.name], falling back to [orElse]
/// instead of throwing if the stored string doesn't match any current value
/// (e.g. after a future enum rename).
T _enumByName<T extends Enum>(List<T> values, String name, T orElse) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return orElse;
}

ChatReadFilter chatReadFilterFromName(String name) => _enumByName(ChatReadFilter.values, name, ChatReadFilter.all);

ChatSenderFilter chatSenderFilterFromName(String name) =>
    _enumByName(ChatSenderFilter.values, name, ChatSenderFilter.all);

ChatTypeFilter chatTypeFilterFromName(String name) => _enumByName(ChatTypeFilter.values, name, ChatTypeFilter.all);

ChatMuteFilter chatMuteFilterFromName(String name) => _enumByName(ChatMuteFilter.values, name, ChatMuteFilter.all);

ChatServiceFilter chatServiceFilterFromName(String name) =>
    _enumByName(ChatServiceFilter.values, name, ChatServiceFilter.all);
