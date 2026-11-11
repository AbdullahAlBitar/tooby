import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../player_service.dart';

// Small building blocks used by PlayerControlsOverlay.

class ControlIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const ControlIconButton({super.key, required this.icon, this.onTap, this.size = 24, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: size),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ControlRoundButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool enabled;

  const ControlRoundButton({super.key, 
    required this.icon,
    required this.size,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: size * 0.6),
        ),
      ),
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  final Player player;
  final double size;
  final VoidCallback onTap;

  const PlayPauseButton({super.key, required this.player, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, _) {
        return StreamBuilder<bool>(
          stream: player.stream.buffering,
          initialData: player.state.buffering,
          builder: (context, _) {
            final playing = player.state.playing;
            final completed = player.state.completed;
            final buffering = player.state.buffering;
            return Material(
              color: Colors.black38,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: buffering && !completed
                      ? Padding(
                          padding: EdgeInsets.all(size * 0.25),
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Icon(
                            completed
                                ? Icons.replay_rounded
                                : (playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            key: ValueKey('$playing$completed'),
                            color: Colors.white,
                            size: size * 0.66,
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SeekRipple extends StatelessWidget {
  final int side;
  final int seconds;

  const SeekRipple({super.key, required this.side, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * 0.42;
        final left = side < 0;
        return Stack(
          children: [
            Positioned(
              left: left ? 0 : null,
              right: left ? null : 0,
              top: 0,
              bottom: 0,
              width: w,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(seconds),
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, v, child) => Opacity(opacity: v, child: child),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: left
                          ? BorderRadius.horizontal(right: Radius.elliptical(w, c.maxHeight))
                          : BorderRadius.horizontal(left: Radius.elliptical(w, c.maxHeight)),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Chevrons(forward: !left),
                        const SizedBox(height: 4),
                        Text(
                          '${left ? '-' : '+'}${seconds}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Three chevrons that light up one after another.
class _Chevrons extends StatefulWidget {
  final bool forward;
  const _Chevrons({required this.forward});

  @override
  State<_Chevrons> createState() => _ChevronsState();
}

class _ChevronsState extends State<_Chevrons> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final active = (_c.value * 3).floor();
        final icons = List.generate(3, (i) {
          final index = widget.forward ? i : 2 - i;
          return Icon(
            widget.forward ? Icons.play_arrow_rounded : Icons.arrow_left_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: index == active ? 1 : 0.35),
          );
        });
        return Row(mainAxisSize: MainAxisSize.min, children: icons);
      },
    );
  }
}

class ControlPill extends StatelessWidget {
  final IconData? icon;
  final String text;

  const ControlPill({super.key, this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, color: Colors.white, size: 18),
          ],
        ],
      ),
    );
  }
}

class ScrubLabel extends StatelessWidget {
  final Duration target;
  final Duration start;
  final Duration duration;

  const ScrubLabel({super.key, required this.target, required this.start, required this.duration});

  @override
  Widget build(BuildContext context) {
    final diff = target - start;
    final sign = diff.isNegative ? '-' : '+';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign${formatDuration(diff.abs())}',
            style: const TextStyle(color: AppColors.tertiary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '${formatDuration(target)} / ${formatDuration(duration)}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class CountdownOverlay extends StatelessWidget {
  final PlayerService service;

  const CountdownOverlay({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final next = service.upNext.first;
    final seconds = service.countdown ?? 0;
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Up next in $seconds',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            next.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: service.cancelCountdown,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: service.playNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
