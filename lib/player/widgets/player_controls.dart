import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/utils/format.dart';
import '../pip_bridge.dart';
import '../player_service.dart';
import 'control_widgets.dart';
import 'seek_bar.dart';

enum _DragMode { none, scrub, minimize, swipeUp, exitDown, pinch, ignore }

/// Overlay drawn on top of the video: all gestures plus the YouTube-style
/// controls.
///
/// Gestures:
/// - tap: show / hide controls
/// - double-tap left / right: -10 s / +10 s (keep tapping to add more)
/// - long-press: 2x speed while held
/// - horizontal drag: scrub
/// - portrait: drag down = minimize, drag up = fullscreen
/// - long-press while paused + drag: pick a position, jump on release
/// - fullscreen: drag down = exit fullscreen, pinch = zoom to fill / original
class PlayerControlsOverlay extends StatefulWidget {
  final PlayerService service;
  final bool fullscreen;
  final ValueChanged<double> onDragDown;
  final ValueChanged<double> onDragDownEnd;

  const PlayerControlsOverlay({
    super.key,
    required this.service,
    required this.fullscreen,
    required this.onDragDown,
    required this.onDragDownEnd,
  });

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
  PlayerService get _service => widget.service;
  Player get _player => widget.service.player;

  bool _visible = true;
  bool _locked = false;
  Timer? _hideTimer;
  StreamSubscription<bool>? _playingSub;

  // Tap detection (done by hand so double-taps can chain without delay).
  int _pointers = 0;
  Offset? _downPos;
  DateTime? _downTime;
  bool _moved = false;
  Timer? _singleTapTimer;

  // Double-tap seek.
  int _seekSide = 0; // -1 left, 1 right
  int _seekSeconds = 0;
  DateTime? _seekModeUntil;
  Timer? _seekIndicatorTimer;

  // Long-press: 2x while playing, drag-to-seek while paused.
  bool _fast = false;
  double _rateBefore = 1;
  bool _pausedScrub = false;

  // Drag gestures.
  _DragMode _mode = _DragMode.none;
  Offset _dragStart = Offset.zero;
  Offset _lastDelta = Offset.zero;
  Duration _dragStartPos = Duration.zero;
  Duration? _scrubTarget;
  DateTime _lastLiveSeek = DateTime.fromMillisecondsSinceEpoch(0);
  double _pinchScale = 1;

