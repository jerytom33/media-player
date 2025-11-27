import 'package:flutter/material.dart';
import '../services/dj_service.dart' as service;
import '../widgets/audio_waveform_widget.dart';
import '../models/deck_state.dart' as model;

class DJControlsScreen extends StatefulWidget {
  final service.DJService dj;
  const DJControlsScreen({super.key, required this.dj});

  @override
  State<DJControlsScreen> createState() => _DJControlsScreenState();
}

class _DJControlsScreenState extends State<DJControlsScreen>
    with SingleTickerProviderStateMixin {
  double _deckAVol = 1.0;
  double _deckBVol = 1.0;
  double _crossfader = 0.5;
  late final AnimationController _spinControllerA;
  late final AnimationController _spinControllerB;

  @override
  void initState() {
    super.initState();
    _deckAVol = widget.dj.deckAVol;
    _deckBVol = widget.dj.deckBVol;
    _crossfader = widget.dj.crossfader;
    _spinControllerA = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _spinControllerB = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void dispose() {
    _spinControllerA.dispose();
    _spinControllerB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dj = widget.dj;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF091024),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'DJ Mixer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                try {
                  await widget.dj.exportMix();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export started')),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export failed')),
                    );
                }
              },
              icon: const Icon(Icons.download),
            ),
            IconButton(
              onPressed: () async {
                await widget.dj.pauseDeckA();
                await widget.dj.pauseDeckB();
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Paused all')));
              },
              icon: const Icon(Icons.pause_circle),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0F0F1E), const Color(0xFF1E1E2E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Main mixer area: platters and vertical faders
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final platterSize = (constraints.maxWidth / 3).clamp(
                        140.0,
                        260.0,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Deck A with vertical fader
                          SizedBox(
                            width: platterSize + 64,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: SizedBox(
                                      width: 160,
                                      child: Slider(
                                        value: _deckAVol,
                                        min: 0,
                                        max: 1,
                                        onChanged: (v) {
                                          setState(() {
                                            _deckAVol = v;
                                            widget.dj.setDeckAVolume(v);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _buildDeckControlA(dj, platterSize),
                                ),
                              ],
                            ),
                          ),
                          // Crossfader vertical in center
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RotatedBox(
                                quarterTurns: -1,
                                child: SizedBox(
                                  width: 200,
                                  child: Slider(
                                    value: _crossfader,
                                    min: 0,
                                    max: 1,
                                    onChanged: (v) {
                                      setState(() {
                                        _crossfader = v;
                                        widget.dj.setCrossfader(v);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Deck B with vertical fader
                          SizedBox(
                            width: platterSize + 64,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildDeckControlB(dj, platterSize),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: SizedBox(
                                      width: 160,
                                      child: Slider(
                                        value: _deckBVol,
                                        min: 0,
                                        max: 1,
                                        onChanged: (v) {
                                          setState(() {
                                            _deckBVol = v;
                                            widget.dj.setDeckBVolume(v);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 18),
                  // Removed duplicate crossfader widget here
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // No additional code needed here. All widget methods are already defined.
  Widget _buildDeckControlA(service.DJService dj, double size) {
    return StreamBuilder<model.DeckState>(
      stream: dj.deckAState as Stream<model.DeckState>?,
      initialData: model.DeckState(
        player: dj.deckA,
        filePath: dj.deckAFilePath,
        isPlaying: false,
      ),
      builder: (context, snapshot) {
        final s = snapshot.data!;
        // manage spinner speed & animation
        final bpm = s.bpm > 0 ? s.bpm : 120.0;
        final period = (60.0 / bpm).clamp(0.25, 6.0);
        if (s.isPlaying) {
          if (!_spinControllerA.isAnimating) {
            _spinControllerA.duration = Duration(
              milliseconds: (period * 1000).round(),
            );
            _spinControllerA.repeat();
          }
        } else {
          if (_spinControllerA.isAnimating) {
            _spinControllerA.stop();
          }
        }
        return _deckControlA(s, dj, size);
      },
    );
  }

  Widget _buildDeckControlB(service.DJService dj, double size) {
    return StreamBuilder<model.DeckState>(
      stream: dj.deckBState as Stream<model.DeckState>?,
      initialData: model.DeckState(
        player: dj.deckB,
        filePath: dj.deckBFilePath,
        isPlaying: false,
      ),
      builder: (context, snapshot) {
        final s = snapshot.data!;
        final bpm = s.bpm > 0 ? s.bpm : 120.0;
        final period = (60.0 / bpm).clamp(0.25, 6.0);
        if (s.isPlaying) {
          if (!_spinControllerB.isAnimating) {
            _spinControllerB.duration = Duration(
              milliseconds: (period * 1000).round(),
            );
            _spinControllerB.repeat();
          }
        } else {
          if (_spinControllerB.isAnimating) {
            _spinControllerB.stop();
          }
        }
        return _deckControlB(s, dj, size);
      },
    );
  }

  Widget _deckControlA(model.DeckState s, service.DJService dj, double size) {
    return _deckControl(
      s,
      dj,
      controller: _spinControllerA,
      deckIndex: 0,
      platterSize: size,
    );
  }

  Widget _deckControlB(model.DeckState s, service.DJService dj, double size) {
    return _deckControl(
      s,
      dj,
      controller: _spinControllerB,
      deckIndex: 1,
      platterSize: size,
    );
  }

  Widget _deckControl(
    model.DeckState state,
    service.DJService dj, {
    required AnimationController controller,
    required int deckIndex,
    required double platterSize,
  }) {
    // deckIndex: 0 = A, 1 = B
    final isPlaying = state.isPlaying;
    final fileName = state.filePath ?? 'No file';
    final bpm = state.bpm;
    final loopEnabled = state.loopEnabled;
    final loopBeats = state.loopBeats;
    final displayLabel = deckIndex == 0 ? 'Track 1' : 'Track 2';
    final audioPlayer = deckIndex == 0 ? dj.deckA : dj.deckB;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(displayLabel, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(
            fileName,
            style: const TextStyle(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // show animated platter + waveform
          Column(
            children: [
              RotationTransition(
                turns: controller,
                child: Container(
                  width: platterSize,
                  height: platterSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F0F14),
                    border: Border.all(
                      color: isPlaying
                          ? const Color(0xFF8B5CF6)
                          : Colors.white12,
                      width: isPlaying ? 3 : 1,
                    ),
                    boxShadow: isPlaying
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.08),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${bpm.toStringAsFixed(0)} BPM',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: AudioWaveformWidget(
                  audioPlayer: audioPlayer,
                  barCount: 48,
                  height: 36,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (isPlaying) {
                    if (deckIndex == 0) {
                      await dj.pauseDeckA();
                    } else {
                      await dj.pauseDeckB();
                    }
                  } else {
                    if (deckIndex == 0) {
                      await dj.playDeckA();
                    } else {
                      await dj.playDeckB();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.flag, color: Colors.white70),
                onPressed: () async {
                  if (deckIndex == 0) {
                    await dj.deckA.seek(Duration.zero);
                  } else {
                    await dj.deckB.seek(Duration.zero);
                  }
                },
              ),
              const SizedBox(width: 6),
              PopupMenuButton<int>(
                tooltip: 'Loop',
                onSelected: (beats) async {
                  if (deckIndex == 0) {
                    await dj.enableLoopDeckA(
                      enabled: !(loopEnabled && loopBeats == beats),
                      beats: beats,
                      bpm: bpm,
                    );
                  } else {
                    await dj.enableLoopDeckB(
                      enabled: !(loopEnabled && loopBeats == beats),
                      beats: beats,
                      bpm: bpm,
                    );
                  }
                },
                itemBuilder: (context) => [1, 2, 4, 8].map((b) {
                  final suffix = b > 1 ? 's' : '';
                  return PopupMenuItem(value: b, child: Text('$b beat$suffix'));
                }).toList(),
                icon: Icon(
                  loopEnabled ? Icons.loop : Icons.loop_outlined,
                  color: loopEnabled ? Colors.greenAccent : Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white38),
                tooltip: 'Edit BPM',
                onPressed: () async {
                  final controller = TextEditingController(
                    text: bpm.toStringAsFixed(0),
                  );
                  final res = await showDialog<double?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E2E),
                      title: const Text(
                        'Set BPM',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            double.tryParse(controller.text),
                          ),
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                  );
                  if (res != null) {
                    if (deckIndex == 0) {
                      dj.setDeckABPM(res);
                    } else {
                      dj.setDeckBBPM(res);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Vertical faders are implemented inline next to the platters.
}
