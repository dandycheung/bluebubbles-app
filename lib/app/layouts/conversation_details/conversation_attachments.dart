import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachments_loader.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/documents_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/links_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/locations_section.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_grid_section.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class ConversationAttachments extends StatefulWidget {
  final Chat chat;
  final AttachmentSectionType section;
  final List<Attachment>? media;
  final List<Attachment>? docs;
  final List<Attachment>? locations;

  const ConversationAttachments({
    super.key,
    required this.chat,
    required this.section,
    this.media,
    this.docs,
    this.locations,
  });

  static void open(
    BuildContext context, {
    required Chat chat,
    required AttachmentSectionType section,
    List<Attachment>? media,
    List<Attachment>? docs,
    List<Attachment>? locations,
  }) {
    NavigationSvc.push(
      context,
      ConversationAttachments(
        chat: chat,
        section: section,
        media: media,
        docs: docs,
        locations: locations,
      ),
    );
  }

  @override
  State<ConversationAttachments> createState() => _ConversationAttachmentsState();
}

class _ConversationAttachmentsState extends State<ConversationAttachments> with ThemeHelpers {
  List<Attachment> media = <Attachment>[];
  List<Attachment> docs = <Attachment>[];
  List<Attachment> locations = <Attachment>[];
  bool isLoadingAttachments = false;
  final RxList<String> selected = <String>[].obs;

  @override
  void initState() {
    super.initState();
    if (widget.media != null) media = widget.media!;
    if (widget.docs != null) docs = widget.docs!;
    if (widget.locations != null) locations = widget.locations!;
    if (_needsLoadForCurrentSection()) {
      isLoadingAttachments = true;
    }
  }

  bool _needsLoadForCurrentSection() {
    switch (widget.section) {
      case AttachmentSectionType.media:
        return widget.media == null;
      case AttachmentSectionType.documents:
        return widget.docs == null;
      case AttachmentSectionType.locations:
        return widget.locations == null;
      case AttachmentSectionType.links:
        return false;
    }
  }

  void onAttachmentsLoaded(
      List<Attachment> loadedMedia, List<Attachment> loadedDocs, List<Attachment> loadedLocations) {
    if (mounted) {
      setState(() {
        media = loadedMedia;
        docs = loadedDocs;
        locations = loadedLocations;
        isLoadingAttachments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getOrCreateChatState(widget.chat);
    return ChatStateScope(
      chatState: chatState,
      child: Obx(() {
        final isDark = ThemeSvc.inDarkMode(context);
        chatState.themeVersion.value;
        final themeName = isDark ? chatState.customThemeDark.value : chatState.customThemeLight.value;
        final baseTheme = ThemeStruct.resolveByName(themeName, isDark ? Brightness.dark : Brightness.light).data;

        final hasWindowEffect = SettingsSvc.settings.windowEffect.value != WindowEffect.disabled;
        final reverseMapping = SettingsSvc.settings.skin.value == Skins.Material && isDark;
        final rawHeaderColor = (isDark ? baseTheme.colorScheme.surface : baseTheme.colorScheme.surfaceContainerHighest)
            .withAlpha(hasWindowEffect ? 20 : 255);
        final rawTileColor = (isDark ? baseTheme.colorScheme.surfaceContainerHighest : baseTheme.colorScheme.surface)
            .withAlpha(hasWindowEffect ? 100 : 255);
        final scaffoldHeaderColor = reverseMapping ? rawTileColor : rawHeaderColor;
        final scaffoldTileColor = reverseMapping ? rawHeaderColor : rawTileColor;

        final bubbleColors = baseTheme.extensions[BubbleColors] as BubbleColors?;
        final bubbleColor = widget.chat.isIMessage
            ? bubbleColors?.iMessageBubbleColor ?? baseTheme.colorScheme.iMessageBubble
            : bubbleColors?.smsBubbleColor ?? baseTheme.colorScheme.smsBubble;
        final onBubbleColor = widget.chat.isIMessage
            ? bubbleColors?.oniMessageBubbleColor ?? baseTheme.colorScheme.oniMessageBubble
            : bubbleColors?.onSmsBubbleColor ?? baseTheme.colorScheme.onSmsBubble;
        final useGeneratedThemeSurface = themeName != null
            ? ThemesService.isGeneratedMaterialThemeName(themeName)
            : ThemeSvc.isMaterialYouActive(context);

        return Theme(
          data: baseTheme.copyWith(
            primaryColor: bubbleColor,
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: bubbleColor,
              onPrimary: onBubbleColor,
              surface: useGeneratedThemeSurface ? null : bubbleColors?.receivedBubbleColor,
              onSurface: useGeneratedThemeSurface ? null : bubbleColors?.onReceivedBubbleColor,
            ),
          ),
          child: Obx(() => SettingsScaffold(
                headerColor: scaffoldHeaderColor,
                title: widget.section.title,
                tileColor: scaffoldTileColor,
                initialHeader: null,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                actions: widget.section == AttachmentSectionType.media
                    ? [
                        Obx(() {
                          if (selected.isNotEmpty) {
                            return IconButton(
                              icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close,
                                  color: context.theme.colorScheme.onSurface),
                              onPressed: () => selected.clear(),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        Obx(() {
                          if (selected.isNotEmpty) {
                            return IconButton(
                              icon: Icon(iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                                  color: context.theme.colorScheme.onSurface),
                              onPressed: () {
                                final attachments = media.where((e) => selected.contains(e.guid!));
                                for (final a in attachments) {
                                  final file = AttachmentsSvc.getContent(a, autoDownload: false);
                                  if (file is PlatformFile) {
                                    AttachmentsSvc.saveToDisk(file);
                                  }
                                }
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ]
                    : const [],
                bodySlivers: [
                  if (isLoadingAttachments)
                    SliverToBoxAdapter(
                      child: AttachmentsLoader(
                        chat: widget.chat,
                        onAttachmentsLoaded: onAttachmentsLoaded,
                      ),
                    ),
                  ..._buildSectionSlivers(),
                  const SliverPadding(padding: EdgeInsets.only(top: 50)),
                ],
              )),
        );
      }),
    );
  }

  List<Widget> _buildSectionSlivers() {
    switch (widget.section) {
      case AttachmentSectionType.media:
        return [
          MediaGridSection(
            chat: widget.chat,
            media: media,
            selected: selected,
            isLoading: isLoadingAttachments,
            fullPage: true,
            crossAxisCount: 3,
          ),
        ];
      case AttachmentSectionType.links:
        return [
          LinksSection(chat: widget.chat, fullPage: true),
        ];
      case AttachmentSectionType.locations:
        return [
          LocationsSection(
            chat: widget.chat,
            locations: locations,
            isLoading: isLoadingAttachments,
            fullPage: true,
          ),
        ];
      case AttachmentSectionType.documents:
        return [
          DocumentsSection(
            chat: widget.chat,
            docs: docs,
            isLoading: isLoadingAttachments,
            fullPage: true,
          ),
        ];
    }
  }
}
