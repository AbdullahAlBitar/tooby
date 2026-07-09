import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';
import '../../../data/models/tag_model.dart';

class VideoTagEditorPage extends ConsumerStatefulWidget {
  final int videoId;
  final String videoTitle;

  const VideoTagEditorPage({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  ConsumerState<VideoTagEditorPage> createState() => _VideoTagEditorPageState();
}

class _VideoTagEditorPageState extends ConsumerState<VideoTagEditorPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final videoTagsAsync = ref.watch(tagsForVideoProvider(widget.videoId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tags...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              )
            : const Text('Edit Tags', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    _searchQuery = '';
                  } else {
                    _isSearching = false;
                  }
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.videoTitle,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(color: AppColors.outlineVariant),
          Expanded(
            child: allTagsAsync.when(
              data: (allTags) => videoTagsAsync.when(
                data: (videoTags) {
                  final videoTagIds = videoTags.map((t) => t.id).toSet();
                  
                  // Sort tags alphabetically (case-insensitive)
                  final sortedTags = List<TagModel>.from(allTags);
                  sortedTags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  // Filter tags by search query
                  final filteredTags = _searchQuery.isEmpty
                      ? sortedTags
                      : sortedTags.where((t) => t.name.toLowerCase().contains(_searchQuery)).toList();

                  if (filteredTags.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? "No tags available" : "No tags match your search",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.outline,
                            ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredTags.length,
                    itemBuilder: (context, index) {
                      final tag = filteredTags[index];
                      final isSelected = videoTagIds.contains(tag.id);
                      return CheckboxListTile(
                        title: Text(tag.name),
                        value: isSelected,
                        activeColor: AppColors.primary,
                        checkColor: AppColors.onPrimary,
                        onChanged: (value) => _toggleTag(tag.id!, value ?? false),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text("Error: $err")),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Error: $err")),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTag(int tagId, bool isAdding) async {
    final repo = ref.read(tagRepositoryProvider);
    if (isAdding) {
      await repo.addTagToVideo(widget.videoId, tagId);
    } else {
      await repo.removeTagFromVideo(widget.videoId, tagId);
    }
    // Refresh the tags and recommendations for ALL videos
    ref.invalidate(tagsForVideoProvider(widget.videoId));
    ref.invalidate(recommendedVideosProvider);
  }
}
