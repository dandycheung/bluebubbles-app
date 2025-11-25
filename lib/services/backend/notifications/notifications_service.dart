import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/scheduled_messages_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/ui/facetime_helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:get/get.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';
import 'package:timezone/timezone.dart';
import 'package:universal_html/html.dart' hide File, Platform, Navigator;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

NotificationsService notif =
    Get.isRegistered<NotificationsService>() ? Get.find<NotificationsService>() : Get.put(NotificationsService());

class PendingToastItem {
  final String? sender;
  final String text;
  final bool isReaction;
  final bool isGroupEvent;

  String get senderText => sender == null ? text : "$sender: $text";

  PendingToastItem({required this.sender, required this.text, required this.isReaction, required this.isGroupEvent});
}

class NotificationsService extends GetxService {
  static const String NEW_MESSAGE_CHANNEL = "com.bluebubbles.new_messages";
  static const String ERROR_CHANNEL = "com.bluebubbles.errors";
  static const String REMINDER_CHANNEL = "com.bluebubbles.reminders";
  static const String FACETIME_CHANNEL = "com.bluebubbles.incoming_facetimes";
  static const String FOREGROUND_SERVICE_CHANNEL = "com.bluebubbles.foreground_service";

  static const String NEW_MESSAGE_TAG = "com.bluebubbles.messaging.NEW_MESSAGE_NOTIFICATION";
  static const String NEW_FACETIME_TAG = "com.bluebubbles.messaging.NEW_FACETIME_NOTIFICATION";

  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
  StreamSubscription? countSub;
  int currentCount = 0;

  /// For desktop use only
  static LocalNotification? failedToast;
  static LocalNotification? socketToast;
  static LocalNotification? aliasesToast;
  static Map<String, LocalNotification> facetimeNotifications = {};
  static Map<String, LocalNotification> activeToasts = {};
  static Map<String, Timer> debounceTimers = {};
  static Map<String, List<PendingToastItem>> pendingMessages = {};
  static final Lock _lock = Lock();
  static final Player desktopNotificationPlayer = Player();

  static const int maxLines = 4;
  static const int charsPerLineEst = 40;

  bool get hideContent => ss.settings.hideTextPreviews.value;

