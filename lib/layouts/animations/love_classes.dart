import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LoveController implements Listenable {
  LoveController({
    required this.vsync,
  });

  final TickerProvider vsync;
  LoveObject? heart;
  final Random random = Random();
  Size windowSize = Size.zero;

  late Ticker ticker;
  late Point<double> position;

  bool isPlaying = false;
  bool requestedToStop = false;
  final List<VoidCallback> listeners = [];

  Duration lastAutoLaunch = Duration.zero;
  Duration autoLaunchDuration = Duration(milliseconds: 100);

  void start(Point<double> startPos) {
    isPlaying = true;
    autoLaunchDuration = Duration(milliseconds: 100);
    lastAutoLaunch = Duration.zero;
    position = startPos;
    ticker = vsync.createTicker(update)..start();
  }

  void stop() {
    autoLaunchDuration = Duration.zero;
    requestedToStop = true;
  }

  @override
  void addListener(listener) {
    assert(!listeners.contains(listener));

    listeners.add(listener);
  }

  @override
  void removeListener(listener) {
    assert(listeners.contains(listener));

    listeners.remove(listener);
  }

  void dispose() {
    listeners.clear();
    ticker.dispose();
  }

  void update(Duration elapsedDuration) {
    if (windowSize == Size.zero) {
      // We need to wait until we have the size.
      return;
    }

    heart ??= LoveObject(
        random: random,
        originalPosition: position,
        position: position,
        size: 1,
      );

    heart!.update();

    if (heart!.position.y < -200 && requestedToStop) {
      ticker.stop();
      ticker.dispose();
      isPlaying = false;
      requestedToStop = false;
      heart = null;
    }
    // Notify listeners.
    // The copy of the list and the condition prevent
    // ConcurrentModificationError's, in case a listener removes itself
    // or another listener.
    // See https://stackoverflow.com/q/62417999/6509751.
    for (final listener in List.of(listeners)) {
      if (!listeners.contains(listener)) continue;
      listener.call();
    }
  }
}

class LoveObject {
  LoveObject({
    required this.random,
    required this.originalPosition,
    required this.position,
    required this.size,
  });

  final Random random;
  final Point<double> originalPosition;
  Point<double> position;
  double size;

  double velocity = 0.5;
  final double acceleration = 1.01;

  void update() {
    if (size < 200) {
      size = 1 + size;
      position = Point(originalPosition.x - size / 2, originalPosition.y - size);
      return;
    }

    position = Point(position.x - velocity * cos(5 * pi / 12), position.y - velocity * sin(5 * pi / 12));

    velocity *= acceleration;
    velocity.clamp(0.5, 2);
  }
}