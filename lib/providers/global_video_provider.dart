import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:floatube_player/floatube_player.dart';

import '../core/theme/app_colors.dart';
import '../data/models/watch_history_model.dart';
import '../presentation/pages/player/video_player_content.dart';
import 'video_provider.dart';

enum VideoViewMode { hidden, miniPlayer, normal, fullscreen }

class GlobalVideoState {
  final int? videoId;
  final String? videoPath;
  final VideoViewMode mode;
  final bool isInitialized;
  
  GlobalVideoState({
    this.videoId,
    this.videoPath,
    this.mode = VideoViewMode.hidden,
    this.isInitialized = false,
  });
  
  GlobalVideoState copyWith({
    int? videoId,
    String? videoPath,
    VideoViewMode? mode,
    bool? isInitialized,
  }) {
    return GlobalVideoState(
      videoId: videoId ?? this.videoId,
      videoPath: videoPath ?? this.videoPath,
      mode: mode ?? this.mode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class GlobalVideoNotifier extends StateNotifier<GlobalVideoState> {
  GlobalVideoNotifier(this.ref) : super(GlobalVideoState());
  
  final Ref ref;
  VideoPlayerController? videoPlayerController;
  
  Future<void> playVideo(int videoId) async {
    if (state.videoId == videoId && state.isInitialized) {
      if (state.mode == VideoViewMode.hidden || state.mode == VideoViewMode.miniPlayer) {
        state = state.copyWith(mode: VideoViewMode.normal);
      }
      return;
    }
    
    _disposeControllers();
    
    state = GlobalVideoState(
      videoId: videoId,
      mode: VideoViewMode.normal,
      isInitialized: false,
    );
    
    try {
      final repo = ref.read(videoRepositoryProvider);
      final video = await repo.getVideoById(videoId);
      if (video == null) throw Exception("Video not found");
      
      final history = await repo.getWatchHistory(videoId);
      final initialPosition = history?.lastPosition ?? Duration.zero;
      final videoPath = video.path;
      
      state = state.copyWith(videoPath: videoPath);
      
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        videoPlayerController = VideoPlayerController.file(File(videoPath));
      }
      
      await videoPlayerController!.initialize();
      
      if (initialPosition > Duration.zero) {
        await videoPlayerController!.seekTo(initialPosition);
      }
      
      await WakelockPlus.enable();
      
      videoPlayerController!.addListener(_onPositionChanged);
      
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      debugPrint("Error initializing global video player: $e");
    }
  }
  
  void _onPositionChanged() {
    if (videoPlayerController?.value.isPlaying == true && state.videoId != null) {
      ref.read(videoRepositoryProvider).saveWatchHistory(
        WatchHistoryModel(
          videoId: state.videoId!,
          lastPosition: videoPlayerController!.value.position,
          lastWatched: DateTime.now(),
        ),
      );
    }
  }
  
  void setMode(VideoViewMode mode) {
    state = state.copyWith(mode: mode);
  }
  
  void closeVideo() {
    _disposeControllers();
    state = GlobalVideoState(mode: VideoViewMode.hidden);
  }
  
  void _disposeControllers() {
    WakelockPlus.disable();
    if (videoPlayerController != null) {
      videoPlayerController!.removeListener(_onPositionChanged);
      videoPlayerController!.dispose();
      videoPlayerController = null;
    }
  }
  
  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }
}

final globalVideoProvider = StateNotifierProvider<GlobalVideoNotifier, GlobalVideoState>((ref) {
  return GlobalVideoNotifier(ref);
});

void openVideo(BuildContext context, WidgetRef ref, int videoId) {
  ref.read(globalVideoProvider.notifier).playVideo(videoId).then((_) {
    final notifier = ref.read(globalVideoProvider.notifier);
    if (notifier.videoPlayerController != null) {
      context.floatingController.open(
        context,
        (key) => FloatingPlayerView(
          key: key,
          source: VideoSource.controller(notifier.videoPlayerController!),
          autoPlay: true,
          contentBuilder: () => VideoPlayerContent(videoId: videoId),
        ),
      );
    }
  });
}
