import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/video_model.dart';
import '../../player/player_service.dart';
import '../../providers/video_provider.dart';
import '../../services/video_actions.dart';
import 'video_preview_widget.dart';

/// Extra bottom padding for scrollable pages so the docked mini-player does
/// not cover the last items.
double miniPlayerPadding(WidgetRef ref) =>
    ref.watch(playerServiceProvider.select((s) => s.isActive)) ? kMiniPlayerHeight + 16 : 0;

/// YouTube-style video card: thumbnail with duration + watch progress,
/// title, and a ⋮ menu. Press and hold for a moving preview.
class VideoCard extends ConsumerStatefulWidget {
  final String title;
  final String? thumbnail;
  final String? duration;
  final String? videoPath;
  final VoidCallback onTap;

  /// Enables the watch-progress bar and the ⋮ menu.
  final int? videoId;

  const VideoCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.videoPath,
    this.videoId,
    required this.onTap,
  });

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard> {
  bool _isPreviewing = false;
  Timer? _previewTimer;
  bool _wasPlayingBeforePreview = false;

  void _startPreview() {
    if (widget.videoPath == null) return;
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final player = ref.read(playerServiceProvider).player;
      _wasPlayingBeforePreview = player.state.playing;
      if (_wasPlayingBeforePreview) player.pause();
      setState(() => _isPreviewing = true);
    });
  }

  void _stopPreview() {
    _previewTimer?.cancel();
    if (_isPreviewing && mounted) {
      setState(() => _isPreviewing = false);
      if (_wasPlayingBeforePreview) {
        ref.read(playerServiceProvider).player.play();
        _wasPlayingBeforePreview = false;
      }
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.videoId == null
        ? null
        : ref.watch(watchProgressProvider).valueOrNull?[widget.videoId];

    return Listener(
      onPointerDown: (_) => _startPreview(),
      onPointerUp: (_) => _stopPreview(),
      onPointerCancel: (_) => _stopPreview(),
      child: InkWell(
        onTap: () {
          _stopPreview();
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isPreviewing && widget.videoPath != null
                    ? VideoPreviewWidget(videoPath: widget.videoPath!)
                    : _Thumbnail(
                        thumbnail: widget.thumbnail,
                        duration: widget.duration,
                        progress: progress,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (widget.videoId != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.onSurfaceVariant),
                        onPressed: () => showVideoActions(context, ref, widget.videoId!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? thumbnail;
  final String? duration;
  final double? progress;

  const _Thumbnail({this.thumbnail, this.duration, this.progress});

  @override
  Widget build(BuildContext context) {
    final t = thumbnail;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.surfaceContainerHigh),
        if (t != null)
          Image(
            image: t.startsWith('http://') || t.startsWith('https://')
                ? NetworkImage(t) as ImageProvider
                : FileImage(File(t)),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.movie_outlined, color: AppColors.outline, size: 40),
            ),
          )
        else
          const Center(child: Icon(Icons.movie_outlined, color: AppColors.outline, size: 40)),
        if (duration != null)
          Positioned(
            right: 6,
            bottom: (progress ?? 0) > 0 ? 8 : 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                duration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (progress != null && progress! > 0.01)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.white24)),
                FractionallySizedBox(
                  widthFactor: progress!.clamp(0.0, 1.0),
                  child: const ColoredBox(color: AppColors.primary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet with actions for a video (play, tags, rename, thumbnail).
Future<void> showVideoActions(BuildContext context, WidgetRef ref, int videoId) async {
  final video = await ref.read(videoRepositoryProvider).getVideoById(videoId);
  if (video == null || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerHigh,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(sheetContext);
              ref.read(playerServiceProvider).open(videoId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Edit tags'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.pushNamed(context, '/video-tags',
                  arguments: {'videoId': videoId, 'videoTitle': video.title});
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRenameDialog(context, ref, videoId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Regenerate thumbnail'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(content: Text('Regenerating thumbnail…')));
              final ok = await regenerateThumbnailFlow(ref, videoId);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(ok ? 'Thumbnail updated' : 'Could not create thumbnail'),
                ));
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRenameDialog(BuildContext context, WidgetRef ref, int videoId) async {
  final video = await ref.read(videoRepositoryProvider).getVideoById(videoId);
  if (video == null || !context.mounted) return;
  final controller = TextEditingController(text: video.title);
  final messenger = ScaffoldMessenger.of(context);

  final newTitle = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename video'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'File name',
          helperText: 'Renames the file on your device too',
        ),
        onSubmitted: (v) => Navigator.pop(dialogContext, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();

  final title = newTitle?.trim();
  if (title == null || title.isEmpty || title == video.title) return;
  final error = await renameVideoFlow(ref, video, title);
  messenger.showSnackBar(SnackBar(content: Text(error ?? 'Renamed to "$title"')));
}

class TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const TagChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of [VideoCard]s used by Library, Search and tag feeds.
class VideoGrid extends ConsumerWidget {
  final List<VideoModel> videos;
  final EdgeInsets padding;

  const VideoGrid({super.key, required this.videos, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraBottom = miniPlayerPadding(ref);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final available = constraints.maxWidth - padding.horizontal;
        final columns = (available / 240).ceil().clamp(2, 6);
        final itemWidth = (available - spacing * (columns - 1)) / columns;
        return GridView.builder(
          padding: padding.copyWith(bottom: padding.bottom + extraBottom),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 16,
            mainAxisExtent: itemWidth * 9 / 16 + 54,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            return VideoCard(
              title: v.title,
              thumbnail: v.thumbnail,
              duration: v.duration,
              videoPath: v.path,
              videoId: v.id,
              onTap: () => openVideo(context, ref, v.id!),
            );
          },
        );
      },
    );
  }
}
