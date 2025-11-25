import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../utils/format_utils.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerController videoController;
  final String? filePath;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final Function(bool)? onFullScreenChanged;

  const VideoPlayerWidget({
    super.key,
    required this.videoController,
    required this.filePath,
    this.onNext,
    this.onPrevious,
    this.onFullScreenChanged,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  bool _isFullScreen = false;
  bool _showControls = true;
  double _volume = 1.0;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.videoController.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _setVolume(double volume) {
    setState(() => _volume = volume);
    widget.videoController.setVolume(volume);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showControls = true;
    });
    _startHideControlsTimer();

    // Notify parent about fullscreen state change
    widget.onFullScreenChanged?.call(_isFullScreen);

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
    _hideControlsTimer?.cancel();
    // Always restore to portrait mode and normal system UI when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _toggleFullScreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _toggleControlsVisibility,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: widget.videoController.value.aspectRatio,
                    child: VideoPlayer(widget.videoController),
                  ),
                ),
                // Fullscreen controls overlay
                if (_showControls) ...[
                  // Top gradient overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            FormatUtils.getDisplayName(widget.filePath),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                          onPressed: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ),
                  ),
                  // Bottom controls overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: widget.videoController,
                        builder: (context, value, child) {
                          final position = value.position;
                          final total = value.duration;
                          final pct = total.inMilliseconds == 0
                              ? 0.0
                              : position.inMilliseconds / total.inMilliseconds;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
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
                                          await widget.videoController.seekTo(seekTo);
                                        },
                                  onChangeStart: (_) => _hideControlsTimer?.cancel(),
                                  onChangeEnd: (_) => _startHideControlsTimer(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Controls row
                              Row(
                                children: [
                                  // Play/Pause button
                                  IconButton(
                                    icon: Icon(
                                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      if (value.isPlaying) {
                                        widget.videoController.pause();
                                      } else {
                                        widget.videoController.play();
                                        _startHideControlsTimer();
                                      }
                                    },
                                  ),
                                  // Previous button
                                  IconButton(
                                    icon: Icon(
                                      Icons.skip_previous,
                                      color: widget.onPrevious != null ? Colors.white : Colors.white.withOpacity(0.3),
                                      size: 28,
                                    ),
                                    onPressed: widget.onPrevious,
                                  ),
                                  // Next button
                                  IconButton(
                                    icon: Icon(
                                      Icons.skip_next,
                                      color: widget.onNext != null ? Colors.white : Colors.white.withOpacity(0.3),
                                      size: 28,
                                    ),
                                    onPressed: widget.onNext,
                                  ),
                                  // Time display
                                  const SizedBox(width: 8),
                                  Text(
                                    '${FormatUtils.formatDuration(position)} / ${FormatUtils.formatDuration(total)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  // Volume control
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          _setVolume(_volume == 0 ? 1.0 : 0.0);
                                        },
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 3,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                                            thumbColor: Colors.white,
                                          ),
                                          child: Slider(
                                            value: _volume,
                                            onChanged: _setVolume,
                                            onChangeStart: (_) => _hideControlsTimer?.cancel(),
                                            onChangeEnd: (_) => _startHideControlsTimer(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.videoController,
      builder: (context, value, child) {
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
              const SizedBox(height: 12),
              // File name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
              const SizedBox(height: 6),
              // Subtitle placeholder
              const Text(
                'Video',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white38,
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
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
                          await widget.videoController.seekTo(seekTo);
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
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    Text(
                      FormatUtils.formatDuration(total),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      size: 36,
                      color: widget.onPrevious != null ? Colors.white : Colors.white24,
                    ),
                    onPressed: widget.onPrevious,
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
                        value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 34,
                      ),
                      color: Colors.white,
                      onPressed: () {
                        value.isPlaying ? widget.videoController.pause() : widget.videoController.play();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Next button
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: 36,
                      color: widget.onNext != null ? Colors.white : Colors.white24,
                    ),
                    onPressed: widget.onNext,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
