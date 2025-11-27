import 'package:just_audio/just_audio.dart';

class DeckState {
  final AudioPlayer player;
  final String? filePath;
  final bool isPlaying;
  final double bpm;
  final bool loopEnabled;
  final int loopBeats;

  DeckState({
    required this.player,
    this.filePath,
    this.isPlaying = false,
    this.bpm = 120.0,
    this.loopEnabled = false,
    this.loopBeats = 4,
  });
}
