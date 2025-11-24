import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../constants/media_constants.dart';

class MediaService {
  final AudioPlayer audioPlayer;
  VideoPlayerController? videoController;

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

  void dispose() {
    audioPlayer.dispose();
    videoController?.dispose();
  }
}
