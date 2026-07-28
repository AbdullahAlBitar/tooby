import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../data/models/video_model.dart';
import '../data/models/tag_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/video_repository.dart';
import 'thumbnail_service.dart';

class VideoScannerService {
  final VideoRepository _videoRepository = LocalVideoRepository();
  final TagRepository _tagRepository = LocalTagRepository();
  final ThumbnailService _thumbnailService = ThumbnailService();
  final _videoInfo = FlutterVideoInfo();

  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.flv', '.wmv'];

  Future<void> scanFullStorage({bool autoTag = false}) async {
    // On Android, we can find the root by taking an external directory and stripping the path
    final directory = await getExternalStorageDirectory();
    if (directory == null) return;

    // The path is usually /storage/emulated/X/Android/data/com.example.tooby/files
    // We want /storage/emulated/X
    final String rootPath = directory.path.split('/Android/')[0];
    await scanDirectory(rootPath, autoTag: autoTag);
  }

  Future<void> scanDirectory(String rootPath, {bool autoTag = false}) async {
    final Directory rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return;

    List<VideoModel> existingVideos = await _videoRepository.getAllVideos();
    Set<String> existingPaths = existingVideos.map((v) => v.path).toSet();

    await _scanRecursive(rootDir, existingPaths, autoTag: autoTag);
  }

  Future<void> _scanRecursive(Directory dir, Set<String> existingPaths, {bool autoTag = false}) async {
    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: false);

