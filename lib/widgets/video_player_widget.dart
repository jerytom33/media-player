import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/format_utils.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoPlayerController videoController;
  final String? filePath;

  const VideoPlayerWidget({
    super.key,
    required this.videoController,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: videoController,
      builder: (context, value, child) {
        final position = value.position;
        final total = value.duration;
        final pct = total.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / total.inMilliseconds;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(videoController),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      value.isPlaying ? videoController.pause() : videoController.play();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () async {
                      await videoController.pause();
                      await videoController.seekTo(Duration.zero);
                    },
                  ),
                ],
              ),
              Slider(
                value: pct.clamp(0.0, 1.0),
                onChanged: total.inMilliseconds == 0
                    ? null
                    : (v) async {
                        final seekTo = Duration(
                          milliseconds: (total.inMilliseconds * v).round(),
                        );
                        await videoController.seekTo(seekTo);
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      FormatUtils.formatDuration(position),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      FormatUtils.formatDuration(total),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FormatUtils.getDisplayName(filePath),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
