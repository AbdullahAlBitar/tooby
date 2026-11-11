import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/tag_editor_body.dart';

class VideoTagEditorPage extends StatelessWidget {
  final int videoId;
  final String videoTitle;

  const VideoTagEditorPage({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Tags', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              videoTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: TagEditorBody(videoId: videoId),
    );
  }
}
