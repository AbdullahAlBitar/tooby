import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';
import '../../widgets/common_widgets.dart';

final isScanningProvider = StateProvider<bool>((ref) => false);
final autoTagByFolderProvider = StateProvider<bool>((ref) => false);

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allVideosAsync = ref.watch(allVideosProvider);
    final isScanning = ref.watch(isScanningProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
            allVideosAsync.when(
              data: (videos) => Text(
                '${videos.length} videos',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              loading: () => const Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(autoTagByFolderProvider) ? Icons.label : Icons.label_off_outlined,
              color: ref.watch(autoTagByFolderProvider) ? AppColors.primary : AppColors.outline,
            ),
            onPressed: () {
              ref.read(autoTagByFolderProvider.notifier).update((state) => !state);
            },
            tooltip: 'Auto-tag by folder',
          ),
          IconButton(
            icon: const Icon(Icons.new_label_outlined, color: AppColors.primary),
            onPressed: () async {
              ref.read(isScanningProvider.notifier).state = true;
              try {
                await ref.read(videoScannerServiceProvider).syncFolderTags();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Folder tags synced!")),
                  );
                }
              } finally {
                ref.read(isScanningProvider.notifier).state = false;
              }
            },
            tooltip: 'Sync folder tags',
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: AppColors.primary),
            onPressed: () async {
              ref.read(isScanningProvider.notifier).state = true;
              try {
                await ref.read(videoScannerServiceProvider).refreshAllDurations();
                ref.invalidate(allVideosProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Durations refreshed!")),
                  );
                }
              } finally {
                ref.read(isScanningProvider.notifier).state = false;
              }
            },
            tooltip: 'Refresh durations',
          ),
          if (isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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
      body: allVideosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library_outlined, size: 64, color: AppColors.outline),
                  const SizedBox(height: 16),
                  Text(
                    "Your library is empty",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => _pickAndScan(context, ref),
                    icon: const Icon(Icons.folder_open),
                    label: const Text("Select Folder to Scan"),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.75,
            ),
            itemCount: videos.length,
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
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Future<void> _pickAndScan(BuildContext context, WidgetRef ref) async {
    // 1. Request Permissions
    PermissionStatus status;
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.storage,
        Permission.videos,
      ].request();
      status = statuses[Permission.videos] ?? statuses[Permission.storage] ?? PermissionStatus.denied;
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

    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      ref.read(isScanningProvider.notifier).state = true;
      try {
        final autoTag = ref.read(autoTagByFolderProvider);
        await ref.read(videoScannerServiceProvider).scanDirectory(selectedDirectory, autoTag: autoTag);
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
      final statuses = await [
        Permission.storage,
        Permission.videos,
      ].request();
      status = statuses[Permission.videos] ?? statuses[Permission.storage] ?? PermissionStatus.denied;
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
          const SnackBar(content: Text("Scanning full storage... this may take a moment.")),
        );
      }
      final autoTag = ref.read(autoTagByFolderProvider);
      await ref.read(videoScannerServiceProvider).scanFullStorage(autoTag: autoTag);
      ref.invalidate(allVideosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Scan completed!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      ref.read(isScanningProvider.notifier).state = false;
    }
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_outlined, size: 80, color: AppColors.outline),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: const Text("Auto-Tag by Folder Name", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    value: ref.watch(autoTagByFolderProvider),
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      ref.read(autoTagByFolderProvider.notifier).state = val;
                    },
                    secondary: const Icon(Icons.label_outlined, color: AppColors.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
