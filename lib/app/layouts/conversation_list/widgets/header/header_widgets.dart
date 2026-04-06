import 'package:auto_size_text/auto_size_text.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/profile/profile_panel.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/message_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:pull_down_button/pull_down_button.dart';

class HeaderText extends StatelessWidget {
  const HeaderText({super.key, required this.controller, this.fontSize});

  final ConversationListController controller;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: AutoSizeText(
        controller.showArchivedChats
            ? "Archive"
            : controller.showUnknownSenders
                ? "Unknown Senders"
                : "Messages",
        style: context.textTheme.headlineLarge!.copyWith(
          color: context.theme.colorScheme.onBackground,
          fontWeight: FontWeight.w400,
          fontSize: fontSize,
        ),
        maxLines: 1,
      ),
    );
  }
}

class SyncIndicator extends StatelessWidget {
  final double size;

  const SyncIndicator({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!SettingsSvc.settings.showSyncIndicator.value || !SyncSvc.isIncrementalSyncing.value) {
        return const SizedBox.shrink();
      }
      return buildProgressIndicator(context, size: size);
    });
  }
}

class OverflowMenu extends StatelessWidget {
  final bool extraItems;
  final ConversationListController? controller;
  const OverflowMenu({super.key, this.extraItems = false, this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (SettingsSvc.settings.skin.value == Skins.iOS && !(kIsDesktop || kIsWeb)) {
        return CupertinoOverflowMenu(extraItems: extraItems, controller: controller);
      }

      return MaterialOverflowMenu(controller: controller, extraItems: extraItems);
    });
  }
}

class MaterialOverflowMenu extends StatelessWidget {
  const MaterialOverflowMenu({
    super.key,
    required this.controller,
    required this.extraItems,
  });

  final ConversationListController? controller;
  final bool extraItems;

