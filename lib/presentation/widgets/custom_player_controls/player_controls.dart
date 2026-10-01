import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:floatube_player/floatube_player.dart' hide PlayerControls, VideoSeekBar;
import '../../../core/theme/app_colors.dart';
import 'video_seek_bar.dart';

/// Full-featured overlay controls for the video player.
///
/// Supports:
/// - Tap to toggle visibility
/// - Double-tap zones for ±5 s seek
/// - Long-press to 2× fast-forward
/// - Settings, CC, fullscreen, arrow-down callbacks
/// - Landscape / collapsed / expanded states
class PlayerControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onPlayPressed;
  final ValueNotifier<FloatingState> overlayState;

  const PlayerControls({
    required this.controller,
    required this.overlayState,
    this.onPlayPressed,
    super.key,
  });

  @override
  State<PlayerControls> createState() => PlayerControlsState();
}

class PlayerControlsState extends State<PlayerControls> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  int _seekTapCountLeft = 0;
  int _seekTapCountRight = 0;
  int _leftSeekSeconds = 0;
  int _rightSeekSeconds = 0;
  bool _showLeftSeek = false;
  bool _showRightSeek = false;
  bool _isFastForwarding = false;
  DateTime? _lastSeekTapTime;
  Timer? _seekResetTimer;

  bool get _isLandscape =>
      widget.overlayState.value == FloatingState.landscaped;

  bool get _isCollapsed => widget.overlayState.value == FloatingState.collapsed;

  @override
  void initState() {
    super.initState();
    _startAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekResetTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startAutoHide();
  }

  void _startAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void hideControls() {
    _hideTimer?.cancel();
    if (_controlsVisible) setState(() => _controlsVisible = false);
  }

  void _seek(bool forward) {
    const step = 5;
    const tapWindow = 600;

    final now = DateTime.now();

    if (_lastSeekTapTime == null ||
        now.difference(_lastSeekTapTime!).inMilliseconds > tapWindow) {
      _seekTapCountLeft = 0;
      _seekTapCountRight = 0;
    }

    _lastSeekTapTime = now;

    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;

    if (forward) {
      _seekTapCountRight++;
      _rightSeekSeconds = _seekTapCountRight * step;
      _showRightSeek = true;
    } else {
      _seekTapCountLeft++;
      _leftSeekSeconds = _seekTapCountLeft * step;
      _showLeftSeek = true;
    }

    Duration target = forward
        ? position + const Duration(seconds: step)
        : position - const Duration(seconds: step);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    widget.controller.seekTo(target);

    setState(() {});

    _seekResetTimer?.cancel();
    _seekResetTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showLeftSeek = false;
        _showRightSeek = false;
        _seekTapCountLeft = 0;
        _seekTapCountRight = 0;
        _leftSeekSeconds = 0;
        _rightSeekSeconds = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.overlayState,
      builder: (context, value, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isCollapsed ? null : _toggleControls,
          onLongPressStart: (details) {
            if (!_controlsVisible && widget.controller.value.isPlaying) {
              setState(() => _isFastForwarding = true);
              widget.controller.setPlaybackSpeed(2.0);
            }
          },
          onLongPressEnd: (details) {
            if (_isFastForwarding) {
              setState(() => _isFastForwarding = false);
              widget.controller.setPlaybackSpeed(1.0);
            }
          },
          child: Stack(
            children: [
              // ── Seek gesture zones ──────────────────────────────────────
              if (!_isCollapsed)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () => _seek(false),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () => _seek(true),
                          onLongPressStart: (_) {
                            if (widget.controller.value.isPlaying) {
                              setState(() => _isFastForwarding = true);
                              widget.controller.setPlaybackSpeed(2.0);
                            }
                          },
                          onLongPressEnd: (_) {
                            setState(() => _isFastForwarding = false);
                            widget.controller.setPlaybackSpeed(1.0);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Seek indicators ─────────────────────────────────────────
              if (_showLeftSeek && !_isCollapsed)
                Positioned(
                  left: 40,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _SeekIndicator(
                      seconds: _leftSeekSeconds,
                      forward: false,
                    ),
                  ),
                ),

              if (_showRightSeek && !_isCollapsed)
                Positioned(
                  right: 40,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _SeekIndicator(
                      seconds: _rightSeekSeconds,
                      forward: true,
                    ),
                  ),
                ),

              // ── Fast-forward indicator ──────────────────────────────────
              if (_isFastForwarding && !_isCollapsed)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _isLandscape
                      ? MediaQuery.paddingOf(context).top + 50
                      : 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '2x',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.fast_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Gradient ────────────────────────────────────────────────
              if (_controlsVisible && !_isCollapsed)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(120),
                          Colors.black.withAlpha(90),
                          Colors.black.withAlpha(60),
                          Colors.black.withAlpha(30),
                          Colors.black.withAlpha(0),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

              if (_controlsVisible && !_isCollapsed)
                _TopControls(
                  isLandscape: _isLandscape,
                ),

              if (_controlsVisible && !_isCollapsed)
                _CenterControls(
                  controller: widget.controller,
                  onPlayPressed: widget.onPlayPressed,
                  isLandscape: _isLandscape,
                  onForwardPressed: () => _seek(true),
                  onRewindPressed: () => _seek(false),
                ),

              if (_controlsVisible && !_isCollapsed)
                _BottomControls(
                  controller: widget.controller,
                  isLandscape: _isLandscape,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Seek indicator
// ---------------------------------------------------------------------------

class _SeekIndicator extends StatelessWidget {
  final int seconds;
  final bool forward;

  const _SeekIndicator({required this.seconds, required this.forward});

  @override
  Widget build(BuildContext context) {
    final icon = forward ? Icons.arrow_forward_ios : Icons.arrow_back_ios;
    final sign = forward ? '+' : '-';

    Widget arrow = TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(
        begin: forward ? const Offset(-0.5, 0) : const Offset(0.5, 0),
        end: forward ? const Offset(0.5, 0) : const Offset(-0.5, 0),
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, offset, child) {
        return Transform.translate(
          offset: Offset(offset.dx * 20, 0),
          child: child,
        );
      },
      child: Icon(icon, color: Colors.white, size: 16),
    );

    final text = Text(
      '$sign$seconds sec',
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );

    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: seconds > 0 ? 1 : 0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: forward
              ? [text, const SizedBox(width: 6), arrow]
              : [arrow, const SizedBox(width: 6), text],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top controls
// ---------------------------------------------------------------------------

class _TopControls extends StatelessWidget {
  final bool isLandscape;

  const _TopControls({
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isLandscape ? 12 : 8,
      left: isLandscape ? kToolbarHeight : 8,
      right: isLandscape ? kToolbarHeight : 8,
      child: Row(
        children: [
          if (!isLandscape)
            InkWell(
              onTap: () {
                context.floatingController.collapse();
              },
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Center controls
// ---------------------------------------------------------------------------

class _CenterControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback? onPlayPressed;
  final bool isLandscape;
  final VoidCallback? onForwardPressed;
  final VoidCallback? onRewindPressed;

  const _CenterControls({
    required this.controller,
    this.onPlayPressed,
    this.isLandscape = false,
    this.onForwardPressed,
    this.onRewindPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final isCompleted =
              value.duration != Duration.zero &&
              value.position >= value.duration &&
              !value.isPlaying;

          return Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controlWidth =
                    constraints.maxWidth / (isLandscape ? 3 : 2);
                return SizedBox(
                  width: controlWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isCompleted)
                        GestureDetector(
                          onTap: onRewindPressed,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black38,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.replay_5,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isCompleted) {
                              controller.seekTo(Duration.zero);
                              controller.play();
                            } else {
                              if (value.isPlaying) {
                                controller.pause();
                              } else {
                                if (onPlayPressed != null) {
                                  onPlayPressed?.call();
                                } else {
                                  controller.play();
                                }
                              }
                            }
                          },
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black38,
                            ),
                            alignment: Alignment.center,
                            child: Builder(
                              builder: (context) {
                                if (isCompleted) {
                                  return const Icon(
                                    Icons.replay,
                                    color: Colors.white,
                                    size: 55,
                                  );
                                } else if (value.isPlaying) {
                                  return const Icon(
                                    Icons.pause,
                                    color: Colors.white,
                                    size: 50,
                                  );
                                } else {
                                  return const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 55,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),

                      if (!isCompleted)
                        GestureDetector(
                          onTap: onForwardPressed,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black38,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.forward_5,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom controls
// ---------------------------------------------------------------------------

class _BottomControls extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isLandscape;

  const _BottomControls({
    required this.controller,
    required this.isLandscape,
  });

  @override
  State<_BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends State<_BottomControls> {
  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.isLandscape ? 20 : 0,
      left: widget.isLandscape ? kToolbarHeight : 0,
      right: widget.isLandscape ? kToolbarHeight : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ValueListenableBuilder(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                final position = value.position;
                final duration = value.duration;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(45),
                      ),
                      child: Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          wordSpacing: 0,
                        ),
                      ),
                    ),

                    InkWell(
                      onTap: () {
                        if (widget.isLandscape) {
                          context.floatingController.closeLandscapeVideo();
                        } else {
                          context.floatingController.openLandscapeVideo();
                        }
                      },
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          widget.isLandscape
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          VideoSeekBar(
            controller: widget.controller,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
