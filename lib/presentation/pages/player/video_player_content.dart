import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../providers/video_provider.dart';
import '../../../providers/global_video_provider.dart';
import '../../widgets/common_widgets.dart';

class VideoPlayerContent extends ConsumerStatefulWidget {
  final int videoId;

  const VideoPlayerContent({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerContent> createState() => _VideoPlayerContentState();
}

class _VideoPlayerContentState extends ConsumerState<VideoPlayerContent> {
  bool _isRenaming = false;

  Future<void> _showEditTitleDialog(BuildContext context, WidgetRef ref, VideoModel video) async {
    final TextEditingController controller = TextEditingController(text: video.title);
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Video Title"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Title",
              hintText: "Enter new video title",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isEmpty || newTitle == video.title) {
                  Navigator.pop(context);
                  return;
                }
                
                Navigator.pop(context); // Close dialog first
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Renaming video...")),
                );

                setState(() => _isRenaming = true);
                
                try {
                  await ref.read(videoScannerServiceProvider).renameVideo(video.id!, newTitle);
                  
                  ref.invalidate(videoByIdProvider(video.id!));
                  ref.invalidate(allVideosProvider);
                  ref.invalidate(recentVideosProvider);
                  ref.invalidate(continueWatchingProvider);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Video renamed successfully!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error renaming video: $e")),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isRenaming = false);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoByIdProvider(widget.videoId));
    final tagsAsync = ref.watch(tagsForVideoProvider(widget.videoId));
    final recommendationsAsync = ref.watch(recommendedVideosProvider(widget.videoId));

    return videoAsync.when(
      data: (video) {
        if (video == null) return const Center(child: Text("Video not found"));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(video.title, style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 24, color: AppColors.primary),
                      onPressed: () => _showEditTitleDialog(context, ref, video),
                      tooltip: 'Edit Title',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: tagsAsync.when(
                        data: (tags) => Wrap(
                          spacing: 8,
                          children: tags.map((t) => TagChip(label: t.name)).toList(),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                      onPressed: () {
                        Navigator.pushNamed(context, '/video-tags', arguments: {'videoId': widget.videoId, 'videoTitle': video.title});
                      },
                    ),
                  ],
                ),
                const Divider(color: AppColors.outlineVariant, height: 32),
                _buildRecommendations(context, recommendationsAsync, ref),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    AsyncValue<List<VideoModel>> recommendationsAsync,
    WidgetRef ref,
  ) {
    return recommendationsAsync.when(
      data: (videos) {
        if (videos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Suggested Videos",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final v = videos[index];
                return VideoCard(
                  title: v.title,
                  thumbnail: v.thumbnail,
                  videoPath: v.path,
                  onTap: () {
                    // Navigate using the new global video provider
                    openVideo(context, ref, v.id!);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
