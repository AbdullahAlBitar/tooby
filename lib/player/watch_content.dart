import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation.dart';
import '../core/theme/app_colors.dart';
import '../data/models/video_model.dart';
import '../providers/video_provider.dart';
import '../services/video_actions.dart';
import 'pip_bridge.dart';
import 'player_service.dart';

/// Everything below the video on the expanded player: title, actions, tags,
/// and the up-next list.
class WatchContent extends ConsumerStatefulWidget {
  final PlayerService service;
  const WatchContent({super.key, required this.service});

  @override
  ConsumerState<WatchContent> createState() => _WatchContentState();
}

class _WatchContentState extends ConsumerState<WatchContent> {
  bool _titleExpanded = false;
  String? _message;

  PlayerService get service => widget.service;

  void _flash(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _message == text) setState(() => _message = null);
    });
  }

  void _openTagFeed(int tagId, String tagName) {
    service.minimize();
    rootNavigatorKey.currentState?.pushNamed(
      '/tag-feed',
      arguments: {'tagId': tagId, 'tagName': tagName},
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = service.current!;
    final tags = ref.watch(tagsForVideoProvider(video.id!)).valueOrNull ?? const [];
    final folder = _folderOf(video.path);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: GestureDetector(
                  onTap: () => setState(() => _titleExpanded = !_titleExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: _titleExpanded ? null : 2,
                        overflow: _titleExpanded ? null : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (video.duration != null) video.duration!,
                          if (folder.isNotEmpty) folder,
                          if (_titleExpanded) video.path,
                        ].join('  ·  '),
                        maxLines: _titleExpanded ? 4 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action row
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    _Action(
                      icon: Icons.sell_outlined,
                      label: 'Tags',
                      onTap: () => service.openPanel(PlayerPanel.tags),
                    ),
                    _Action(
                      icon: Icons.drive_file_rename_outline_rounded,
                      label: 'Rename',
                      onTap: () => service.openPanel(PlayerPanel.rename),
                    ),
                    _Action(icon: Icons.shuffle_rounded, label: 'Shuffle', onTap: service.playRandom),
                    _Action(
                      icon: service.loop ? Icons.repeat_one_on_rounded : Icons.repeat_one_rounded,
                      label: 'Loop',
                      highlighted: service.loop,
                      onTap: () => service.setLoop(!service.loop),
                    ),
                    if (PipBridge.instance.isSupported)
                      _Action(
                        icon: Icons.picture_in_picture_alt_rounded,
                        label: 'PIP',
                        onTap: service.enterPip,
                      ),
                    _Action(
                      icon: Icons.image_outlined,
                      label: 'Thumbnail',
                      onTap: () async {
                        _flash('Regenerating thumbnail…');
                        final ok = await regenerateThumbnailFlow(ref, video.id!);
                        if (mounted) _flash(ok ? 'Thumbnail updated' : 'Could not create thumbnail');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Tags
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: tags.isEmpty
                    ? InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => service.openPanel(PlayerPanel.tags),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Add tags to this video',
                                  style: TextStyle(color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in tags)
                            ActionChip(
                              avatar: const Icon(Icons.tag_rounded, size: 16, color: AppColors.primary),
                              label: Text(t.name),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openTagFeed(t.id!, t.name),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Edit'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => service.openPanel(PlayerPanel.tags),
                          ),
                        ],
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(color: AppColors.outlineVariant, height: 16)),

            // Up next header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Up next',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const Text('Autoplay',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                    Switch(value: service.autoplay, onChanged: service.setAutoplay),
                  ],
                ),
              ),
            ),

            if (service.upNext.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              SliverList.builder(
                itemCount: service.upNext.length,
                itemBuilder: (context, i) => _UpNextTile(
                  video: service.upNext[i],
                  onTap: () => service.open(service.upNext[i].id!),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 24)),
          ],
        ),
        if (_message != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
            child: Material(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!),
              ),
            ),
          ),
      ],
    );
  }

  static String _folderOf(String path) {
    if (path.startsWith('http')) return 'Network';
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.length > 1 ? parts[parts.length - 2] : '';
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: highlighted ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: highlighted ? AppColors.onPrimaryContainer : AppColors.onSurface),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: highlighted ? AppColors.onPrimaryContainer : AppColors.onSurface,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const _UpNextTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = video.thumbnail;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 160,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      Image(
                        image: thumb.startsWith('http')
                            ? NetworkImage(thumb) as ImageProvider
                            : FileImage(File(thumb)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surfaceContainerHigh),
                      )
                    else
                      const ColoredBox(
                        color: AppColors.surfaceContainerHigh,
                        child: Icon(Icons.movie_outlined, color: AppColors.outline),
                      ),
                    if (video.duration != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(video.duration!,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                video.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
