import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../services/media_service.dart';
import '../services/playlist_service.dart';
import '../services/liked_songs_service.dart';
import '../services/audio_metadata_service.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/video_player_widget.dart';
import 'audio_edit_screen.dart';

class MediaHomePage extends StatefulWidget {
  const MediaHomePage({super.key});

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  late final MediaService _mediaService;
  late final PlaylistService _playlistService;
  late final LikedSongsService _likedSongsService;
  AudioMetadataService? _metadataService;
  String? _filePath;
  bool _isVideo = false;
  bool _loading = false;
  String? _error;
  List<MediaFile> _mediaFiles = [];
  List<MediaFile> _audioFiles = [];
  List<MediaFile> _videoFiles = [];
  List<MediaFile> _filteredFiles = [];
  List<Playlist> _playlists = [];
  Set<String> _likedSongs = {};
  Playlist? _currentPlaylist;
  bool _isScanning = false;
  bool _showList = true;
  String _currentView = 'audio'; // 'audio', 'videos', 'playlists', 'liked', 'playlist_view'
  int _currentPlayingIndex = -1;
  bool _isVideoFullScreen = false;
  bool _isShuffleEnabled = false;
  LoopMode _repeatMode = LoopMode.off;
  List<MediaFile> _shuffledMediaFiles = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService(AudioPlayer());
    _playlistService = PlaylistService();
    _likedSongsService = LikedSongsService();
    _initMetadataService();
    _scanForFiles();
    _loadPlaylists();
    _loadLikedSongs();
    _searchController.addListener(_filterFiles);
    
