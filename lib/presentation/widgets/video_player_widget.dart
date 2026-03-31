import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/watch_history_model.dart';
import '../../providers/video_provider.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final int videoId;
  final String videoPath;
  final Duration initialPosition;

  const VideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.videoPath,
    this.initialPosition = Duration.zero,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
    
    try {
      await _videoPlayerController.initialize();
      
      // Seek to initial position
      if (widget.initialPosition > Duration.zero) {
        await _videoPlayerController.seekTo(widget.initialPosition);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: AppColors.primary.withValues(alpha: 0.5),
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
      );

      // Listen for position changes to save progress
      _videoPlayerController.addListener(_onPositionChanged);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint("Error initializing video player: $e");
    }
  }

  void _onPositionChanged() {
    if (_videoPlayerController.value.isPlaying) {
      ref.read(videoRepositoryProvider).saveWatchHistory(
            WatchHistoryModel(
              videoId: widget.videoId,
              lastPosition: _videoPlayerController.value.position,
              lastWatched: DateTime.now(),
            ),
          );
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_onPositionChanged);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _chewieController == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}
