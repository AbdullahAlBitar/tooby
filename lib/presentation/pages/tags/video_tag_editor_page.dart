import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/video_provider.dart';

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
  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final videoTagsAsync = ref.watch(tagsForVideoProvider(widget.videoId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Edit Tags', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  return ListView.builder(
                    itemCount: allTags.length,
                    itemBuilder: (context, index) {
                      final tag = allTags[index];
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
