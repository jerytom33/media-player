import 'dart:async';
import 'package:flutter/services.dart';

/// Minimal shim matching a simple equalizer Flutter API.
/// Delegates to the project's MethodChannel at
/// `com.example.mp3_player/equalizer` so the existing
/// native Android implementation is used.

class EqualizerFlutter {
  static const MethodChannel _channel = MethodChannel('com.example.mp3_player/equalizer');

  static Future<void> setAudioSessionId(int? sessionId) async {
    await _channel.invokeMethod('setAudioSessionId', {'sessionId': sessionId});
  }

  static Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod('setEnabled', {'enabled': enabled});
  }

  /// `gains` expected as list of doubles (dB), `bandCount` number of bands
  static Future<void> setBands(List<double> gains, int bandCount) async {
    await _channel.invokeMethod('setBands', {'gains': gains, 'bandCount': bandCount});
  }

  static Future<void> setBassBoost(double strength) async {
    await _channel.invokeMethod('setBassBoost', {'strength': strength});
  }

  static Future<void> setVirtualizer(double strength) async {
    await _channel.invokeMethod('setVirtualizer', {'strength': strength});
  }
}
