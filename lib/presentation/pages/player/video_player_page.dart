import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/common_widgets.dart';

class VideoPlayerPage extends ConsumerWidget {
  final int videoId;

  const VideoPlayerPage({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoAsync = ref.watch(videoByIdProvider(videoId));
    final tagsAsync = ref.watch(tagsForVideoProvider(videoId));
    final recommendationsAsync = ref.watch(recommendedVideosProvider(videoId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Regenerating thumbnail...")),
              );
              await ref.read(videoScannerServiceProvider).regenerateThumbnailById(videoId);
              ref.invalidate(videoByIdProvider(videoId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Thumbnail updated!")),
                );
              }
            },
            tooltip: 'Refresh Thumbnail',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.primary),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            tooltip: 'Close Player',
          ),
        ],
      ),
      body: videoAsync.when(
        data: (video) {
          if (video == null) return const Center(child: Text("Video not found"));
          return _buildContent(context, ref, video, tagsAsync, recommendationsAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    VideoModel video,
    AsyncValue<List<dynamic>> tagsAsync,
    AsyncValue<List<VideoModel>> recommendationsAsync,
  ) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left half (Video + details)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    FutureBuilder(
                      future: ref.read(videoRepositoryProvider).getWatchHistory(videoId),
                      builder: (context, snapshot) {
                        final initialPosition = snapshot.data?.lastPosition ?? Duration.zero;
                        return VideoPlayerWidget(
                          videoId: videoId,
                          videoPath: video.path,
                          initialPosition: initialPosition,
                        );
                      },
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video.title, style: Theme.of(context).textTheme.headlineMedium),
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
                                      Navigator.pushNamed(context, '/video-tags', arguments: {'videoId': videoId, 'videoTitle': video.title});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Right half (Recommendations)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.outlineVariant)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildRecommendations(context, recommendationsAsync, ref),
                  ),
                ),
              ),
            ],
          );
        }

        // Portrait mode
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: ref.read(videoRepositoryProvider).getWatchHistory(videoId),
              builder: (context, snapshot) {
                final initialPosition = snapshot.data?.lastPosition ?? Duration.zero;
                return VideoPlayerWidget(
                  videoId: videoId,
                  videoPath: video.path,
                  initialPosition: initialPosition,
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.title, style: Theme.of(context).textTheme.headlineMedium),
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
                              Navigator.pushNamed(context, '/video-tags', arguments: {'videoId': videoId, 'videoTitle': video.title});
                            },
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.outlineVariant, height: 32),
                      _buildRecommendations(context, recommendationsAsync, ref),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
                  onTap: () {
                    // Navigate to same page with new ID (using push to keep history)
                    Navigator.pushNamed(
                      context,
                      '/player',
                      arguments: {'videoId': v.id!},
                    );
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
