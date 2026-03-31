import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../widgets/common_widgets.dart';
import '../../../providers/video_provider.dart';

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => "");
final selectedTagIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);

final searchResultsProvider = FutureProvider.autoDispose<List<VideoModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final tagIds = ref.watch(selectedTagIdsProvider);
  
  if (query.isEmpty && tagIds.isEmpty) return [];
  
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.searchVideos(query, tagIds);
});

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final selectedTags = ref.watch(selectedTagIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: const InputDecoration(
            hintText: 'Search films or creators...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.primary),
                onPressed: () => _showFilterSheet(context, ref),
                tooltip: 'Filter by tags',
              ),
              if (selectedTags.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${selectedTags.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: searchResultsAsync.when(
        data: (videos) {
          final query = ref.read(searchQueryProvider);
          if (videos.isEmpty) {
            if (query.isEmpty && selectedTags.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 64, color: AppColors.outline),
                    SizedBox(height: 16),
                    Text("Search by title or filter by tags", style: TextStyle(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              );
            }
            return Center(
              child: Text(
                "No results found",
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final v = videos[index];
              return VideoCard(
                title: v.title,
                thumbnail: v.thumbnail,
                duration: v.duration,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/player',
                    arguments: {'videoId': v.id!},
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

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const TagFilterSheet();
      },
    );
  }
}

class TagFilterSheet extends ConsumerWidget {
  const TagFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsWithCountProvider);
    final selectedIds = ref.watch(selectedTagIdsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filter by Tags", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ref.read(selectedTagIdsProvider.notifier).state = [];
                },
                child: const Text("Clear All"),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Text("No tags found"),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    final int id = tag['id'];
                    final bool isSelected = selectedIds.contains(id);

                    return CheckboxListTile(
                      title: Text(tag['name']),
                      subtitle: Text("${tag['video_count']} videos"),
                      value: isSelected,
                      activeColor: AppColors.primary,
                      onChanged: (bool? checked) {
                        if (checked == true) {
                          ref.read(selectedTagIdsProvider.notifier).state = [...selectedIds, id];
                        } else {
                          ref.read(selectedTagIdsProvider.notifier).state = selectedIds.where((val) => val != id).toList();
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text("Error loading tags"),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Apply Details"),
            ),
          ),
        ],
      ),
    );
  }
}
