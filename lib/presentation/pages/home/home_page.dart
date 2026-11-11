import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../main.dart' show navigationIndexProvider;
import '../../../player/player_service.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final randomTagTypeVideosAsync = ref.watch(randomTagTypeVideosProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);
    final recentVideosAsync = ref.watch(recentVideosProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/toopy_new_logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
            tooltip: 'Play Random Video',
            onPressed: () async {
              final videos = await ref.read(videoRepositoryProvider).getAllVideos();
              if (videos.isNotEmpty && context.mounted) {
                final randomVideo = videos[Random().nextInt(videos.length)];
                openVideo(context, ref, randomVideo.id!);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No videos available to play.")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.primary),
            tooltip: 'Filter videos',
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(randomTagTypeVideosProvider);
          ref.invalidate(continueWatchingProvider);
          ref.invalidate(recentVideosProvider);
          ref.invalidate(watchProgressProvider);
          await ref.read(recentVideosProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.only(top: 8, bottom: 24 + miniPlayerPadding(ref)),
          children: [
            // Continue watching
            continueWatchingAsync.when(
              data: (rows) {
                if (rows.isEmpty) return const SizedBox.shrink();
                final videos = rows.map(VideoModel.fromMap).toList();
                return _VideoRow(
                  title: 'Continue watching',
                  icon: Icons.history_rounded,
                  videos: videos,
                );
              },
              loading: () => const _RowPlaceholder(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Random tag type
            randomTagTypeVideosAsync.when(
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                final String typeName = data['typeName'];
                final List<VideoModel> videos = data['videos'] as List<VideoModel>;
                if (videos.isEmpty) return const SizedBox.shrink();
                return _VideoRow(
                  title: typeName,
                  icon: Icons.auto_awesome_rounded,
                  subtitle: 'A random pick from your tags · pull to refresh',
                  videos: videos,
                );
              },
              loading: () => const _RowPlaceholder(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Recently added
            recentVideosAsync.when(
              data: (videos) => videos.isEmpty
                  ? const _EmptyHome()
                  : _VideoRow(
                      title: 'Recently added',
                      icon: Icons.new_releases_outlined,
                      videos: videos,
                      onSeeAll: () => ref.read(navigationIndexProvider.notifier).state = 1,
                    ),
              loading: () => const _RowPlaceholder(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRow extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<VideoModel> videos;
  final VoidCallback? onSeeAll;

  const _VideoRow({
    required this.title,
    required this.icon,
    required this.videos,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const cardWidth = 250.0;
    const cardHeight = cardWidth * 9 / 16 + 54;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final v = videos[index];
                return SizedBox(
                  width: cardWidth,
                  child: VideoCard(
                    title: v.title,
                    thumbnail: v.thumbnail,
                    duration: v.duration,
                    videoPath: v.path,
                    videoId: v.id,
                    onTap: () => openVideo(context, ref, v.id!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RowPlaceholder extends StatelessWidget {
  const _RowPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends ConsumerWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        children: [
          const Icon(Icons.video_library_outlined, size: 72, color: AppColors.outline),
          const SizedBox(height: 16),
          const Text('No videos yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Scan a folder in the Library tab to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => ref.read(navigationIndexProvider.notifier).state = 1,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Go to Library'),
          ),
        ],
      ),
    );
  }
}
