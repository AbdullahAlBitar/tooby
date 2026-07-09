import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingItem(
            context,
            icon: Icons.history,
            title: "Clear Watch History",
            onTap: () => _showClearHistoryDialog(context, ref),
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.refresh,
            title: "Rescan Library",
            subtitle: "Update metadata and detect new videos",
            onTap: () {
              // Redirect to Library page rescan logic or implement here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Go to Library tab to rescan specific folders")),
              );
            },
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.image_search_outlined,
            title: "Fix Video Thumbnails",
            subtitle: "Regenerate all thumbnails to avoid black frames",
            onTap: () => _showRegenerateThumbnailsDialog(context, ref),
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.cleaning_services,
            title: "Clean Missing Videos",
            subtitle: "Remove videos from database that were deleted or moved",
            onTap: () => _showCleanMissingVideosDialog(context, ref),
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.unarchive,
            title: "Export Library Backup",
            subtitle: "Export tags & metadata to a JSON file",
            onTap: () => _exportBackup(context, ref),
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.archive,
            title: "Import Library Backup",
            subtitle: "Import tags & metadata from a JSON file",
            onTap: () => _importBackup(context, ref),
          ),
          const Divider(color: AppColors.outlineVariant),
          _buildSettingItem(
            context,
            icon: Icons.info_outline,
            title: "About Tooby",
            subtitle: "Version 1.0.0+3 • Offline Video Player",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.onSurfaceVariant)) : null,
      onTap: onTap,
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Are you sure you want to clear your watch history?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ref.read(videoRepositoryProvider).clearWatchHistory();
              ref.invalidate(continueWatchingProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Clear", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRegenerateThumbnailsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Regenerate All Thumbnails?"),
        content: const Text(
          "This will update thumbnails for all videos using smarter positioning to avoid black frames. It may take a few minutes if you have many videos.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Regenerating all thumbnails in background...")),
              );
              await ref.read(videoScannerServiceProvider).regenerateAllThumbnails();
              ref.invalidate(allVideosProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All thumbnails regenerated!")),
                );
              }
            },
            child: const Text("Regenerate"),
          ),
        ],
      ),
    );
  }

  void _showCleanMissingVideosDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clean Missing Videos"),
        content: const Text(
          "This will check all videos in the database. If their files are missing or deleted, they will be removed from your library. This cannot be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
              final removedCount = await ref.read(videoScannerServiceProvider).removeMissingVideos();
              
              ref.invalidate(allVideosProvider);
              ref.invalidate(recentVideosProvider);
              ref.invalidate(continueWatchingProvider);
              ref.invalidate(allTagsWithCountProvider);
              
              if (context.mounted) {
                Navigator.pop(context); // Dismiss loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      removedCount > 0
                          ? "Cleaned up $removedCount missing video(s)!"
                          : "No missing videos found.",
                    ),
                  ),
                );
              }
            },
            child: const Text("Clean", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      if (!context.mounted) return;
      // Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final fileName = await ref.read(videoScannerServiceProvider).exportLibraryMetadata(selectedDirectory);

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup exported: $fileName")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog if showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      if (!context.mounted) return;
      // Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final stats = await ref.read(videoScannerServiceProvider).importLibraryMetadata(filePath);

      // Invalidate all relevant providers
      ref.invalidate(allVideosProvider);
      ref.invalidate(recentVideosProvider);
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(allTagsProvider);
      ref.invalidate(allTagsWithCountProvider);

      final matched = stats['matchedVideos'] ?? 0;
      final applied = stats['tagsApplied'] ?? 0;

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Imported: matched $matched videos & applied $applied new tags.",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog if showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }
}
