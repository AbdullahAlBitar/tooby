import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../widgets/common_widgets.dart';
import '../../../providers/video_provider.dart';

final includedTagIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);
final excludedTagIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);
final includedTypeIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);
final excludedTypeIdsProvider = StateProvider.autoDispose<List<int>>((ref) => []);
final matchAllTagsProvider = StateProvider.autoDispose<bool>((ref) => false);

final searchResultsProvider = FutureProvider.autoDispose<List<VideoModel>>((ref) async {
  final includedTags = ref.watch(includedTagIdsProvider);
  final excludedTags = ref.watch(excludedTagIdsProvider);
  final includedTypes = ref.watch(includedTypeIdsProvider);
  final excludedTypes = ref.watch(excludedTypeIdsProvider);
  final matchAll = ref.watch(matchAllTagsProvider);

  final repo = ref.watch(videoRepositoryProvider);
  return await repo.searchVideos(
    query: '',
    includedTagIds: includedTags,
    excludedTagIds: excludedTags,
    includedTypeIds: includedTypes,
    excludedTypeIds: excludedTypes,
    matchAllTags: matchAll,
  );
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  bool _filtersExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Filter Videos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            tooltip: _filtersExpanded ? 'Collapse Filters' : 'Expand Filters',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: AppColors.primary),
            onPressed: () {
              ref.read(includedTagIdsProvider.notifier).state = [];
              ref.read(excludedTagIdsProvider.notifier).state = [];
              ref.read(includedTypeIdsProvider.notifier).state = [];
              ref.read(excludedTypeIdsProvider.notifier).state = [];
              ref.read(matchAllTagsProvider.notifier).state = false;
            },
            tooltip: 'Clear All Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filtersExpanded)
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildFilterPanel(context, ref),
              ),
            ),
          Expanded(
            child: _buildResultsSection(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsWithCountProvider);
    final tagTypesAsync = ref.watch(allTagTypesProvider);

    final includedTags = ref.watch(includedTagIdsProvider);
    final excludedTags = ref.watch(excludedTagIdsProvider);
    final includedTypes = ref.watch(includedTypeIdsProvider);
    final excludedTypes = ref.watch(excludedTypeIdsProvider);

    return tagTypesAsync.when(
      data: (types) => tagsAsync.when(
        data: (tags) {
          if (types.isEmpty) {
            return const Center(child: Text("No tag types found."));
          }

          // Group tags by typeId
          final Map<int, List<Map<String, dynamic>>> groupedTags = {};
          for (var type in types) {
            groupedTags[type.id!] = [];
          }
          for (var tag in tags) {
            final typeId = tag['type_id'] ?? 1;
            if (groupedTags.containsKey(typeId)) {
              groupedTags[typeId]!.add(tag);
            } else {
              groupedTags[1]?.add(tag);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match All Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Match all selected tags", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Switch(
                    value: ref.watch(matchAllTagsProvider),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(matchAllTagsProvider.notifier).state = val;
                    },
                  ),
                ],
              ),
              const Divider(color: AppColors.outlineVariant, height: 16),
              ...types.map((type) {
                final typeId = type.id!;
                final typeTags = groupedTags[typeId] ?? [];

                final bool isTypeIncluded = includedTypes.contains(typeId);
                final bool isTypeExcluded = excludedTypes.contains(typeId);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isTypeIncluded ? Icons.check_circle : Icons.check_circle_outline,
                                color: isTypeIncluded ? Colors.green : AppColors.outline,
                                size: 18,
                              ),
                              onPressed: () {
                                if (isTypeIncluded) {
                                  ref.read(includedTypeIdsProvider.notifier).update(
                                      (state) => state.where((id) => id != typeId).toList());
                                } else {
                                  ref.read(includedTypeIdsProvider.notifier).update((state) => [...state, typeId]);
                                  ref.read(excludedTypeIdsProvider.notifier).update(
                                      (state) => state.where((id) => id != typeId).toList());
                                }
                              },
                              tooltip: 'Require this type',
                            ),
                            IconButton(
                              icon: Icon(
                                isTypeExcluded ? Icons.remove_circle : Icons.remove_circle_outline,
                                color: isTypeExcluded ? Colors.red : AppColors.outline,
                                size: 18,
                              ),
                              onPressed: () {
                                if (isTypeExcluded) {
                                  ref.read(excludedTypeIdsProvider.notifier).update(
                                      (state) => state.where((id) => id != typeId).toList());
                                } else {
                                  ref.read(excludedTypeIdsProvider.notifier).update((state) => [...state, typeId]);
                                  ref.read(includedTypeIdsProvider.notifier).update(
                                      (state) => state.where((id) => id != typeId).toList());
                                }
                              },
                              tooltip: 'Exclude this type',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (typeTags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("No tags in this type", style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: typeTags.map((tag) {
                          final tagId = tag['id'] as int;
                          final bool isTagIncluded = includedTags.contains(tagId);
                          final bool isTagExcluded = excludedTags.contains(tagId);

                          Color chipBg;
                          Widget? avatar;
                          if (isTagIncluded) {
                            chipBg = Colors.green.withValues(alpha: 0.15);
                            avatar = const Icon(Icons.check_circle, color: Colors.green, size: 14);
                          } else if (isTagExcluded) {
                            chipBg = Colors.red.withValues(alpha: 0.15);
                            avatar = const Icon(Icons.cancel, color: Colors.red, size: 14);
                          } else {
                            chipBg = AppColors.surfaceContainerHigh;
                            avatar = null;
                          }

                          void toggleState() {
                            if (!isTagIncluded && !isTagExcluded) {
                              ref.read(includedTagIdsProvider.notifier).update((state) => [...state, tagId]);
                            } else if (isTagIncluded) {
                              ref.read(includedTagIdsProvider.notifier).update(
                                  (state) => state.where((id) => id != tagId).toList());
                              ref.read(excludedTagIdsProvider.notifier).update((state) => [...state, tagId]);
                            } else {
                              ref.read(excludedTagIdsProvider.notifier).update(
                                  (state) => state.where((id) => id != tagId).toList());
                            }
                          }

                          return GestureDetector(
                            onTap: toggleState,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isTagIncluded 
                                      ? Colors.green 
                                      : (isTagExcluded ? Colors.red : AppColors.outlineVariant),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (avatar != null) ...[
                                    avatar,
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    "${tag['name']} (${tag['video_count']})",
                                    style: TextStyle(
                                      color: isTagIncluded 
                                          ? Colors.green 
                                          : (isTagExcluded ? Colors.red : AppColors.onSurface),
                                      fontWeight: (isTagIncluded || isTagExcluded) ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildResultsSection(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return searchResultsAsync.when(
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Text("No videos match selected filters", style: TextStyle(color: AppColors.onSurfaceVariant)),
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
      error: (err, _) => Center(child: Text("Error loading results: $err")),
    );
  }
}