      for (var entity in entities) {
        if (entity is Directory) {
          // Avoid hidden directories
          if (!p.basename(entity.path).startsWith('.')) {
            await _scanRecursive(entity, existingPaths, autoTag: autoTag);
          }
        } else if (entity is File) {
          final String ext = p.extension(entity.path).toLowerCase();
          if (videoExtensions.contains(ext)) {
            if (!existingPaths.contains(entity.path)) {
              // New video found
              await _processNewVideo(entity, autoTag: autoTag);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
  }

  Future<void> _processNewVideo(File file, {required bool autoTag}) async {
    final String title = p.basenameWithoutExtension(file.path);
    final String path = file.path;

    // Extract duration and calculate thumbnail offset
    String? durationStr;
    int? thumbOffsetMs;
    try {
      final info = await _videoInfo.getVideoInfo(path);
      if (info != null && info.duration != null) {
        durationStr = _formatDuration(info.duration!);
        // Pick a point at 10% of the video, max 20 seconds, min 1 second
        thumbOffsetMs = (info.duration! * 0.1).toInt();
        // if (thumbOffsetMs > 20000) thumbOffsetMs = 20000;
        if (thumbOffsetMs < 1000) thumbOffsetMs = 1000;
      }
    } catch (e) {
      debugPrint('Error extracting duration for $path: $e');
    }

    // Generate thumbnail with calculated offset
    final String? thumbnailPath = await _thumbnailService.generateThumbnail(path, timeMs: thumbOffsetMs);

    final VideoModel video = VideoModel(
      path: path,
      title: title,
      duration: durationStr,
      thumbnail: thumbnailPath,
    );

    final int videoId = await _videoRepository.insertVideo(video);

    // Auto-tag by folder name
    if (autoTag) {
      try {
        final folderName = p.basename(file.parent.path);
        if (folderName.isNotEmpty && folderName != '0' && folderName != 'emulated') {
          final int tagId = await _tagRepository.getOrCreateTag(folderName);
          await _tagRepository.addTagToVideo(videoId, tagId);
        }
      } catch (e) {
        debugPrint('Error auto-tagging video $path: $e');
      }
    }
  }

  Future<void> regenerateAllThumbnails() async {
    final List<VideoModel> videos = await _videoRepository.getAllVideos();
    for (var video in videos) {
      await regenerateThumbnailById(video.id!);
    }
  }

  Future<String?> regenerateThumbnailById(int videoId) async {
    final video = await _videoRepository.getVideoById(videoId);
    if (video == null) return null;

    int? thumbOffsetMs;
    try {
      final info = await _videoInfo.getVideoInfo(video.path);
      if (info != null && info.duration != null) {
        thumbOffsetMs = (info.duration! * 0.1).toInt();
        if (thumbOffsetMs > 20000) thumbOffsetMs = 20000;
        if (thumbOffsetMs < 1000) thumbOffsetMs = 1000;
      }
    } catch (e) {
      debugPrint('Error getting info for ${video.path}: $e');
    }

    // Force regeneration by providing a timeMs (ThumbnailService logic preserves existing if timeMs is null)
    final String? newThumb = await _thumbnailService.generateThumbnail(video.path, timeMs: thumbOffsetMs ?? 15000);
    
    if (newThumb != null) {
      await _videoRepository.updateVideo(video.copyWith(thumbnail: newThumb));
    }
    return newThumb;
  }

  Future<void> refreshAllDurations() async {
    final List<VideoModel> videos = await _videoRepository.getAllVideos();
    for (var video in videos) {
      if (video.duration == null || video.duration!.isEmpty) {
        try {
          final info = await _videoInfo.getVideoInfo(video.path);
          if (info != null && info.duration != null) {
            final String durationStr = _formatDuration(info.duration!);
            await _videoRepository.updateVideo(video.copyWith(duration: durationStr));
          }
        } catch (e) {
          debugPrint('Error refreshing duration for ${video.path}: $e');
        }
      }
    }
  }

  Future<void> syncFolderTags() async {
    final List<VideoModel> videos = await _videoRepository.getAllVideos();
    for (var video in videos) {
      try {
        final File file = File(video.path);
        if (await file.exists()) {
          final folderName = p.basename(file.parent.path);
          if (folderName.isNotEmpty && folderName != '0' && folderName != 'emulated') {
            final int tagId = await _tagRepository.getOrCreateTag(folderName);
            
            // Link if not already linked
            final List<TagModel> tags = await _tagRepository.getTagsForVideo(video.id!);
            if (!tags.any((t) => t.id == tagId)) {
              await _tagRepository.addTagToVideo(video.id!, tagId);
            }
          }
        }
      } catch (e) {
        debugPrint('Error syncing folder tag for ${video.path}: $e');
      }
    }
  }

  Future<int> removeMissingVideos() async {
    final List<VideoModel> videos = await _videoRepository.getAllVideos();
    int removedCount = 0;
    for (var video in videos) {
      if (video.id == null) continue;
      final File file = File(video.path);
      if (!await file.exists()) {
        // Delete video database record (cascading deletes watch history and tag mappings)
        await _videoRepository.deleteVideo(video.id!);
        
        // Delete generated thumbnail file if it exists
        if (video.thumbnail != null && video.thumbnail!.isNotEmpty) {
          try {
            final File thumbFile = File(video.thumbnail!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          } catch (e) {
            debugPrint('Error deleting thumbnail for missing video ${video.path}: $e');
          }
        }
        removedCount++;
      }
    }
    return removedCount;
  }

  String _getRelativePath(String filePath) {
    final parts = p.split(filePath);
    if (parts.length >= 2) {
      return p.join(parts[parts.length - 2], parts[parts.length - 1]);
    }
    return parts.isNotEmpty ? parts.last : '';
  }

  Future<String> exportLibraryMetadata(String directoryPath) async {
    final List<VideoModel> videos = await _videoRepository.getAllVideos();
    final List<Map<String, dynamic>> exportedVideos = [];

    for (var video in videos) {
      if (video.id == null) continue;
      final tags = await _tagRepository.getTagsForVideo(video.id!);
      
      final filename = p.basename(video.path);
      final relativePath = _getRelativePath(video.path);

      exportedVideos.add({
        'title': video.title,
        'path': video.path,
        'filename': filename,
        'relativePath': relativePath,
        'tags': tags.map((t) => {
          'name': t.name,
          'type': t.typeName ?? 'default',
        }).toList(),
      });
    }

    final backupData = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'videos': exportedVideos,
    };

    final String jsonStr = jsonEncode(backupData);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = 'tooby_backup_$timestamp.json';
    final String fullPath = p.join(directoryPath, fileName);

    final File backupFile = File(fullPath);
    await backupFile.writeAsString(jsonStr);

    return fileName;
  }

  Future<Map<String, int>> importLibraryMetadata(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Backup file not found.");
    }

    final String jsonStr = await file.readAsString();
    final Map<String, dynamic> backupData = jsonDecode(jsonStr);
    
    final List<dynamic> backupVideos = backupData['videos'] ?? [];
    int matchedCount = 0;
    int tagsAppliedCount = 0;

    // Get all current videos in database to match against
    final List<VideoModel> currentVideos = await _videoRepository.getAllVideos();

    for (var backupVideo in backupVideos) {
      final String? bPath = backupVideo['path'];
      final String? bFilename = backupVideo['filename'];
      final String? bRelativePath = backupVideo['relativePath'];
      final List<dynamic> bTags = backupVideo['tags'] ?? [];

      if (bTags.isEmpty) continue;

      // Try to find a matching video in the current database
      VideoModel? matchedVideo;

      // 1. Match by exact path
      if (bPath != null) {
        for (var currentVideo in currentVideos) {
          if (currentVideo.path == bPath) {
            matchedVideo = currentVideo;
            break;
          }
        }
      }

      // 2. Match by relative path suffix
      if (matchedVideo == null && bRelativePath != null) {
        final normBRel = p.normalize(bRelativePath).replaceAll('\\', '/');
        for (var currentVideo in currentVideos) {
          final normCurrent = p.normalize(currentVideo.path).replaceAll('\\', '/');
          if (normCurrent.endsWith(normBRel)) {
            matchedVideo = currentVideo;
            break;
          }
        }
      }

      // 3. Match by filename
      if (matchedVideo == null && bFilename != null) {
        for (var currentVideo in currentVideos) {
          if (p.basename(currentVideo.path) == bFilename) {
            matchedVideo = currentVideo;
            break;
          }
        }
      }

      // If matched, apply tags
      if (matchedVideo != null && matchedVideo.id != null) {
        matchedCount++;
        final List<TagModel> currentTags = await _tagRepository.getTagsForVideo(matchedVideo.id!);
        final Set<String> currentTagNames = currentTags.map((t) => t.name.toLowerCase()).toSet();

        for (var tagValue in bTags) {
          String tagName = '';
          String typeName = 'default';

          if (tagValue is String) {
            tagName = tagValue;
          } else if (tagValue is Map<String, dynamic>) {
            tagName = tagValue['name'] ?? '';
            typeName = tagValue['type'] ?? 'default';
          }

          if (tagName.isEmpty) continue;

          // Get or create tag type
          final int typeId = await _tagRepository.getOrCreateTagType(typeName);

          // Get or create tag
          final int tagId = await _tagRepository.getOrCreateTag(tagName, typeId: typeId);

          // Update tag type if it is currently 'default' but backup specifies a custom type
          final allTags = await _tagRepository.getAllTags();
          final existingTag = allTags.firstWhere((t) => t.id == tagId);
          if (existingTag.typeId == 1 && typeId != 1) {
            await _tagRepository.updateTag(existingTag.copyWith(typeId: typeId));
          }

          // Add mapping if not exists
          if (!currentTagNames.contains(tagName.toLowerCase())) {
            await _tagRepository.addTagToVideo(matchedVideo.id!, tagId);
            tagsAppliedCount++;
          }
        }
      }
    }

    return {
      'totalInBackup': backupVideos.length,
      'matchedVideos': matchedCount,
      'tagsApplied': tagsAppliedCount,
    };
  }


  String _formatDuration(double durationMs) {
    final int totalSeconds = (durationMs / 1000).floor();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
