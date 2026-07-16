import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String videoPath;
  
  const VideoPreviewWidget({super.key, required this.videoPath});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  
  Timer? _segmentTimer;
  int _currentSegmentIndex = 0;
  final int _totalSegments = 10;
  final int _segmentDurationMs = 2500; // 2.5s per segment

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();
      await _controller.setVolume(0.0); // Mute for preview
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _playNextSegment();
      }
    } catch (e) {
      debugPrint("Error initializing preview for ${widget.videoPath}: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _playNextSegment() async {
    if (!mounted || !_isInitialized) return;

    final totalDurationMs = _controller.value.duration.inMilliseconds;
    if (totalDurationMs == 0) return;

    // Calculate start time for the current segment
    // E.g., if total is 100s, segments start at 0s, 10s, 20s... 90s.
    final segmentOffsetMs = (totalDurationMs / _totalSegments).floor();
    final startTimeMs = _currentSegmentIndex * segmentOffsetMs;
    
    await _controller.seekTo(Duration(milliseconds: startTimeMs));
    await _controller.play();

    _segmentTimer?.cancel();
    _segmentTimer = Timer(Duration(milliseconds: _segmentDurationMs), () {
      if (!mounted) return;
      _currentSegmentIndex = (_currentSegmentIndex + 1) % _totalSegments;
      _playNextSegment();
    });
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppColors.surfaceContainerLow,
        child: const Center(
          child: Icon(Icons.error_outline, color: AppColors.error),
        ),
      );
    }
    
    if (!_isInitialized) {
      return Container(
        color: AppColors.surfaceContainerLow,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller),
          // A subtle overlay to indicate it's a preview
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "PREVIEW",
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
