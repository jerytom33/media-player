import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AudioMetadata {
  final String filePath;
  final String? customName;
  final String? description;
  final String? customImagePath;

  AudioMetadata({
    required this.filePath,
    this.customName,
    this.description,
    this.customImagePath,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'customName': customName,
        'description': description,
        'customImagePath': customImagePath,
      };

  factory AudioMetadata.fromJson(Map<String, dynamic> json) => AudioMetadata(
        filePath: json['filePath'] as String,
        customName: json['customName'] as String?,
        description: json['description'] as String?,
        customImagePath: json['customImagePath'] as String?,
      );
}

class AudioMetadataService {
  static const String _storageKey = 'audio_metadata';
  static AudioMetadataService? _instance;
  Map<String, AudioMetadata> _metadata = {};

  AudioMetadataService._();

  static Future<AudioMetadataService> getInstance() async {
    if (_instance == null) {
      _instance = AudioMetadataService._();
      await _instance!._loadMetadata();
    }
    return _instance!;
  }

  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _metadata = jsonMap.map((key, value) => MapEntry(
              key,
              AudioMetadata.fromJson(value as Map<String, dynamic>),
            ));
      }
    } catch (e) {
      print('Error loading metadata: $e');
      _metadata = {};
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = _metadata.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_storageKey, json.encode(jsonMap));
    } catch (e) {
      print('Error saving metadata: $e');
    }
  }

  Future<void> saveAudioMetadata({
    required String filePath,
    String? customName,
    String? description,
    String? customImagePath,
  }) async {
    _metadata[filePath] = AudioMetadata(
      filePath: filePath,
      customName: customName,
      description: description,
      customImagePath: customImagePath,
    );
    await _saveMetadata();
  }

  AudioMetadata? getAudioMetadata(String filePath) {
    return _metadata[filePath];
  }

  String getDisplayName(String filePath, String defaultName) {
    final metadata = _metadata[filePath];
    return metadata?.customName ?? defaultName;
  }

  String? getCustomImagePath(String filePath) {
    final metadata = _metadata[filePath];
    return metadata?.customImagePath;
  }

  String? getDescription(String filePath) {
    final metadata = _metadata[filePath];
    return metadata?.description;
  }

  Future<void> deleteAudioMetadata(String filePath) async {
    _metadata.remove(filePath);
    await _saveMetadata();
  }
}
