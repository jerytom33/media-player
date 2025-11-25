import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/format_utils.dart';

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? filePath;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool isShuffleEnabled;
  final VoidCallback? onShuffleToggle;
  final LoopMode repeatMode;
  final VoidCallback? onRepeatToggle;
  final VoidCallback? onAddToPlaylist;

  const AudioPlayerWidget({
    super.key,
    required this.audioPlayer,
    required this.filePath,
    this.onNext,
    this.onPrevious,
    this.isShuffleEnabled = false,
    this.onShuffleToggle,
    this.repeatMode = LoopMode.off,
    this.onRepeatToggle,
    this.onAddToPlaylist,
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
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Album art with shadow
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFEC4899),
                            const Color(0xFF8B5CF6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 120,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Add to playlist button
                    if (onAddToPlaylist != null)
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add,
                          color: Color(0xFF8B5CF6),
                          size: 28,
                        ),
                        onPressed: onAddToPlaylist,
                        tooltip: 'Add to Playlist',
                      ),
                    const SizedBox(height: 8),
                    // Song title
                    Text(
                      FormatUtils.getDisplayName(filePath),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Artist name placeholder
                    const Text(
                      'Unknown Artist',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: const Color(0xFF8B5CF6),
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: Colors.white,
                        overlayColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                      ),
                      child: Slider(
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
                    ),
                    // Time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            FormatUtils.formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            FormatUtils.formatDuration(total),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shuffle button
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 28,
                            color: isShuffleEnabled ? const Color(0xFF8B5CF6) : Colors.white38,
                          ),
                          onPressed: onShuffleToggle,
                        ),
                        const SizedBox(width: 8),
                        // Previous button
                        IconButton(
                          icon: Icon(
                            Icons.skip_previous_rounded,
                            size: 36,
                            color: onPrevious != null ? Colors.white : Colors.white24,
                          ),
                          onPressed: onPrevious,
                        ),
                        const SizedBox(width: 16),
                        // Play/Pause button
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF8B5CF6),
                                Color(0xFFEC4899),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              audioPlayer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 34,
                            ),
                            color: Colors.white,
                            onPressed: () async {
                              if (audioPlayer.playing) {
                                await audioPlayer.pause();
                              } else {
                                unawaited(audioPlayer.play());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Next button
                        IconButton(
                          icon: Icon(
                            Icons.skip_next_rounded,
                            size: 36,
                            color: onNext != null ? Colors.white : Colors.white24,
                          ),
                          onPressed: onNext,
                        ),
                        const SizedBox(width: 8),
                        // Repeat button
                        IconButton(
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.repeat_rounded,
                                size: 28,
                                color: repeatMode != LoopMode.off 
                                    ? const Color(0xFF8B5CF6) 
                                    : Colors.white38,
                              ),
                              if (repeatMode == LoopMode.one)
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      '1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: onRepeatToggle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
