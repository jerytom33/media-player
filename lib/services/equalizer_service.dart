import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerSettings {
  final int bandCount;
  final List<double> bands; // dB values
  final double bassBoost; // 0..1
  final double virtualizer; // 0..1
  final bool enabled;

  EqualizerSettings({
    required this.bandCount,
    required this.bands,
    required this.bassBoost,
    required this.virtualizer,
    required this.enabled,
  });

  Map<String, dynamic> toJson() => {
        'bandCount': bandCount,
        'bands': bands,
        'bassBoost': bassBoost,
        'virtualizer': virtualizer,
        'enabled': enabled,
      };

  factory EqualizerSettings.fromJson(Map<String, dynamic> j) => EqualizerSettings(
        bandCount: (j['bandCount'] as num?)?.toInt() ?? 5,
        bands: (j['bands'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? List<double>.filled(5, 0.0),
        bassBoost: (j['bassBoost'] as num?)?.toDouble() ?? 0.0,
        virtualizer: (j['virtualizer'] as num?)?.toDouble() ?? 0.0,
        enabled: (j['enabled'] as bool?) ?? false,
      );
}

class EqualizerService {
  static const _kKey = 'equalizer_settings_v1';
  final SharedPreferences _prefs;

  EqualizerService._(this._prefs);

  static Future<EqualizerService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return EqualizerService._(prefs);
  }

  EqualizerSettings getSettings() {
    final raw = _prefs.getString(_kKey);
    if (raw == null) {
      return EqualizerSettings(bandCount: 5, bands: List<double>.filled(5, 0.0), bassBoost: 0.0, virtualizer: 0.0, enabled: false);
    }
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return EqualizerSettings.fromJson(map);
    } catch (_) {
      return EqualizerSettings(bandCount: 5, bands: List<double>.filled(5, 0.0), bassBoost: 0.0, virtualizer: 0.0, enabled: false);
    }
  }

  Future<void> setSettings(EqualizerSettings settings) async {
    final raw = json.encode(settings.toJson());
    await _prefs.setString(_kKey, raw);
  }
}