    // Listen to player completion for repeat functionality
    _mediaService.audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleAudioCompletion();
      }
    });
  }

  Future<void> _loadPlaylists() async {
    final playlists = await _playlistService.getPlaylists();
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _loadLikedSongs() async {
    final likedSongs = await _likedSongsService.getLikedSongs();
    setState(() {
      _likedSongs = likedSongs;
    });
  }

  Future<void> _toggleLikedSong(MediaFile file) async {
    await _likedSongsService.toggleLikedSong(file.path);
    await _loadLikedSongs();
    
    // Show feedback
    final isNowLiked = _likedSongs.contains(file.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs'),
          backgroundColor: const Color(0xFF8B5CF6),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _scanForFiles({bool forceRefresh = false}) async {
    // Check if we have cached files and not forcing refresh
    if (!forceRefresh && _mediaService.hasCachedFiles()) {
      final cachedFiles = _mediaService.getCachedFiles()!;
      setState(() {
        _mediaFiles = cachedFiles;
        _filteredFiles = cachedFiles;
      });
      return;
    }

    // Only show scanning UI on initial load, not on force refresh
    if (!forceRefresh) {
      setState(() {
        _isScanning = true;
        _error = null;
      });
    }

    try {
      final files = await _mediaService.scanForMediaFiles(forceRefresh: forceRefresh);
      if (!mounted) return;
      
      // Separate audio and video files
      final audioFiles = files.where((file) => !file.isVideo).toList();
      final videoFiles = files.where((file) => file.isVideo).toList();
      
      setState(() {
        _mediaFiles = files;
        _audioFiles = audioFiles;
        _videoFiles = videoFiles;
        _filteredFiles = _currentView == 'videos' ? videoFiles : audioFiles;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to scan for media files: $e';
        _isScanning = false;
      });
    }
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      final sourceFiles = _currentView == 'videos' ? _videoFiles : _audioFiles;
      if (query.isEmpty) {
        _filteredFiles = sourceFiles;
      } else {
        _filteredFiles = sourceFiles
            .where((file) => file.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await _mediaService.pickFile();
      if (result == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      await _loadMedia(
        path: result['path'],
        contentUri: result['contentUri'],
        isVideo: result['isVideo'],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to pick file: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMedia({
    String? path,
    Uri? contentUri,
    required bool isVideo,
  }) async {
    setState(() {
      _filePath = path ?? contentUri?.toString();
      _isVideo = isVideo;
      _loading = true;
      _error = null;
      _showList = false;
    });

    try {
      await _mediaService.loadMedia(
        path: path,
        contentUri: contentUri,
        isVideo: isVideo,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load media: $e';
        _loading = false;
      });
    }
  }

  Future<void> _playMediaFile(MediaFile file) async {
    try {
      // Determine the current list based on file type or current view
      final currentList = file.isVideo ? _videoFiles : _audioFiles;
      final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
      
      // Find the index in the appropriate list
      final index = playList.indexWhere((f) => f.path == file.path);
      
      setState(() {
        _loading = true;
        _error = null;
        _showList = false;
        _filePath = file.path;
        _isVideo = file.isVideo;
        _currentPlayingIndex = index;
        // Update current view based on file type
        _currentView = file.isVideo ? 'videos' : 'audio';
      });

      await _mediaService.loadMediaFromFile(file);
      
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load media: $e';
        _loading = false;
      });
    }
  }

  void _playNext() {
    final currentList = _currentView == 'videos' ? _videoFiles : _audioFiles;
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
    if (_currentPlayingIndex >= 0 && _currentPlayingIndex < playList.length - 1) {
      _playMediaFile(playList[_currentPlayingIndex + 1]);
    }
  }

  void _playPrevious() {
    final currentList = _currentView == 'videos' ? _videoFiles : _audioFiles;
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
    if (_currentPlayingIndex > 0) {
      _playMediaFile(playList[_currentPlayingIndex - 1]);
    }
  }

  Future<void> _showAudioEditDialog() async {
    final currentList = _currentView == 'videos' ? _videoFiles : _audioFiles;
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
    
    if (_currentPlayingIndex < 0 || _currentPlayingIndex >= playList.length) {
      return;
    }

    final currentFile = playList[_currentPlayingIndex];
    final metadata = _metadataService?.getAudioMetadata(currentFile.path);
    
    final result = await Navigator.push<Map<String, String?>>(
      context,
      MaterialPageRoute(
        builder: (context) => AudioEditScreen(
          filePath: currentFile.path,
          currentName: metadata?.customName ?? currentFile.displayName,
          currentDescription: metadata?.description,
        ),
      ),
    );

    if (result != null && mounted) {
      // Save the metadata
      await _metadataService?.saveAudioMetadata(
        filePath: currentFile.path,
        customName: result['name']?.isNotEmpty == true ? result['name'] : null,
        description: result['description']?.isNotEmpty == true ? result['description'] : null,
        customImagePath: result['imagePath'],
      );
      
      // Refresh the UI
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio info updated'),
          backgroundColor: Color(0xFF8B5CF6),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Methods for mini player - don't change screen
  Future<void> _playNextInBackground() async {
    // Always use audio files for mini player navigation
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : _audioFiles;
    if (_currentPlayingIndex >= 0 && _currentPlayingIndex < playList.length - 1) {
      final nextFile = playList[_currentPlayingIndex + 1];
      // Only proceed if next file is audio
      if (nextFile.isVideo) return;
      
      try {
        setState(() {
          _loading = true;
          _error = null;
          _filePath = nextFile.path;
          _isVideo = false; // Always audio in mini player
          _currentPlayingIndex = _currentPlayingIndex + 1;
        });

        await _mediaService.loadMediaFromFile(nextFile);
        
        if (!mounted) return;
        setState(() => _loading = false);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load media: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _playPreviousInBackground() async {
    // Always use audio files for mini player navigation
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : _audioFiles;
    if (_currentPlayingIndex > 0) {
      final prevFile = playList[_currentPlayingIndex - 1];
      // Only proceed if previous file is audio
      if (prevFile.isVideo) return;
      
      try {
        setState(() {
          _loading = true;
          _error = null;
          _filePath = prevFile.path;
          _isVideo = false; // Always audio in mini player
          _currentPlayingIndex = _currentPlayingIndex - 1;
        });

        await _mediaService.loadMediaFromFile(prevFile);
        
        if (!mounted) return;
        setState(() => _loading = false);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load media: $e';
          _loading = false;
        });
      }
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffleEnabled = !_isShuffleEnabled;
      final currentList = _currentView == 'videos' ? _videoFiles : _audioFiles;
      
      if (_isShuffleEnabled) {
        // Create a shuffled copy of current view's files
        _shuffledMediaFiles = List<MediaFile>.from(currentList)..shuffle();
        
        // If currently playing, find the current file in shuffled list and adjust index
        if (_currentPlayingIndex >= 0 && _currentPlayingIndex < currentList.length) {
          final currentFile = currentList[_currentPlayingIndex];
          _currentPlayingIndex = _shuffledMediaFiles.indexWhere(
            (file) => file.path == currentFile.path,
          );
        }
        
        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shuffle enabled - ${currentList.length} tracks'),
              backgroundColor: const Color(0xFF8B5CF6),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // When turning off shuffle, find current file in original list
        if (_currentPlayingIndex >= 0 && _currentPlayingIndex < _shuffledMediaFiles.length) {
          final currentFile = _shuffledMediaFiles[_currentPlayingIndex];
          _currentPlayingIndex = currentList.indexWhere(
            (file) => file.path == currentFile.path,
          );
        }
        
        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shuffle disabled'),
              backgroundColor: Color(0xFF8B5CF6),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  void _toggleRepeat() {
    setState(() {
      // Cycle through: off -> one -> all -> off
      if (_repeatMode == LoopMode.off) {
        _repeatMode = LoopMode.one;
      } else if (_repeatMode == LoopMode.one) {
        _repeatMode = LoopMode.all;
      } else {
        _repeatMode = LoopMode.off;
      }
      _mediaService.audioPlayer.setLoopMode(_repeatMode);
    });
  }

  Future<void> _initMetadataService() async {
    _metadataService = await AudioMetadataService.getInstance();
  }

  void _handleAudioCompletion() {
    if (_repeatMode == LoopMode.off) {
      // Auto play next if available (in background, don't switch screens)
      final currentList = _currentView == 'videos' ? _videoFiles : _audioFiles;
      final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
      if (_currentPlayingIndex >= 0 && _currentPlayingIndex < playList.length - 1) {
        _playNextInBackground();
      }
    }
    // LoopMode.one and LoopMode.all are handled automatically by just_audio
  }

  void _onFullScreenChanged(bool isFullScreen) {
    setState(() {
      _isVideoFullScreen = isFullScreen;
    });
  }

  @override
  void dispose() {
    _mediaService.dispose();
    _searchController.dispose();
    // Ensure portrait mode when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Widget _buildMediaList() {
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scanning for media files...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withOpacity(0.3),
                    const Color(0xFFDC2626).withOpacity(0.3),
                  ],
                ),
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _scanForFiles(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      // Special message for liked songs when empty
      if (_currentView == 'liked') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      const Color(0xFFEC4899).withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You have no liked audios',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Start liking songs by tapping the heart icon',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6B7280).withOpacity(0.3),
                    const Color(0xFF4B5563).withOpacity(0.3),
                  ],
                ),
              ),
              child: Icon(
                _searchController.text.isNotEmpty 
                    ? Icons.search_off 
                    : Icons.music_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No media files match your search'
                  : 'No media files found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.add),
              label: const Text('Pick File Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ),
        // Category tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('Playlist', _currentView == 'playlists', onTap: () {
                  setState(() {
                    _currentView = 'playlists';
                  });
                }),
                const SizedBox(width: 10),
                _buildCategoryChip('Videos', _currentView == 'videos', onTap: () {
                  setState(() {
                    _currentView = 'videos';
                    _filteredFiles = _videoFiles;
                  });
                }),
                const SizedBox(width: 10),
                _buildCategoryChip('Audio', _currentView == 'audio', onTap: () {
                  setState(() {
                    _currentView = 'audio';
                    _filteredFiles = _audioFiles;
                  });
                }),
                const SizedBox(width: 10),
                _buildCategoryChip('Liked', _currentView == 'liked', onTap: () {
                  setState(() {
                    _currentView = 'liked';
                    // Filter to show only liked audio files
                    _filteredFiles = _audioFiles.where((file) => _likedSongs.contains(file.path)).toList();
                  });
                }),
                if (_currentView == 'playlists') ...[
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF8B5CF6), size: 28),
                    onPressed: _showCreatePlaylistDialog,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Section title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentView == 'playlists' 
                    ? 'My Playlists' 
                    : _currentView == 'videos'
                        ? 'All Videos'
                        : _currentView == 'liked'
                            ? 'Liked Songs'
                            : _currentView == 'playlist_view'
                                ? _currentPlaylist?.name ?? 'Playlist'
                                : 'All Audio',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _currentView == 'playlists'
                    ? '${_playlists.length} playlists'
                    : _currentView == 'videos'
                        ? '${_videoFiles.length} videos'
                        : '${_audioFiles.length} tracks',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            backgroundColor: const Color(0xFF1E1E2E),
            onRefresh: () async {
              if (_currentView == 'playlists') {
                await _loadPlaylists();
              } else if (_currentView == 'playlist_view') {
                // Refresh the current playlist
                await _loadPlaylists();
                if (_currentPlaylist != null) {
                  final updatedPlaylist = _playlists.firstWhere(
                    (p) => p.id == _currentPlaylist!.id,
                    orElse: () => _currentPlaylist!,
                  );
                  setState(() {
                    _currentPlaylist = updatedPlaylist;
                  });
                }
              } else if (_currentView == 'liked') {
                await _loadLikedSongs();
                setState(() {
                  _filteredFiles = _audioFiles.where((file) => _likedSongs.contains(file.path)).toList();
                });
              } else {
                // Only refresh for 'audio' and 'videos' views
                await _scanForFiles(forceRefresh: true);
              }
            },
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: (!_showList || _currentPlayingIndex < 0 || _isVideo) ? 8 : 100, // Add bottom padding when mini player is visible
              ),
              itemCount: _currentView == 'playlists' ? _playlists.length : _filteredFiles.length,
              itemBuilder: (context, index) {
                if (_currentView == 'playlists') {
                  final playlist = _playlists[index];
                  return _buildPlaylistItem(playlist);
                }
                final file = _filteredFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _playMediaFile(file),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // Rounded thumbnail
                            Builder(
                              builder: (context) {
                                final customImagePath = !file.isVideo ? _metadataService?.getCustomImagePath(file.path) : null;
                                return Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: customImagePath == null ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: file.isVideo 
                                          ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                                          : [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
                                    ) : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: customImagePath != null
                                        ? Image.file(
                                            File(customImagePath),
                                            fit: BoxFit.cover,
                                            width: 56,
                                            height: 56,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                file.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                                                color: Colors.white,
                                                size: 26,
                                              );
                                            },
                                          )
                                        : Icon(
                                            file.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                  ),
                                );
                              }
                            ),
                            const SizedBox(width: 14),
                            // Title and subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _metadataService?.getDisplayName(
                                      file.path,
                                      file.displayName,
                                    ) ?? file.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _metadataService?.getDescription(file.path) ?? file.formattedSize,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Duration placeholder
                            const Text(
                              '04:32',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                            // Heart button (only for audio files)
                            if (!file.isVideo) ...[
                              const SizedBox(width: 8),
                              // Show remove button in playlist view, heart button otherwise
                              if (_currentView == 'playlist_view' && _currentPlaylist != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                    size: 24,
                                  ),
                                  splashColor: Colors.redAccent.withOpacity(0.3),
                                  highlightColor: Colors.redAccent.withOpacity(0.2),
                                  onPressed: () async {
                                    // Remove from playlist
                                    final updatedPaths = List<String>.from(_currentPlaylist!.mediaFilePaths)
                                      ..remove(file.path);
                                    
                                    if (updatedPaths.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Cannot remove the last song from playlist'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    final updatedPlaylist = _currentPlaylist!.copyWith(
                                      mediaFilePaths: updatedPaths,
                                    );
                                    
                                    await _playlistService.updatePlaylist(updatedPlaylist);
                                    await _loadPlaylists();
                                    
                                    setState(() {
                                      _currentPlaylist = updatedPlaylist;
                                      _filteredFiles.remove(file);
                                    });
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Removed from "${_currentPlaylist!.name}"'),
                                          backgroundColor: const Color(0xFF8B5CF6),
                                        ),
                                      );
                                    }
                                  },
                                )
                              else
                                IconButton(
                                  icon: Icon(
                                    _likedSongs.contains(file.path) 
                                        ? Icons.favorite 
                                        : Icons.favorite_border,
                                    color: _likedSongs.contains(file.path) 
                                        ? Colors.red 
                                        : Colors.white54,
                                    size: 24,
                                  ),
                                  splashColor: Colors.red.withOpacity(0.3),
                                  highlightColor: Colors.red.withOpacity(0.2),
                                  onPressed: () => _toggleLikedSong(file),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_filePath == null) {
      return const Center(
        child: Text('Pick an audio or video file using the + button'),
      );
    }
    if (_isVideo) {
      final vc = _mediaService.videoController;
      if (vc == null || !vc.value.isInitialized) {
        return const Center(child: Text('Video not initialized'));
      }
      final currentList = _videoFiles;
      final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
      return VideoPlayerWidget(
        videoController: vc,
        filePath: _filePath,
        onNext: _currentPlayingIndex < playList.length - 1 ? _playNext : null,
        onPrevious: _currentPlayingIndex > 0 ? _playPrevious : null,
        onFullScreenChanged: _onFullScreenChanged,
      );
    } else {
      final currentList = _audioFiles;
      final playList = _isShuffleEnabled ? _shuffledMediaFiles : currentList;
      return AudioPlayerWidget(
        audioPlayer: _mediaService.audioPlayer,
        filePath: _filePath,
        onNext: _currentPlayingIndex < playList.length - 1 ? _playNext : null,
        onPrevious: _currentPlayingIndex > 0 ? _playPrevious : null,
        isShuffleEnabled: _isShuffleEnabled,
        onShuffleToggle: _toggleShuffle,
        repeatMode: _repeatMode,
        onRepeatToggle: _toggleRepeat,
        onAddToPlaylist: _filePath != null ? () => _showAddToPlaylistDialog(_filePath!) : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F1E),
              const Color(0xFF1E1E2E),
              const Color(0xFF2D1B4E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_isVideoFullScreen) _buildAppBar(context),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _showList ? _buildMediaList() : _buildPlayer(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _buildMiniPlayer(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_showList)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
              onPressed: () {
                setState(() => _showList = true);
              },
            )
          else if (_currentView == 'liked' || _currentView == 'playlist_view')
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
              onPressed: () {
                setState(() {
                  if (_currentView == 'playlist_view') {
                    _currentView = 'playlists';
                    _currentPlaylist = null;
                    // No need to set _filteredFiles for playlists view
                  } else {
                    _currentView = 'audio';
                    _filteredFiles = _audioFiles;
                  }
                });
              },
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showList ? 'Home' : 'Now Playing',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          Row(
            children: [
              if (_showList)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                  onPressed: () => _scanForFiles(forceRefresh: true),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFF1E1E1E),
                elevation: 8,
                onSelected: (value) {
                  if (value == 'edit_audio' && !_isVideo && _currentPlayingIndex >= 0) {
                    _showAudioEditDialog();
                  }
                },
                itemBuilder: (context) => [
                  if (!_isVideo && _currentPlayingIndex >= 0)
                    PopupMenuItem(
                      value: 'edit_audio',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 20, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit Audio Info',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 20, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 12),
                        const Text(
                          'Settings',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'about',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 12),
                        const Text(
                          'About',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildMiniPlayer() {
    // Only show mini player when in list view and audio is loaded and playing (not video)
    if (!_showList || _currentPlayingIndex < 0 || _isVideo) {
      return null;
    }

    // Check if audio player has any content loaded
    if (_mediaService.audioPlayer.processingState == ProcessingState.idle) {
      return null;
    }

    // Use audio files for mini player since it only displays when audio is playing
    final playList = _isShuffleEnabled ? _shuffledMediaFiles : _audioFiles;
    
    if (_currentPlayingIndex >= playList.length) {
      return null;
    }

    final currentFile = playList[_currentPlayingIndex];

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showList = false;
          });
        },
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1E2E),
                Color(0xFF2D1B4E),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
            children: [
              // Album art
              Builder(
                builder: (context) {
                  final customImagePath = _metadataService?.getCustomImagePath(currentFile.path);
                  return SizedBox(
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: customImagePath == null ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                        ) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: customImagePath != null
                            ? Image.file(
                                File(customImagePath),
                                fit: BoxFit.cover,
                                width: 50,
                                height: 50,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  );
                }
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _metadataService?.getDisplayName(
                        currentFile.path,
                        currentFile.displayName,
                      ) ?? currentFile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metadataService?.getDescription(currentFile.path) ?? currentFile.formattedSize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Controls
              StreamBuilder<PlayerState>(
                stream: _mediaService.audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous button
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white),
                        iconSize: 28,
                        onPressed: _playPreviousInBackground,
                      ),
                      // Play/Pause button
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          iconSize: 24,
                          onPressed: () {
                            if (isPlaying) {
                              _mediaService.audioPlayer.pause();
                            } else {
                              _mediaService.audioPlayer.play();
                            }
                          },
                        ),
                      ),
                      // Next button
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        iconSize: 28,
                        onPressed: _playNextInBackground,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F0F1E) : Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(Playlist playlist) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playPlaylist(playlist),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Rounded thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.mediaFilePaths.length} track${playlist.mediaFilePaths.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                // More button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                  color: const Color(0xFF1E1E2E),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deletePlaylist(playlist);
                    } else if (value == 'rename') {
                      _showRenamePlaylistDialog(playlist);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.white70),
                          SizedBox(width: 12),
                          Text('Rename', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Color(0xFF8B5CF6)),
              title: const Text('Create New Playlist', style: TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(initialFilePath: filePath);
              },
            ),
            const Divider(color: Colors.white12),
            if (_playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No playlists yet',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final isAlreadyAdded = playlist.mediaFilePaths.contains(filePath);
                    return ListTile(
                      leading: Icon(
                        isAlreadyAdded ? Icons.check_circle : Icons.playlist_play,
                        color: isAlreadyAdded ? Colors.green : const Color(0xFF8B5CF6),
                      ),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${playlist.mediaFilePaths.length} track(s)',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      contentPadding: EdgeInsets.zero,
                      enabled: !isAlreadyAdded,
                      onTap: isAlreadyAdded
                          ? null
                          : () async {
                              await _playlistService.addToPlaylist(playlist.id, filePath);
                              await _loadPlaylists();
                              if (context.mounted) Navigator.pop(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added to "${playlist.name}"'),
                                    backgroundColor: const Color(0xFF8B5CF6),
                                  ),
                                );
                              }
                            },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog({String? initialFilePath}) {
    final nameController = TextEditingController();
    final searchController = TextEditingController();
    final selectedFiles = <String>{};
    String searchQuery = '';
    
    // Add initial file if provided
    if (initialFilePath != null) {
      selectedFiles.add(initialFilePath);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Filter and sort audio files based on search query
          List<MediaFile> filteredFiles = _audioFiles;
          
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            filteredFiles = _audioFiles.where((file) {
              return file.name.toLowerCase().contains(query);
            }).toList();
            
            // Sort by relevance: files starting with query come first
            filteredFiles.sort((a, b) {
              final aLower = a.name.toLowerCase();
              final bLower = b.name.toLowerCase();
              final aStarts = aLower.startsWith(query);
              final bStarts = bLower.startsWith(query);
              
              if (aStarts && !bStarts) return -1;
              if (!aStarts && bStarts) return 1;
              return aLower.compareTo(bLower);
            });
          } else {
            // Show selected files first when no search
            filteredFiles = List<MediaFile>.from(_audioFiles);
            filteredFiles.sort((a, b) {
              final aSelected = selectedFiles.contains(a.path);
              final bSelected = selectedFiles.contains(b.path);
              
              if (aSelected && !bSelected) return -1;
              if (!aSelected && bSelected) return 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select audio files (at least 1 required)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // Search field for songs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search songs...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredFiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No songs found',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          final isSelected = selectedFiles.contains(file.path);
                          return CheckboxListTile(
                            title: Text(
                              file.name,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: isSelected,
                            activeColor: const Color(0xFF8B5CF6),
                            checkColor: Colors.white,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedFiles.add(file.path);
                                } else {
                                  selectedFiles.remove(file.path);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedFiles.length} file(s) selected',
                        style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12),
                      ),
                      if (searchQuery.isNotEmpty)
                        Text(
                          '${filteredFiles.length} result(s)',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: selectedFiles.isEmpty || nameController.text.trim().isEmpty
                    ? null
                    : () async {
                        await _playlistService.createPlaylist(
                          nameController.text.trim(),
                          selectedFiles.toList(),
                        );
                        await _loadPlaylists();
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Playlist "${nameController.text.trim()}" created'),
                              backgroundColor: const Color(0xFF8B5CF6),
                            ),
                          );
                        }
                      },
                child: Text(
                  'Create',
                  style: TextStyle(
                    color: selectedFiles.isEmpty || nameController.text.trim().isEmpty
                        ? Colors.white24
                        : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenamePlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final updated = playlist.copyWith(name: nameController.text.trim());
                await _playlistService.updatePlaylist(updated);
                await _loadPlaylists();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Rename', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _playlistService.deletePlaylist(playlist.id);
      await _loadPlaylists();
    }
  }

  Future<void> _playPlaylist(Playlist playlist) async {
    if (playlist.mediaFilePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This playlist is empty')),
      );
      return;
    }

    // Collect all files from playlist that exist in current media files
    final playlistFiles = <MediaFile>[];
    for (final path in playlist.mediaFilePaths) {
      final fileIndex = _mediaFiles.indexWhere((f) => f.path == path);
      if (fileIndex != -1) {
        playlistFiles.add(_mediaFiles[fileIndex]);
      }
    }

    if (playlistFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No media files found in this playlist')),
      );
      return;
    }

    // Only show audio files in playlists
    final playlistAudio = playlistFiles.where((f) => !f.isVideo).toList();
    
    if (playlistAudio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio files found in this playlist')),
      );
      return;
    }
    
    setState(() {
      _currentPlaylist = playlist;
      _currentView = 'playlist_view';
      _filteredFiles = playlistAudio;
      _currentPlayingIndex = 0;
      
      if (_isShuffleEnabled) {
        _shuffledMediaFiles = List<MediaFile>.from(playlistAudio)..shuffle();
      }
    });

    // Start playing the first audio in background (don't switch to player view)
    final firstFile = playlistAudio[0];
    try {
      setState(() {
        _loading = true;
        _error = null;
        _filePath = firstFile.path;
        _isVideo = false;
      });

      await _mediaService.loadMediaFromFile(firstFile);
      
      if (!mounted) return;
      setState(() => _loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing "${playlist.name}"'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load media: $e';
        _loading = false;
      });
    }
  }
}
