import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';
import '../player/video_player_page.dart';

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
        title: Text('#$tagName', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(child: Text("No videos found for this tag"));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.8,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final v = videos[index];
              return VideoCard(
                title: v.title,
                thumbnail: v.thumbnail,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerPage(videoId: v.id!),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
