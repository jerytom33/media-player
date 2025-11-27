import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_waveform_widget.dart';

class DJDeckWidget extends StatefulWidget {
  final AudioPlayer player;
  final String label; // 'A' or 'B'
  final VoidCallback onLoad;
  final VoidCallback onPlayPause;
  final VoidCallback onCue;
  final ValueChanged<int>? onLoopSelected; // beats: 1/2/4/8
  final bool loopEnabled;
  final int loopBeats;
  final Stream<Duration> positionStream; // optional
  final bool isPlaying;
  final String? filePath;
  final double bpm;
  final ValueChanged<double>? onBpmChanged;

  const DJDeckWidget({
    super.key,
    required this.player,
    required this.label,
    required this.onLoad,
    required this.onPlayPause,
    required this.onCue,
    required this.positionStream,
    this.isPlaying = false,
    this.filePath,
    this.bpm = 120,
    this.onBpmChanged,
    this.onLoopSelected,
    this.loopEnabled = false,
    this.loopBeats = 4,
  });

  @override
  State<DJDeckWidget> createState() => _DJDeckWidgetState();
}

class _DJDeckWidgetState extends State<DJDeckWidget> {
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _posSub = widget.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath != null ? widget.filePath!.split(Platform.pathSeparator).last : 'No File';
    final displayLabel = widget.label == 'A' ? 'Track 1' : widget.label == 'B' ? 'Track 2' : 'Deck ${widget.label}';
    return LayoutBuilder(builder: (context, constraints) {
      // Make the UI adapt to the available vertical space.
      final isCompact = constraints.maxHeight < 140;
      final waveformHeight = (constraints.maxHeight * 0.35).clamp(18.0, 64.0);
      final barCount = (constraints.maxWidth / 6).clamp(8.0, 64.0).toInt();
      final contentPadding = isCompact ? 6.0 : 8.0;
      final textSizeSmall = isCompact ? 10.0 : 12.0;
      final iconSize = isCompact ? 18.0 : 24.0;

      return Container(
        padding: EdgeInsets.all(contentPadding),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(displayLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: textSizeSmall + 2)),
                const SizedBox(width: 8),
                Flexible(child: Text(fileName, style: TextStyle(color: Colors.white70, fontSize: textSizeSmall), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: waveformHeight),
            child: SizedBox(height: waveformHeight, child: AudioWaveformWidget(audioPlayer: widget.player, barCount: barCount, height: waveformHeight, color: const Color(0xFF8B5CF6))),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: Icon(Icons.folder_open, color: Colors.white70, size: iconSize), onPressed: widget.onLoad),
                  IconButton(
                    icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: iconSize),
                    onPressed: widget.onPlayPause,
                  ),
                  IconButton(icon: Icon(Icons.flag, color: Colors.white70, size: iconSize), onPressed: widget.onCue),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isCompact ? 64 : 80),
                      child: Text('${widget.bpm.toStringAsFixed(0)} BPM', style: TextStyle(color: Colors.white70, fontSize: textSizeSmall), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white38, size: iconSize - 6),
                      onPressed: () async {
                        final controller = TextEditingController(text: widget.bpm.toStringAsFixed(0));
                        final value = await showDialog<double?>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E2E),
                            title: const Text('Set BPM', style: TextStyle(color: Colors.white)),
                            content: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text)), child: const Text('Set')),
                            ],
                          ),
                        );
                        if (value != null && widget.onBpmChanged != null) {
                          widget.onBpmChanged!(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(_formatDuration(_position), style: TextStyle(color: Colors.white54, fontSize: textSizeSmall))),
                const SizedBox(width: 8),
                Flexible(child: _buildLoopButtons(compact: isCompact)),
              ],
            ),
        ],
      ),
      );
    });
  }

  Widget _buildLoopButtons({bool compact = false}) {
    // Use Wrap for compact layout so buttons wrap to the next line if needed.
    final spacing = compact ? 4.0 : 6.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: spacing,
        children: [
          _loopButton('1', 1),
          _loopButton('2', 2),
          _loopButton('4', 4),
          _loopButton('8', 8),
        ],
      ),
    );
  }

  Widget _loopButton(String label, int beats) {
    final selected = widget.loopEnabled && widget.loopBeats == beats;
    return GestureDetector(
      onTap: () => widget.onLoopSelected?.call(beats),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF8B5CF6) : Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
