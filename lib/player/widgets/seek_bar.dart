import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// YouTube-style seek bar: buffered + played track, a thumb that grows while
/// dragging, and a time bubble above the finger.
class PlayerSeekBar extends StatefulWidget {
  final Player player;
  final bool showThumb;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const PlayerSeekBar({
    super.key,
    required this.player,
    this.showThumb = true,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _dragValue; // 0..1 while dragging

  void _seekTo(double fraction) {
    final dur = widget.player.state.duration;
    widget.player.seek(dur * fraction.clamp(0.0, 1.0));
  }

  double _fractionFor(Offset local, double width) => (local.dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _seekTo(_fractionFor(d.localPosition, width)),
          onHorizontalDragStart: (d) {
            widget.onDragStart?.call();
            setState(() => _dragValue = _fractionFor(d.localPosition, width));
          },
          onHorizontalDragUpdate: (d) =>
              setState(() => _dragValue = _fractionFor(d.localPosition, width)),
          onHorizontalDragEnd: (_) {
            if (_dragValue != null) _seekTo(_dragValue!);
            setState(() => _dragValue = null);
            widget.onDragEnd?.call();
          },
          onHorizontalDragCancel: () {
            setState(() => _dragValue = null);
            widget.onDragEnd?.call();
          },
          child: SizedBox(
            height: 28,
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, _) {
                final dur = player.state.duration;
                final total = dur.inMilliseconds;
                final played = total == 0
                    ? 0.0
                    : (player.state.position.inMilliseconds / total).clamp(0.0, 1.0);
                final buffered = total == 0
                    ? 0.0
                    : (player.state.buffer.inMilliseconds / total).clamp(0.0, 1.0);
                final value = _dragValue ?? played;
                final dragging = _dragValue != null;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Track
                    Positioned(
                      left: 0,
                      right: 0,
                      child: _bar(width, 1, Colors.white24, dragging),
                    ),
                    Positioned(left: 0, child: _bar(width, buffered, Colors.white38, dragging)),
                    Positioned(left: 0, child: _bar(width, value, AppColors.primary, dragging)),
                    // Thumb
                    if (widget.showThumb || dragging)
                      Positioned(
                        left: value * width - (dragging ? 9 : 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: dragging ? 18 : 12,
                          height: dragging ? 18 : 12,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    // Time bubble
                    if (dragging)
                      Positioned(
                        left: (value * width - 36).clamp(0.0, (width - 72).clamp(0.0, double.infinity)),
                        bottom: 30,
                        child: Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            formatDuration(dur * value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _bar(double width, double fraction, Color color, bool thick) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width * fraction,
      height: thick ? 5 : 3,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

/// A thin, non-interactive progress line (used when controls are hidden and
/// in the mini-player).
class ThinProgressLine extends StatelessWidget {
  final Player player;
  final double height;

  const ThinProgressLine({super.key, required this.player, this.height = 2});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, _) {
        final total = player.state.duration.inMilliseconds;
        final value =
            total == 0 ? 0.0 : (player.state.position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(color: AppColors.primary),
            ),
          ),
        );
      },
    );
  }
}
