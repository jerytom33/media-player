import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/format_utils.dart';

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? filePath;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const AudioPlayerWidget({
    super.key,
    required this.audioPlayer,
    required this.filePath,
    this.onNext,
    this.onPrevious,
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
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E2E),
                    const Color(0xFF2D1B4E).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Album art placeholder
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFEC4899),
                          const Color(0xFF8B5CF6),
                          const Color(0xFF6D28D9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // File name
                  Text(
                    FormatUtils.getDisplayName(filePath),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Progress slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: const Color(0xFFEC4899),
                      inactiveTrackColor: const Color(0xFF4B5563),
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFFEC4899).withOpacity(0.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          FormatUtils.formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          FormatUtils.formatDuration(total),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Play/Pause button with Previous and Next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6B7280).withOpacity(onPrevious != null ? 1.0 : 0.3),
                              const Color(0xFF4B5563).withOpacity(onPrevious != null ? 1.0 : 0.3),
                            ],
                          ),
                          boxShadow: onPrevious != null ? [
                            BoxShadow(
                              color: const Color(0xFF6B7280).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ] : [],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.skip_previous, size: 28),
                          color: Colors.white,
                          onPressed: onPrevious,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Play/Pause button
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFF6D28D9),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                            size: 36,
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
                      const SizedBox(width: 20),
                      // Next button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6B7280).withOpacity(onNext != null ? 1.0 : 0.3),
                              const Color(0xFF4B5563).withOpacity(onNext != null ? 1.0 : 0.3),
                            ],
                          ),
                          boxShadow: onNext != null ? [
                            BoxShadow(
                              color: const Color(0xFF6B7280).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ] : [],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.skip_next, size: 28),
                          color: Colors.white,
                          onPressed: onNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
