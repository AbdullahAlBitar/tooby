import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

import 'video_preview_widget.dart';

class VideoCard extends StatefulWidget {
  final String title;
  final String? thumbnail;
  final String? duration;
  final String? videoPath;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.videoPath,
    required this.onTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isPreviewing = false;

  void _togglePreview() {
    if (widget.videoPath == null) return;
    setState(() {
      _isPreviewing = !_isPreviewing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (_isPreviewing) {
          setState(() => _isPreviewing = false);
        }
        widget.onTap();
      },
      onLongPress: _togglePreview,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isPreviewing && widget.videoPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoPreviewWidget(videoPath: widget.videoPath!),
                )
              : _buildThumbnail(aspectRatio: 16 / 9),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.duration != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Text(
                widget.duration!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail({double aspectRatio = 1.0}) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              image: widget.thumbnail != null
                  ? DecorationImage(
                      image: FileImage(File(widget.thumbnail!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.thumbnail == null
                ? const Center(child: Icon(Icons.video_library, color: AppColors.outline, size: 48))
                : null,
          ),
          if (widget.duration != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.duration!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
