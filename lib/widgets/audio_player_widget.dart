import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/format_utils.dart';

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? filePath;

  const AudioPlayerWidget({
    super.key,
    required this.audioPlayer,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: audioPlayer.durationStream,
      builder: (context, durationSnap) {
        final total = durationSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: audioPlayer.positionStream,
          builder: (context, positionSnap) {
            final position = positionSnap.data ?? Duration.zero;
            final pct = total.inMilliseconds == 0
                ? 0.0
                : position.inMilliseconds / total.inMilliseconds;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (audioPlayer.playing) {
                      await audioPlayer.pause();
                    } else {
                      unawaited(audioPlayer.play());
                    }
                  },
                ),
                Slider(
                  value: pct.clamp(0.0, 1.0),
                  onChanged: total.inMilliseconds == 0
                      ? null
                      : (v) async {
                          final seekTo = Duration(
                            milliseconds: (total.inMilliseconds * v).round(),
                          );
                          await audioPlayer.seek(seekTo);
                        },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(FormatUtils.formatDuration(position)),
                      Text(FormatUtils.formatDuration(total)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  FormatUtils.getDisplayName(filePath),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
