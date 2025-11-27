import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioWaveformWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color color;
  final Color? accentColor;
  final double height;
  final int barCount;

  const AudioWaveformWidget({
    super.key,
    required this.audioPlayer,
    this.color = const Color(0xFF8B5CF6),
    this.accentColor,
    this.height = 80,
    this.barCount = 40,
  });

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _barHeights = [];
  final Random _random = Random();
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();

    // Initialize bar heights
    final initialCount = widget.barCount > 0 ? widget.barCount : 1;
    for (int i = 0; i < initialCount; i++) {
      _barHeights.add(_random.nextDouble() * 0.5 + 0.2);
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animationController.addListener(() {
      if (!mounted) return;
      setState(() {
        // Update random bars for animation effect
        final available = _barHeights.length;
        if (available <= 0) return;
        final barToUpdate = _random.nextInt(available);
        _barHeights[barToUpdate] = _random.nextDouble() * 0.8 + 0.2;
      });
    });

    // Listen to player state and keep a subscription so we can cancel it
    _playerStateSub = widget.audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      try {
        if (state.playing) {
          if (!_animationController.isAnimating) {
            _animationController.repeat();
          }
        } else {
          if (_animationController.isAnimating) {
            _animationController.stop();
          }
          // Reset to minimal heights when paused
          setState(() {
            for (int i = 0; i < _barHeights.length; i++) {
              _barHeights[i] = 0.2;
            }
          });
        }
      } catch (_) {
        // If controller has been disposed, ignore any errors here.
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AudioWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ensure our internal buffer matches the requested bar count
    final newCount = widget.barCount > 0 ? widget.barCount : 1;
    if (newCount > _barHeights.length) {
      final toAdd = newCount - _barHeights.length;
      for (int i = 0; i < toAdd; i++) {
        _barHeights.add(_random.nextDouble() * 0.5 + 0.2);
      }
    } else if (newCount < _barHeights.length) {
      _barHeights.removeRange(newCount, _barHeights.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;

        return Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barHeights.length, (index) {
              final barHeight = isPlaying
                  ? _barHeights[index] * widget.height
                  : widget.height * 0.2;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                width: 2,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.color,
                      widget.accentColor ?? widget.color.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: isPlaying
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
