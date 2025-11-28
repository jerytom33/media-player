import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/dj_mixer_service.dart';

class DJMixerScreen extends StatefulWidget {
  const DJMixerScreen({super.key});

  @override
  State<DJMixerScreen> createState() => _DJMixerScreenState();
}

class _DJMixerScreenState extends State<DJMixerScreen> {
  final DJMixerService _djService = DJMixerService();
  double _crossfader = 0.5;

  @override
  void initState() {
    super.initState();
    _initializeMixer();
  }

  Future<void> _initializeMixer() async {
    try {
      await _djService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize mixer: $e')),
        );
      }
    }
  }

  Future<void> _pickAudioForDeck(bool isDeckA) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      if (isDeckA) {
        await _djService.loadDeckA(filePath);
      } else {
        await _djService.loadDeckB(filePath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${isDeckA ? "Deck A" : "Deck B"}'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
  }

  @override
  void dispose() {
    // Note: Don't dispose the singleton service here
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text(
          'DJ Mixer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Dual deck display
              Row(
                children: [
                  Expanded(child: _buildDeck(isDeckA: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDeck(isDeckA: false)),
                ],
              ),
              const SizedBox(height: 24),

              // Crossfader
              _buildCrossfader(),

              const SizedBox(height: 24),

              // Control buttons
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeck({required bool isDeckA}) {
    final stream = isDeckA ? _djService.deckAState : _djService.deckBState;
    final deckLabel = isDeckA ? 'DECK A' : 'DECK B';
    final color = isDeckA ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4);

    return StreamBuilder<DeckState>(
      stream: stream,
      initialData: const DeckState(),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final fileName = state.filePath != null
            ? state.filePath!.split(Platform.pathSeparator).last
            : 'No File';

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state.isPlaying ? color : Colors.white12,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Deck label
              Text(
                deckLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Virtual platter
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withOpacity(0.3), const Color(0xFF0F0F1E)],
                  ),
                  border: Border.all(color: color, width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.bpm.toInt()} BPM',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // File name
              Text(
                fileName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Position
              Text(
                _formatDuration(state.position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Control buttons
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _pickAudioForDeck(isDeckA),
                      icon: const Icon(Icons.folder_open),
                      color: Colors.white70,
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (state.isPlaying) {
                          if (isDeckA) {
                            await _djService.pauseDeckA();
                          } else {
                            await _djService.pauseDeckB();
                          }
                        } else {
                          if (state.isPaused) {
                            if (isDeckA) {
                              await _djService.resumeDeckA();
                            } else {
                              await _djService.resumeDeckB();
                            }
                          } else {
                            if (isDeckA) {
                              await _djService.playDeckA();
                            } else {
                              await _djService.playDeckB();
                            }
                          }
                        }
                      },
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      color: color,
                      iconSize: 28,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (isDeckA) {
                          await _djService.stopDeckA();
                        } else {
                          await _djService.stopDeckB();
                        }
                      },
                      icon: const Icon(Icons.stop),
                      color: Colors.white70,
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // BPM adjustment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          final newBpm = (state.bpm - 1).clamp(60.0, 200.0);
                          if (isDeckA) {
                            _djService.setDeckABPM(newBpm);
                          } else {
                            _djService.setDeckBBPM(newBpm);
                          }
                        },
                        icon: const Icon(Icons.remove),
                        color: Colors.white54,
                        iconSize: 14,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      Flexible(
                        child: Text(
                          'BPM',
                          style: TextStyle(
                            color: color.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final newBpm = (state.bpm + 1).clamp(60.0, 200.0);
                          if (isDeckA) {
                            _djService.setDeckABPM(newBpm);
                          } else {
                            _djService.setDeckBBPM(newBpm);
                          }
                        },
                        icon: const Icon(Icons.add),
                        color: Colors.white54,
                        iconSize: 14,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCrossfader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DECK A',
                style: TextStyle(
                  color: const Color(0xFF8B5CF6).withOpacity(1.0 - _crossfader),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'CROSSFADER',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'DECK B',
                style: TextStyle(
                  color: const Color(0xFF06B6D4).withOpacity(_crossfader),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: const Color(0xFF06B6D4),
              inactiveTrackColor: const Color(0xFF8B5CF6),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: _crossfader,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _crossfader = value;
                });
                _djService.setCrossfader(value);
              },
            ),
          ),
          Text(
            '${(_crossfader * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SYNC & EFFECTS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Sync Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactSyncButton(
                label: 'SYNC B→A',
                color: const Color(0xFF8B5CF6),
                onPressed: () async {
                  await _djService.syncDeckBToA();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synced Deck B to Deck A'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              _buildCompactSyncButton(
                label: 'SYNC A→B',
                color: const Color(0xFF06B6D4),
                onPressed: () async {
                  await _djService.syncDeckAToB();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synced Deck A to Deck B'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Effects Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEffectButton('E', 'Echo'),
                const SizedBox(width: 8),
                _buildEffectButton('R', 'Reverb'),
                const SizedBox(width: 8),
                _buildEffectButton('C', 'Chorus'),
                const SizedBox(width: 8),
                _buildEffectButton('F', 'Flanger'),
                const SizedBox(width: 8),
                _buildEffectButton('Fi', 'Filter'),
                const SizedBox(width: 8),
                _buildEffectButton('S', 'Spin'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSyncButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Track active effects
  final Set<String> _activeEffects = {};

  Widget _buildEffectButton(String label, String tooltip) {
    final isActive = _activeEffects.contains(tooltip);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isActive) {
              _activeEffects.remove(tooltip);
            } else {
              _activeEffects.add(tooltip);
            }
          });

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$tooltip ${isActive ? "disabled" : "enabled"}'),
              duration: const Duration(milliseconds: 500),
              backgroundColor: isActive ? Colors.grey : const Color(0xFF8B5CF6),
            ),
          );
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF8B5CF6) : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF8B5CF6) : Colors.white24,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
