import 'package:shared_preferences/shared_preferences.dart';

class LikedSongsService {
  static const String _likedSongsKey = 'liked_songs';

  Future<Set<String>> getLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    return likedSongs.toSet();
  }

  Future<void> toggleLikedSong(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final likedSongs = (prefs.getStringList(_likedSongsKey) ?? []).toSet();
    
    if (likedSongs.contains(filePath)) {
      likedSongs.remove(filePath);
    } else {
      likedSongs.add(filePath);
    }
    
    await prefs.setStringList(_likedSongsKey, likedSongs.toList());
  }

  Future<bool> isLiked(String filePath) async {
    final likedSongs = await getLikedSongs();
    return likedSongs.contains(filePath);
  }

  Future<void> clearLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_likedSongsKey);
  }
}
