import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/theme/app_colors.dart';
import '../pip_bridge.dart';
import '../player_service.dart';

/// Bottom sheet with playback options. Drawn inside the player layer so it
/// works over the expanded player and in fullscreen.
class SettingsSheet extends StatelessWidget {
  final PlayerService service;
  const SettingsSheet({super.key, required this.service});

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * (service.isFullscreen ? 0.9 : 0.7);

    return Stack(
      children: [
        // Scrim
        Positioned.fill(
          child: GestureDetector(
            onTap: service.closePanel,
            child: const ColoredBox(color: Colors.black54),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) =>
                FractionalTranslation(translation: Offset(0, v), child: child),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
              child: Material(
                color: AppColors.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: mq.viewPadding.bottom + 8, top: 8),
                  child: StreamBuilder<double>(
                    stream: service.player.stream.rate,
                    initialData: service.player.state.rate,
                    builder: (context, _) => StreamBuilder<Track>(
                      stream: service.player.stream.track,
                      initialData: service.player.state.track,
                      builder: (context, _) => _content(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final rate = service.player.state.rate;
    final tracks = service.player.state.tracks;
    final track = service.player.state.track;
    final audio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subs = tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _header('Playback speed'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _speeds)
                ChoiceChip(
                  label: Text(s == 1.0 ? 'Normal' : '${_fmt(s)}x'),
                  selected: (rate - s).abs() < 0.01,
                  onSelected: (_) => service.setSpeed(s),
                ),
            ],
          ),
        ),
        _header('Double-tap to seek'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in PlayerService.seekStepOptions)
                ChoiceChip(
                  label: Text('${s}s'),
                  selected: service.seekStep == s,
                  onSelected: (_) => service.setSeekStep(s),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          secondary: const Icon(Icons.repeat_one_rounded),
          title: const Text('Loop video'),
          value: service.loop,
          onChanged: service.setLoop,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.playlist_play_rounded),
          title: const Text('Autoplay next'),
          value: service.autoplay,
          onChanged: service.setAutoplay,
        ),
        _header('Video size'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            children: [
              _fitChip('Fit', BoxFit.contain),
              _fitChip('Fill (zoom)', BoxFit.cover),
              _fitChip('Stretch', BoxFit.fill),
            ],
          ),
        ),
        if (audio.length > 1) ...[
          _header('Audio track'),
          for (final t in audio)
            _choice(
              _trackName(t.title, t.language, t.id),
              track.audio.id == t.id,
              () => service.player.setAudioTrack(t),
            ),
        ],
        if (subs.isNotEmpty) ...[
          _header('Subtitles'),
          _choice('Off', track.subtitle.id == 'no',
              () => service.player.setSubtitleTrack(SubtitleTrack.no())),
          for (final t in subs)
            _choice(
              _trackName(t.title, t.language, t.id),
              track.subtitle.id == t.id,
              () => service.player.setSubtitleTrack(t),
            ),
        ],
        const Divider(color: AppColors.outlineVariant),
        if (!service.isFullscreen) ...[
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Edit tags'),
            onTap: () => service.openPanel(PlayerPanel.tags),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('Rename'),
            onTap: () => service.openPanel(PlayerPanel.rename),
          ),
        ],
        if (PipBridge.instance.isSupported)
          ListTile(
            leading: const Icon(Icons.picture_in_picture_alt_rounded),
            title: const Text('Picture-in-picture'),
            onTap: () {
              service.closePanel();
              service.enterPip();
            },
          ),
      ],
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => ListTile(
        dense: true,
        title: Text(label),
        trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
        onTap: onTap,
      );

  Widget _fitChip(String label, BoxFit fit) => ChoiceChip(
        label: Text(label),
        selected: service.fit == fit,
        onSelected: (_) => service.setFit(fit),
      );

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  static String _fmt(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll(RegExp(r'0+$'), '');

  static String _trackName(String? title, String? language, String id) {
    final parts = [if (title != null && title.isNotEmpty) title, if (language != null) language];
    return parts.isEmpty ? 'Track $id' : parts.join(' · ');
  }
}
