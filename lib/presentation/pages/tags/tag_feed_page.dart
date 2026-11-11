import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../../player/player_service.dart';

class TagFeedPage extends ConsumerWidget {
  final int tagId;
  final String tagName;

  const TagFeedPage({super.key, required this.tagId, required this.tagName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosForTagProvider(tagId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#$tagName', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (videosAsync.valueOrNull != null)
              Text('${videosAsync.valueOrNull!.length} videos',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Play all (shuffle)',
            icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
            onPressed: () {
              final list = [...?videosAsync.valueOrNull]..shuffle();
              if (list.isNotEmpty) openVideo(context, ref, list.first.id!);
            },
          ),
        ],
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(
              child: Text("No videos found for this tag",
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            );
          }
          return VideoGrid(videos: videos);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
