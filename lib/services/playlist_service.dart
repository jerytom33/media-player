import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class PlaylistService {
  static const String _playlistsKey = 'playlists';

  Future<List<Playlist>> getPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistsJson = prefs.getString(_playlistsKey);
    
    if (playlistsJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(playlistsJson);
    return decoded.map((item) => Playlist.fromJson(item)).toList();
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final playlistsJson = jsonEncode(
      playlists.map((playlist) => playlist.toJson()).toList(),
    );
    await prefs.setString(_playlistsKey, playlistsJson);
  }

  Future<void> createPlaylist(String name, List<String> mediaFilePaths) async {
    final playlists = await getPlaylists();
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mediaFilePaths: mediaFilePaths,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    playlists.add(newPlaylist);
    await savePlaylists(playlists);
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      playlists[index] = playlist;
      await savePlaylists(playlists);
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final playlists = await getPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    await savePlaylists(playlists);
  }

  Future<void> addToPlaylist(String playlistId, String mediaFilePath) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final updatedPaths = List<String>.from(playlists[index].mediaFilePaths)
        ..add(mediaFilePath);
      playlists[index] = playlists[index].copyWith(
        mediaFilePaths: updatedPaths,
        updatedAt: DateTime.now(),
      );
      await savePlaylists(playlists);
    }
  }

  Future<void> removeFromPlaylist(String playlistId, String mediaFilePath) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final updatedPaths = List<String>.from(playlists[index].mediaFilePaths)
        ..remove(mediaFilePath);
      playlists[index] = playlists[index].copyWith(
        mediaFilePaths: updatedPaths,
        updatedAt: DateTime.now(),
      );
      await savePlaylists(playlists);
    }
  }
}
