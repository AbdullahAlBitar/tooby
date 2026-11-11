import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_colors.dart';

/// Plays short jumps through a video (10 segments of 2.5 s) while a card is
/// held down.
class VideoPreviewWidget extends StatefulWidget {
  final String videoPath;

  const VideoPreviewWidget({super.key, required this.videoPath});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<Duration>? _durationSub;
  bool _ready = false;
  bool _hasError = false;

  Timer? _segmentTimer;
  int _segment = 0;
  static const int _totalSegments = 10;
  static const int _segmentMs = 2500;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _durationSub = _player.stream.duration.listen((d) {
        if (d > Duration.zero && !_ready && mounted) {
          setState(() => _ready = true);
          _playNextSegment();
        }
      });
      _player.stream.error.listen((_) {
        if (mounted && !_ready) setState(() => _hasError = true);
      });
      await _player.open(Media(widget.videoPath), play: true);
    } catch (e) {
      debugPrint('Error initializing preview for ${widget.videoPath}: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _playNextSegment() async {
    if (!mounted || !_ready) return;
    final total = _player.state.duration.inMilliseconds;
    if (total == 0) return;
    final start = (total / _totalSegments).floor() * _segment;
    await _player.seek(Duration(milliseconds: start));
    await _player.play();
    _segmentTimer?.cancel();
    _segmentTimer = Timer(const Duration(milliseconds: _segmentMs), () {
      if (!mounted) return;
      _segment = (_segment + 1) % _totalSegments;
      _playNextSegment();
    });
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: AppColors.surfaceContainerLow,
        child: Center(child: Icon(Icons.error_outline, color: AppColors.error)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
          fill: AppColors.surfaceContainerLow,
          wakelock: false,
        ),
        if (!_ready)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'PREVIEW',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
