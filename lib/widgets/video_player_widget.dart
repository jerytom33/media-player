import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../utils/format_utils.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerController videoController;
  final String? filePath;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const VideoPlayerWidget({
    super.key,
    required this.videoController,
    required this.filePath,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  bool _isFullScreen = false;

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.videoController.value.aspectRatio,
                child: VideoPlayer(widget.videoController),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32),
                onPressed: _toggleFullScreen,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(context),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.videoController,
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
              // Video player without borders or padding
              GestureDetector(
                onTap: () {}, // Prevent accidental taps
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: Stack(
                    children: [
                      VideoPlayer(widget.videoController),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                          ),
                          onPressed: _toggleFullScreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // File name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  FormatUtils.getDisplayName(widget.filePath),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              _buildControls(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.videoController,
      builder: (context, value, child) {
        final position = value.position;
        final total = value.duration;
        final pct = total.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / total.inMilliseconds;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1E2E),
                const Color(0xFF2D1B4E).withOpacity(0.8),
              ],
            ),
            borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(20),
            border: _isFullScreen ? null : Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: _isFullScreen ? [] : [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
                      // Control buttons
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
                          const SizedBox(width: 16),
                          // Play/Pause button
                          Container(
                            width: 60,
                            height: 60,
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
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                              color: Colors.white,
                              onPressed: () {
                                value.isPlaying ? videoController.pause() : videoController.play();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stop button
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFEC4899),
                                  Color(0xFFF472B6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEC4899).withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.stop, size: 30),
                              color: Colors.white,
                              onPressed: () async {
                                await videoController.pause();
                                await videoController.seekTo(Duration.zero);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
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
                      const SizedBox(height: 24),
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
                          activeTrackColor: const Color(0xFF8B5CF6),
                          inactiveTrackColor: const Color(0xFF4B5563),
                          thumbColor: Colors.white,
                          overlayColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                        child: Slider(
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
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              FormatUtils.formatDuration(total),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
  }
}
