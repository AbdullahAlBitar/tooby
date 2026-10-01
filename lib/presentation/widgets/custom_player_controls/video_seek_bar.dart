import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A custom seek/progress bar for the video player.
class VideoSeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  final bool showThumb;
  final Color activeColor;
  final Color bufferedColor;
  final Color inactiveColor;
  final Function(double)? onChanged;

  const VideoSeekBar({
    required this.controller,
    this.showThumb = true,
    this.activeColor = const Color(0xFF4285F4),
    this.bufferedColor = Colors.white54,
    this.inactiveColor = const Color.fromRGBO(255, 255, 255, 0.24),
    this.onChanged,
    super.key,
  });

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> {
  double _sliderValue = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final sliderThemeData = SliderTheme.of(context).copyWith(
      trackHeight: 2.5,
      thumbShape: widget.showThumb
          ? const RoundSliderThumbShape(enabledThumbRadius: 6.5)
          : SliderComponentShape.noThumb,
      overlayShape: widget.showThumb
          ? const RoundSliderOverlayShape(overlayRadius: 10)
          : SliderComponentShape.noThumb,
      trackShape: const RectangularSliderTrackShape(),
      activeTrackColor: widget.activeColor,
      inactiveTrackColor: widget.inactiveColor,
      thumbColor: widget.activeColor,
      overlayColor: widget.activeColor.withValues(alpha: 0.2),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      secondaryActiveTrackColor: widget.bufferedColor,
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
      valueIndicatorColor: widget.activeColor,
      padding: EdgeInsets.zero,
    );

    return SliderTheme(
      data: sliderThemeData,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final duration = value.duration;

          if (!_isDragging && duration.inMilliseconds > 0) {
            _sliderValue = value.position.inMilliseconds.toDouble();
          }

          return Slider(
            min: 0,
            max: duration.inMilliseconds.toDouble() > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0,
            value: _sliderValue.clamp(0, duration.inMilliseconds.toDouble()),
            secondaryTrackValue: value.buffered.isNotEmpty
                ? value.buffered.last.end.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble()
                : null,
            onChanged: (v) {
              setState(() {
                _sliderValue = v;
                _isDragging = true;
              });
              widget.onChanged?.call(v);
            },
            onChangeEnd: (v) {
              widget.controller.seekTo(Duration(milliseconds: v.toInt()));
              widget.onChanged?.call(v);
              _isDragging = false;
            },
          );
        },
      ),
    );
  }
}
