import 'package:bluebubbles/database/models.dart' hide Entity;
import 'package:flutter/foundation.dart';

class ReactionTypes {
  // ignore: non_constant_identifier_names
  static const String LOVE = "love";
  // ignore: non_constant_identifier_names
  static const String LIKE = "like";
  // ignore: non_constant_identifier_names
  static const String DISLIKE = "dislike";
  // ignore: non_constant_identifier_names
  static const String LAUGH = "laugh";
  // ignore: non_constant_identifier_names
  static const String EMPHASIZE = "emphasize";
  // ignore: non_constant_identifier_names
  static const String QUESTION = "question";

  static List<String> toList() {
    return [
      LOVE,
      LIKE,
      DISLIKE,
      LAUGH,
      EMPHASIZE,
      QUESTION,
    ];
  }

  static final Map<String, String> reactionToVerb = {
    LOVE: "loved",
    LIKE: "liked",
    DISLIKE: "disliked",
    LAUGH: "laughed at",
    EMPHASIZE: "emphasized",
    QUESTION: "questioned",
    "-$LOVE": "removed a heart from",
    "-$LIKE": "removed a like from",
    "-$DISLIKE": "removed a dislike from",
    "-$LAUGH": "removed a laugh from",
    "-$EMPHASIZE": "removed an exclamation from",
    "-$QUESTION": "removed a question mark from",
  };

  static final Map<String, String> reactionToEmoji = {
    LOVE: "❤️",
    LIKE: "👍",
    DISLIKE: "👎",
    LAUGH: "😂",
    EMPHASIZE: "❗",
    QUESTION: "❓",
  };

  static final Map<String, String> emojiToReaction = {
    "❤️": LOVE,
    "👍": LIKE,
    "👎": DISLIKE,
    "😂": LAUGH,
    "❗": EMPHASIZE,
    "❓": QUESTION,
  };

  /// Regex matching Unicode emoji: emoji presentation sequences, modifier sequences,
  /// keycap sequences, regional indicators, and common emoji codepoint ranges.
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
    r'[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|'
    r'[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|[\u{1F700}-\u{1F8FF}]|'
    r'[\u{200D}]|[\u{20E3}]|[\u{E0020}-\u{E007F}]|[\u{2702}-\u{27B0}]|'
    r'[\u{231A}-\u{231B}]|[\u{23E9}-\u{23F3}]|[\u{23F8}-\u{23FA}]|'
    r'[\u{25AA}-\u{25AB}]|[\u{25B6}]|[\u{25C0}]|[\u{25FB}-\u{25FE}]|'
    r'[\u{2614}-\u{2615}]|[\u{2648}-\u{2653}]|[\u{267F}]|[\u{2693}]|'
    r'[\u{26A1}]|[\u{26AA}-\u{26AB}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|'
    r'[\u{26CE}]|[\u{26D4}]|[\u{26EA}]|[\u{26F2}-\u{26F3}]|[\u{26F5}]|'
    r'[\u{26FA}]|[\u{26FD}]|[\u{2702}]|[\u{2705}]|[\u{2708}-\u{270D}]|'
    r'[\u{270F}]|[\u{2712}]|[\u{2714}]|[\u{2716}]|[\u{271D}]|[\u{2721}]|'
    r'[\u{2728}]|[\u{2733}-\u{2734}]|[\u{2744}]|[\u{2747}]|[\u{274C}]|'
    r'[\u{274E}]|[\u{2753}-\u{2755}]|[\u{2757}]|[\u{2763}-\u{2764}]|'
    r'[\u{2795}-\u{2797}]|[\u{27A1}]|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|'
    r'[\u{2B1B}-\u{2B1C}]|[\u{2B50}]|[\u{2B55}]|[\u{3030}]|[\u{303D}]|'
    r'[\u{3297}]|[\u{3299}]|[\u{00A9}]|[\u{00AE}]',
    unicode: true,
  );

  static final RegExp _asciiLetterRegex = RegExp(r'[a-zA-Z]');

  /// Returns true if [text] contains at least one emoji character and no ASCII letters.
  static bool _looksLikeEmoji(String text) {
    if (text.isEmpty) return false;
    if (_asciiLetterRegex.hasMatch(text)) return false;
    return _emojiRegex.hasMatch(text);
  }

  /// Strips the removal prefix ("-") if present.
  static String _stripRemovalPrefix(String type) {
    return type.startsWith("-") ? type.substring(1) : type;
  }

  /// Returns true if [type] is a classic tapback or an emoji reaction.
  static bool isValidReaction(String? type) {
    if (type == null || type.isEmpty) return false;
    final cleaned = _stripRemovalPrefix(type);
    return toList().contains(cleaned) || isEmojiReaction(cleaned);
  }

  /// Returns true if [type] is an emoji reaction (not a classic tapback or sticker).
  static bool isEmojiReaction(String? type) {
    if (type == null || type.isEmpty) return false;
    final cleaned = _stripRemovalPrefix(type);
    if (toList().contains(cleaned) || cleaned == "sticker") return false;
    return _looksLikeEmoji(cleaned);
  }

  /// Returns the emoji to display for a reaction type.
  /// Classic tapbacks map to their emoji; emoji reactions ARE the emoji.
  static String getReactionEmoji(String? type) {
    if (type == null || type.isEmpty) return "";
    return reactionToEmoji[type] ?? type;
  }

  /// Returns a verb phrase for notification text.
  /// Classic tapbacks use the verb map; emoji reactions use "reacted [emoji] to".
  static String getReactionVerb(String? type) {
    if (type == null || type.isEmpty) return "reacted to";
    if (reactionToVerb.containsKey(type)) return reactionToVerb[type]!;
    if (type.startsWith("-")) return "removed a ${type.substring(1)} reaction from";
    return "reacted $type to";
  }
}

List<Message> getUniqueReactionMessages(List<Message> messages) {
  List<int> handleCache = [];
  List<Message> output = [];
  // Sort the messages, putting the latest at the top
  final ids = messages.map((e) => e.guid).toSet();
  messages.retainWhere((element) => ids.remove(element.guid));
  messages.sort(Message.sort);
  // Iterate over the messages and insert the latest reaction for each user
  for (Message msg in messages) {
    int cache = msg.isFromMe! ? 0 : msg.handleId ?? 0;
    if (!handleCache.contains(cache) && !kIsWeb) {
      handleCache.add(cache);
      // Only add the reaction if it's not a "negative"
      if (!msg.associatedMessageType!.startsWith("-")) {
        output.add(msg);
      }
    } else if (kIsWeb && !msg.associatedMessageType!.startsWith("-")) {
      output.add(msg);
    }
  }

  return output;
}
