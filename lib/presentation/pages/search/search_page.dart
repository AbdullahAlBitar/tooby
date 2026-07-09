import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../widgets/common_widgets.dart';
import '../../../providers/video_provider.dart';

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => "");
final selectedTagIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);
final matchAllTagsProvider = StateProvider.autoDispose<bool>((ref) => false);

final searchResultsProvider = FutureProvider.autoDispose<List<VideoModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final tagIds = ref.watch(selectedTagIdsProvider);
  final matchAll = ref.watch(matchAllTagsProvider);
  
  if (query.isEmpty && tagIds.isEmpty) return [];
  
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.searchVideos(query, tagIds, matchAllTags: matchAll);
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

abstract class FilterItem {}

class HeaderFilterItem extends FilterItem {
  final String title;
  HeaderFilterItem(this.title);
}

class TagFilterItem extends FilterItem {
  final int id;
  final String name;
  final int videoCount;
  TagFilterItem(this.id, this.name, this.videoCount);
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
                  ref.read(matchAllTagsProvider.notifier).state = false;
                },
                child: const Text("Clear All"),
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Match all selected tags"),
            subtitle: const Text("Show videos containing every selected tag"),
            value: ref.watch(matchAllTagsProvider),
            activeColor: AppColors.primary,
            onChanged: (value) {
              ref.read(matchAllTagsProvider.notifier).state = value;
            },
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

                // Group tags by type name
                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var tag in tags) {
                  final typeName = (tag['type_name'] ?? 'default').toString().toUpperCase();
                  grouped.putIfAbsent(typeName, () => []).add(tag);
                }

                // Flatten into a list of FilterItem
                final List<FilterItem> items = [];
                final sortedTypes = grouped.keys.toList()
                  ..sort((a, b) {
                    if (a == 'DEFAULT') return -1;
                    if (b == 'DEFAULT') return 1;
                    return a.compareTo(b);
                  });

                for (var type in sortedTypes) {
                  items.add(HeaderFilterItem(type));
                  for (var tag in grouped[type]!) {
                    items.add(TagFilterItem(
                      tag['id'] as int,
                      tag['name'] as String,
                      tag['video_count'] as int,
                    ));
                  }
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item is HeaderFilterItem) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 12.0),
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      );
                    }

                    final tag = item as TagFilterItem;
                    final bool isSelected = selectedIds.contains(tag.id);

                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(tag.name),
                      subtitle: Text("${tag.videoCount} videos"),
                      value: isSelected,
                      activeColor: AppColors.primary,
                      onChanged: (bool? checked) {
                        if (checked == true) {
                          ref.read(selectedTagIdsProvider.notifier).state = [...selectedIds, tag.id];
                        } else {
                          ref.read(selectedTagIdsProvider.notifier).state =
                              selectedIds.where((val) => val != tag.id).toList();
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
