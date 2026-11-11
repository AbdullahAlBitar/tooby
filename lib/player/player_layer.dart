import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/navigation.dart';
import '../core/theme/app_colors.dart';
import 'panels/rename_panel.dart';
import 'panels/settings_panel.dart';
import 'panels/tags_panel.dart';
import 'player_service.dart';
import 'watch_content.dart';
import 'widgets/player_controls.dart';
import 'widgets/seek_bar.dart';

/// The app-wide player. Sits above the root navigator (see `MaterialApp.builder`)
/// and morphs between the expanded watch page, the docked mini-player,
/// fullscreen and PIP.
///
/// It has its own [Overlay] so text fields and tooltips work inside it, and
/// uses in-layer panels instead of dialogs/routes, which would otherwise open
/// *behind* the player.
class PlayerLayer extends StatelessWidget {
  const PlayerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [OverlayEntry(builder: (_) => const _PlayerShell())],
    );
  }
}

class _PlayerShell extends ConsumerStatefulWidget {
  const _PlayerShell();

  @override
  ConsumerState<_PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends ConsumerState<_PlayerShell> with SingleTickerProviderStateMixin {
  /// 0 = expanded, 1 = mini-player.
  late final AnimationController _t = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 280),
  );
  final GlobalKey _videoKey = GlobalKey();

  bool _dragging = false;
  double? _lastTarget;
  double _dismissDx = 0;
  double _dragRange = 1;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _lastTarget = target;
    _t.animateTo(target, curve: Curves.easeOutCubic);
  }

  void _syncWithService(PlayerService service) {
    final target = service.isExpanded ? 0.0 : 1.0;
    if (_dragging || _lastTarget == target) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging) _animateTo(target);
    });
    _lastTarget = target;
  }

  // Drag down on the expanded video.
  void _onExpandedDrag(double dy) {
    _dragging = true;
    _t.value = (_t.value + dy / _dragRange).clamp(0.0, 1.0);
  }

  void _onExpandedDragEnd(double velocity) {
    _dragging = false;
    final service = ref.read(playerServiceProvider);
    if (velocity > 700 || _t.value > 0.35) {
      _animateTo(1);
      service.minimize();
    } else {
      _animateTo(0);
    }
  }

  // Drag up on the mini-player.
  void _onMiniVerticalDrag(DragUpdateDetails d) {
    _dragging = true;
    _t.value = (_t.value + d.delta.dy / _dragRange).clamp(0.0, 1.0);
  }

  void _onMiniVerticalDragEnd(DragEndDetails d) {
    _dragging = false;
    final service = ref.read(playerServiceProvider);
    if ((d.primaryVelocity ?? 0) < -500 || _t.value < 0.65) {
      _animateTo(0);
      service.expand();
    } else {
      _animateTo(1);
    }
  }

  void _onMiniHorizontalDragEnd(DragEndDetails d, double width) {
    final v = d.primaryVelocity ?? 0;
    if (_dismissDx.abs() > width * 0.35 || v.abs() > 900) {
      ref.read(playerServiceProvider).close();
    }
    setState(() => _dismissDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(playerServiceProvider);
    if (!service.isActive) {
      _lastTarget = null;
      if (_t.value != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _t.value = 1;
        });
      }
      return const SizedBox.shrink();
    }
    _syncWithService(service);

    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          RootRouteObserver.instance.isAtRoot,
          RootRouteObserver.instance.hasPopup,
          _t,
        ]),
        builder: (context, _) {
          final layout = _buildLayout(context, service, RootRouteObserver.instance.isAtRoot.value);
          final hide = RootRouteObserver.instance.hasPopup.value && !service.isExpanded && !service.isFullscreen;
          return IgnorePointer(
            ignoring: hide,
            child: AnimatedOpacity(
              opacity: hide ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: layout,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayout(BuildContext context, PlayerService service, bool atRoot) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final W = size.width;
    final H = size.height;
    final pad = mq.viewPadding;
    final fs = service.isFullscreen || service.isInPip;
    final t = fs ? 0.0 : _t.value;

    // ── Geometry ──
    final player = service.player;
    final vw = (player.state.width ?? 16).toDouble();
    final vh = (player.state.height ?? 9).toDouble();
    final aspect = (vw > 0 && vh > 0) ? vw / vh : 16 / 9;
    final boxH = (W / aspect).clamp(W * 9 / 16, H * 0.6).toDouble();

    final bottomInset = (atRoot ? kAppNavBarHeight : 0) + pad.bottom;
    const miniH = kMiniPlayerHeight;
    const miniVideoW = miniH * 16 / 9;
    final miniTop = H - bottomInset - miniH - 6;
    _dragRange = (miniTop).clamp(1.0, double.infinity);

    final containerTop = lerpDouble(0, miniTop, t)!;
    final sideMargin = lerpDouble(0, 8, t)!;
    final containerH = lerpDouble(H, miniH, t)!;
    final radius = lerpDouble(0, 12, t)!;

    final Rect videoRect = fs
        ? Rect.fromLTWH(0, 0, W, H)
        : Rect.fromLTWH(
            0,
            lerpDouble(pad.top, 0, t)!,
            lerpDouble(W, miniVideoW, t)!,
            lerpDouble(boxH, miniH, t)!,
          );

    final contentOpacity = (1 - t * 2.5).clamp(0.0, 1.0);
    final miniOpacity = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
    final isMini = t > 0.98;
    final isExpandedFully = t < 0.02;
    final miniDismissOpacity = (1 - _dismissDx.abs() / W).clamp(0.0, 1.0);

    final contentTop = pad.top + boxH;

    return Stack(
      children: [
        Positioned(
          left: sideMargin + (isMini ? _dismissDx : 0),
          width: W - sideMargin * 2,
          top: containerTop,
          height: containerH,
          child: Opacity(
            opacity: isMini ? miniDismissOpacity : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: fs
                    ? Colors.black
                    : Color.lerp(AppColors.surface, AppColors.surfaceContainerHigh, t)!,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Black strip behind the status bar while expanded.
                    if (!fs && t < 1)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: pad.top * (1 - t),
                        child: const ColoredBox(color: Colors.black),
                      ),

                    // Watch page content (title, tags, up next).
                    if (!fs)
                      Positioned(
                        top: contentTop,
                        left: 0,
                        width: W,
                        height: H - contentTop,
                        child: IgnorePointer(
                          ignoring: !isExpandedFully,
                          child: Opacity(
                            opacity: contentOpacity,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: WatchContent(
                                    key: ValueKey(service.sessionId),
                                    service: service,
                                  ),
                                ),
                                if (service.panel == PlayerPanel.tags ||
                                    service.panel == PlayerPanel.rename)
                                  Positioned.fill(
                                    child: _SlideUpPanel(
                                      key: ValueKey(service.panel),
                                      child: service.panel == PlayerPanel.tags
                                          ? TagsPanel(service: service)
                                          : RenamePanel(service: service),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Video + gesture controls.
                    Positioned.fromRect(
                      rect: videoRect,
                      child: ColoredBox(
                        color: Colors.black,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            KeyedSubtree(
                              key: _videoKey,
                              child: Video(
                                controller: service.videoController,
                                controls: NoVideoControls,
                                fit: service.fit,
                                fill: Colors.black,
                                wakelock: false,
                                pauseUponEnteringBackgroundMode: false,
                                resumeUponEnteringForegroundMode: false,
                              ),
                            ),
                            if (!service.isInPip && t < 0.25)
                              IgnorePointer(
                                ignoring: !isExpandedFully && !fs,
                                child: Opacity(
                                  opacity: (1 - t * 4).clamp(0.0, 1.0),
                                  child: PlayerControlsOverlay(
                                    key: ValueKey('controls-$fs'),
                                    service: service,
                                    fullscreen: service.isFullscreen,
                                    onDragDown: _onExpandedDrag,
                                    onDragDownEnd: _onExpandedDragEnd,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Mini-player: whole-bar gestures + buttons.
                    if (!fs && t > 0.5) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isMini ? service.expand : null,
                          onVerticalDragUpdate: _onMiniVerticalDrag,
                          onVerticalDragEnd: _onMiniVerticalDragEnd,
                          onHorizontalDragUpdate: isMini
                              ? (d) => setState(() => _dismissDx += d.delta.dx)
                              : null,
                          onHorizontalDragEnd: isMini ? (d) => _onMiniHorizontalDragEnd(d, W) : null,
                        ),
                      ),
                      Positioned(
                        left: miniVideoW,
                        top: 0,
                        right: 0,
                        height: miniH,
                        child: IgnorePointer(
                          ignoring: !isMini,
                          child: Opacity(
                            opacity: miniOpacity,
                            child: _MiniBar(service: service),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Opacity(
                          opacity: miniOpacity,
                          child: ThinProgressLine(player: service.player),
                        ),
                      ),
                    ],

                    // Settings sheet (works in portrait and fullscreen).
                    if (service.panel == PlayerPanel.settings && (isExpandedFully || fs))
                      Positioned.fill(child: SettingsSheet(service: service)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final PlayerService service;
  const _MiniBar({required this.service});

  @override
  Widget build(BuildContext context) {
    final video = service.current!;
    final parts = video.path.split(RegExp(r'[\\/]'));
    final folder = video.path.startsWith('http')
        ? 'Network'
        : (parts.length > 1 ? parts[parts.length - 2] : '');
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                folder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        StreamBuilder<bool>(
          stream: service.player.stream.playing,
          initialData: service.player.state.playing,
          builder: (context, snap) => IconButton(
            onPressed: service.togglePlay,
            icon: Icon(
              (snap.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 30,
              color: AppColors.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: service.close,
          icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Slides its child up from the bottom when first shown.
class _SlideUpPanel extends StatelessWidget {
  final Widget child;
  const _SlideUpPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => FractionalTranslation(
        translation: Offset(0, v),
        child: child,
      ),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