  Future<void> init() async {
    if (!kIsWeb && !kIsDesktop) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_stat_icon');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flnp.initialize(initializationSettings, onDidReceiveNotificationResponse: (NotificationResponse? response) {
        if (response?.payload != null) {
          intents.openChat(response!.payload);
        }
      });
      final details = await flnp.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse?.payload != null) {
        intents.openChat(details.notificationResponse!.payload!);
      }
      // create notif channels
      createNotificationChannel(
        NEW_MESSAGE_CHANNEL,
        "New Messages",
        "Displays all received new messages",
      );
      createNotificationChannel(
        ERROR_CHANNEL,
        "Errors",
        "Displays message send failures, connection failures, and more",
      );
      createNotificationChannel(
        REMINDER_CHANNEL,
        "Message Reminders",
        "Displays message reminders set through the app",
      );
      createNotificationChannel(
        FACETIME_CHANNEL,
        "Incoming FaceTimes",
        "Displays incoming FaceTimes detected by the server",
      );
      createNotificationChannel(
        FOREGROUND_SERVICE_CHANNEL,
        "Foreground Service",
        "Allows BlueBubbles to stay open in the background for notifications if FCM is not being used",
      );
    }

    // watch for new messages and handle the notification
    if (!kIsWeb) {
      final countQuery =
          (Database.messages.query()..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
      countSub = countQuery.listen((event) {
        if (!ss.settings.finishedSetup.value) return;
        final newCount = event.count();
        final activeChatFetching = cm.activeChat != null ? ms(cm.activeChat!.chat.guid).isFetching : false;
        if (ls.isAlive &&
            (!sync.isIncrementalSyncing.value && !kIsDesktop) &&
            !activeChatFetching &&
            newCount > currentCount &&
            currentCount != 0) {
          event.limit = newCount - currentCount;
          final messages = event.find();
          event.limit = 0;
          for (Message message in messages) {
            if (message.chat.target == null) continue;
            message.handle = message.getHandle();
            message.attachments = List<Attachment>.from(message.dbAttachments);
          }
          for (Message message in messages) {
            MessageHelper.handleNotification(message, message.chat.target!, findExisting: false);
          }
        }
        currentCount = newCount;
      });
    } else {
      countSub = WebListeners.newMessage.listen((tuple) {
        final activeChatFetching = cm.activeChat != null ? ms(cm.activeChat!.chat.guid).isFetching : false;
        if (ls.isAlive && !activeChatFetching && tuple.item2 != null) {
          MessageHelper.handleNotification(tuple.item1, tuple.item2!, findExisting: false);
        }
      });
    }
  }

  @override
  void onClose() {
    countSub?.cancel();
    super.onClose();
  }

  Future<void> createNotificationChannel(String channelID, String channelName, String channelDescription) async {
    await mcs.invokeMethod("create-notification-channel", {
      "channel_name": channelName,
      "channel_description": channelDescription,
      "channel_id": channelID,
    });
  }

  Future<void> createReminder(Chat? chat, Message? message, DateTime time,
      {String? chatTitle, String? messageText}) async {
    await flnp.zonedSchedule(
      Random().nextInt(9998) + 50000,
      chatTitle ?? 'Reminder: ${chat!.getTitle()}',
      messageText ?? (hideContent ? "iMessage" : MessageHelper.getNotificationText(message!)),
      TZDateTime.from(time, local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          REMINDER_CHANNEL,
          'Reminders',
          channelDescription: 'Message reminder notifications',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: "${time.millisecondsSinceEpoch}",
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> createNotification(Chat chat, Message message) async {
    if (chat.shouldMuteNotification(message) || message.isFromMe!) return;
    final isGroup = chat.isGroup;
    final guid = chat.guid;
    final contactName = message.handle?.displayName ?? "Unknown";
    final title = isGroup ? chat.getTitle() : contactName;
    final text = hideContent ? "iMessage" : MessageHelper.getNotificationText(message);
    final isReaction = !isNullOrEmpty(message.associatedMessageGuid);
    final personIcon = (await rootBundle.load("assets/images/person64.png")).buffer.asUint8List();

    Uint8List chatIcon = await avatarAsBytes(chat: chat, quality: 256);
    Uint8List contactIcon = message.isFromMe!
        ? personIcon
        : await avatarAsBytes(
            participantsOverride:
                !chat.isGroup ? null : chat.participants.where((e) => e.address == message.handle!.address).toList(),
            chat: chat,
            quality: 256);
    if (chatIcon.isEmpty) {
      chatIcon = personIcon;
    }
    if (contactIcon.isEmpty) {
      contactIcon = personIcon;
    }

    if (kIsWeb && Notification.permission == "granted") {
      final notif =
          Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: message.guid);
      notif.onClick.listen((event) async {
        await intents.openChat(guid);
      });
    } else if (kIsDesktop) {
      _lock.synchronized(
          () => showDesktopNotif(text, chat, title, contactName, message, isReaction, message.isGroupEvent));
    } else {
      await mcs.invokeMethod("create-incoming-message-notification", {
        "channel_id": NEW_MESSAGE_CHANNEL,
        "chat_id": chat.id,
        "chat_guid": guid,
        "chat_is_group": isGroup,
        "chat_title": title,
        "chat_icon": isGroup ? chatIcon : contactIcon,
        "contact_name": contactName,
        "contact_avatar": contactIcon,
        "message_guid": message.guid!,
        "message_text": text,
        "message_date": message.dateCreated!.millisecondsSinceEpoch,
        "message_is_from_me": false,
      });
    }
  }

  Future<void> createIncomingFaceTimeNotification(
      String? callUuid, String caller, Uint8List? chatIcon, bool isAudio) async {
    // Set some notification defaults
    String title = caller;
    String text = "${callUuid == null ? "Incoming" : "Answer"} FaceTime ${isAudio ? 'Audio' : 'Video'} Call";
    chatIcon ??= (await rootBundle.load("assets/images/person64.png")).buffer.asUint8List();

    if (kIsWeb && Notification.permission == "granted") {
      final notif =
          Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: callUuid);
      if (callUuid != null) {
        notif.onClick.listen((event) async {
          await intents.answerFaceTime(callUuid);
        });
      }
    } else if (kIsDesktop) {
      _lock.synchronized(() async => await showPersistentDesktopFaceTimeNotif(callUuid, caller, chatIcon, isAudio));
    } else {
      final numeric = callUuid?.numericOnly();
      await mcs.invokeMethod("create-incoming-facetime-notification", {
        "channel_id": FACETIME_CHANNEL,
        "notification_id":
            numeric != null ? int.parse(numeric.substring(0, min(8, numeric.length))) : Random().nextInt(9998) + 1,
        "title": title,
        "body": text,
        "caller_avatar": chatIcon,
        "caller": caller,
        "call_uuid": callUuid
      });
    }
  }

  Future<void> clearFaceTimeNotification(String callUuid) async {
    if (kIsDesktop) {
      await clearDesktopFaceTimeNotif(callUuid);
    } else if (!kIsWeb) {
      final numeric = callUuid.numericOnly();
      mcs.invokeMethod("delete-notification",
          {"notification_id": int.parse(numeric.substring(0, min(8, numeric.length))), "tag": NEW_FACETIME_TAG});
    }
  }

  Future<void> showPersistentDesktopFaceTimeNotif(
      String? callUuid, String caller, Uint8List? avatar, bool isAudio) async {
    List<String> actions = ["Answer", "Ignore"];
    List<LocalNotificationAction> nActions = actions.map((String a) => LocalNotificationAction(text: a)).toList();
    LocalNotification? toast;
    String? path;

    if (avatar != null) {
      Uint8List? _avatar = await clip(avatar, size: 256, circle: true);
      if (_avatar != null) {
        // Create a temp file with the avatar
        path = join(fs.appDocDir.path, "temp", "${randomString(8)}.png");
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(_avatar);
      }
    }

    toast = LocalNotification(
      type: LocalNotificationType.imageAndText02,
      imagePath: path,
      title: caller,
      body: "Incoming FaceTime ${isAudio ? 'Audio' : 'Video'} Call",
      duration: LocalNotificationDuration.long,
      actions: callUuid == null ? null : nActions,
      systemSound: LocalNotificationSound.call,
      soundOption: LocalNotificationSoundOption.loop,
    );

    toast.onClick = () async {
      await windowManager.show();
    };

    if (callUuid != null) {
      toast.onClickAction = (index) async {
        if (actions[index] == "Answer") {
          await windowManager.show();
          await intents.answerFaceTime(callUuid);
        } else {
          hideFaceTimeOverlay(callUuid);
          await toast?.close();
        }
      };
    }

    toast.onClose = (reason) async {
      if (reason == LocalNotificationCloseReason.timedOut && faceTimeOverlays.containsKey(callUuid)) {
        await toast?.show();
      }
    };

    if (facetimeNotifications[callUuid ?? caller] != null) {
      await facetimeNotifications[callUuid ?? caller]?.close();
    }

    facetimeNotifications[callUuid ?? caller] = toast;

    await toast.show();
  }

  Future<void> clearDesktopFaceTimeNotif(String callerUuid) async {
    await facetimeNotifications[callerUuid]?.close();
    facetimeNotifications.remove(callerUuid);
  }

  void showDesktopNotif(
      String text, Chat chat, String title, String contactName, Message message, bool isReaction, bool isGroupEvent) {
    if (kIsDesktop && !ss.settings.desktopNotifications.value) return;

    final String guid = chat.guid;

    pendingMessages[guid] ??= [];

    pendingMessages[guid]!.add(PendingToastItem(
      sender: chat.isGroup && !isReaction ? contactName.split(" ").first : null,
      text: text,
      isReaction: isReaction,
      isGroupEvent: isGroupEvent,
    ));

    debounceTimers[guid]?.cancel();
    debounceTimers[guid] = Timer(
      const Duration(milliseconds: 1000),
      () async => await _buildAndShowToast(chat, title, message),
    );
  }

  Future<void> _buildAndShowToast(Chat chat, String title, Message message) async {
    final String guid = chat.guid;
    if (pendingMessages[guid]?.isEmpty ?? true) return;

    Uint8List avatar = await avatarAsBytes(chat: chat, quality: 256);
    String path = join(fs.appDocDir.path, "temp", "${randomString(8)}.png");
    await File(path).create(recursive: true);
    await File(path).writeAsBytes(avatar);

    int usedLines = 0;
    int numToShow = 0;
    int numMessages = pendingMessages[guid]!.length;

    final int numSenders = pendingMessages[guid]!.map((p) => p.sender).nonNulls.toSet().length;
    for (int i = numMessages - 1; i >= 0; i--) {
      final PendingToastItem item = pendingMessages[guid]![i];
      final String displayText = numSenders > 1 ? item.senderText : item.text;
      final int newLines = _estimateLines(displayText);
      if (usedLines + newLines > maxLines) {
        break;
      }

      usedLines += newLines;
      numToShow += 1;
    }
    if (numToShow == 0) {
      numToShow = 1;
    }

    final int overflowCount = numMessages - numToShow;
    String body = "";
    body += pendingMessages[guid]!
        .slice(overflowCount)
        .map((PendingToastItem e) => numSenders > 1 ? e.senderText : e.text)
        .join("\n");

    final PendingToastItem lastItem = pendingMessages[guid]!.last;

    final papi = ss.settings.enablePrivateAPI.value;
    final List<int> selectedIndices = ss.settings.selectedActionIndices;
    List<String> actions = ss.settings.actionList
        .whereIndexed((i, e) => selectedIndices.contains(i))
        .map((action) => action == "Mark Read"
            ? action
            : !lastItem.isReaction && !lastItem.isGroupEvent && papi
                ? ReactionTypes.reactionToEmoji[action]!
                : null)
        .nonNulls
        .toList();

    bool showMarkRead = actions.contains("Mark Read");
    List<LocalNotificationAction> nActions = actions.map((String a) => LocalNotificationAction(text: a)).toList();

    activeToasts[guid]?.close();

    String displayTitle;
    if (numSenders == 1 && !lastItem.isReaction && !lastItem.isGroupEvent) {
      displayTitle = "$title: ${lastItem.sender}";
    } else {
      displayTitle = title;
    }

    final LocalNotification toast = LocalNotification(
      type: LocalNotificationType.imageAndText03,
      imagePath: path,
      title: displayTitle,
      body: body,
      attributionText: overflowCount > 0 ? "+$overflowCount earlier message${overflowCount > 1 ? "s" : ""}\n" : null,
      duration: LocalNotificationDuration.long,
      actions: numMessages > 1
          ? showMarkRead
              ? [LocalNotificationAction(text: "Mark $numMessages Messages Read")]
              : []
          : nActions,
      hasInput: ss.settings.showReplyField.value,
      inputPlaceholder: "Type a reply...",
      inputButtonText: "Reply",
      systemSound: LocalNotificationSound.sms,
      soundOption: ss.settings.desktopNotificationSoundPath.value != null
          ? LocalNotificationSoundOption.silent
          : LocalNotificationSoundOption.defaultOption,
    );

    activeToasts[guid] = toast;

    _attachToastHandlers(toast, chat, message, path, actions, numMessages > 1);

    await playDesktopNotificationSound();

    await toast.show();
  }

  int _estimateLines(String text) {
    return (text.length / charsPerLineEst).ceil() + "\n".allMatches(text).length;
  }

  void _attachToastHandlers(LocalNotification toast, Chat chat, Message message, String avatarPath,
      List<String> actions, bool multipleMessages) {
    toast.onClick = () async {
      _cleanNotificationState(chat.guid);
      await _openChat(chat);
      await windowManager.show();
      _deleteTempFile(avatarPath);
    };

    toast.onClickAction = (index) {
      _cleanNotificationState(chat.guid);
      if (actions[index] == "Mark Read" || multipleMessages) {
        chat.toggleHasUnread(false);
        EventDispatcher().emit('refresh', null);
      } else if (ss.settings.enablePrivateAPI.value) {
        final String reaction = ReactionTypes.emojiToReaction[actions[index]]!;
        final Message _message = Message(
          associatedMessageGuid: message.guid!,
          associatedMessageType: reaction,
          associatedMessagePart: 0,
          dateCreated: DateTime.now(),
          handleId: 0,
        );
        _message.generateTempGuid();
        outq.queue(
          OutgoingItem(
            type: QueueType.sendMessage,
            chat: chat,
            message: _message,
            selected: message,
            reaction: reaction,
          ),
        );
      }
      _deleteTempFile(avatarPath);
    };

    toast.onInput = (text) {
      _cleanNotificationState(chat.guid);
      final Message _message = Message(
        dateCreated: DateTime.now(),
        handleId: 0,
        text: text,
        hasDdResults: true,
      );

      _message.generateTempGuid();

      outq.queue(
        OutgoingItem(
          type: QueueType.sendMessage,
          chat: chat,
          message: _message,
        ),
      );

      _deleteTempFile(avatarPath);
    };

    toast.onClose = (reason) async {
      if (reason != LocalNotificationCloseReason.unknown) {
        _cleanNotificationState(chat.guid);
      }

      _deleteTempFile(avatarPath);
    };
  }

  void _cleanNotificationState(String guid) {
    activeToasts.remove(guid);
  }

  Future<void> _openChat(Chat chat) async {
    if (cm.isChatActive(chat.guid) && Get.context != null) {
      ns.pushAndRemoveUntil(
        Get.context!,
        ConversationView(chat: chat),
        (route) => route.isFirst,
      );
    }
  }

  void _deleteTempFile(String path) async {
    final File file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<void> playDesktopNotificationSound() async {
    if (ss.settings.desktopNotificationSoundPath.value != null) {
      if (desktopNotificationPlayer.state.playing) {
        await desktopNotificationPlayer.stop();
      }
      await desktopNotificationPlayer.setVolume(ss.settings.desktopNotificationSoundVolume.value.toDouble());
      await desktopNotificationPlayer.open(Media(ss.settings.desktopNotificationSoundPath.value!));
    }
  }

  Future<void> createSocketError() async {
    const title = 'Could not connect';
    const subtitle = 'Your server may be offline!';
    if (kIsDesktop) {
      if (socketToast != null) return;
      socketToast = LocalNotification(
        type: LocalNotificationType.text02,
        title: title,
        body: subtitle,
        actions: [],
      );

      socketToast!.onClick = () async {
        socketToast = null;
        await windowManager.show();
        Navigator.of(Get.context!).push(
          ThemeSwitcher.buildPageRoute(
            builder: (BuildContext context) {
              return ServerManagementPanel();
            },
          ),
        );
      };

      await socketToast!.show();
      return;
    } else {
      final notifs = await flnp.getActiveNotifications();
      if (notifs.firstWhereOrNull((element) => element.id == -2) != null) return;
      await flnp.show(
        -2,
        title,
        subtitle,
        NotificationDetails(
          android: AndroidNotificationDetails(
            ERROR_CHANNEL,
            'Errors',
            channelDescription: 'Displays message send failures, connection failures, and more',
            priority: Priority.max,
            importance: Importance.max,
            color: HexColor("4990de"),
            ongoing: true,
            onlyAlertOnce: true,
          ),
        ),
      );
    }
  }

  Future<void> createAliasesRemovedNotification(List<String> aliases) async {
    const title = "iMessage alias deregistered!";
    const notifId = -3;
    final text = aliases.length == 1
        ? "${aliases[0]} has been deregistered!"
        : "The following aliases have been deregistered:\n${aliases.join("\n")}";

    if (kIsDesktop) {
      if (aliasesToast?.body == text) {
        return;
      } else {
        await aliasesToast?.close();
      }

      aliasesToast = LocalNotification(
        type: LocalNotificationType.text02,
        title: title,
        body: text,
        actions: [],
      );

      aliasesToast!.onClick = () async {
        aliasesToast = null;
        await windowManager.show();
      };

      await aliasesToast!.show();
    } else {
      final notifs = await flnp.getActiveNotifications();

      //Already have this notification
      if (notifs.firstWhereOrNull((n) => n.id == notifId && n.body == text) != null) {
        return;
      }

      await flnp.show(
        notifId,
        title,
        text,
        NotificationDetails(
          android: AndroidNotificationDetails(ERROR_CHANNEL, 'Errors',
              channelDescription: 'Displays message send failures, connection failures, and more',
              priority: Priority.max,
              importance: Importance.max,
              color: HexColor("4990de"),
              ongoing: false,
              onlyAlertOnce: false,
              styleInformation: const BigTextStyleInformation('')),
        ),
      );
    }
  }

  Future<void> createFailedToSend(Chat chat, {bool scheduled = false}) async {
    final title = 'Failed to send${scheduled ? " scheduled" : ""} message';
    final subtitle = scheduled ? 'Tap to open scheduled messages list' : 'Tap to see more details or retry';
    if (kIsDesktop) {
      failedToast = LocalNotification(
        type: LocalNotificationType.text02,
        title: title,
        body: subtitle,
        actions: [],
      );

      failedToast!.onClick = () async {
        failedToast = null;
        await windowManager.show();
        if (scheduled) {
          Navigator.of(Get.context!).push(
            ThemeSwitcher.buildPageRoute(
              builder: (BuildContext context) {
                return ScheduledMessagesPanel();
              },
            ),
          );
        } else {
          bool chatIsOpen = cm.activeChat?.chat.guid == chat.guid;
          if (!chatIsOpen) {
            ns.pushAndRemoveUntil(
              Get.context!,
              ConversationView(
                chat: chat,
              ),
              (route) => route.isFirst,
            );
          }
        }
      };

      await failedToast!.show();
      return;
    }
    await flnp.show(
      (chat.id! + 75000) * (scheduled ? -1 : 1),
      title,
      subtitle,
      NotificationDetails(
        android: AndroidNotificationDetails(
          ERROR_CHANNEL,
          'Errors',
          channelDescription: 'Displays message send failures, connection failures, and more',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: chat.guid + (scheduled ? "-scheduled" : ""),
    );
  }

  Future<void> clearSocketError() async {
    if (kIsDesktop) {
      await socketToast?.close();
      socketToast = null;
      return;
    }
    await flnp.cancel(-2);
  }

  Future<void> clearFailedToSend(int id) async {
    if (kIsDesktop) {
      await failedToast?.close();
      failedToast = null;
      return;
    }
    await flnp.cancel(id);
  }

  Future<void> clearDesktopNotificationsForChat(String chatGuid) async {
    await _lock.synchronized(() async {
      await activeToasts[chatGuid]?.close();
      _cleanNotificationState(chatGuid);
      debounceTimers[chatGuid]?.cancel();
      debounceTimers.remove(chatGuid);
      pendingMessages.remove(chatGuid);
    });
  }
}
