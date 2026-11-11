import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/tag_model.dart';
import '../../providers/video_provider.dart';
import '../../services/video_actions.dart';

/// Search, add, remove and create tags for one video.
///
/// Used both by the standalone "Edit Tags" page and by the panel inside the
/// player, so it must not open dialogs or routes.
class TagEditorBody extends ConsumerStatefulWidget {
  final int videoId;
  final bool autofocus;

  const TagEditorBody({super.key, required this.videoId, this.autofocus = false});

  @override
  ConsumerState<TagEditorBody> createState() => _TagEditorBodyState();
}

class _TagEditorBodyState extends ConsumerState<TagEditorBody> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int? _newTagTypeId;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(int tagId, bool add) async {
    final repo = ref.read(tagRepositoryProvider);
    if (add) {
      await repo.addTagToVideo(widget.videoId, tagId);
    } else {
      await repo.removeTagFromVideo(widget.videoId, tagId);
    }
    invalidateTagLists(ref, widget.videoId);
  }

  Future<void> _create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(tagRepositoryProvider);
      final id = await repo.getOrCreateTag(trimmed, typeId: _newTagTypeId ?? 1);
      await repo.addTagToVideo(widget.videoId, id);
      invalidateTagLists(ref, widget.videoId);
      _search.clear();
      setState(() => _query = '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final videoTags = ref.watch(tagsForVideoProvider(widget.videoId)).valueOrNull ?? const <TagModel>[];
    final types = ref.watch(allTagTypesProvider).valueOrNull ?? const [];
    final selectedIds = videoTags.map((t) => t.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Search or create a tag',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
            onSubmitted: (v) {
              final tags = allTagsAsync.valueOrNull ?? const <TagModel>[];
              final exact = tags.where((t) => t.name.toLowerCase() == v.trim().toLowerCase());
              if (exact.isNotEmpty) {
                final tag = exact.first;
                _toggle(tag.id!, !selectedIds.contains(tag.id));
                _search.clear();
                setState(() => _query = '');
              } else {
                _create(v);
              }
            },
          ),
        ),

        // Tags already on this video
        if (videoTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in videoTags)
                  InputChip(
                    label: Text(t.name),
                    backgroundColor: AppColors.primaryContainer,
                    labelStyle: const TextStyle(color: AppColors.onPrimaryContainer, fontSize: 13),
                    deleteIconColor: AppColors.onPrimaryContainer,
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => _toggle(t.id!, false),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.outlineVariant),

        Expanded(
          child: allTagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (allTags) {
              final q = _query.toLowerCase();
              final filtered = q.isEmpty
                  ? allTags
                  : allTags.where((t) => t.name.toLowerCase().contains(q)).toList();
              final hasExact = allTags.any((t) => t.name.toLowerCase() == q);

              // Group by tag type for easier scanning.
              final groups = <String, List<TagModel>>{};
              for (final t in filtered) {
                groups.putIfAbsent(t.typeName ?? 'default', () => []).add(t);
              }
              final groupNames = groups.keys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              return ListView(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
                children: [
                  if (q.isNotEmpty && !hasExact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : () => _create(_query),
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Create "$_query"'),
                          ),
                          if (types.length > 1) ...[
                            const SizedBox(height: 8),
                            const Text('Category',
                                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final type in types)
                                  ChoiceChip(
                                    label: Text(type.name),
                                    selected: (_newTagTypeId ?? 1) == type.id,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() => _newTagTypeId = type.id),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (filtered.isEmpty && q.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No tags yet. Type a name above to create one.',
                            style: TextStyle(color: AppColors.outline)),
                      ),
                    ),
                  for (final g in groupNames) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        g.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final tag in groups[g]!)
                      CheckboxListTile(
                        dense: true,
                        title: Text(tag.name, style: const TextStyle(fontSize: 15)),
                        value: selectedIds.contains(tag.id),
                        activeColor: AppColors.primary,
                        checkColor: AppColors.onPrimary,
                        onChanged: (v) => _toggle(tag.id!, v ?? false),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
