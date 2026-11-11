import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models/video_model.dart';
import '../player/player_service.dart';
import '../providers/network_provider.dart';
import '../providers/video_provider.dart';

/// Refreshes every provider that shows video titles / paths / thumbnails.
void invalidateVideoLists(WidgetRef ref, int videoId) {
  ref.invalidate(videoByIdProvider(videoId));
  ref.invalidate(allVideosProvider);
  ref.invalidate(recentVideosProvider);
  ref.invalidate(continueWatchingProvider);
  ref.invalidate(randomTagTypeVideosProvider);
  ref.invalidate(videosForTagProvider);
  ref.invalidate(recommendedVideosProvider);
  ref.invalidate(watchProgressProvider);
}

/// Refreshes providers that depend on a video's tags.
void invalidateTagLists(WidgetRef ref, int videoId) {
  ref.invalidate(tagsForVideoProvider(videoId));
  ref.invalidate(recommendedVideosProvider);
  ref.invalidate(allTagsProvider);
  ref.invalidate(allTagsWithCountProvider);
  ref.invalidate(videosForTagProvider);
  ref.invalidate(randomTagTypeVideosProvider);
}

/// Renames a video file (asking for storage access if needed).
/// Returns `null` on success, or an error message to show the user.
Future<String?> renameVideoFlow(WidgetRef ref, VideoModel video, String newTitle) async {
  if (ref.read(networkStateProvider).isClient) {
    return 'Renaming only works on the device that stores the videos (you are connected as a network client).';
  }

  if (!kIsWeb && Platform.isAndroid) {
    // Android 11+ only lets apps rename files they did not create when they
    // have "All files access". On older versions this reports granted.
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted) {
      return 'Tooby needs "All files access" to rename video files. '
          'Turn it on for Tooby in the settings screen, then try again.';
    }
  }

  try {
    final updated = await ref.read(videoScannerServiceProvider).renameVideo(video.id!, newTitle);
    invalidateVideoLists(ref, video.id!);
    ref.read(playerServiceProvider).updateCurrent(updated);
    return null;
  } on FileSystemException catch (e) {
    return 'Could not rename the file: ${e.osError?.message ?? e.message}';
  } catch (e) {
    return e.toString().replaceFirst('Exception: ', '');
  }
}

/// Regenerates a video's thumbnail. Returns true on success.
Future<bool> regenerateThumbnailFlow(WidgetRef ref, int videoId) async {
  final result = await ref.read(videoScannerServiceProvider).regenerateThumbnailById(videoId);
  // Thumbnails keep the same file name, so drop Flutter's cached image too.
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  invalidateVideoLists(ref, videoId);
  return result != null;
}
