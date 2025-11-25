import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static const String _storageKey = 'user_profile';
  static UserProfileService? _instance;
  Map<String, dynamic> _data = {};

  UserProfileService._();

  static Future<UserProfileService> getInstance() async {
    if (_instance == null) {
      _instance = UserProfileService._();
      await _instance!._load();
    }
    return _instance!;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        _data = Map<String, dynamic>.from(json.decode(jsonString));
      }
    } catch (_) {
      _data = {};
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(_data));
    } catch (_) {}
  }

  String? getProfileImagePath() {
    return _data['profileImagePath'] as String?;
  }

  Future<void> setProfileImagePath(String? path) async {
    if (path == null) {
      _data.remove('profileImagePath');
    } else {
      _data['profileImagePath'] = path;
    }
    await _save();
  }
}
