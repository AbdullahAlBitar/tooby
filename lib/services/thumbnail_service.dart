import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailService {
  Future<String?> generateThumbnail(String videoPath, {int? timeMs}) async {
    try {
      final Directory tempDir = await getApplicationDocumentsDirectory();
      final String thumbnailDir = p.join(tempDir.path, 'thumbnails');
      
      // Create directory if it doesn't exist
      final Directory dir = Directory(thumbnailDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Generate a unique filename using MD5 hash of the video path
      // This avoids collisions for same-named files in different folders
      final String pathHash = md5.convert(utf8.encode(videoPath)).toString();
      final String fileName = '$pathHash.jpg';
      final String fullThumbnailPath = p.join(thumbnailDir, fileName);

      // Check if thumbnail already exists to avoid redundant generation
      // unless we want to force regeneration by deleting it first elsewhere.
      final File thumbnailFile = File(fullThumbnailPath);
      if (await thumbnailFile.exists()) {
        // Return existing path if no specific timeMs requested (standard scan)
        if (timeMs == null) return fullThumbnailPath;
        // If specific timeMs requested, we'll continue and overwrite (regeneration)
      }

      final String? resultPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: fullThumbnailPath, // Note: video_thumbnail uses this as the output FILE path if it ends with an extension
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: timeMs ?? 15000, // Default to 15 seconds if not specified
      );

      return resultPath;
    } catch (e) {
      debugPrint('Error generating thumbnail for $videoPath: $e');
      return null;
    }
  }
}
