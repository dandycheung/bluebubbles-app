import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

/// Full-screen in-app camera screen using CameraAwesome (CameraX under the
/// hood on Android). Supports both photo and video modes via the built-in UI.
///
/// Returns the captured [XFile] via [Navigator.pop], or `null` if the user
/// cancels. Only rendered on Android; callers should guard with
/// `Platform.isAndroid && !kIsWeb` before pushing this route.
class CameraScreen extends StatefulWidget {
  /// 'photo' (default) or 'video'.
  final String initialMode;

  const CameraScreen({super.key, this.initialMode = 'photo'});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _previewFile;
  bool _isVideo = false;

  final TransformationController _previewTransformController = TransformationController();
  Offset _previewDoubleTapPosition = Offset.zero;

  @override
  void dispose() {
    _previewTransformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraAwesome(),
          if (_previewFile != null) _buildConfirmOverlay(_previewFile!),
        ],
      ),
    );
  }

  Widget _buildCameraAwesome() {
    return CameraAwesomeBuilder.awesome(
      saveConfig: SaveConfig.photoAndVideo(
        initialCaptureMode: widget.initialMode == 'video' ? CaptureMode.video : CaptureMode.photo,
        photoPathBuilder: (sensors) async {
          final dir = await getTemporaryDirectory();
          final ts = DateTime.now().millisecondsSinceEpoch;
          return SingleCaptureRequest('${dir.path}/bb_photo_$ts.jpg', sensors.first);
        },
        videoPathBuilder: (sensors) async {
          final dir = await getTemporaryDirectory();
          final ts = DateTime.now().millisecondsSinceEpoch;
          return SingleCaptureRequest('${dir.path}/bb_video_$ts.mp4', sensors.first);
        },
        videoOptions: VideoOptions(
          enableAudio: true,
          android: AndroidVideoOptions(
            bitrate: 6000000,
            fallbackStrategy: QualityFallbackStrategy.lower,
          ),
        ),
      ),
      sensorConfig: SensorConfig.single(
        sensor: Sensor.position(SensorPosition.back),
        flashMode: FlashMode.none,
        aspectRatio: CameraAspectRatios.ratio_4_3,
        zoom: 0.0,
      ),
      availableFilters: [],
      enablePhysicalButton: true,
      // Override the default scale handler so pinch-to-zoom always starts from
      // the actual current zoom rather than the gesture detector's stale base.
      onPreviewScaleBuilder: (state) {
        double? _prevScale;
        return OnPreviewScale(
          onScale: (scale) {
            if (_prevScale == null) {
              _prevScale = scale;
              return;
            }
            final delta = scale - _prevScale!;
            _prevScale = scale;
            if (delta == 0) return;
            final newLinear = (state.sensorConfig.zoom + delta).clamp(0.0, 1.0);
            state.sensorConfig.setZoom(newLinear);
          },
        );
      },
      middleContentBuilder: (state) => Column(
        children: [
          const Spacer(),
          _ZoomPill(state: state),
          AwesomeCameraModeSelector(state: state),
        ],
      ),
      onMediaCaptureEvent: (event) {
        if (event.status == MediaCaptureStatus.success) {
          event.captureRequest.when(
            single: (req) {
              final path = req.file?.path;
              if (path != null && mounted) {
                setState(() {
                  _isVideo = path.toLowerCase().endsWith('.mp4');
                  _previewFile = XFile(path);
                });
              }
            },
            multiple: (req) {
              final path = req.fileBySensor.values.first?.path;
              if (path != null && mounted) {
                setState(() {
                  _isVideo = path.toLowerCase().endsWith('.mp4');
                  _previewFile = XFile(path);
                });
              }
            },
          );
        }
      },
    );
  }

  Widget _buildConfirmOverlay(XFile file) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen interactive preview (pinch-to-zoom + double-tap)
          GestureDetector(
            onDoubleTapDown: (d) => _previewDoubleTapPosition = d.localPosition,
            onDoubleTap: () {
              final isZoomedIn = _previewTransformController.value != Matrix4.identity();
              if (isZoomedIn) {
                _previewTransformController.value = Matrix4.identity();
              } else {
                final m = Matrix4.identity()
                  ..translateByDouble(
                    -_previewDoubleTapPosition.dx * (2.5 - 1),
                    -_previewDoubleTapPosition.dy * (2.5 - 1),
                    0,
                    1,
                  )
                  ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
                _previewTransformController.value = m;
              }
            },
            child: InteractiveViewer(
              transformationController: _previewTransformController,
              minScale: 1.0,
              maxScale: 4.0,
              boundaryMargin: EdgeInsets.zero,
              child: Center(
                child: _isVideo ? _VideoPreview(file: file) : Image.file(File(file.path), fit: BoxFit.contain),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 8,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ),
          ),

          // Retake / Use bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: () {
                        _previewTransformController.value = Matrix4.identity();
                        setState(() => _previewFile = null);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('Use', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: () => Navigator.of(context).pop(file),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zoom pill — shows discrete optical zoom levels (0.5×, 1×, 2×, …) filtered
// to the device's actual range. The active pill displays the live ratio so
// pinch-to-zoom updates are reflected in real time.
// ---------------------------------------------------------------------------

class _ZoomPill extends StatefulWidget {
  final CameraState state;

  const _ZoomPill({required this.state});

  @override
  State<_ZoomPill> createState() => _ZoomPillState();
}

class _ZoomPillState extends State<_ZoomPill> with WidgetsBindingObserver {
  double? _minZoom;
  double? _maxZoom;
  List<double> _levels = const [];

  /// Source of truth for the active pill and live label.
  double _currentRatio = 1.0;

  /// True while we are programmatically setting zoom (init, reset, pill tap).
  /// The zoom$ listener ignores emissions during this window so it can't
  /// replay the old value and override a reset.
  bool _programmaticZoom = false;

  bool _zoomReady = false;
  StreamSubscription<CameraAspectRatios>? _aspectRatioSub;
  StreamSubscription<double>? _zoomSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadZoomRange().then((_) {
      if (!mounted) return;
      final sensorConfig = widget.state.sensorConfig;
      // aspectRatio$ is a BehaviorSubject — skip(1) ignores the initial replay
      // so we only fire on actual aspect-ratio changes.
      _aspectRatioSub = sensorConfig.aspectRatio$.skip(1).listen((_) {
        if (_zoomReady) _reapplyDefaultZoom();
      });
      _subscribeZoom(sensorConfig);
    });
  }

  /// Subscribes to [sensorConfig]'s zoom$ stream so pinch-to-zoom events
  /// update _currentRatio.  Uses skip(1) to ignore the BehaviorSubject replay.
  void _subscribeZoom(SensorConfig sensorConfig) {
    _zoomSub?.cancel();
    _zoomSub = sensorConfig.zoom$.skip(1).listen((linear) {
      if (_programmaticZoom || !mounted || _minZoom == null || _maxZoom == null) return;
      final ratio = _linearToRatio(linear);
      if ((ratio - _currentRatio).abs() > 0.02) {
        setState(() => _currentRatio = ratio);
      }
    });
  }

  Future<void> _loadZoomRange() async {
    final min = await CamerawesomePlugin.getMinZoom();
    final max = await CamerawesomePlugin.getMaxZoom();
    if (min == null || max == null || !mounted) return;

    final List<double> levels = [];

    if (min < 0.95) levels.add(min);
    if (max >= 1.0) levels.add(1.0);
    for (final candidate in [2.0, 5.0]) {
      if (candidate > 1.05 && candidate <= max + 0.05) levels.add(candidate);
    }

    final defaultRatio = max >= 1.0 ? 1.0 : min;

    if (mounted) {
      setState(() {
        _minZoom = min;
        _maxZoom = max;
        _levels = levels;
        _currentRatio = defaultRatio;
      });
    }

    await _applyZoom(defaultRatio, min: min, max: max);
    _zoomReady = true;
  }

  /// Re-applies the default zoom after a config reset (aspect-ratio change or
  /// app resume).  Sets _currentRatio immediately so the pill updates at once.
  Future<void> _reapplyDefaultZoom() async {
    if (_minZoom == null || _maxZoom == null || !mounted) return;
    final defaultRatio = _maxZoom! >= 1.0 ? 1.0 : _minZoom!;
    setState(() => _currentRatio = defaultRatio);
    await _applyZoom(defaultRatio);
  }

  /// Converts [ratio] to a CameraX FOV-linear value, blocks the zoom$ listener
  /// during the call, then applies it.
  Future<void> _applyZoom(double ratio, {double? min, double? max}) async {
    final effectiveMin = min ?? _minZoom;
    final effectiveMax = max ?? _maxZoom;
    if (effectiveMin == null || effectiveMax == null) return;
    final invMin = 1.0 / effectiveMin;
    final invMax = 1.0 / effectiveMax;
    final linear = invMin == invMax ? 0.0 : (((1.0 / ratio) - invMin) / (invMax - invMin)).clamp(0.0, 1.0);
    _programmaticZoom = true;
    await widget.state.sensorConfig.setZoom(linear);
    // Brief hold to absorb any synchronous BehaviorSubject replay before
    // re-enabling pinch-driven updates.
    await Future.delayed(const Duration(milliseconds: 150));
    _programmaticZoom = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aspectRatioSub?.cancel();
    _zoomSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _zoomReady) {
      Future.delayed(const Duration(milliseconds: 800), _reapplyDefaultZoom);
    }
  }

  /// Converts a CameraX linear value back to the optical zoom ratio.
  double _linearToRatio(double linear) {
    final invMin = 1.0 / _minZoom!;
    final invMax = 1.0 / _maxZoom!;
    return 1.0 / (invMin + linear * (invMax - invMin));
  }

  /// Returns the preset level closest to [ratio].
  double _closestLevel(double ratio) => _levels.reduce((a, b) => (a - ratio).abs() < (b - ratio).abs() ? a : b);

  @override
  Widget build(BuildContext context) {
    if (_minZoom == null || _maxZoom == null || _levels.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeLevel = _closestLevel(_currentRatio);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: _levels.map((level) {
          final isActive = level == activeLevel;
          final label = isActive
              ? '${_currentRatio.toStringAsFixed(_currentRatio < 10 ? 1 : 0)}×'
              : '${level.toStringAsFixed(level >= 1 && level % 1 == 0 ? 0 : 1)}×';

          return GestureDetector(
            onTap: () {
              setState(() => _currentRatio = level);
              _applyZoom(level);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  isActive ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: isActive ? Border.all(color: Colors.white54, width: 1) : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final XFile file;

  const _VideoPreview({required this.file});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _videoController;
  bool _initialized = false;
  bool _muted = false;

  /// Whether the control bar is currently visible.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.file.path));
    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _videoController.setLooping(true);
        _videoController.play();
        _scheduleHide();
      }
    });
    // Rebuild on every position tick so the seek bar updates smoothly.
    _videoController.addListener(_onVideoTick);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoController.removeListener(_onVideoTick);
    _videoController.dispose();
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  // ── Controls visibility ────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  // ── Playback helpers ───────────────────────────────────────────────────

  void _togglePlay() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _hideTimer?.cancel(); // keep controls visible while paused
      } else {
        _videoController.play();
        _scheduleHide();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _videoController.setVolume(_muted ? 0.0 : 1.0);
    });
    _scheduleHide();
  }

  // ── Formatting ─────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final value = _videoController.value;
    final total = value.duration.inMilliseconds.toDouble();
    final position = value.position.inMilliseconds.toDouble().clamp(0.0, total);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController),

            // Tap-to-reveal scrim + controls
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Gradient scrim so controls are readable over any content
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Centre play/pause button
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            key: ValueKey(value.isPlaying),
                            color: Colors.white,
                            size: 68,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
                          ),
                        ),
                      ),
                    ),

                    // Bottom bar: seek + time + mute
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Seek slider
                            SliderTheme(
                              data: const SliderThemeData(
                                trackHeight: 2.5,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white38,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
                              ),
                              child: Slider(
                                value: total > 0 ? position / total : 0.0,
                                onChangeStart: (_) => _hideTimer?.cancel(),
                                onChanged: total > 0
                                    ? (v) {
                                        final target = Duration(milliseconds: (v * total).round());
                                        _videoController.seekTo(target);
                                      }
                                    : null,
                                onChangeEnd: (_) {
                                  if (_videoController.value.isPlaying) _scheduleHide();
                                },
                              ),
                            ),

                            // Time labels + mute button
                            Row(
                              children: [
                                Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const Text(
                                  ' / ',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                Text(
                                  _formatDuration(value.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _toggleMute,
                                  child: Icon(
                                    _muted ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
