import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'equalizer_service.dart';

class AudioProcessingService {
  static const List<double> _freqs5 = [60, 230, 910, 3600, 14000];
  static const List<double> _freqs10 = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  static final AudioProcessingService _instance = AudioProcessingService._();
  AudioProcessingService._();
  factory AudioProcessingService.getInstance() => _instance;

  Future<String> applyEqualizerToFile(String inputPath, EqualizerSettings settings) async {
    // Create a unique temp output path
    final tmpDir = await getTemporaryDirectory();
    final base = p.basenameWithoutExtension(inputPath);
    // build an output path that would be used when processing is enabled
    final outPath = p.join(tmpDir.path, '${base}_eq_${DateTime.now().millisecondsSinceEpoch}.wav');

    final freqList = settings.bandCount == 5 ? _freqs5 : _freqs10;
    final filters = <String>[];

    // Build per-band equalizers
    for (var i = 0; i < settings.bands.length && i < freqList.length; i++) {
      final gain = settings.bands[i];
      if (gain == 0.0) continue;
      final freq = freqList[i];
      // Use Q factor of 1.0 for gentle band widths
      filters.add('equalizer=f=${freq.toStringAsFixed(0)}:width_type=q:width=1:g=${gain.toStringAsFixed(2)}');
    }

    // Bass boost - add only if nonzero
    if (settings.bassBoost > 0) {
      final bassGain = (settings.bassBoost * 10).clamp(0.0, 10.0);
      filters.add('bass=g=${bassGain.toStringAsFixed(2)}');
    }

    // Virtualizer approximation using a subtle echo / stereo widening
    if (settings.virtualizer > 0) {
      // aecho parameters: in_gain:out_gain:delays:decays
      final strength = (settings.virtualizer * 0.8).clamp(0.0, 0.8);
      // We chain a light echo (mono) to both channels with short delays
      final delays = '60|120';
      final decays = '${(0.2 * strength).toStringAsFixed(3)}|${(0.15 * strength).toStringAsFixed(3)}';
      filters.add('aecho=0.8:0.9:${delays}:${decays}');
    }

    final filterGraph = filters.join(',');

    // If there are no filters and the equalizer is disabled or empty, return the original path early;
    // we don't alter originals and no processing is required.
    if (filterGraph.isEmpty) {
      return inputPath;
    }
    // FFmpeg filter arg placeholder when processing is enabled
    final ffmpegFilterArg = ' -af "$filterGraph" ';
    // Avoid analyzer unused variable warnings - log values so maintainers know what the intended values would be
    debugPrint('Equalizer processing requested. Out path: $outPath; Filter: $ffmpegFilterArg');

    // FFmpeg SDK was removed from pubspec, so this runtime will just return input path to preserve original
    // and indicate processing is not available in this build environment.
    // To enable processing, add ffmpeg_kit_flutter_min to pubspec.yaml and implement ffmpeg execution.
    return inputPath; // no actual processing performed in this build
  }
}