  // Feedback.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        if (!_visible) setState(() => _visible = true);
      }
    });
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant PlayerControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreen && !widget.fullscreen) _locked = false;
  }

  @override
  void dispose() {
    // Safety net: if we go away mid minimize-drag, finish the drag so the
    // player never stays stuck half-way.
    if (_mode == _DragMode.minimize) {
      final end = widget.onDragDownEnd;
      Future.microtask(() => end(0));
    }
    _playingSub?.cancel();
    _hideTimer?.cancel();
    _singleTapTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _toastTimer?.cancel();
    if (_fast) _player.setRate(_rateBefore);
    super.dispose();
  }

  // ── Visibility ───────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_player.state.playing) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _show() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  void _hide() {
    _hideTimer?.cancel();
    setState(() => _visible = false);
  }

  void _toggleControls() => _visible ? _hide() : _show();

  /// Wraps a button action so it also keeps the controls on screen.
  VoidCallback _keep(VoidCallback action) => () {
        action();
        _scheduleHide();
      };

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── Taps ─────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    _pointers++;
    if (_pointers == 1) {
      _downPos = e.localPosition;
      _downTime = DateTime.now();
      _moved = false;
    } else {
      _moved = true;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_downPos != null && (e.localPosition - _downPos!).distance > 18) _moved = true;
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers != 0 || _moved || _fast || _downTime == null) return;
    if (DateTime.now().difference(_downTime!) > const Duration(milliseconds: 400)) return;
    _handleTap(e.localPosition);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers = math.max(0, _pointers - 1);
  }

  void _handleTap(Offset pos) {
    if (_locked) {
      _toggleControls();
      return;
    }
    final width = context.size?.width ?? 1;
    final side = pos.dx < width * 0.35 ? -1 : (pos.dx > width * 0.65 ? 1 : 0);
    final inSeekMode = _seekModeUntil != null && DateTime.now().isBefore(_seekModeUntil!);

    if (inSeekMode && side != 0 && side == _seekSide) {
      _doubleTapSeek(side);
      return;
    }
    if (_singleTapTimer?.isActive == true) {
      _singleTapTimer!.cancel();
      if (side != 0) {
        _doubleTapSeek(side);
      } else {
        _service.togglePlay();
      }
      return;
    }
    _singleTapTimer = Timer(const Duration(milliseconds: 250), _toggleControls);
  }

  void _doubleTapSeek(int side) {
    final step = _service.seekStep;
    if (side != _seekSide || _seekSeconds == 0) _seekSeconds = 0;
    _seekSide = side;
    _seekSeconds += step;
    _seekModeUntil = DateTime.now().add(const Duration(milliseconds: 800));
    _service.seekBy(Duration(seconds: step * side));
    _hideTimer?.cancel();
    setState(() => _visible = false);
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekSeconds = 0);
    });
  }

  // ── Long press ───────────────────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails d) {
    if (_locked || _mode != _DragMode.none) return;
    _singleTapTimer?.cancel();
    if (_player.state.playing) {
      _rateBefore = _player.state.rate;
      _player.setRate(2.0);
      setState(() => _fast = true);
    } else {
      // Paused: hold, then drag left/right to pick a position.
      _hideTimer?.cancel();
      _dragStartPos = _player.state.position;
      setState(() {
        _pausedScrub = true;
        _visible = false;
        _scrubTarget = _dragStartPos;
      });
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (!_pausedScrub) return;
    final target = _scrubTargetFor(d.offsetFromOrigin.dx);
    if (target != null) setState(() => _scrubTarget = target);
  }

  void _onLongPressEnd() {
    if (_fast) {
      _player.setRate(_rateBefore);
      setState(() => _fast = false);
    }
    if (_pausedScrub) {
      if (_scrubTarget != null) _player.seek(_scrubTarget!);
      setState(() {
        _pausedScrub = false;
        _scrubTarget = null;
        _visible = true;
      });
    }
  }

  /// Position for a horizontal drag of [dx] pixels from where the drag began.
  Duration? _scrubTargetFor(double dx) {
    final dur = _player.state.duration;
    if (dur == Duration.zero) return null;
    final width = context.size?.width ?? 1;
    final secPerPx = (dur.inSeconds / width).clamp(0.1, 0.5);
    var target = _dragStartPos + Duration(milliseconds: (dx * secPerPx * 1000).round());
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    return target;
  }

  // ── Drags / pinch ────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _mode = _DragMode.none;
    _dragStart = d.localFocalPoint;
    _lastDelta = Offset.zero;
    _dragStartPos = _player.state.position;
    _pinchScale = 1;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_locked || _fast || _pausedScrub) return;
    if (d.pointerCount >= 2) {
      if (widget.fullscreen) {
        _mode = _DragMode.pinch;
        _pinchScale = d.scale;
      }
      return;
    }
    if (_mode == _DragMode.pinch || _mode == _DragMode.ignore) return;

    final delta = d.localFocalPoint - _dragStart;
    _lastDelta = delta;

    if (_mode == _DragMode.none) {
      if (delta.distance < 14) return;
      if (delta.dx.abs() > delta.dy.abs()) {
        _mode = _DragMode.scrub;
      } else if (widget.fullscreen) {
        _mode = delta.dy > 0 ? _DragMode.exitDown : _DragMode.ignore;
      } else {
        _mode = delta.dy > 0 ? _DragMode.minimize : _DragMode.swipeUp;
      }
      _singleTapTimer?.cancel();
      if (_mode != _DragMode.minimize) _hide();
    }

    switch (_mode) {
      case _DragMode.scrub:
        final target = _scrubTargetFor(delta.dx);
        if (target == null) return;
        setState(() => _scrubTarget = target);
        final now = DateTime.now();
        if (now.difference(_lastLiveSeek) > const Duration(milliseconds: 120)) {
          _lastLiveSeek = now;
          _player.seek(target);
        }
        break;
      case _DragMode.minimize:
        widget.onDragDown(d.focalPointDelta.dy);
        break;
      default:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    switch (_mode) {
      case _DragMode.scrub:
        if (_scrubTarget != null) _player.seek(_scrubTarget!);
        setState(() => _scrubTarget = null);
        break;
      case _DragMode.minimize:
        widget.onDragDownEnd(d.velocity.pixelsPerSecond.dy);
        break;
      case _DragMode.swipeUp:
        if (_lastDelta.dy < -50) _service.enterFullscreen();
        break;
      case _DragMode.exitDown:
        if (_lastDelta.dy > 50) _service.exitFullscreen();
        break;
      case _DragMode.pinch:
        if (_pinchScale > 1.12 && _service.fit != BoxFit.cover) {
          _service.setFit(BoxFit.cover);
          _showToast('Zoomed to fill');
        } else if (_pinchScale < 0.9 && _service.fit != BoxFit.contain) {
          _service.setFit(BoxFit.contain);
          _showToast('Original');
        }
        break;
      default:
        break;
    }
    _mode = _DragMode.none;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fs = widget.fullscreen;
    final pad = fs ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    final hPad = fs ? math.max(24.0, math.max(pad.left, pad.right)) : 4.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gesture layer
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMove,
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: const SizedBox.expand(),
          ),
        ),

        // Double-tap ripple
        if (_seekSeconds > 0) SeekRipple(side: _seekSide, seconds: _seekSeconds),

        // Buffering spinner
        IgnorePointer(
          child: StreamBuilder<bool>(
            stream: _player.stream.buffering,
            initialData: _player.state.buffering,
            builder: (context, snap) => (snap.data ?? false) && !_visible
                ? const Center(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Controls
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: _locked ? _buildLocked() : _buildControls(fs, pad, hPad),
          ),
        ),

        // Thin progress line while controls are hidden (portrait)
        if (!_visible && !fs)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: ThinProgressLine(player: _player)),
          ),

        // 2x pill
        if (_fast)
          Positioned(
            top: fs ? pad.top + 24 : 12,
            left: 0,
            right: 0,
            child: const IgnorePointer(
              child: Center(child: ControlPill(icon: Icons.fast_forward_rounded, text: '2x')),
            ),
          ),

        // Scrub preview
        if (_scrubTarget != null)
          IgnorePointer(
            child: Center(
              child: ScrubLabel(
                target: _scrubTarget!,
                start: _dragStartPos,
                duration: _player.state.duration,
              ),
            ),
          ),

        // Toast
        if (_toast != null)
          Positioned(
            top: fs ? pad.top + 24 : 16,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: ControlPill(text: _toast!))),
          ),

        // Auto-play countdown
        if (_service.countdown != null && _service.upNext.isNotEmpty)
          CountdownOverlay(service: _service),
      ],
    );
  }

  Widget _buildLocked() {
    return Stack(
      children: [
        Positioned(
          left: 32,
          top: 0,
          bottom: 0,
          child: Center(
            child: ControlRoundButton(
              icon: Icons.lock_open_rounded,
              size: 52,
              onTap: () {
                setState(() => _locked = false);
                _show();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool fs, EdgeInsets pad, double hPad) {
    final service = _service;
    return Stack(
      children: [
        // Scrim
        const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.black38))),

        // Top bar
        Positioned(
          top: fs ? math.max(pad.top, 12) : 4,
          left: hPad,
          right: hPad,
          child: Row(
            children: [
              ControlIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                size: 30,
                tooltip: fs ? 'Exit fullscreen' : 'Minimize',
                onTap: fs ? service.exitFullscreen : service.minimize,
              ),
              if (fs) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.current?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ControlIconButton(
                  icon: Icons.lock_outline_rounded,
                  tooltip: 'Lock controls',
                  onTap: () {
                    setState(() => _locked = true);
                    _showToast('Controls locked');
                    _scheduleHide();
                  },
                ),
              ] else
                const Spacer(),
              if (PipBridge.instance.isSupported)
                ControlIconButton(
                  icon: Icons.picture_in_picture_alt_rounded,
                  tooltip: 'Picture-in-picture',
                  onTap: _keep(service.enterPip),
                ),
              ControlIconButton(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                onTap: () => service.openPanel(PlayerPanel.settings),
              ),
            ],
          ),
        ),

        // Center: previous / play / next
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ControlRoundButton(
                icon: Icons.skip_previous_rounded,
                size: fs ? 52 : 44,
                onTap: _keep(service.playPrevious),
              ),
              SizedBox(width: fs ? 56 : 36),
              PlayPauseButton(player: _player, size: fs ? 72 : 60, onTap: _keep(service.togglePlay)),
              SizedBox(width: fs ? 56 : 36),
              ControlRoundButton(
                icon: Icons.skip_next_rounded,
                size: fs ? 52 : 44,
                enabled: service.hasNext,
                onTap: _keep(service.playNext),
              ),
            ],
          ),
        ),

        // Bottom: time + fullscreen, then seek bar
        Positioned(
          left: hPad + (fs ? 0 : 8),
          right: hPad + (fs ? 0 : 4),
          bottom: fs ? math.max(pad.bottom, 16) : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    initialData: _player.state.position,
                    builder: (context, snap) => Text(
                      '${formatDuration(snap.data ?? Duration.zero)} / ${formatDuration(_player.state.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (fs)
                    ControlIconButton(
                      icon: service.fit == BoxFit.cover
                          ? Icons.fit_screen_rounded
                          : Icons.zoom_out_map_rounded,
                      tooltip: 'Zoom',
                      onTap: _keep(() {
                        final cover = service.fit != BoxFit.cover;
                        service.setFit(cover ? BoxFit.cover : BoxFit.contain);
                        _showToast(cover ? 'Zoomed to fill' : 'Original');
                      }),
                    ),
                  ControlIconButton(
                    icon: fs ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    size: 28,
                    tooltip: fs ? 'Exit fullscreen' : 'Fullscreen',
                    onTap: service.toggleFullscreen,
                  ),
                ],
              ),
              PlayerSeekBar(
                player: _player,
                onDragStart: () => _hideTimer?.cancel(),
                onDragEnd: _scheduleHide,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
