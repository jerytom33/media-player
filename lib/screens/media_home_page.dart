import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/media_service.dart';
import '../models/media_file.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/video_player_widget.dart';

class MediaHomePage extends StatefulWidget {
  const MediaHomePage({super.key});

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  late final MediaService _mediaService;
  String? _filePath;
  bool _isVideo = false;
  bool _loading = false;
  String? _error;
  List<MediaFile> _mediaFiles = [];
  List<MediaFile> _filteredFiles = [];
  bool _isScanning = false;
  bool _showList = true;
  int _currentPlayingIndex = -1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService(AudioPlayer());
    _scanForFiles();
    _searchController.addListener(_filterFiles);
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
      setState(() {
        _mediaFiles = files;
        _filteredFiles = files;
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
      if (query.isEmpty) {
        _filteredFiles = _mediaFiles;
      } else {
        _filteredFiles = _mediaFiles
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
      // Find the index in the main media files list
      final index = _mediaFiles.indexWhere((f) => f.path == file.path);
      
      setState(() {
        _loading = true;
        _error = null;
        _showList = false;
        _filePath = file.path;
        _isVideo = file.isVideo;
        _currentPlayingIndex = index;
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
    if (_currentPlayingIndex >= 0 && _currentPlayingIndex < _mediaFiles.length - 1) {
      _playMediaFile(_mediaFiles[_currentPlayingIndex + 1]);
    }
  }

  void _playPrevious() {
    if (_currentPlayingIndex > 0) {
      _playMediaFile(_mediaFiles[_currentPlayingIndex - 1]);
    }
  }

  @override
  void dispose() {
    _mediaService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildMediaList() {
    if (_isScanning) {
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
                    const Color(0xFF8B5CF6).withOpacity(0.3),
                    const Color(0xFFEC4899).withOpacity(0.3),
                  ],
                ),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanning for media files...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '🔍 Search media files...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFFEC4899)),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            backgroundColor: const Color(0xFF1E1E2E),
            onRefresh: () => _scanForFiles(forceRefresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filteredFiles.length,
              itemBuilder: (context, index) {
                final file = _filteredFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E1E2E),
                        const Color(0xFF2D1B4E).withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: file.isVideo 
                              ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                              : [const Color(0xFFEC4899), const Color(0xFFF472B6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (file.isVideo ? const Color(0xFF8B5CF6) : const Color(0xFFEC4899)).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        file.isVideo ? Icons.video_library : Icons.music_note,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      file.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${file.extension.toUpperCase()} • ${file.formattedSize}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                    onTap: () => _playMediaFile(file),
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
      return VideoPlayerWidget(
        videoController: vc,
        filePath: _filePath,
        onNext: _currentPlayingIndex < _mediaFiles.length - 1 ? _playNext : null,
        onPrevious: _currentPlayingIndex > 0 ? _playPrevious : null,
      );
    } else {
      return AudioPlayerWidget(
        audioPlayer: _mediaService.audioPlayer,
        filePath: _filePath,
        onNext: _currentPlayingIndex < _mediaFiles.length - 1 ? _playNext : null,
        onPrevious: _currentPlayingIndex > 0 ? _playPrevious : null,
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
              _buildAppBar(context),
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.8),
            const Color(0xFF6D28D9).withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!_showList)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                setState(() => _showList = true);
              },
            ),
          Expanded(
            child: Text(
              _showList ? '🎵 Media Library' : '▶️ Now Playing',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: _showList ? TextAlign.center : TextAlign.left,
            ),
          ),
          if (_showList)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
              onPressed: () => _scanForFiles(forceRefresh: true),
              tooltip: 'Refresh',
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: _pickFile,
            tooltip: 'Pick File',
          ),
        ],
      ),
    );
  }
}
