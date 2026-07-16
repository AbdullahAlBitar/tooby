import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/tag_type_model.dart';
import '../../../providers/video_provider.dart';

class TagPage extends ConsumerWidget {
  const TagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final tagTypesAsync = ref.watch(allTagTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.pushNamed(context, '/manage-tag-types');
            },
            tooltip: 'Manage Tag Types',
          ),
        ],
      ),
      body: tagTypesAsync.when(
        data: (types) => tagsAsync.when(
          data: (tags) {
            if (types.isEmpty) {
              return const Center(child: Text("No tag types found."));
            }

            // Group tags by typeId
            final Map<int, List<TagModel>> groupedTags = {};
            for (var type in types) {
              groupedTags[type.id!] = [];
            }
            for (var tag in tags) {
              final typeId = tag.typeId ?? 1;
              if (groupedTags.containsKey(typeId)) {
                groupedTags[typeId]!.add(tag);
              } else {
                // If type doesn't exist, group under default (1)
                groupedTags[1]?.add(tag);
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                final typeTags = groupedTags[type.id!] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (typeTags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Text(
                          "No tags in this type",
                          style: TextStyle(color: AppColors.outline, fontSize: 14),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: typeTags.length,
                        itemBuilder: (context, idx) {
                          final tag = typeTags[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                             title: Row(
                              children: [
                                Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${tag.videoCount ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                  onPressed: () => _showEditTagDialog(context, ref, tag, types),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  onPressed: () => _deleteTag(context, ref, tag),
                                ),
                              ],
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
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text("Error loading tags: $err")),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error loading tag types: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          tagTypesAsync.whenData((types) {
            _showAddTagDialog(context, ref, types);
          });
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref, List<TagTypeModel> types) {
    final controller = TextEditingController();
    int selectedTypeId = types.isNotEmpty ? types.first.id! : 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("New Tag"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Tag name"),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedTypeId,
                decoration: const InputDecoration(labelText: "Tag Type"),
                items: types.map((t) {
                  return DropdownMenuItem<int>(
                    value: t.id,
                    child: Text(t.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedTypeId = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(tagRepositoryProvider).insertTag(name, typeId: selectedTypeId);
                  ref.invalidate(allTagsProvider);
                  ref.invalidate(allTagsWithCountProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTagDialog(BuildContext context, WidgetRef ref, TagModel tag, List<TagTypeModel> types) {
    final controller = TextEditingController(text: tag.name);
    int selectedTypeId = tag.typeId ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Tag"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Tag name"),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedTypeId,
                decoration: const InputDecoration(labelText: "Tag Type"),
                items: types.map((t) {
                  return DropdownMenuItem<int>(
                    value: t.id,
                    child: Text(t.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedTypeId = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(tagRepositoryProvider).updateTag(
                        tag.copyWith(name: name, typeId: selectedTypeId),
                      );
                  ref.invalidate(allTagsProvider);
                  ref.invalidate(allTagsWithCountProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
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