  @override
  Widget build(BuildContext context) {
    final skin = SettingsSvc.settings.skin.value;
    final windowEffect = SettingsSvc.settings.windowEffect.value;

    return PopupMenuButton<int>(
      color: context.theme.colorScheme.properSurface
          .lightenOrDarken(skin == Skins.Samsung ? 20 : 0)
          .withValues(alpha: windowEffect != WindowEffect.disabled ? 0.9 : 1),
      shape: skin != Skins.Material
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(20.0),
              ),
            )
          : null,
      onSelected: (int value) async {
        if (value == 0) {
          ChatsSvc.markAllAsRead();
        } else if (value == 1) {
          goToArchived(context);
        } else if (value == 2) {
          await goToSettings(context);
        } else if (value == 3) {
          goToUnknownSenders(context);
        } else if (value == 4) {
          logout(context);
        } else if (value == 5) {
          await goToFindMy(context);
        } else if (value == 6) {
          await goToSearch(context);
        } else if (value == 7) {
          controller?.openNewChatCreator(context);
        } else if (value == 8) {
          // Test Messages Isolate
          final messages = await MessageInterface.getMessages();
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Message Isolate Test'),
                content: Text(messages.length > 0
                    ? 'Successfully fetched messages from isolate!\nCount: ${messages.length}'
                    : 'No messages found or error occurred'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      },
      itemBuilder: (context) {
        return <PopupMenuItem<int>>[
          PopupMenuItem(
            value: 0,
            child: Text(
              'Mark All As Read',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          PopupMenuItem(
            value: 1,
            child: Text(
              'Archived',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          if (SettingsSvc.settings.filterUnknownSenders.value)
            PopupMenuItem(
              value: 3,
              child: Text(
                'Unknown Senders',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (SettingsSvc.serverDetails.isMinCatalina)
            PopupMenuItem(
              value: 5,
              child: Text(
                'FindMy',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          PopupMenuItem(
            value: 2,
            child: Text(
              'Settings',
              style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
            ),
          ),
          if (kIsWeb)
            PopupMenuItem(
              value: 4,
              child: Text(
                'Logout',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (extraItems)
            PopupMenuItem(
              value: 6,
              child: Text(
                'Search',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
          if (extraItems && SettingsSvc.settings.moveChatCreatorToHeader.value)
            PopupMenuItem(
              value: 7,
              child: Text(
                'New Chat',
                style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
              ),
            ),
        ];
      },
      icon: skin == Skins.Material
          ? Icon(
              Icons.more_vert,
              color: context.theme.colorScheme.properOnSurface,
              size: 25,
            )
          : null,
      child: skin == Skins.Material
          ? null
          : ThemeSwitcher(
              iOSSkin: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: context.theme.colorScheme.properSurface,
                ),
                child: Icon(
                  Icons.more_horiz,
                  color: context.theme.colorScheme.properOnSurface,
                  size: 20,
                ),
              ),
              materialSkin: const SizedBox.shrink(),
              samsungSkin: Icon(
                Icons.more_vert,
                color: context.theme.colorScheme.properOnSurface,
                size: 25,
              ),
            ),
    );
  }
}

class CupertinoOverflowMenu extends StatelessWidget {
  const CupertinoOverflowMenu({
    super.key,
    required this.extraItems,
    required this.controller,
  });

  final bool extraItems;
  final ConversationListController? controller;

  @override
  Widget build(BuildContext context) {
    final userName = SettingsSvc.settings.userName.value;
    final filterUnknownSenders = SettingsSvc.settings.filterUnknownSenders.value;
    final moveChatCreatorToHeader = SettingsSvc.settings.moveChatCreatorToHeader.value;

    final itemTheme = PullDownMenuItemTheme(
      textStyle: TextStyle(
        color: context.theme.colorScheme.onSurface,
      ),
      subtitleStyle: TextStyle(
        color: context.theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );

    return PullDownButton(
      routeTheme:
          PullDownMenuRouteTheme(backgroundColor: context.theme.colorScheme.properSurface.withValues(alpha: 0.9)),
      itemBuilder: (context) => [
        PullDownMenuHeader(
          itemTheme: itemTheme,
          title: userName,
          icon: CupertinoIcons.chevron_right,
          leadingBuilder: (context, constraints) {
            return Container(
                constraints: constraints,
                child: ContactAvatarWidget(
                  size: 50,
                  preferHighResAvatar: true,
                  borderThickness: 0.1,
                  editable: false,
                  fontSize: 16,
                  contact: ContactV2(
                    nativeContactId: 'you',
                    displayName: userName,
                  ),
                ));
          },
          subtitle: "Tap to open profile",
          onTap: () => goToProfile(context),
        ),
        PullDownMenuDivider.large(color: context.theme.colorScheme.background.withValues(alpha: 0.5)),
        PullDownMenuItem(
          itemTheme: itemTheme,
          title: 'Mark All As Read',
          icon: CupertinoIcons.check_mark_circled,
          onTap: ChatsSvc.markAllAsRead,
        ),
        PullDownMenuItem(
          itemTheme: itemTheme,
          title: 'Archived',
          icon: CupertinoIcons.archivebox,
          onTap: () => goToArchived(context),
        ),
        if (filterUnknownSenders)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Unknown Senders',
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            onTap: () => goToUnknownSenders(context),
          ),
        if (SettingsSvc.serverDetails.isMinCatalina)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Find My',
            icon: CupertinoIcons.location,
            onTap: () => goToFindMy(context),
          ),
        if (extraItems)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Search',
            icon: CupertinoIcons.search,
            onTap: () => goToSearch(context),
          ),
        if (extraItems && moveChatCreatorToHeader)
          PullDownMenuItem(
              itemTheme: itemTheme,
              title: 'New Chat',
              icon: CupertinoIcons.plus,
              onTap: () => controller?.openNewChatCreator(context)),
        PullDownMenuItem(
          itemTheme: itemTheme,
          title: 'Settings',
          icon: CupertinoIcons.gear,
          onTap: () => goToSettings(context),
        ),
        if (kIsWeb)
          PullDownMenuItem(
            itemTheme: itemTheme,
            title: 'Logout',
            icon: CupertinoIcons.power,
            onTap: () => logout(context),
          ),
      ],
      buttonBuilder: (context, showMenu) => GestureDetector(
          onTap: showMenu,
          child: ThemeSwitcher(
              iOSSkin: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: context.theme.colorScheme.properSurface,
                ),
                child: Icon(
                  Icons.more_horiz,
                  color: context.theme.colorScheme.properOnSurface,
                  size: 20,
                ),
              ),
              materialSkin: const SizedBox.shrink(),
              samsungSkin: const SizedBox.shrink())),
    );
  }
}

Future<void> goToSearch(BuildContext context) async {
  final current = NavigationSvc.ratio(context);
  EventDispatcherSvc.emit("override-split", 0.3);
  await NavigationSvc.pushLeft(context, const SearchView());
  EventDispatcherSvc.emit("override-split", current);
}

Future<void> goToFindMy(BuildContext context) async {
  final currentChat = ChatsSvc.activeChat?.chat;
  NavigationSvc.closeAllConversationView(context);
  await ChatsSvc.setAllInactive();
  await Navigator.of(Get.context!).push(
    ThemeSwitcher.buildPageRoute(
      builder: (BuildContext context) {
        return const FindMyPage();
      },
    ),
  );
  if (currentChat != null) {
    await ChatsSvc.setActiveChat(currentChat);
    if (SettingsSvc.settings.tabletMode.value) {
      NavigationSvc.pushAndRemoveUntil(
        context,
        ConversationView(
          chat: currentChat,
        ),
        (route) => route.isFirst,
      );
    } else {
      cvc(currentChat).close();
    }
  }
}

void logout(BuildContext context) {
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          "Are you sure?",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
        actions: <Widget>[
          TextButton(
            child: Text("No",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text("Yes",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () async {
              FilesystemSvc.deleteDB();
              SocketSvc.forgetConnection();
              SettingsSvc.settings = Settings();
              SettingsSvc.fcmData = FCMData();
              await PrefsSvc.i.clear();
              await PrefsSvc.i.setString("selected-dark", "OLED Dark");
              await PrefsSvc.i.setString("selected-light", "Bright White");
              Get.offAll(
                  () => const PopScope(
                        canPop: false,
                        child: TitleBarWrapper(child: SetupView()),
                      ),
                  duration: Duration.zero,
                  transition: Transition.noTransition);
            },
          ),
        ],
      );
    },
  );
}

void goToUnknownSenders(BuildContext context) {
  NavigationSvc.pushLeft(
      context,
      ConversationList(
        showArchivedChats: false,
        showUnknownSenders: true,
      ));
}

Future<void> goToSettings(BuildContext context) async {
  final currentChat = ChatsSvc.activeChat?.chat;
  NavigationSvc.closeAllConversationView(context);
  await ChatsSvc.setAllInactive();
  await Navigator.of(Get.context!).push(
    ThemeSwitcher.buildPageRoute(
      builder: (BuildContext context) {
        return const SettingsPage();
      },
    ),
  );
  if (currentChat != null) {
    await ChatsSvc.setActiveChat(currentChat);
    if (SettingsSvc.settings.tabletMode.value) {
      NavigationSvc.pushAndRemoveUntil(
        context,
        ConversationView(
          chat: currentChat,
        ),
        (route) => route.isFirst,
      ).onError((error, stackTrace) => ChatsSvc.setAllInactiveSync());
    } else {
      cvc(currentChat).close();
    }
  }
}

void goToArchived(BuildContext context) {
  NavigationSvc.pushLeft(
      context,
      ConversationList(
        showArchivedChats: true,
        showUnknownSenders: false,
      ));
}

void goToProfile(BuildContext context) {
  NavigationSvc.pushLeft(context, const ProfilePanel());
}
