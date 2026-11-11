import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/utils/format.dart';
import '../data/models/video_model.dart';
import '../data/models/watch_history_model.dart';
import '../providers/video_provider.dart';
import 'pip_bridge.dart';

/// Panels that slide up inside the player layer.
enum PlayerPanel { none, tags, rename, settings }

/// Owns the single app-wide media_kit [Player] and all player UI state
/// (expanded / mini / fullscreen / PIP, queue, panels).
class PlayerService extends ChangeNotifier with WidgetsBindingObserver {
  PlayerService(this._ref) {
    player = Player(configuration: const PlayerConfiguration(title: 'Tooby'));
    videoController = VideoController(player);

    _subs.addAll([
      player.stream.playing.listen(_onPlayingChanged),
      player.stream.position.listen(_onPosition),
      player.stream.completed.listen(_onCompleted),
      player.stream.width.listen((_) {
        _updatePip();
        notifyListeners(); // the layout depends on the video's aspect ratio
      }),
      player.stream.error.listen((e) => debugPrint('Player error: $e')),
    ]);

    PipBridge.instance
      ..init()
      ..onPipChanged = _onPipChanged
      ..onAction = _onPipAction;

    _loadPrefs();

    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  late final Player player;
  late final VideoController videoController;
  final List<StreamSubscription> _subs = [];

  // ── State ────────────────────────────────────────────────────────────────
  VideoModel? current;
  List<VideoModel> upNext = [];
  final List<int> _history = [];

  bool isExpanded = false;
  bool isFullscreen = false;
  bool isInPip = false;
  PlayerPanel panel = PlayerPanel.none;

  BoxFit fit = BoxFit.contain;

  /// Seconds jumped by each double-tap (5, 10, 15, 20, 30 or 60).
  int seekStep = 10;
  static const seekStepOptions = [5, 10, 15, 20, 30, 60];
  bool loop = false;
  bool autoplay = true;

  /// Seconds left before auto-playing the next video (null = no countdown).
  int? countdown;
  Timer? _countdownTimer;

  /// Incremented every time a new video is opened. Lets the UI reset itself.
  int sessionId = 0;

  Duration _lastSaved = Duration.zero;
  int _openToken = 0;

  bool get isActive => current != null;
  bool get hasPrevious => _history.isNotEmpty;
  bool get hasNext => upNext.isNotEmpty;

  // ── Opening / closing ────────────────────────────────────────────────────

  Future<void> open(int videoId, {bool expand = true, bool pushHistory = true}) async {
    if (current?.id == videoId) {
      if (expand) this.expand();
      if (!player.state.playing) player.play();
      return;
    }

    final repo = _ref.read(videoRepositoryProvider);
    final video = await repo.getVideoById(videoId);
    if (video == null) return;

    final token = ++_openToken;
    await _saveHistory();
    _refreshLists();
    cancelCountdown();

    if (pushHistory && current?.id != null) _history.add(current!.id!);
    current = video;
    upNext = [];
    panel = PlayerPanel.none;
    sessionId++;
    if (expand) isExpanded = true;
    notifyListeners();

    final history = await repo.getWatchHistory(videoId);
    if (token != _openToken) return;

    var start = history?.lastPosition ?? Duration.zero;
    final knownDuration = parseDurationString(video.duration);
    // Start over if the video was already (almost) finished.
    if (knownDuration != null && start > knownDuration - const Duration(seconds: 5)) {
      start = Duration.zero;
    }
    _lastSaved = start;

    await player.setPlaylistMode(loop ? PlaylistMode.single : PlaylistMode.none);
    await player.open(
      Media(video.path, start: start > const Duration(seconds: 2) ? start : null),
      play: true,
    );

    _loadUpNext(video);
    _updatePip();
  }

  Future<void> _loadUpNext(VideoModel video) async {
    try {
      var list = await _ref.read(recommendedVideosProvider(video.id!).future);
      list = list.where((v) => v.id != video.id).toList();
      if (list.length < 10) {
        // Fill the queue with random videos so "next" always has something.
        final all = await _ref.read(allVideosProvider.future);
        final ids = {video.id, ...list.map((v) => v.id)};
        final extra = all.where((v) => !ids.contains(v.id)).toList()..shuffle(Random());
        list = [...list, ...extra.take(15 - list.length)];
      }
      if (current?.id != video.id) return;
      upNext = list;
      notifyListeners();
      _updatePip();
    } catch (e) {
      debugPrint('Failed to load up-next: $e');
    }
  }

  Future<void> playNext() async {
    cancelCountdown();
    if (upNext.isEmpty) return;
    await open(upNext.first.id!, expand: isExpanded);
  }

  Future<void> playPrevious() async {
    if (player.state.position > const Duration(seconds: 3) || _history.isEmpty) {
      await player.seek(Duration.zero);
      return;
    }
    final id = _history.removeLast();
    await open(id, expand: isExpanded, pushHistory: false);
  }

  Future<void> playRandom() async {
    final all = await _ref.read(videoRepositoryProvider).getAllVideos();
    final pool = all.where((v) => v.id != current?.id).toList();
    if (pool.isEmpty) return;
    await open(pool[Random().nextInt(pool.length)].id!);
  }

  Future<void> close() async {
    await _saveHistory();
    _refreshLists();
    cancelCountdown();
    _openToken++;
    await player.stop();
    if (isFullscreen) await exitFullscreen();
    current = null;
    upNext = [];
    _history.clear();
    isExpanded = false;
    panel = PlayerPanel.none;
    WakelockPlus.disable();
    PipBridge.instance.update(ready: false, playing: false);
    notifyListeners();
  }

  /// Called after the current video was renamed or edited elsewhere.
  void updateCurrent(VideoModel video) {
    if (current?.id != video.id) return;
    current = video;
    notifyListeners();
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  void togglePlay() {
    if (player.state.completed) {
      player.seek(Duration.zero);
      player.play();
      return;
    }
    player.playOrPause();
  }

  Future<void> seekBy(Duration delta) async {
    final dur = player.state.duration;
    var target = player.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    await player.seek(target);
  }

  Future<void> setSpeed(double rate) => player.setRate(rate);

  Future<void> setLoop(bool value) async {
    loop = value;
    await player.setPlaylistMode(value ? PlaylistMode.single : PlaylistMode.none);
    notifyListeners();
  }

  void setAutoplay(bool value) {
    autoplay = value;
    if (!value) cancelCountdown();
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool('autoplay', value)).catchError((_) => false);
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      seekStep = prefs.getInt('seekStep') ?? 10;
      autoplay = prefs.getBool('autoplay') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load player prefs: $e');
    }
  }

