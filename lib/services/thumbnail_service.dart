import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailService {
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      final Directory tempDir = await getApplicationDocumentsDirectory();
      final String thumbnailDir = p.join(tempDir.path, 'thumbnails');
      
      // Create directory if it doesn't exist
      final Directory dir = Directory(thumbnailDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailDir,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400, // Reduced size for performance
        quality: 75,
        timeMs: 12000, // 12 seconds offset to avoid black frames
      );

      return thumbnailPath;
    } catch (e) {
      debugPrint('Error generating thumbnail for $videoPath: $e');
      return null;
    }
  }
}
