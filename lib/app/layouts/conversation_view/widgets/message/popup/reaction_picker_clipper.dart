import 'dart:math';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

class ReactionPickerClipper extends CustomClipper<Path> {
  final Size messageSize;
  final bool isFromMe;
  final double cornerRadius;

  const ReactionPickerClipper({
    required this.messageSize,
    required this.isFromMe,
    this.cornerRadius = 30,
  });

  @override
  Path getClip(Size size) {
    // Bottom of the visible shape (leaves room for the tail dots below)
    const double bottomY = 15.0;
    final path = Path();
    // Use addRRect for guaranteed perfect corners
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - bottomY),
      Radius.circular(cornerRadius),
    ));
    if (size.width > messageSize.width && SettingsSvc.settings.skin.value == Skins.iOS) {
      if (isFromMe) {
        path.addArc(Rect.fromLTWH(size.width - messageSize.width, size.height - 22.5, 17.5, 17.5), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(size.width - messageSize.width - 5, size.height - 7.5, 7, 7), 0, 2 * pi);
      } else {
        path.addArc(Rect.fromLTWH(messageSize.width - 20, size.height - 22.5, 17.5, 17.5), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(messageSize.width - 5, size.height - 7.5, 7, 7), 0, 2 * pi);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionPickerClipper oldClipper) {
    return cornerRadius != oldClipper.cornerRadius ||
        messageSize != oldClipper.messageSize ||
        isFromMe != oldClipper.isFromMe;
  }
}
