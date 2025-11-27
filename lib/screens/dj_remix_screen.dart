import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../platform/dj_toolbar_bridge.dart' as djBridge;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dj_controls_screen.dart';
import '../widgets/audio_waveform_widget.dart';
import '../services/dj_service.dart';

class DJRemixScreen extends StatefulWidget {
  const DJRemixScreen({super.key});

  @override
  State<DJRemixScreen> createState() => _DJRemixScreenState();
}

// Compact circular platter widget to match referenced UI
class _DeckPlatter extends StatelessWidget {
  final String label;
  final String fileName;
  final double bpm;
  final bool isPlaying;
  final VoidCallback onPick;
  final VoidCallback onPlayPause;
  final VoidCallback onCue;
  final ValueChanged<int> onLoopSelected;

  const _DeckPlatter({
    required this.label,
    required this.fileName,
    required this.bpm,
    required this.isPlaying,
    required this.onPick,
    required this.onPlayPause,
    required this.onCue,
    required this.onLoopSelected,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label == 'A'
        ? 'Track 1'
        : label == 'B'
        ? 'Track 2'
        : 'Deck $label';
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final platterSize = (size.shortestSide * 0.7).clamp(150.0, 340.0);
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF111215),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayLabel, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              SizedBox(
                height: platterSize,
                width: platterSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF2A2A40), Color(0xFF111215)],
                        ),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    // inner ring
                    Container(
                      height: platterSize * 0.65,
                      width: platterSize * 0.65,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E1E2E),
                      ),
                      child: Center(
                        child: Text(
                          '${bpm.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.folder_open,
                              color: Colors.white70,
                            ),
                            onPressed: onPick,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onPlayPause,
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: Colors.white,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.flag, color: Colors.white70),
                            onPressed: onCue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _miniLoop(context, 1),
                  _miniLoop(context, 2),
                  _miniLoop(context, 4),
                  _miniLoop(context, 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniLoop(BuildContext context, int beats) => SizedBox(
    width: 44,
    height: 32,
    child: OutlinedButton(
      onPressed: () => onLoopSelected(beats),
      child: Text('$beats', style: const TextStyle(color: Colors.white70)),
    ),
  );
}

class _DJRemixScreenState extends State<DJRemixScreen> {
  final DJService _dj = DJService();
  bool _isRecording = false;
  double _crossfader = 0.5;
  double _deckAVol = 1.0;
  double _deckBVol = 1.0;
  int _effectMode = 0; // 0: off, 1: bass, 2: virtualizer
  bool _toolbarRegistered = false;

  @override
  void initState() {
    super.initState();
    // Lock this particular screen to landscape only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Register for toolbar messages in web development builds and auto-register controls
    if (kIsWeb && !kReleaseMode) {
      try {
        djBridge.addToolbarMessageListener(_onToolbarMessage);
      } catch (_) {}

      // Delay auto registration so the toolbar script has time to load in the page
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          if (!_toolbarRegistered) {
            _autoRegisterControls();
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _dj.dispose();
    // Restore default orientations (allow portrait and landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _pickForDeckA() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null) return;
    final p = result.files.single.path!;
    await _dj.loadDeckA(p);
    setState(() {});
  }

  Future<void> _pickForDeckB() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null) return;
    final p = result.files.single.path!;
    await _dj.loadDeckB(p);
    setState(() {});
  }

