import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to MainActivity.kt to drive Android picture-in-picture.
class PipBridge {
  PipBridge._();
  static final PipBridge instance = PipBridge._();

  static const _channel = MethodChannel('com.abdullah.tooby/pip');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  void Function(bool inPip)? onPipChanged;
  void Function(String action)? onAction;

  bool _initialized = false;

  void init() {
    if (_initialized || !isSupported) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPipChanged':
          onPipChanged?.call(call.arguments == true);
          break;
        case 'pipAction':
          onAction?.call(call.arguments as String);
          break;
      }
    });
  }

  /// Tells Android whether the app should auto-enter PIP when the user leaves,
  /// plus the info needed for the PIP window (aspect ratio, play/pause button).
  Future<void> update({
    required bool ready,
    required bool playing,
    int? width,
    int? height,
    bool hasNext = false,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setPipState', {
        'ready': ready,
        'playing': playing,
        'width': width ?? 16,
        'height': height ?? 9,
        'hasNext': hasNext,
      });
    } catch (e) {
      debugPrint('PIP update failed: $e');
    }
  }

  /// Asks Android for audio focus so we get told (and pause) when a call or
  /// another media app takes over.
  Future<void> requestAudioFocus() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('requestAudioFocus');
    } catch (e) {
      debugPrint('Audio focus request failed: $e');
    }
  }

  Future<bool> enter() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } catch (e) {
      debugPrint('PIP enter failed: $e');
      return false;
    }
  }
}
