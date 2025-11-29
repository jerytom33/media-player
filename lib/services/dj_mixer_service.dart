import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_mixer_engine.dart';

/// State for a single DJ deck
class DeckState {
  final String? filePath;
  final bool isPlaying;
  final bool isPaused;
  final double speed; // Playback speed for BPM matching
  final double bpm; // User-set BPM
  final Duration position;
  final Duration duration;

  const DeckState({
    this.filePath,
    this.isPlaying = false,
    this.isPaused = false,
    this.speed = 1.0,
    this.bpm = 120.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  DeckState copyWith({
    String? filePath,
    bool? isPlaying,
    bool? isPaused,
    double? speed,
    double? bpm,
    Duration? position,
    Duration? duration,
  }) {
    return DeckState(
      filePath: filePath ?? this.filePath,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      speed: speed ?? this.speed,
      bpm: bpm ?? this.bpm,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// DJ Mixer Service managing dual decks and mixing
class DJMixerService {
  static final DJMixerService _instance = DJMixerService._internal();
  factory DJMixerService() => _instance;

  final AudioMixerEngine _engine = AudioMixerEngine();

  // State streams
  final _deckAController = StreamController<DeckState>.broadcast();
  final _deckBController = StreamController<DeckState>.broadcast();
  final _crossfaderController = StreamController<double>.broadcast();
  // Effect maps streamers (broadcast current effect levels per deck)
  final _deckAEffectsController = StreamController<Map<String, double>>.broadcast();
  final _deckBEffectsController = StreamController<Map<String, double>>.broadcast();

  Stream<DeckState> get deckAState => _deckAController.stream;
  Stream<DeckState> get deckBState => _deckBController.stream;
  Stream<double> get crossfaderStream => _crossfaderController.stream;
  Stream<Map<String, double>> get deckAEffectsStream => _deckAEffectsController.stream;
  Stream<Map<String, double>> get deckBEffectsStream => _deckBEffectsController.stream;

  // Current state
  DeckState _deckAState = const DeckState();
  DeckState _deckBState = const DeckState();
  double _crossfader = 0.5;

  // Position update timer
  Timer? _positionTimer;

  DJMixerService._internal() {
    _startPositionUpdates();
  }

  /// Initialize the mixer engine
  Future<void> initialize() async {
    try {
      await _engine.initialize();
    } catch (e) {
      if (kDebugMode) print('Failed to initialize DJ mixer: $e');
      rethrow;
    }
  }

  /// Start periodic position updates
  void _startPositionUpdates() {
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_deckAState.isPlaying) {
        final pos = _engine.getDeckAPosition();
        _deckAState = _deckAState.copyWith(position: pos);
        _deckAController.add(_deckAState);
      }

      if (_deckBState.isPlaying) {
        final pos = _engine.getDeckBPosition();
        _deckBState = _deckBState.copyWith(position: pos);
        _deckBController.add(_deckBState);
      }
    });
  }

  // ===== Deck A Methods =====

  Future<void> loadDeckA(String filePath) async {
    try {
      await _engine.loadDeckA(filePath);
      _deckAState = DeckState(filePath: filePath);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error loading Deck A: $e');
      rethrow;
    }
  }

  Future<void> playDeckA() async {
    try {
      await _engine.playDeckA();
      _deckAState = _deckAState.copyWith(isPlaying: true, isPaused: false);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error playing Deck A: $e');
    }
  }

  Future<void> pauseDeckA() async {
    try {
      await _engine.pauseDeckA();
      _deckAState = _deckAState.copyWith(isPlaying: false, isPaused: true);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error pausing Deck A: $e');
    }
  }

  Future<void> resumeDeckA() async {
    try {
      await _engine.resumeDeckA();
      _deckAState = _deckAState.copyWith(isPlaying: true, isPaused: false);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error resuming Deck A: $e');
    }
  }

  Future<void> stopDeckA() async {
    try {
      await _engine.stopDeckA();
      _deckAState = _deckAState.copyWith(
        isPlaying: false,
        isPaused: false,
        position: Duration.zero,
      );
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error stopping Deck A: $e');
    }
  }

  Future<void> seekDeckA(Duration position) async {
    try {
      await _engine.seekDeckA(position);
      _deckAState = _deckAState.copyWith(position: position);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error seeking Deck A: $e');
    }
  }

  void setDeckABPM(double bpm) {
    _deckAState = _deckAState.copyWith(bpm: bpm);
    _deckAController.add(_deckAState);
  }

  Future<void> setDeckASpeed(double speed) async {
    try {
      await _engine.setDeckASpeed(speed);
      _deckAState = _deckAState.copyWith(speed: speed);
      _deckAController.add(_deckAState);
    } catch (e) {
      if (kDebugMode) print('Error setting Deck A speed: $e');
    }
  }

  // ===== Deck B Methods =====

  Future<void> loadDeckB(String filePath) async {
    try {
      await _engine.loadDeckB(filePath);
      _deckBState = DeckState(filePath: filePath);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error loading Deck B: $e');
      rethrow;
    }
  }

  Future<void> playDeckB() async {
    try {
      await _engine.playDeckB();
      _deckBState = _deckBState.copyWith(isPlaying: true, isPaused: false);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error playing Deck B: $e');
    }
  }

  Future<void> pauseDeckB() async {
    try {
      await _engine.pauseDeckB();
      _deckBState = _deckBState.copyWith(isPlaying: false, isPaused: true);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error pausing Deck B: $e');
    }
  }

  Future<void> resumeDeckB() async {
    try {
      await _engine.resumeDeckB();
      _deckBState = _deckBState.copyWith(isPlaying: true, isPaused: false);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error resuming Deck B: $e');
    }
  }

  Future<void> stopDeckB() async {
    try {
      await _engine.stopDeckB();
      _deckBState = _deckBState.copyWith(
        isPlaying: false,
        isPaused: false,
        position: Duration.zero,
      );
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error stopping Deck B: $e');
    }
  }

  Future<void> seekDeckB(Duration position) async {
    try {
      await _engine.seekDeckB(position);
      _deckBState = _deckBState.copyWith(position: position);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error seeking Deck B: $e');
    }
  }

  void setDeckBBPM(double bpm) {
    _deckBState = _deckBState.copyWith(bpm: bpm);
    _deckBController.add(_deckBState);
  }

  Future<void> setDeckBSpeed(double speed) async {
    try {
      await _engine.setDeckBSpeed(speed);
      _deckBState = _deckBState.copyWith(speed: speed);
      _deckBController.add(_deckBState);
    } catch (e) {
      if (kDebugMode) print('Error setting Deck  B speed: $e');
    }
  }

  // ===== Crossfader Methods =====

  void setCrossfader(double value) {
    _crossfader = value.clamp(0.0, 1.0);
    _engine.setCrossfader(_crossfader);
    _crossfaderController.add(_crossfader);
  }

  // ===== Effects =====

  /// Set an effect level for a specific deck ('A' or 'B'). Level is 0.0..1.0
  void setDeckEffectLevel({required String deck, required String effect, required double level}) {
    final normalized = level.clamp(0.0, 1.0);
    _engine.setDeckEffect(deck, effect, normalized);

    // Broadcast the current effect maps so UI can update
    final a = <String, double>{};
    final b = <String, double>{};
    // gather values for a small set of known effects by asking engine
    // Note: asking engine for each effect is cheap; this keeps UI and engine in sync.
    for (final fx in ['echo', 'reverb', 'delay', 'wet']) {
      final va = _engine.getDeckEffect('A', fx);
      final vb = _engine.getDeckEffect('B', fx);
      if (va > 0.0) a[fx] = va;
      if (vb > 0.0) b[fx] = vb;
    }

    _deckAEffectsController.add(a);
    _deckBEffectsController.add(b);
  }

  /// Get the current effect level
  double getDeckEffectLevel(String deck, String effect) {
    return _engine.getDeckEffect(deck, effect);
  }

  double get crossfader => _crossfader;

  // ===== Sync Methods =====

  /// Sync Deck B to Deck A's BPM
  Future<void> syncDeckBToA() async {
    if (_deckAState.bpm > 0 && _deckBState.bpm > 0) {
      final speedRatio = _deckAState.bpm / _deckBState.bpm;
      await setDeckBSpeed(speedRatio);
    }
  }

  /// Sync Deck A to Deck B's BPM
  Future<void> syncDeckAToB() async {
    if (_deckAState.bpm > 0 && _deckBState.bpm > 0) {
      final speedRatio = _deckBState.bpm / _deckAState.bpm;
      await setDeckASpeed(speedRatio);
    }
  }

  // ===== Getters =====

  DeckState get deckACurrentState => _deckAState;
  DeckState get deckBCurrentState => _deckBState;

  /// Dispose resources
  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _engine.dispose();
    await _deckAController.close();
    await _deckBController.close();
    await _crossfaderController.close();
  }
}
