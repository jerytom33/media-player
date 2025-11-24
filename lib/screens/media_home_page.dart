import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/media_service.dart';
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

  @override
  void initState() {
    super.initState();
    _mediaService = MediaService(AudioPlayer());
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

  @override
  void dispose() {
    _mediaService.dispose();
    super.dispose();
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
      );
    } else {
      return AudioPlayerWidget(
        audioPlayer: _mediaService.audioPlayer,
        filePath: _filePath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Media Player')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPlayer(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        child: const Icon(Icons.add),
      ),
    );
  }
}