  Future<void> setSeekStep(int seconds) async {
    seekStep = seconds;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setInt('seekStep', seconds);
    } catch (_) {}
  }

  void setFit(BoxFit value) {
    fit = value;
    notifyListeners();
  }

  // ── Layout state ─────────────────────────────────────────────────────────

  void expand() {
    if (!isActive) return;
    isExpanded = true;
    notifyListeners();
  }

  void minimize() {
    if (isFullscreen) exitFullscreen();
    _saveHistory().then((_) => _refreshLists());
    isExpanded = false;
    panel = PlayerPanel.none;
    notifyListeners();
  }

  void openPanel(PlayerPanel value) {
    panel = value;
    notifyListeners();
  }

  void closePanel() {
    if (panel == PlayerPanel.none) return;
    panel = PlayerPanel.none;
    notifyListeners();
  }

  Future<void> enterFullscreen() async {
    if (isFullscreen) return;
    isFullscreen = true;
    panel = PlayerPanel.none;
    notifyListeners();
    final w = player.state.width ?? 16;
    final h = player.state.height ?? 9;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      w >= h
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
  }

  Future<void> exitFullscreen() async {
    if (!isFullscreen) return;
    isFullscreen = false;
    notifyListeners();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> toggleFullscreen() => isFullscreen ? exitFullscreen() : enterFullscreen();

  Future<void> enterPip() => PipBridge.instance.enter();

  /// Handles the Android back button. Returns true if the player consumed it.
  bool handleBack() {
    if (!isActive || isInPip) return false;
    if (panel != PlayerPanel.none) {
      closePanel();
      return true;
    }
    if (isFullscreen) {
      exitFullscreen();
      return true;
    }
    if (isExpanded) {
      minimize();
      return true;
    }
    return false;
  }

  // ── Auto-play countdown ──────────────────────────────────────────────────

  void _onCompleted(bool completed) {
    if (!completed || current == null) return;
    // Ignore "completed" events caused by stop()/switching files.
    final d = player.state.duration;
    if (d == Duration.zero || player.state.position < d - const Duration(seconds: 2)) return;
    _saveHistory(position: Duration.zero);
    if (autoplay && upNext.isNotEmpty && !loop) {
      countdown = isInPip ? 0 : 5;
      notifyListeners();
      if (countdown == 0) {
        playNext();
        return;
      }
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (countdown == null) return t.cancel();
        countdown = countdown! - 1;
        if (countdown! <= 0) {
          t.cancel();
          playNext();
        } else {
          notifyListeners();
        }
      });
    }
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    if (countdown != null) {
      countdown = null;
      notifyListeners();
    }
  }

  // ── Listeners ────────────────────────────────────────────────────────────

  void _onPlayingChanged(bool playing) {
    if (playing) {
      PipBridge.instance.requestAudioFocus();
      WakelockPlus.enable();
      if (countdown != null) cancelCountdown();
    } else {
      WakelockPlus.disable();
      _saveHistory();
    }
    _updatePip();
  }

  void _onPosition(Duration position) {
    if (current == null || !player.state.playing) return;
    if ((position - _lastSaved).abs() >= const Duration(seconds: 5)) {
      _saveHistory(position: position);
    }
  }

  Future<void> _saveHistory({Duration? position}) async {
    final video = current;
    if (video?.id == null) return;
    final pos = position ?? player.state.position;
    _lastSaved = pos;
    try {
      await _ref.read(videoRepositoryProvider).saveWatchHistory(
            WatchHistoryModel(videoId: video!.id!, lastPosition: pos, lastWatched: DateTime.now()),
          );
    } catch (e) {
      debugPrint('Failed to save watch history: $e');
    }
  }

  /// Refreshes "continue watching" and card progress bars.
  void _refreshLists() {
    _ref.invalidate(watchProgressProvider);
    _ref.invalidate(continueWatchingProvider);
  }

  void _updatePip() {
    PipBridge.instance.update(
      ready: isActive && player.state.playing,
      playing: player.state.playing,
      width: player.state.width,
      height: player.state.height,
      hasNext: upNext.isNotEmpty,
    );
  }

  void _onPipChanged(bool inPip) {
    isInPip = inPip;
    if (inPip) panel = PlayerPanel.none;
    notifyListeners();
  }

  void _onPipAction(String action) {
    switch (action) {
      case 'play':
        player.play();
        break;
      case 'pause':
        player.pause();
        break;
      case 'next':
        playNext();
        break;
      case 'previous':
        playPrevious();
        break;
      case 'closed':
        // PIP window dismissed with X: stop playback (the video stays in the
        // mini-player so it can be resumed later).
        player.pause();
        break;
      case 'audioFocusLost':
        // Phone call or another app started playing audio.
        player.pause();
        break;
      case 'rewind':
        seekBy(const Duration(seconds: -10));
        break;
      case 'forward':
        seekBy(const Duration(seconds: 10));
        break;
    }
  }

  // ── WidgetsBindingObserver ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app went fully to the background (not into PIP): pause playback.
    if (state == AppLifecycleState.paused && !isInPip && player.state.playing) {
      player.pause();
    }
  }

  @override
  Future<bool> didPopRoute() async => handleBack();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _countdownTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}

final playerServiceProvider = ChangeNotifierProvider<PlayerService>((ref) => PlayerService(ref));

/// Opens a video in the global player (expanded). Kept with the same
/// signature as before so every page can keep calling it.
void openVideo(BuildContext context, WidgetRef ref, int videoId) {
  ref.read(playerServiceProvider).open(videoId);
}
