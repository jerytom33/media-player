import 'package:just_audio/just_audio.dart';

/// Audio mixer engine using just_audio for dual deck DJ mixing
class AudioMixerEngine {
  static final AudioMixerEngine _instance = AudioMixerEngine._internal();
  factory AudioMixerEngine() => _instance;

  // Separate audio players for each deck
  late AudioPlayer _deckAPlayer;
  late AudioPlayer _deckBPlayer;

  bool _initialized = false;

  // Crossfader value (0.0 = full deck A, 1.0 = full deck B)
  double _crossfaderValue = 0.5;

  AudioMixerEngine._internal();

  /// Initialize the audio players
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _deckAPlayer = AudioPlayer();
      _deckBPlayer = AudioPlayer();
      _initialized = true;
      _updateCrossfaderVolumes();
      print('AudioMixerEngine initialized successfully with just_audio');
    } catch (e) {
      print('Failed to initialize AudioMixerEngine: $e');
      rethrow;
    }
  }

  /// Load audio file for Deck A
  Future<void> loadDeckA(String filePath) async {
    if (!_initialized) await initialize();

    try {
      await _deckAPlayer.setFilePath(filePath);
      print('Deck A loaded: $filePath');
    } catch (e) {
      print('Failed to load Deck A: $e');
      rethrow;
    }
  }

  /// Load audio file for Deck B
  Future<void> loadDeckB(String filePath) async {
    if (!_initialized) await initialize();

    try {
      await _deckBPlayer.setFilePath(filePath);
      print('Deck B loaded: $filePath');
    } catch (e) {
      print('Failed to load Deck B: $e');
      rethrow;
    }
  }

  /// Play Deck A
  Future<void> playDeckA() async {
    try {
      await _deckAPlayer.play();
      print('Deck A playing');
    } catch (e) {
      print('Failed to play Deck A: $e');
    }
  }

  /// Play Deck B
  Future<void> playDeckB() async {
    try {
      await _deckBPlayer.play();
      print('Deck B playing');
    } catch (e) {
      print('Failed to play Deck B: $e');
    }
  }

  /// Pause Deck A
  Future<void> pauseDeckA() async {
    try {
      await _deckAPlayer.pause();
    } catch (e) {
      print('Failed to pause Deck A: $e');
    }
  }

  /// Pause Deck B
  Future<void> pauseDeckB() async {
    try {
      await _deckBPlayer.pause();
    } catch (e) {
      print('Failed to pause Deck B: $e');
    }
  }

  /// Resume Deck A
  Future<void> resumeDeckA() async {
    await playDeckA();
  }

  /// Resume Deck B
  Future<void> resumeDeckB() async {
    await playDeckB();
  }

  /// Stop Deck A
  Future<void> stopDeckA() async {
    await _deckAPlayer.stop();
    await _deckAPlayer.seek(Duration.zero);
  }

  /// Stop Deck B
  Future<void> stopDeckB() async {
    await _deckBPlayer.stop();
    await _deckBPlayer.seek(Duration.zero);
  }

  /// Set crossfader position (0.0 = full A, 1.0 = full B)
  void setCrossfader(double value) {
    _crossfaderValue = value.clamp(0.0, 1.0);
    _updateCrossfaderVolumes();
  }

  /// Update volumes based on crossfader position
  void _updateCrossfaderVolumes() {
    final volumeA = (1.0 - _crossfaderValue).clamp(0.0, 1.0);
    final volumeB = _crossfaderValue.clamp(0.0, 1.0);

    _deckAPlayer.setVolume(volumeA);
    _deckBPlayer.setVolume(volumeB);
  }

  // --- Simple per-deck effect state (UI-level virtualization only) ---
  // These are placeholders for effect levels. Real audio DSP is out of
  // scope for this change — these values can be used by a native plugin
  // or a DSP pipeline later.
  final Map<String, double> _deckAEffects = {};
  final Map<String, double> _deckBEffects = {};

  /// Set an effect level for a deck.
  /// `deck` should be either 'A' or 'B'. `effect` is an identifier like
  /// 'echo', 'reverb', etc. `level` is clamped between 0.0 and 1.0.
  void setDeckEffect(String deck, String effect, double level) {
    final clamped = level.clamp(0.0, 1.0);
    if (deck == 'A') {
      _deckAEffects[effect] = clamped;
    } else {
      _deckBEffects[effect] = clamped;
    }
    // NOTE: No DSP applied here. This method stores the level and can be
    // observed by higher-level services to update UI or to forward to a
    // real audio processing pipeline in the future.
    print('setDeckEffect: deck=$deck effect=$effect level=$clamped');
  }

  /// Get current effect level for a deck/effect (0.0 if unset).
  double getDeckEffect(String deck, String effect) {
    if (deck == 'A') return _deckAEffects[effect] ?? 0.0;
    return _deckBEffects[effect] ?? 0.0;
  }

  /// Set playback speed for Deck A (for BPM matching)
  Future<void> setDeckASpeed(double speed) async {
    await _deckAPlayer.setSpeed(speed.clamp(0.5, 2.0));
  }

  /// Set playback speed for Deck B (for BPM matching)
  Future<void> setDeckBSpeed(double speed) async {
    await _deckBPlayer.setSpeed(speed.clamp(0.5, 2.0));
  }

  /// Check if Deck A is playing
  bool isDeckAPlaying() {
    return _deckAPlayer.playing;
  }

  /// Check if Deck B is playing
  bool isDeckBPlaying() {
    return _deckBPlayer.playing;
  }

  /// Get current playback position for Deck A
  Duration getDeckAPosition() {
    return _deckAPlayer.position;
  }

  /// Get current playback position for Deck B
  Duration getDeckBPosition() {
    return _deckBPlayer.position;
  }

  /// Get duration for Deck A
  Duration? getDeckADuration() {
    return _deckAPlayer.duration;
  }

  /// Get duration for Deck B
  Duration? getDeckBDuration() {
    return _deckBPlayer.duration;
  }

  /// Seek Deck A to position
  Future<void> seekDeckA(Duration position) async {
    await _deckAPlayer.seek(position);
  }

  /// Seek Deck B to position
  Future<void> seekDeckB(Duration position) async {
    await _deckBPlayer.seek(position);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _deckAPlayer.dispose();
    await _deckBPlayer.dispose();
    _initialized = false;
  }
}
