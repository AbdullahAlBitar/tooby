import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/watch_history_model.dart';
import '../../providers/video_provider.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final int videoId;
  final String videoPath;
  final Duration initialPosition;
  final bool showFullscreenButton;

  const VideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.videoPath,
    this.initialPosition = Duration.zero,
    this.showFullscreenButton = true,
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

      // Enable wakelock to prevent screen from dimming
      await WakelockPlus.enable();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: false,
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

  Future<void> _openFullscreen() async {
    if (!_isInitialized || _chewieController == null) return;

    final currentPosition = _videoPlayerController.value.position;
    final isPlaying = _videoPlayerController.value.isPlaying;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayerPage(
          videoId: widget.videoId,
          videoPath: widget.videoPath,
          initialPosition: currentPosition,
          isPlaying: isPlaying,
        ),
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    // Disable wakelock when the player is disposed
    WakelockPlus.disable();
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

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: _videoPlayerController.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
        if (widget.showFullscreenButton)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: _openFullscreen,
                tooltip: 'Fullscreen',
              ),
            ),
          ),
      ],
    );
  }
}

class FullScreenVideoPlayerPage extends StatefulWidget {
  final int videoId;
  final String videoPath;
  final Duration initialPosition;
  final bool isPlaying;

  const FullScreenVideoPlayerPage({
    super.key,
    required this.videoId,
    required this.videoPath,
    required this.initialPosition,
    required this.isPlaying,
  });

  @override
  State<FullScreenVideoPlayerPage> createState() => _FullScreenVideoPlayerPageState();
}

class _FullScreenVideoPlayerPageState extends State<FullScreenVideoPlayerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: VideoPlayerWidget(
            videoId: widget.videoId,
            videoPath: widget.videoPath,
            initialPosition: widget.initialPosition,
            showFullscreenButton: false,
          ),
        ),
      ),
    );
  }
}
