import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tag_model.dart';
import '../../../providers/video_provider.dart';

class TagPage extends ConsumerWidget {
  const TagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sell_outlined, size: 64, color: AppColors.outline),
                  const SizedBox(height: 16),
                  Text(
                    "No tags created yet",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    onPressed: () => _showAddTagDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text("Create New Tag"),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                title: Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _deleteTag(context, ref, tag),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/tag-feed',
                    arguments: {'tagId': tag.id!, 'tagName': tag.name},
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Tag"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Tag name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(tagRepositoryProvider).insertTag(controller.text);
                ref.invalidate(allTagsProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _deleteTag(BuildContext context, WidgetRef ref, TagModel tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Tag"),
        content: Text("Are you sure you want to delete '${tag.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ref.read(tagRepositoryProvider).deleteTag(tag.id!);
              ref.invalidate(allTagsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
