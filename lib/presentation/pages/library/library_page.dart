import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/tag_type_model.dart';
import '../../../data/models/video_model.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';

// State providers for library filtering
final selectedTagTypeProvider = StateProvider<TagTypeModel?>((ref) => null);
final selectedTagsProvider = StateProvider<Set<int>>((ref) => {});

// Filtered videos based on the selected tag type and tags
final libraryFilteredVideosProvider = FutureProvider<List<VideoModel>>((
  ref,
) async {
  final tagType = ref.watch(selectedTagTypeProvider);
  final selectedTags = ref.watch(selectedTagsProvider);

  if (tagType == null) {
    return ref.watch(allVideosProvider.future);
  }

  final repo = ref.watch(videoRepositoryProvider);
  if (selectedTags.isEmpty) {
    return repo.searchVideos(
      query: '',
      includedTagIds: [],
      excludedTagIds: [],
      includedTypeIds: [tagType.id!],
      excludedTypeIds: [],
    );
  }

  return repo.searchVideos(
    query: '',
    includedTagIds: selectedTags.toList(),
    excludedTagIds: [],
    includedTypeIds:
        [], // searchVideos matches exact tags, which already belong to this type
    excludedTypeIds: [],
    matchAllTags: true,
  );
});

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredVideosAsync = ref.watch(libraryFilteredVideosProvider);
    final isScanning = ref.watch(isScanningProvider);
    final allVideosAsync = ref.watch(allVideosProvider);

    final tagTypesAsync = ref.watch(allTagTypesProvider);
    final selectedType = ref.watch(selectedTagTypeProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                allVideosAsync.when(
                  data: (videos) => Text(
                    '${videos.length} total videos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_alt, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: tagTypesAsync.when(
                      data: (types) {
                        if (types.isEmpty) return const Text("No tags yet.");
                        return DropdownButton<TagTypeModel?>(
                          value: selectedType,
                          hint: const Text("Select category"),
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text("All Videos"),
                            ),
                            ...types.map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            ref.read(selectedTagTypeProvider.notifier).state =
                                val;
                            ref.read(selectedTagsProvider.notifier).state =
                                {}; // Reset tags
                          },
                        );
                      },
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () => _pickAndScan(context, ref),
              tooltip: 'Scan for videos',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allVideosAsync.when(
            data: (videos) {
              if (videos.isEmpty) return const SizedBox.shrink();
              return _buildFilterSection(context, ref, selectedType);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: filteredVideosAsync.when(
              data: (videos) {
                // If there are no videos AT ALL in the DB, show empty state
                final allVideos = ref.read(allVideosProvider).valueOrNull ?? [];
                if (allVideos.isEmpty) {
                  return _buildEmptyState(context, ref, isScanning);
                }

                if (videos.isEmpty) {
                  return const Center(
                    child: Text(
                      "No videos found for this filter.",
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final v = videos[index];
                    return VideoCard(
                      title: v.title,
                      thumbnail: v.thumbnail,
                      duration: v.duration,
                      videoPath: v.path,
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
              error: (err, stack) => Center(child: Text("Error: $err")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, WidgetRef ref, TagTypeModel? selectedType) {
    // final tagTypesAsync = ref.watch(allTagTypesProvider);
    // final selectedType = ref.watch(selectedTagTypeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        //   child: Row(
        //     children: [
        //       const Text("Filter by: ", style: TextStyle(fontWeight: FontWeight.bold)),
        //       const SizedBox(width: 8),
        //       Expanded(
        //         child: tagTypesAsync.when(
        //           data: (types) {
        //             if (types.isEmpty) return const Text("No tags yet.");
        //             return DropdownButton<TagTypeModel?>(
        //               value: selectedType,
        //               hint: const Text("Select category"),
        //               isExpanded: true,
        //               underline: const SizedBox.shrink(),
        //               items: [
        //                 const DropdownMenuItem(
        //                   value: null,
        //                   child: Text("All Videos"),
        //                 ),
        //                 ...types.map((t) => DropdownMenuItem(
        //                   value: t,
        //                   child: Text(t.name),
        //                 ))
        //               ],
        //               onChanged: (val) {
        //                 ref.read(selectedTagTypeProvider.notifier).state = val;
        //                 ref.read(selectedTagsProvider.notifier).state = {}; // Reset tags
        //               },
        //             );
        //           },
        //           loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        //           error: (_, __) => const SizedBox.shrink(),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        if (selectedType != null) _buildTagChips(context, ref, selectedType),
      ],
    );
  }

  Widget _buildTagChips(
    BuildContext context,
    WidgetRef ref,
    TagTypeModel type,
  ) {
    final tagsAsync = ref.watch(allTagsProvider);
    final selectedTags = ref.watch(selectedTagsProvider);

    return tagsAsync.when(
      data: (tags) {
        final filteredTags = tags.where((t) => t.typeId == type.id).toList();
        if (filteredTags.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredTags.length,
            itemBuilder: (context, index) {
              final tag = filteredTags[index];
              final isSelected = selectedTags.contains(tag.id);

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  selectedColor: AppColors.primaryContainer,
                  checkmarkColor: AppColors.onPrimaryContainer,
                  onSelected: (selected) {
                    final current = Set<int>.from(selectedTags);
                    if (selected) {
                      current.add(tag.id!);
                    } else {
                      current.remove(tag.id);
                    }
                    ref.read(selectedTagsProvider.notifier).state = current;
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _pickAndScan(BuildContext context, WidgetRef ref) async {
    // 1. Request Permissions
    PermissionStatus status;
    if (Platform.isAndroid) {
      final statuses = await [Permission.storage, Permission.videos].request();
      status =
          statuses[Permission.videos] ??
          statuses[Permission.storage] ??
          PermissionStatus.denied;
    } else {
      status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Media/Storage permission required")),
        );
      }
      return;
    }

    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath();
    if (selectedDirectory != null) {
      ref.read(isScanningProvider.notifier).state = true;
      try {
        final autoTag = ref.read(autoTagByFolderProvider);
        await ref
            .read(videoScannerServiceProvider)
            .scanDirectory(selectedDirectory, autoTag: autoTag);
        ref.invalidate(allVideosProvider);
      } finally {
        ref.read(isScanningProvider.notifier).state = false;
      }
    }
  }

  Future<void> _scanFullStorage(BuildContext context, WidgetRef ref) async {
    // 1. Request Permissions (same as pickAndScan)
    PermissionStatus status;
    if (Platform.isAndroid) {
      final statuses = await [Permission.storage, Permission.videos].request();
      status =
          statuses[Permission.videos] ??
          statuses[Permission.storage] ??
          PermissionStatus.denied;
    } else {
      status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Media/Storage permission required")),
        );
      }
      return;
    }

    ref.read(isScanningProvider.notifier).state = true;
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Scanning full storage... this may take a moment."),
          ),
        );
      }
      final autoTag = ref.read(autoTagByFolderProvider);
      await ref
          .read(videoScannerServiceProvider)
          .scanFullStorage(autoTag: autoTag);
      ref.invalidate(allVideosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Scan completed!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      ref.read(isScanningProvider.notifier).state = false;
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    bool isScanning,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 80,
            color: AppColors.outline,
          ),
          const SizedBox(height: 24),
          Text(
            "No videos found",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan your storage to find videos",
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          if (isScanning)
            const CircularProgressIndicator(color: AppColors.primary)
          else
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndScan(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Select Folder to Scan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _scanFullStorage(context, ref),
                  icon: const Icon(Icons.search),
                  label: const Text("Scan Full Internal Storage"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
                  child: Text(
                    "(Use this if folder selection is empty/failing)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      "Auto-Tag by Folder Name",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: ref.watch(autoTagByFolderProvider),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(autoTagByFolderProvider.notifier).state = val;
                    },
                    secondary: const Icon(
                      Icons.label_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
