import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/conversation_attachments.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/attachment_section_header.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that handles locations section display
class LocationsSection extends StatefulWidget {
  final Chat chat;
  final List<Attachment> locations;
  final bool isLoading;
  final bool fullPage;

  const LocationsSection({
    super.key,
    required this.chat,
    required this.locations,
    this.isLoading = false,
    this.fullPage = false,
  });

  @override
  State<LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<LocationsSection> {
  static const int _chunkSize = 10;
  late int _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
  bool _loadingMore = false;

  @override
  void didUpdateWidget(LocationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations.length != widget.locations.length) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
    if (oldWidget.fullPage != widget.fullPage) {
      _displayCount = widget.fullPage ? _chunkSize : kAttachmentPreviewLimit;
    }
  }

  int get _visibleCount {
    if (widget.fullPage) return min(_displayCount, widget.locations.length);
    return min(kAttachmentPreviewLimit, widget.locations.length);
  }

  void _loadMore() {
    if (_loadingMore || _displayCount >= widget.locations.length) return;
    _loadingMore = true;
    setState(() => _displayCount = min(_displayCount + _chunkSize, widget.locations.length));
    _loadingMore = false;
  }

  Widget _buildLocationTile(BuildContext context, int index) {
    if (AttachmentsSvc.getContent(widget.locations[index]) is! PlatformFile) {
      return const Text("Failed to load location!");
    }
    return Material(
      color: context.theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final attachment = widget.locations[index];
          if (attachment.mimeType?.contains("location") ?? false) {
            final location = attachment.transferName;
            if (location != null) {
              final uri = Uri.parse("https://maps.google.com/?q=$location");
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: Center(
          child: UrlPreview(
            data: UrlPreviewData(
              title: "Location from ${DateFormat.yMd().format(widget.locations[index].message.target!.dateCreated!)}",
              siteName: "Tap to open",
            ),
            file: AttachmentsSvc.getContent(widget.locations[index]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!widget.fullPage)
          SliverToBoxAdapter(
            child: AttachmentSectionHeader(
              title: AttachmentSectionType.locations.sectionLabel,
              onShowMore: () => ConversationAttachments.open(
                context,
                chat: widget.chat,
                section: AttachmentSectionType.locations,
                locations: widget.locations,
              ),
            ),
          ),
        if (widget.isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Center(child: buildProgressIndicator(context, size: 24)),
            ),
          )
        else if (widget.locations.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Center(
                child: Text(
                  "No locations",
                  style: context.theme.textTheme.bodyMedium!.copyWith(
                    color: context.theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else ...[
          Obx(() => SliverPadding(
                padding: EdgeInsets.only(
                  left: SettingsSvc.settings.skin.value == Skins.iOS ? 20 : 10,
                  right: SettingsSvc.settings.skin.value == Skins.iOS ? 20 : 10,
                  top: widget.fullPage ? 10 : 0,
                  bottom: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: MasonryGridView.count(
                    crossAxisCount: max(2, NavigationSvc.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) => _buildLocationTile(context, index),
                    itemCount: _visibleCount,
                  ),
                ),
              )),
          if (widget.fullPage && _displayCount < widget.locations.length)
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  if (!_loadingMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: buildProgressIndicator(context, size: 24)),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}
