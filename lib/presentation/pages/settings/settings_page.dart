import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            icon: Icons.info_outline,
            title: "About Tooby",
            subtitle: "Version 1.0.0 • Offline Video Player",
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
}
