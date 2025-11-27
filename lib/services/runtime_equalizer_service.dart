import 'dart:async';
import 'package:flutter/services.dart';

class RuntimeEqualizerService {
  static const _channel = MethodChannel('com.example.mp3_player/equalizer');
  static final RuntimeEqualizerService _instance = RuntimeEqualizerService._();
  RuntimeEqualizerService._();
  factory RuntimeEqualizerService.getInstance() => _instance;

  Future<void> setAudioSessionId(int? sessionId) async {
    await _channel.invokeMethod('setAudioSessionId', {'sessionId': sessionId});
  }

  Future<void> setEnabled(bool enabled, {int? sessionId}) async {
    await _channel.invokeMethod('setEnabled', {'enabled': enabled, 'sessionId': sessionId});
  }

  Future<void> setBands(List<double> gains, int bandCount, {int? sessionId}) async {
    await _channel.invokeMethod('setBands', {
      'gains': gains,
      'bandCount': bandCount,
      'sessionId': sessionId,
    });
  }

  Future<void> setBassBoost(double strength, {int? sessionId}) async {
    await _channel.invokeMethod('setBassBoost', {'strength': strength, 'sessionId': sessionId});
  }

  Future<void> setVirtualizer(double strength, {int? sessionId}) async {
    await _channel.invokeMethod('setVirtualizer', {'strength': strength, 'sessionId': sessionId});
  }
}
