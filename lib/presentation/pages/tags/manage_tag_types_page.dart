import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tag_type_model.dart';
import '../../../providers/video_provider.dart';

class ManageTagTypesPage extends ConsumerWidget {
  const ManageTagTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagTypesAsync = ref.watch(allTagTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Manage Tag Types', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: tagTypesAsync.when(
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text("No tag types found"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.outlineVariant),
            itemBuilder: (context, index) {
              final type = types[index];
              final isDefault = type.name.toLowerCase() == 'default';

              return ListTile(
                title: Text(
                  type.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDefault ? AppColors.onSurfaceVariant : AppColors.onSurface,
                  ),
                ),
                trailing: isDefault
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'System Default',
                          style: TextStyle(fontSize: 12, color: AppColors.outline),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            onPressed: () => _showEditTypeDialog(context, ref, type),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _deleteTagType(context, ref, type),
                          ),
                        ],
                      ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTypeDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Tag Type"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Type name (e.g. Genre, Year)"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (name.toLowerCase() == 'default') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot create a type named 'default'")),
                  );
                  return;
                }
                await ref.read(tagRepositoryProvider).insertTagType(name);
                ref.invalidate(allTagTypesProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showEditTypeDialog(BuildContext context, WidgetRef ref, TagTypeModel type) {
    final controller = TextEditingController(text: type.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Tag Type"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Type name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != type.name) {
                if (name.toLowerCase() == 'default') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot rename a type to 'default'")),
                  );
                  return;
                }
                await ref.read(tagRepositoryProvider).updateTagType(type.id!, name);
                ref.invalidate(allTagTypesProvider);
                ref.invalidate(allTagsProvider); // Also refresh tags since their type name changed
                ref.invalidate(allTagsWithCountProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteTagType(BuildContext context, WidgetRef ref, TagTypeModel type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Tag Type"),
        content: Text("Are you sure you want to delete '${type.name}'?\n\nTags of this type will revert to the 'default' type. This will not delete the tags themselves."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ref.read(tagRepositoryProvider).deleteTagType(type.id!);
              ref.invalidate(allTagTypesProvider);
              ref.invalidate(allTagsProvider); // Refresh tags since their type was reset to default
              ref.invalidate(allTagsWithCountProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
