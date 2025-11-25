import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/media_constants.dart';
import '../models/media_file.dart';

class MediaService {
  final AudioPlayer audioPlayer;
  VideoPlayerController? videoController;
  List<MediaFile>? _cachedMediaFiles;
  DateTime? _lastScanTime;

  MediaService(this.audioPlayer);

  VideoViewType get _videoViewType => !kIsWeb && Platform.isAndroid
      ? VideoViewType.platformView
      : VideoViewType.textureView;

  Future<Map<String, dynamic>?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...MediaConstants.audioExtensions,
        ...MediaConstants.videoExtensions
      ],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    final path = picked.path;
    final identifier = picked.identifier;
    String? effectivePath = path;
    Uri? contentUri;

    if ((identifier ?? '').startsWith('content://')) {
      contentUri = Uri.parse(identifier!);
    }

    String nameForExt = picked.name;
    if (effectivePath != null && effectivePath.contains('.')) {
      nameForExt = effectivePath.split(Platform.pathSeparator).last;
    }
    final ext = nameForExt.contains('.')
        ? nameForExt.split('.').last.toLowerCase()
        : '';
    final isVideo = MediaConstants.videoExtensions.contains(ext);

    if (effectivePath == null && contentUri == null) {
      throw kIsWeb
          ? 'Web picking provides bytes, which this minimal app does not yet stream.'
          : 'Picked file has no accessible path or URI';
    }

    return {
      'path': effectivePath,
      'contentUri': contentUri,
      'isVideo': isVideo,
    };
  }

  Future<void> loadMedia({
    String? path,
    Uri? contentUri,
    required bool isVideo,
  }) async {
    final previousController = videoController;
    videoController = null;
    await previousController?.dispose();
    await audioPlayer.stop();

    if (isVideo) {
      late final VideoPlayerController controller;
      if (contentUri != null) {
        controller = VideoPlayerController.contentUri(
          contentUri,
          viewType: _videoViewType,
        );
      } else if (path != null) {
        controller = VideoPlayerController.file(
          File(path),
          viewType: _videoViewType,
        );
      } else {
        throw 'No valid video source provided';
      }
      videoController = controller;
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
    } else {
      if (contentUri != null) {
        await audioPlayer.setAudioSource(AudioSource.uri(contentUri));
      } else if (path != null) {
        await audioPlayer.setFilePath(path);
      } else {
        throw 'No valid audio source provided';
      }
      unawaited(audioPlayer.play());
    }
  }

  /// Returns Android audio session id if available (null otherwise).
  int? getAudioSessionId() {
    try {
      return audioPlayer.androidAudioSessionId;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    audioPlayer.dispose();
    videoController?.dispose();
  }

  // Storage scanning functionality
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted) return true;
      
      final androidVersion = int.tryParse(Platform.version.split('.').first) ?? 0;
      
      // Android 13+ (API 33+) uses different permissions
      if (androidVersion >= 33) {
        final audioStatus = await Permission.audio.request();
        final videoStatus = await Permission.videos.request();
        return audioStatus.isGranted && videoStatus.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require storage permissions for app directories
      return true;
    }
    
    return false;
  }

  Future<List<MediaFile>> scanForMediaFiles({bool forceRefresh = false}) async {
    if (kIsWeb) return [];
    
    // Return cached files if available and not forcing refresh
    if (!forceRefresh && _cachedMediaFiles != null && _cachedMediaFiles!.isNotEmpty) {
      return _cachedMediaFiles!;
    }
    
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied');
    }

    final mediaFiles = <MediaFile>[];
    final scannedPaths = <String>{};

    // Get common directories to scan
    final directories = await _getDirectoriesToScan();

    for (final directory in directories) {
      if (!await directory.exists()) continue;

      try {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final path = entity.path;
            
            // Skip if already scanned
            if (scannedPaths.contains(path)) continue;
            scannedPaths.add(path);

            final extension = path.split('.').last.toLowerCase();
            
            if (MediaConstants.audioExtensions.contains(extension)) {
              try {
                mediaFiles.add(MediaFile.fromFile(entity, false));
              } catch (e) {
                // Skip files that can't be read
                debugPrint('Error reading file $path: $e');
              }
            } else if (MediaConstants.videoExtensions.contains(extension)) {
              try {
                mediaFiles.add(MediaFile.fromFile(entity, true));
              } catch (e) {
                debugPrint('Error reading file $path: $e');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning directory ${directory.path}: $e');
      }
    }

    // Sort by name
    mediaFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    // Cache the results
    _cachedMediaFiles = mediaFiles;
    _lastScanTime = DateTime.now();
    
    return mediaFiles;
  }

  Future<List<Directory>> _getDirectoriesToScan() async {
    final directories = <Directory>[];

    try {
      if (Platform.isAndroid) {
        // Android: scan common media directories
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          directories.add(externalDir);
        }

        // Try to access common Android media directories
        final commonPaths = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Documents',
        ];

        for (final path in commonPaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            directories.add(dir);
          }
        }
      } else if (Platform.isIOS) {
        // iOS: scan app directories
        final appDir = await getApplicationDocumentsDirectory();
        directories.add(appDir);
        
        try {
          final downloadDir = await getDownloadsDirectory();
          if (downloadDir != null) {
            directories.add(downloadDir);
          }
        } catch (e) {
          debugPrint('Could not access downloads directory: $e');
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: scan common user directories
        final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (homeDir != null) {
          final musicDir = Directory('$homeDir${Platform.pathSeparator}Music');
          final videosDir = Directory('$homeDir${Platform.pathSeparator}Videos');
          final downloadsDir = Directory('$homeDir${Platform.pathSeparator}Downloads');
          final documentsDir = Directory('$homeDir${Platform.pathSeparator}Documents');

          if (await musicDir.exists()) directories.add(musicDir);
          if (await videosDir.exists()) directories.add(videosDir);
          if (await downloadsDir.exists()) directories.add(downloadsDir);
          if (await documentsDir.exists()) directories.add(documentsDir);
        }
      }
    } catch (e) {
      debugPrint('Error getting directories to scan: $e');
    }

    return directories;
  }

  Future<void> loadMediaFromFile(MediaFile mediaFile) async {
    await loadMedia(
      path: mediaFile.path,
      contentUri: null,
      isVideo: mediaFile.isVideo,
    );
  }

  bool hasCachedFiles() {
    return _cachedMediaFiles != null && _cachedMediaFiles!.isNotEmpty;
  }

  DateTime? getLastScanTime() {
    return _lastScanTime;
  }

  void clearCache() {
    _cachedMediaFiles = null;
    _lastScanTime = null;
  }

  List<MediaFile>? getCachedFiles() {
    return _cachedMediaFiles;
  }
}
