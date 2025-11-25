import 'dart:io';
import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';
import '../services/audio_processing_service.dart';

class EqualizerScreen extends StatefulWidget {
  final String? filePath;
  const EqualizerScreen({super.key, this.filePath});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  late EqualizerService _service;
  late EqualizerSettings _settings;
  bool _loading = true;

  static const List<String> _freqLabels5 = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  static const List<String> _freqLabels10 = ['31Hz','62Hz','125Hz','250Hz','500Hz','1kHz','2kHz','4kHz','8kHz','16kHz'];

  @override
  void initState() {
    super.initState();
    EqualizerService.getInstance().then((s) {
      _service = s;
      setState(() {
        _settings = _service.getSettings();
        _loading = false;
      });
    });
  }

  void _setBand(int index, double value) {
    final bands = List<double>.from(_settings.bands);
    bands[index] = value;
    setState(() {
      _settings = EqualizerSettings(
        bandCount: _settings.bandCount,
        bands: bands,
        bassBoost: _settings.bassBoost,
        virtualizer: _settings.virtualizer,
        enabled: _settings.enabled,
      );
    });
  }

  void _save() async {
    await _service.setSettings(_settings);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _apply() async {
    if (widget.filePath == null || widget.filePath!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No file to apply equalizer to.')));
      return;
    }
    final f = File(widget.filePath!);
    if (!f.existsSync()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected file no longer exists on disk.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final out = await AudioProcessingService.getInstance().applyEqualizerToFile(widget.filePath!, _settings);
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to process file: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final labels = _settings.bandCount == 5 ? _freqLabels5 : _freqLabels10;
    final bandCount = _settings.bandCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        backgroundColor: const Color(0xFF1E1E2E),
        actions: [
          if (!_loading)
            TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))))
          else
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))) ,
          const SizedBox(width: 8),
          // Apply button
          if (!_loading)
            TextButton(onPressed: _apply, child: const Text('Apply', style: TextStyle(color: Color(0xFF8B5CF6))))
          else
            const SizedBox.shrink(),
        ],
      ),
      backgroundColor: const Color(0xFF12121A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Enabled', style: TextStyle(color: Colors.white)),
                const Spacer(),
                Switch(
                  value: _settings.enabled,
                  onChanged: (v) => setState(() => _settings = EqualizerSettings(
                    bandCount: _settings.bandCount,
                    bands: _settings.bands,
                    bassBoost: _settings.bassBoost,
                    virtualizer: _settings.virtualizer,
                    enabled: v,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.filePath != null) ...[
              Text('Processing will create a temporary file and won\'t change the original', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
            ] else ...[
              Text('No file selected. Use Equalizer from the player screen to apply changes to the currently playing file.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Text('Bands', style: TextStyle(color: Colors.white)),
                const Spacer(),
                ToggleButtons(
                  isSelected: [ _settings.bandCount == 5, _settings.bandCount == 10 ],
                  onPressed: (i) {
                    final newCount = i == 0 ? 5 : 10;
                    final newBands = List<double>.filled(newCount, 0.0);
                    for (var j = 0; j < newCount && j < _settings.bands.length; j++) {
                      newBands[j] = _settings.bands[j];
                    }
                    setState(() {
                      _settings = EqualizerSettings(
                        bandCount: newCount,
                        bands: newBands,
                        bassBoost: _settings.bassBoost,
                        virtualizer: _settings.virtualizer,
                        enabled: _settings.enabled,
                      );
                    });
                  },
                  children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('5')), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('10'))],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: bandCount,
                itemBuilder: (context, index) {
                  final label = index < labels.length ? labels[index] : 'Band ${index+1}';
                  final value = index < _settings.bands.length ? _settings.bands[index] : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label, style: const TextStyle(color: Colors.white)),
                            const Spacer(),
                            Text('${value.toStringAsFixed(1)} dB', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        Slider(
                          value: value,
                          min: -12.0,
                          max: 12.0,
                          divisions: 48,
                          label: '${value.toStringAsFixed(1)} dB',
                          onChanged: (v) => _setBand(index, v),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text('Bass Boost', style: TextStyle(color: Colors.white)),
            Slider(
              value: _settings.bassBoost,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${(_settings.bassBoost * 100).round()}%',
              onChanged: (v) => setState(() => _settings = EqualizerSettings(
                bandCount: _settings.bandCount,
                bands: _settings.bands,
                bassBoost: v,
                virtualizer: _settings.virtualizer,
                enabled: _settings.enabled,
              )),
            ),
            const SizedBox(height: 8),
            const Text('Virtualizer', style: TextStyle(color: Colors.white)),
            Slider(
              value: _settings.virtualizer,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${(_settings.virtualizer * 100).round()}%',
              onChanged: (v) => setState(() => _settings = EqualizerSettings(
                bandCount: _settings.bandCount,
                bands: _settings.bands,
                bassBoost: _settings.bassBoost,
                virtualizer: v,
                enabled: _settings.enabled,
              )),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