  Future<void> _toggleRecord() async {
    setState(() => _isRecording = !_isRecording);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRecording ? 'Recording started' : 'Recording stopped',
          ),
        ),
      );
  }

  void _onToolbarMessage(Map<String, dynamic> data) {
    try {
      final action = data['action']?.toString();
      if (action == null) return;
      switch (action) {
        case 'play-track1':
          _dj.playDeckA();
          break;
        case 'play-track2':
          _dj.playDeckB();
          break;
        case 'pause-track1':
          _dj.pauseDeckA();
          break;
        case 'pause-track2':
          _dj.pauseDeckB();
          break;
        case 'toggle-record':
          _toggleRecord();
          break;
        case 'set-bpm':
          final d = data['value'];
          if (d != null) {
            final v = double.tryParse(d.toString());
            if (v != null) {
              // set both for simplicity unless a specific track is provided
              _dj.setDeckABPM(v);
              _dj.setDeckBBPM(v);
            }
          }
          break;
        case 'set-crossfader':
          final d = data['value'];
          if (d != null) {
            final v = double.tryParse(d.toString());
            if (v != null)
              setState(() {
                _crossfader = v;
                _dj.setCrossfader(v);
              });
          }
          break;
        default:
          break;
      }
    } catch (e) {
      // ignore
    }
  }

  /// Auto-register the DJ controls (for web dev). Called by initState.
  void _autoRegisterControls() {
    if (!kIsWeb || kReleaseMode || _toolbarRegistered) return;
    final payload = {
      'controls': [
        {'id': 'track1-platter', 'label': 'Track 1 Platter', 'type': 'platter'},
        {'id': 'track2-platter', 'label': 'Track 2 Platter', 'type': 'platter'},
        {
          'id': 'bpm',
          'label': 'BPM',
          'type': 'bpm',
          'valueA': _dj.deckABPM,
          'valueB': _dj.deckBBPM,
        },
        {
          'id': 'crossfader',
          'label': 'Crossfader',
          'type': 'slider',
          'value': _crossfader,
        },
        {
          'id': 'track1-fader',
          'label': 'Track 1 Volume',
          'type': 'slider',
          'value': _deckAVol,
        },
        {
          'id': 'track2-fader',
          'label': 'Track 2 Volume',
          'type': 'slider',
          'value': _deckBVol,
        },
        {'id': 'export', 'label': 'Export Mix', 'type': 'action'},
      ],
    };
    try {
      djBridge.registerDJControls(payload);
      djBridge.sendMessageToToolbar({
        'event': 'dj-registered',
        'count': payload['controls']?.length ?? 0,
      });
      setState(() {
        _toolbarRegistered = true;
      });
    } catch (e) {
      // ignore registration error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DJ Remix',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        actions: [
          // 21st.dev toolbar hook (web dev only)
          if (kIsWeb && !kReleaseMode)
            IconButton(
              icon: const Icon(Icons.developer_board),
              tooltip: 'Register DJ Mixer with 21st.dev toolbar for editing',
              onPressed: () {
                final payload = {
                  'controls': [
                    {
                      'id': 'track1-platter',
                      'label': 'Track 1 Platter',
                      'type': 'platter',
                    },
                    {
                      'id': 'track2-platter',
                      'label': 'Track 2 Platter',
                      'type': 'platter',
                    },
                    {
                      'id': 'bpm',
                      'label': 'BPM',
                      'type': 'bpm',
                      'valueA': _dj.deckABPM,
                      'valueB': _dj.deckBBPM,
                    },
                    {
                      'id': 'crossfader',
                      'label': 'Crossfader',
                      'type': 'slider',
                      'value': _crossfader,
                    },
                    {
                      'id': 'track1-fader',
                      'label': 'Track 1 Volume',
                      'type': 'slider',
                      'value': _deckAVol,
                    },
                    {
                      'id': 'track2-fader',
                      'label': 'Track 2 Volume',
                      'type': 'slider',
                      'value': _deckBVol,
                    },
                    {'id': 'export', 'label': 'Export Mix', 'type': 'action'},
                  ],
                };
                try {
                  djBridge.registerDJControls(payload);
                  djBridge.sendMessageToToolbar({
                    'event': 'dj-registered',
                    'count': payload['controls']?.length ?? 0,
                  });
                  _toolbarRegistered = true;
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '21st.dev integration: DJ controls registered',
                        ),
                      ),
                    );
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('21st.dev integration failed: $e'),
                      ),
                    );
                }
              },
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // we force landscape so expect width > height, but still adapt
            final isWide =
                constraints.maxWidth >= 900 ||
                constraints.maxWidth > constraints.maxHeight;

            // Horizontal view shows decks side-by-side as two "platters"
            Widget decksSideBySide = Row(
              children: [
                Expanded(child: _buildDeckA()),
                const SizedBox(width: 12),
                Container(width: 64, child: _buildVerticalCrossfader()),
                const SizedBox(width: 12),
                Expanded(child: _buildDeckB()),
              ],
            );

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top: single small waveform (full width) then decks
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AudioWaveformWidget(
                              audioPlayer: _dj.deckA,
                              height: 48,
                              barCount: ((constraints.maxWidth / 4).clamp(
                                8.0,
                                64.0,
                              )).toInt(),
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // For this simplified flow, if no tracks are loaded, show a selection screen
                    StreamBuilder<DeckState>(
                      stream: _dj.deckAState,
                      builder: (context, aSnap) => StreamBuilder<DeckState>(
                        stream: _dj.deckBState,
                        builder: (context, bSnap) {
                          final a = aSnap.data ?? DeckState(player: _dj.deckA);
                          final b = bSnap.data ?? DeckState(player: _dj.deckB);
                          final aLoaded = a.filePath != null;
                          final bLoaded = b.filePath != null;
                          if (!aLoaded || !bLoaded) {
                            return _buildSelectionScreen(
                              a.filePath,
                              b.filePath,
                            );
                          }
                          return SizedBox(
                            height: math.min(constraints.maxHeight * 0.64, 380),
                            child: isWide ? decksSideBySide : decksSideBySide,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<DeckState>(
                      stream: _dj.deckAState,
                      builder: (context, aSnapshot) => StreamBuilder<DeckState>(
                        stream: _dj.deckBState,
                        builder: (context, bSnapshot) {
                          final aState =
                              aSnapshot.data ?? DeckState(player: _dj.deckA);
                          final bState =
                              bSnapshot.data ?? DeckState(player: _dj.deckB);
                          return _buildMixerControls(isWide, aState, bState);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeckA() {
    return StreamBuilder<DeckState>(
      stream: _dj.deckAState,
      initialData: DeckState(
        player: _dj.deckA,
        filePath: null,
        isPlaying: false,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final fileName = state.filePath != null
            ? state.filePath!.split(Platform.pathSeparator).last
            : 'No File';
        return _DeckPlatter(
          label: 'A',
          fileName: fileName,
          bpm: state.bpm,
          isPlaying: state.isPlaying,
          onPick: _pickForDeckA,
          onPlayPause: () async {
            if (state.isPlaying)
              await _dj.pauseDeckA();
            else
              await _dj.playDeckA();
          },
          onCue: () async => await _dj.deckA.seek(Duration.zero),
          onLoopSelected: (beats) async {
            final enabled = !(state.loopEnabled && state.loopBeats == beats);
            await _dj.enableLoopDeckA(
              enabled: enabled,
              beats: beats,
              bpm: state.bpm,
            );
          },
        );
      },
    );
  }

  Widget _buildDeckB() {
    return StreamBuilder<DeckState>(
      stream: _dj.deckBState,
      initialData: DeckState(
        player: _dj.deckB,
        filePath: null,
        isPlaying: false,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final fileName = state.filePath != null
            ? state.filePath!.split(Platform.pathSeparator).last
            : 'No File';
        return _DeckPlatter(
          label: 'B',
          fileName: fileName,
          bpm: state.bpm,
          isPlaying: state.isPlaying,
          onPick: _pickForDeckB,
          onPlayPause: () async {
            if (state.isPlaying)
              await _dj.pauseDeckB();
            else
              await _dj.playDeckB();
          },
          onCue: () async => await _dj.deckB.seek(Duration.zero),
          onLoopSelected: (beats) async {
            final enabled = !(state.loopEnabled && state.loopBeats == beats);
            await _dj.enableLoopDeckB(
              enabled: enabled,
              beats: beats,
              bpm: state.bpm,
            );
          },
        );
      },
    );
  }

  Widget _buildMixerControls(bool isWide, DeckState aState, DeckState bState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Volume Sliders
        Row(
          children: [
            const Expanded(
              child: Text(
                'Track 1 Vol',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Slider(
                value: _deckAVol,
                min: 0,
                max: 1,
                onChanged: (v) {
                  setState(() {
                    _deckAVol = v;
                    _dj.setDeckAVolume(v);
                  });
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Track 2 Vol',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Slider(
                value: _deckBVol,
                min: 0,
                max: 1,
                onChanged: (v) {
                  setState(() {
                    _deckBVol = v;
                    _dj.setDeckBVolume(v);
                  });
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Crossfader', style: TextStyle(color: Colors.white70)),
            Expanded(
              child: Slider(
                value: _crossfader,
                min: 0,
                max: 1,
                onChanged: (v) {
                  setState(() {
                    _crossfader = v;
                    _dj.setCrossfader(v);
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Single BPM Button
        Center(
          child: ElevatedButton(
            onPressed: () async {
              final aController = TextEditingController(
                text: aState.bpm.toStringAsFixed(0),
              );
              final bController = TextEditingController(
                text: bState.bpm.toStringAsFixed(0),
              );
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E2E),
                  title: const Text(
                    'Set BPM',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: aController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Track 1 BPM',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextField(
                        controller: bController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Track 2 BPM',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Set'),
                    ),
                  ],
                ),
              );
              if (result == true) {
                final aBpm = double.tryParse(aController.text) ?? aState.bpm;
                final bBpm = double.tryParse(bController.text) ?? bState.bpm;
                _dj.setDeckABPM(aBpm);
                _dj.setDeckBBPM(bBpm);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  aState.bpm.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Loop Controls
        const Text(
          'Loops',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text(
                    'Track 1',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [1, 2, 4, 8]
                        .map(
                          (beats) => SizedBox(
                            width: 40,
                            child: ElevatedButton(
                              onPressed: () async {
                                final enabled =
                                    !(aState.loopEnabled &&
                                        aState.loopBeats == beats);
                                await _dj.enableLoopDeckA(
                                  enabled: enabled,
                                  beats: beats,
                                  bpm: aState.bpm,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    aState.loopEnabled &&
                                        aState.loopBeats == beats
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.grey,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                              ),
                              child: Text(
                                '$beats',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    'Track 2',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [1, 2, 4, 8]
                        .map(
                          (beats) => SizedBox(
                            width: 40,
                            child: ElevatedButton(
                              onPressed: () async {
                                final enabled =
                                    !(bState.loopEnabled &&
                                        bState.loopBeats == beats);
                                await _dj.enableLoopDeckB(
                                  enabled: enabled,
                                  beats: beats,
                                  bpm: bState.bpm,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    bState.loopEnabled &&
                                        bState.loopBeats == beats
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.grey,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                              ),
                              child: Text(
                                '$beats',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Other Controls
        Center(
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _primaryControl(
                icon: Icons.sync_alt,
                label: 'SYNC',
                subtitle: 'Auto tempo',
                onPressed: () async {
                  await _dj.syncDecks(syncToA: true);
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Synced decks (B -> A)')),
                    );
                },
              ),
              _primaryControl(
                icon: Icons.tune,
                label: 'FX',
                subtitle: 'Echo, Reverb',
                onPressed: () {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FX placeholder')),
                    );
                },
              ),
              _primaryControl(
                icon: Icons.fiber_manual_record,
                label: _isRecording ? 'Stop' : 'RECORD',
                subtitle: 'Save mix',
                onPressed: () async {
                  await _toggleRecord();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Merged effects icon toggle: cycles Off -> Bass -> Virtualizer
            IconButton(
              onPressed: () {
                setState(() {
                  _effectMode = (_effectMode + 1) % 3;
                });
                final msg = _effectMode == 0
                    ? 'Effects off'
                    : _effectMode == 1
                    ? 'Bass on'
                    : 'Virtualizer on';
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
              },
              icon: Icon(
                _effectMode == 0
                    ? Icons.music_off
                    : _effectMode == 1
                    ? Icons.multitrack_audio
                    : Icons.surround_sound,
                color: _effectMode == 0 ? Colors.white38 : Colors.white,
              ),
              tooltip: _effectMode == 0
                  ? 'Effects Off'
                  : _effectMode == 1
                  ? 'Bass'
                  : 'Virtualizer',
              style: IconButton.styleFrom(
                backgroundColor: _effectMode == 0
                    ? Colors.grey
                    : _effectMode == 1
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 16),
            // Export Mix Icon Button
            IconButton(
              onPressed: () async {
                await _dj.exportMix();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export started')),
                  );
              },
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'Export Mix',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // The first screen: choose two audio files
  Widget _buildSelectionScreen(String? aPath, String? bPath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _selectionCard('Track 1', aPath, _pickForDeckA)),
            const SizedBox(width: 12),
            Expanded(child: _selectionCard('Track 2', bPath, _pickForDeckB)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: (aPath != null && bPath != null)
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DJControlsScreen(dj: _dj),
                        ),
                      );
                    }
                  : null,
              child: const Text('Open Mixer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectionCard(
    String title,
    String? filePath,
    Future<void> Function() onPick,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filePath ?? 'No file chosen',
            style: const TextStyle(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add),
            label: const Text('Add Track'),
          ),
        ],
      ),
    );
  }

  Widget _primaryControl({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildVerticalCrossfader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.headset, color: Colors.white54, size: 16),
        const SizedBox(height: 6),
        SizedBox(
          height: 220,
          child: RotatedBox(
            quarterTurns: -1,
            child: Slider(
              value: _crossfader,
              min: 0,
              max: 1,
              onChanged: (v) {
                setState(() {
                  _crossfader = v;
                  _dj.setCrossfader(v);
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Icon(Icons.headset, color: Colors.white54, size: 16),
      ],
    );
  }
}
