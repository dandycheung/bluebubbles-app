import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supercharged/supercharged.dart';

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
    this.currentIndexNotifier,
  });

  final List<Attachment> attachments;
  final int partIndex;
  final bool isInReply;
  final GalleryFanDirection fanDirection;
  final bool infiniteScroll;
  final ValueNotifier<int>? currentIndexNotifier;

  @override
  State<MessageImageGallery> createState() => _MessageImageGalleryState();
}

class _MessageImageGalleryState extends State<MessageImageGallery> with ThemeHelpers {
  static const int _visibleFanSlots = 5;
  static const double _swipeCommitThreshold = 70;
  static const double _maxDragDx = 140;
  static const double _maxWiggleDx = 20.0;
  int _currentIndex = 0;
  double _dragDx = 0;
  bool _hapticGivenForCurrentEnd = false;
  final Map<String, Size> _imageSizes = {};

  List<Attachment> get _attachments => widget.attachments;

  @override
  void initState() {
    super.initState();
    _loadImageSizes();
  }

  @override
  void didUpdateWidget(covariant MessageImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final diff = widget.attachments.filter((a) => !_imageSizes.containsKey(a.guid ?? a.transferName)).toList();
    if (diff.isNotEmpty) {
      _currentIndex = 0;
      _imageSizes.clear();
      _loadImageSizes();
    }
  }

  void _loadImageSizes() {
    for (final a in _attachments) {
      if (a.mimeStart == 'image') {
        _loadOneImageSize(a);
      }
    }
  }

  Future<void> _loadOneImageSize(Attachment attachment) async {
    final key = attachment.guid ?? attachment.transferName;
    if (key == null || _imageSizes.containsKey(key)) return;
    try {
      // Prefer the converted PNG path (exists for HEIC/TIFF), fall back to original.
      File? imageFile;
      for (final candidate in [attachment.convertedPath, attachment.path]) {
        final f = File(candidate);
        if (f.existsSync()) {
          imageFile = f;
          break;
        }
      }
      if (imageFile == null) return;

      final completer = Completer<Size?>();
      final provider = FileImage(imageFile);
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
          }
          stream.removeListener(listener);
        },
        onError: (dynamic _, StackTrace? __) {
          if (!completer.isCompleted) completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      final size = await completer.future;
      if (mounted && size != null) {
        setState(() {
          _imageSizes[key] = size;
        });
      }
    } catch (_) {}
  }

  void _advance(int direction) {
    if (_attachments.length <= 1) return;
    if (widget.infiniteScroll) {
      _currentIndex = (_currentIndex + direction) % _attachments.length;
      if (_currentIndex < 0) _currentIndex += _attachments.length;
    } else {
      _currentIndex = (_currentIndex + direction).clamp(0, _attachments.length - 1);
    }
    widget.currentIndexNotifier?.value = _currentIndex;
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
        final key = a.guid ?? a.transferName;
        final size = key != null ? _imageSizes[key] : null;
        if (size == null || size.width <= 0 || size.height <= 0) {
          return max(current, baseCardWidth);
        }
        return max(current, (size.height / size.width) * baseCardWidth);
      },
    );
    return tallest.clamp(minHeight, maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final baseCardWidth = min((NavigationSvc.width(context) * 0.5), 260.0);
    final baseHeight = _computeBaseCardHeight(baseCardWidth);
    final baseCardHeight = baseHeight.clamp(100.0, 300.0);

    final fanCanvasWidth = baseCardWidth + 56;
    final fanCanvasHeight = baseCardHeight;
    final baseOffset =
        ((fanCanvasWidth - baseCardWidth) / 2) + (widget.fanDirection == GalleryFanDirection.left ? 36 : -50);
    final fanDirectionSign = widget.fanDirection == GalleryFanDirection.left ? -1.0 : 1.0;
    final textOffset = (baseOffset + 25 + fanDirectionSign * 10.0).clamp(0.0, double.infinity);
    final photoCount = _attachments.where((a) => a.mimeStart == 'image').length;
    final videoCount = _attachments.where((a) => a.mimeStart == 'video').length;
    final galleryLabel = photoCount > 0 && videoCount > 0
        ? '${photoCount + videoCount} Photos & Videos'
        : videoCount > 0
            ? '$videoCount ${videoCount == 1 ? 'Video' : 'Videos'}'
            : '$photoCount ${photoCount == 1 ? 'Photo' : 'Photos'}';

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_attachments.length <= 1) return;
        if (!widget.infiniteScroll) {
          final fanFlip = widget.fanDirection == GalleryFanDirection.left ? -1 : 1;
          final atStart = _currentIndex == 0;
          final atEnd = _currentIndex == _attachments.length - 1;
          final blockedPositive = (atStart && fanFlip > 0) || (atEnd && fanFlip < 0);
          final blockedNegative = (atStart && fanFlip < 0) || (atEnd && fanFlip > 0);

          final draggingIntoBlockedEnd =
              (blockedPositive && details.delta.dx > 0) || (blockedNegative && details.delta.dx < 0);
          if (draggingIntoBlockedEnd) {
            if (!_hapticGivenForCurrentEnd) {
              HapticFeedback.lightImpact();
              _hapticGivenForCurrentEnd = true;
            }
            // Rubber-band: allow limited overscroll in the blocked direction with friction.
            setState(() {
              _dragDx += details.delta.dx * 0.3;
              if (blockedPositive) _dragDx = _dragDx.clamp(0.0, _maxWiggleDx);
              if (blockedNegative) _dragDx = _dragDx.clamp(-_maxWiggleDx, 0.0);
            });
            return;
          } else {
            _hapticGivenForCurrentEnd = false;
          }
        }
        setState(() {
          _dragDx += details.delta.dx;
          _dragDx = _dragDx.clamp(-_maxDragDx, _maxDragDx);
        });
      },
      onHorizontalDragEnd: (details) {
        _hapticGivenForCurrentEnd = false;
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
        _hapticGivenForCurrentEnd = false;
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
              children: [
                // Peeking-zone tap overlay: sits at the bottom of z-order so it is
                // tested LAST in hit testing. It only wins when every card's SizedBox
                // misses (i.e. the rotated corner that peeks past the card's layout
                // bounds). Uses _advance(1) which is "bring next card to front" for
                // both fan directions.
                if (_attachments.length > 1 && (widget.infiniteScroll || _currentIndex < _attachments.length - 1))
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _advance(1);
                          _dragDx = 0;
                        });
                      },
                    ),
                  ),
                ...List.generate(_attachments.length, (i) {
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
                        // When used, it makes the image container a bit too wide.
                        // width: cardWidth,
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
                }).reversed,
              ],
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
                  galleryLabel,
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
