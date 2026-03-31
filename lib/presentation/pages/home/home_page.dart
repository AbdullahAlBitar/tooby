import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatchingAsync = ref.watch(continueWatchingProvider);
    final recentVideosAsync = ref.watch(recentVideosProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceContainerHigh,
              child: Icon(Icons.person, size: 20, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Continue Watching
            _buildSection(
              context,
              "Continue Watching",
              continueWatchingAsync.when(
                data: (histories) => histories.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: histories.length,
                          itemBuilder: (context, index) {
                            final h = histories[index];
                            return VideoCard(
                              title: h['title'],
                              thumbnail: h['thumbnail'],
                              duration: h['duration'],
                              isHorizontal: true,
                              onTap: () => _navigateToPlayer(context, h['id']),
                            );
                          },
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Recent Videos
            _buildSection(
              context,
              "Recent Videos",
              recentVideosAsync.when(
                data: (videos) => videos.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text("No videos found. Go to Library to scan."),
                      )
                    : SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final v = videos[index];
                            return VideoCard(
                              title: v.title,
                              thumbnail: v.thumbnail,
                              duration: v.duration,
                              isHorizontal: true,
                              onTap: () => _navigateToPlayer(context, v.id!),
                            );
                          },
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("View all", style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        content,
      ],
    );
  }

  void _navigateToPlayer(BuildContext context, int videoId) {
    Navigator.pushNamed(
      context,
      '/player',
      arguments: {'videoId': videoId},
    );
  }
}
