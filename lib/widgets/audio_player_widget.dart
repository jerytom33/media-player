import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/format_utils.dart';

class AudioPlayerWidget extends StatefulWidget {
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
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  double _playbackSpeed = 1.0;

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    widget.audioPlayer.setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.audioPlayer.durationStream,
      builder: (context, durationSnap) {
        final total = durationSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.audioPlayer.positionStream,
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
                    if (widget.onAddToPlaylist != null)
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add,
                          color: Color(0xFF8B5CF6),
                          size: 28,
                        ),
                        onPressed: widget.onAddToPlaylist,
                        tooltip: 'Add to Playlist',
                      ),
                    const SizedBox(height: 8),
                    // Song title
                    Text(
                      FormatUtils.getDisplayName(widget.filePath),
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
                                await widget.audioPlayer.seek(seekTo);
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle & Repeat combined button
                          PopupMenuButton<String>(
                            icon: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (widget.isShuffleEnabled || widget.repeatMode != LoopMode.off)
                                    ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: (widget.isShuffleEnabled || widget.repeatMode != LoopMode.off)
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    widget.isShuffleEnabled ? Icons.shuffle_rounded : Icons.repeat_rounded,
                                    size: 20,
                                    color: (widget.isShuffleEnabled || widget.repeatMode != LoopMode.off)
                                        ? const Color(0xFF8B5CF6)
                                        : Colors.white54,
                                  ),
                                  if (!widget.isShuffleEnabled && widget.repeatMode == LoopMode.one)
                                    Positioned(
                                      bottom: 9,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '1',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'shuffle') {
                                widget.onShuffleToggle?.call();
                              } else if (value == 'repeat') {
                                widget.onRepeatToggle?.call();
                              }
                            },
                            offset: const Offset(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: const Color(0xFF1E1E1E),
                            elevation: 8,
                            constraints: const BoxConstraints(
                              minWidth: 170,
                              maxWidth: 220,
                            ),
                            itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'shuffle',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    color: widget.isShuffleEnabled ? const Color(0xFF8B5CF6) : Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.isShuffleEnabled ? 'Shuffle: ON' : 'Shuffle: OFF',
                                    style: TextStyle(
                                      color: widget.isShuffleEnabled ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: widget.isShuffleEnabled ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'repeat',
                              child: Row(
                                children: [
                                  Icon(
                                    widget.repeatMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                    color: widget.repeatMode != LoopMode.off ? const Color(0xFF8B5CF6) : Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.repeatMode == LoopMode.off
                                        ? 'Repeat: OFF'
                                        : widget.repeatMode == LoopMode.one
                                            ? 'Repeat: One'
                                            : 'Repeat: All',
                                    style: TextStyle(
                                      color: widget.repeatMode != LoopMode.off ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: widget.repeatMode != LoopMode.off ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Previous button
                        IconButton(
                          iconSize: 32,
                          icon: Icon(
                            Icons.skip_previous_rounded,
                            color: widget.onPrevious != null ? Colors.white : Colors.white24,
                          ),
                          onPressed: widget.onPrevious,
                        ),
                        // Play/Pause button
                        Container(
                          width: 56,
                          height: 56,
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
                              widget.audioPlayer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 30,
                            ),
                            color: Colors.white,
                            onPressed: () async {
                              if (widget.audioPlayer.playing) {
                                await widget.audioPlayer.pause();
                              } else {
                                unawaited(widget.audioPlayer.play());
                              }
                            },
                          ),
                        ),
                        // Next button
                        IconButton(
                          iconSize: 32,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: widget.onNext != null ? Colors.white : Colors.white24,
                          ),
                          onPressed: widget.onNext,
                        ),
                        // Speed control button with timer icon
                        PopupMenuButton<double>(
                          icon: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _playbackSpeed != 1.0
                                  ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: _playbackSpeed != 1.0 ? const Color(0xFF8B5CF6) : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: _playbackSpeed != 1.0 ? const Color(0xFF8B5CF6) : Colors.white54,
                            ),
                          ),
                          onSelected: _setPlaybackSpeed,
                          offset: const Offset(-50, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: const Color(0xFF1E1E1E),
                          elevation: 8,
                          constraints: const BoxConstraints(
                            minWidth: 140,
                            maxWidth: 180,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 0.5,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 0.5 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '0.5x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 0.5 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 0.5 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 0.75,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 0.75 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '0.75x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 0.75 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 0.75 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 1.0,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: _playbackSpeed == 1.0 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '1x (Normal)',
                                    style: TextStyle(
                                      color: _playbackSpeed == 1.0 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 1.0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 1.25,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 1.25 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '1.25x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 1.25 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 1.25 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 1.5,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 1.5 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '1.5x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 1.5 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 1.5 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 1.75,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 1.75 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '1.75x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 1.75 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 1.75 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 2.0,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _playbackSpeed == 2.0 ? const Color(0xFF8B5CF6) : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '2x',
                                    style: TextStyle(
                                      color: _playbackSpeed == 2.0 ? const Color(0xFF8B5CF6) : Colors.white,
                                      fontWeight: _playbackSpeed == 2.0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ],
                      ),
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
