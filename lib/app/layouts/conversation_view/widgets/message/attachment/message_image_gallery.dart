import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

enum GalleryFanDirection {
  left,
  right,
}

class MessageImageGallery extends StatefulWidget {
  const MessageImageGallery({
    super.key,
    required this.attachments,
    required this.partIndex,
    required this.isInReply,
    required this.fanDirection,
    this.infiniteScroll = false,
  });

  final List<Attachment> attachments;
  final int partIndex;
  final bool isInReply;
  final GalleryFanDirection fanDirection;
  final bool infiniteScroll;

  @override
  State<MessageImageGallery> createState() => _MessageImageGalleryState();
}

class _MessageImageGalleryState extends State<MessageImageGallery> with ThemeHelpers {
  static const int _visibleFanSlots = 5;
  static const double _swipeCommitThreshold = 70;
  static const double _maxDragDx = 140;
  int _currentIndex = 0;
  double _dragDx = 0;

  List<Attachment> get _attachments => widget.attachments;

  @override
  void didUpdateWidget(covariant MessageImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachments != widget.attachments) {
      _currentIndex = 0;
    }
  }

  void _advance(int direction) {
    if (_attachments.length <= 1) return;
    if (widget.infiniteScroll) {
      _currentIndex = (_currentIndex + direction) % _attachments.length;
      if (_currentIndex < 0) _currentIndex += _attachments.length;
    } else {
      _currentIndex = (_currentIndex + direction).clamp(0, _attachments.length - 1);
    }
  }

  Attachment _attachmentAtOffset(int offset) {
    final index = (_currentIndex + offset) % _attachments.length;
    return _attachments[index];
  }

  MessagePart _partForAttachment(Attachment attachment) {
    return MessagePart(
      part: widget.partIndex,
      attachments: [attachment],
      shouldRedact: false,
      text: null,
      subject: null,
      mentions: const [],
      edits: const [],
      isUnsent: false,
    );
  }

  double _computeBaseCardHeight(double baseCardWidth) {
    if (widget.isInReply) return 120.0;

    const double maxHeight = 300.0;
    const double minHeight = 100.0;

    final tallest = _attachments.fold<double>(
      minHeight,
      (current, a) {
        final w = a.width;
        final h = a.height;
        if (w == null || h == null || w <= 0 || h <= 0) {
          return max(current, baseCardWidth);
        }
        return max(current, (h / w) * baseCardWidth);
      },
    );
    return tallest.clamp(minHeight, maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final baseCardWidth = min((NavigationSvc.width(context) * 0.5), 260.0);
    final baseCardHeight = _computeBaseCardHeight(baseCardWidth).clamp(100.0, 300.0);
    final fanCanvasWidth = baseCardWidth + 56;
    final fanCanvasHeight = baseCardHeight;
    final baseOffset =
        ((fanCanvasWidth - baseCardWidth) / 2) + (widget.fanDirection == GalleryFanDirection.left ? 36 : -50);
    final fanDirectionSign = widget.fanDirection == GalleryFanDirection.left ? -1.0 : 1.0;
    final textOffset = (baseOffset + 25 + fanDirectionSign * 10.0).clamp(0.0, double.infinity);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_attachments.length <= 1) return;
        setState(() {
          _dragDx += details.delta.dx;
          _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
          if (!widget.infiniteScroll) {
            // Compute which drag directions are blocked at the current endpoint.
            // dragDx > 0 with fanFlip=1 (or dragDx < 0 with fanFlip=-1) advances
            // to the previous index; the inverse advances to the next.
            final fanFlip = widget.fanDirection == GalleryFanDirection.left ? -1 : 1;
            final atStart = _currentIndex == 0;
            final atEnd = _currentIndex == _attachments.length - 1;
            final blockedPositive = (atStart && fanFlip > 0) || (atEnd && fanFlip < 0);
            final blockedNegative = (atStart && fanFlip < 0) || (atEnd && fanFlip > 0);
            if (blockedPositive) _dragDx = _dragDx.clamp(-_maxDragDx, 0.0);
            if (blockedNegative) _dragDx = _dragDx.clamp(0.0, _maxDragDx);
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_attachments.length <= 1) return;
        final velocity = details.primaryVelocity ?? 0;
        final bool commit = _dragDx.abs() >= _swipeCommitThreshold || velocity.abs() > 700;
        if (!commit) {
          setState(() {
            _dragDx = 0;
          });
          return;
        }

        final rawSign = (_dragDx != 0 ? _dragDx : velocity) < 0 ? 1 : -1;
        final fanFlip = widget.fanDirection == GalleryFanDirection.left ? -1 : 1;
        setState(() {
          _advance(rawSign * fanFlip);
          _dragDx = 0;
        });
      },
      onHorizontalDragCancel: () {
        if (_attachments.length <= 1) return;
        setState(() {
          _dragDx = 0;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            widget.fanDirection == GalleryFanDirection.left ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: fanCanvasWidth,
            height: fanCanvasHeight,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: List.generate(_attachments.length, (i) {
                final attachment = _attachmentAtOffset(i);
                final slot = i < _visibleFanSlots ? i : (_visibleFanSlots - 1);
                final direction = widget.fanDirection == GalleryFanDirection.left ? -1.0 : 1.0;
                const slotDx = <double>[0, 10, 17, 23, 28];
                const slotDy = <double>[0, 4, 9, 14, 20];
                const slotAngle = <double>[0, 0.08, 0.175, 0.3, 0.425];
                const slotScale = <double>[1.0, 0.9, 0.8, 0.7, 0.6];
                final overflowDepth = i >= _visibleFanSlots ? ((i - (_visibleFanSlots - 1)).clamp(0, 6) * 0.7) : 0.0;
                final angle = slot == 0 ? 0.0 : direction * slotAngle[slot];
                final dy = slotDy[slot] + overflowDepth;
                final dx = direction * slotDx[slot];
                final scale = slotScale[slot];
                final cardWidth = baseCardWidth * scale;
                final cardHeight = baseCardHeight * scale;
                final centeredLeft = baseOffset + ((baseCardWidth - cardWidth) / 2);
                final dragOffset = i == 0 ? _dragDx : 0.0;
                final dragRotate = i == 0 ? (_dragDx / 700) : 0.0;
                final mirroredBias = direction * 10.0;
                return AnimatedPositioned(
                  key: ValueKey(attachment.guid ?? attachment.id ?? '$i-${attachment.transferName}'),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  top: 1 + dy,
                  left: centeredLeft + mirroredBias + dx + dragOffset,
                  child: Transform.translate(
                    offset: Offset.zero,
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: Transform.rotate(
                        angle: angle.toDouble() + dragRotate,
                        alignment: widget.fanDirection == GalleryFanDirection.left
                            ? Alignment.bottomRight
                            : Alignment.bottomLeft,
                        child: IgnorePointer(
                          ignoring: i != 0,
                          child: AttachmentHolder(
                            message: _partForAttachment(attachment),
                            transparentBackground: true,
                            showCardShadow: true,
                            galleryAttachments: _attachments,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).reversed.toList(),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: (widget.fanDirection == GalleryFanDirection.left
                ? const EdgeInsets.only(right: 20)
                : EdgeInsets.only(left: textOffset)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  'Gallery',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
