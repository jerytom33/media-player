import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'runtime_equalizer_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DeckState {
  final AudioPlayer player;
  final String? filePath;
  final double volume;
  final bool isPlaying;
  final double bpm; // user-specified or detected BPM
  final bool loopEnabled;
  final int loopBeats; // 1/2/4/8

  DeckState({
    required this.player,
    this.filePath,
    this.volume = 1.0,
    this.isPlaying = false,
    this.bpm = 120.0,
    this.loopEnabled = false,
    this.loopBeats = 4,
  });

  DeckState copyWith({
    AudioPlayer? player,
    String? filePath,
    double? volume,
    bool? isPlaying,
    double? bpm,
    bool? loopEnabled,
    int? loopBeats,
  }) {
    return DeckState(
      player: player ?? this.player,
      filePath: filePath ?? this.filePath,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      bpm: bpm ?? this.bpm,
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopBeats: loopBeats ?? this.loopBeats,
    );
  }
}

class DJService {
  static final DJService _instance = DJService._internal();
  factory DJService() => _instance;

  final AudioPlayer deckA = AudioPlayer();
  final AudioPlayer deckB = AudioPlayer();

  // Crossfader 0.0 => fully left(deckA), 1.0 => fully right(deckB)
  double _crossfader = 0.5;
  double get crossfader => _crossfader;

  final _deckAStreamCtl = StreamController<DeckState>.broadcast();
  final _deckBStreamCtl = StreamController<DeckState>.broadcast();
  final _crossfaderCtl = StreamController<double>.broadcast();

  Stream<DeckState> get deckAState => _deckAStreamCtl.stream;
  Stream<DeckState> get deckBState => _deckBStreamCtl.stream;
  Stream<double> get crossfaderStream => _crossfaderCtl.stream;

  DeckState _deckAState = DeckState(player: AudioPlayer());
  DeckState _deckBState = DeckState(player: AudioPlayer());

  DJService._internal() {
    // Initialize local player references
    _deckAState = DeckState(player: deckA);
    _deckBState = DeckState(player: deckB);

    // Attach listeners to update state streams
    deckA.playerStateStream.listen((state) {
      _deckAState = _deckAState.copyWith(isPlaying: state.playing);
      _deckAStreamCtl.add(_deckAState);
    });
    deckB.playerStateStream.listen((state) {
      _deckBState = _deckBState.copyWith(isPlaying: state.playing);
      _deckBStreamCtl.add(_deckBState);
    });
  }

  void dispose() {
    deckA.dispose();
    deckB.dispose();
    _deckAStreamCtl.close();
    _deckBStreamCtl.close();
    _crossfaderCtl.close();
  }

  Future<void> loadDeckA(String path) async {
    await deckA.stop();
    await deckA.setFilePath(path);
    _deckAState = _deckAState.copyWith(filePath: path);
    _deckAStreamCtl.add(_deckAState);
    _syncCrossfaderVolumes();
    // Register audio session with runtime equalizer (Android) if available
    try {
      final sid = deckA.androidAudioSessionId;
      if (sid != null) {
        await RuntimeEqualizerService.getInstance().setAudioSessionId(sid);
      }
    } catch (_) {}
  }

  Future<void> loadDeckB(String path) async {
    await deckB.stop();
    await deckB.setFilePath(path);
    _deckBState = _deckBState.copyWith(filePath: path);
    _deckBStreamCtl.add(_deckBState);
    _syncCrossfaderVolumes();
    // Register audio session with runtime equalizer (Android) if available
    try {
      final sid = deckB.androidAudioSessionId;
      if (sid != null) {
        await RuntimeEqualizerService.getInstance().setAudioSessionId(sid);
      }
    } catch (_) {}
  }

  Future<void> playDeckA() async {
    await deckA.play();
    _deckAState = _deckAState.copyWith(isPlaying: true);
    _deckAStreamCtl.add(_deckAState);
  }

  Future<void> pauseDeckA() async {
    await deckA.pause();
    _deckAState = _deckAState.copyWith(isPlaying: false);
    _deckAStreamCtl.add(_deckAState);
  }

  Future<void> playDeckB() async {
    await deckB.play();
    _deckBState = _deckBState.copyWith(isPlaying: true);
    _deckBStreamCtl.add(_deckBState);
  }

  Future<void> pauseDeckB() async {
    await deckB.pause();
    _deckBState = _deckBState.copyWith(isPlaying: false);
    _deckBStreamCtl.add(_deckBState);
  }

  void setCrossfader(double value) {
    _crossfader = value.clamp(0.0, 1.0);
    _syncCrossfaderVolumes();
    _crossfaderCtl.add(_crossfader);
  }

  // Spin (auto crossfader modulation)
  // Spin enabled state is implied by _spinTimer != null
  Timer? _spinTimer;
  double _spinSpeed = 0.5; // cycles per second
  double _spinAmplitude = 0.5; // amplitude as fraction 0..1 (half range)

  void startSpin({double speed = 0.5, double amplitude = 0.5}) {
    // spin enabled indicated by _spinTimer != null
    _spinSpeed = speed;
    _spinAmplitude = amplitude.clamp(0.0, 1.0);
    var phase = 0.0;
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(Duration(milliseconds: 50), (_) {
      phase += _spinSpeed * 0.05 * 2 * 3.14159; // 50ms tick scaled
      final val = 0.5 + (sin(phase) * _spinAmplitude) * 0.5;
      setCrossfader(val.clamp(0.0, 1.0));
    });
  }

  void stopSpin() {
    _spinTimer?.cancel();
    _spinTimer = null;
  }

  void setDeckAVolume(double v) {
    final vol = v.clamp(0.0, 1.0);
    _deckAState = _deckAState.copyWith(volume: vol);
    deckA.setVolume(_computeDeckAVolume());
    _deckAStreamCtl.add(_deckAState);
  }

  void setDeckBVolume(double v) {
    final vol = v.clamp(0.0, 1.0);
    _deckBState = _deckBState.copyWith(volume: vol);
    deckB.setVolume(_computeDeckBVolume());
    _deckBStreamCtl.add(_deckBState);
  }

  double _computeDeckAVolume() {
    final left = (1.0 - _crossfader) * (_deckAState.volume);
    return left;
  }

  double _computeDeckBVolume() {
    final right = (_crossfader) * (_deckBState.volume);
    return right;
  }

  void _syncCrossfaderVolumes() {
    deckA.setVolume(_computeDeckAVolume());
    deckB.setVolume(_computeDeckBVolume());
  }

  /// Looping using clip and automatic restart.
  Future<void> enableLoopDeckA({required bool enabled, int beats = 4, double bpm = 120.0}) async {
    _deckAState = _deckAState.copyWith(loopEnabled: enabled, loopBeats: beats, bpm: bpm);
    if (!enabled) {
      await deckA.setLoopMode(LoopMode.off);
    } else {
      final beatSec = 60.0 / bpm;
      final loopLen = beatSec * beats;
      final pos = deckA.position;
      // Ensure there is a valid audio duration
      final dur = deckA.duration ?? Duration.zero;
      final start = pos;
      final end = (pos + Duration(milliseconds: (loopLen * 1000).round()))
          .compareTo(dur) > 0
          ? dur
          : pos + Duration(milliseconds: (loopLen * 1000).round());
      // Use ClippingAudioSource to set loop - just_audio supports setClip
      final filePath = _deckAState.filePath;
      if (filePath != null) {
        final child = AudioSource.uri(Uri.file(filePath));
        await deckA.setAudioSource(ClippingAudioSource(start: start, end: end, child: child));
      }
      await deckA.setLoopMode(LoopMode.one);
    }
    _deckAStreamCtl.add(_deckAState);
  }

  Future<void> enableLoopDeckB({required bool enabled, int beats = 4, double bpm = 120.0}) async {
    _deckBState = _deckBState.copyWith(loopEnabled: enabled, loopBeats: beats, bpm: bpm);
    if (!enabled) {
      await deckB.setLoopMode(LoopMode.off);
    } else {
      final beatSec = 60.0 / bpm;
      final loopLen = beatSec * beats;
      final pos = deckB.position;
      final dur = deckB.duration ?? Duration.zero;
      final start = pos;
      final end = (pos + Duration(milliseconds: (loopLen * 1000).round()))
          .compareTo(dur) > 0
          ? dur
          : pos + Duration(milliseconds: (loopLen * 1000).round());
      final filePath = _deckBState.filePath;
      if (filePath != null) {
        final child = AudioSource.uri(Uri.file(filePath));
        await deckB.setAudioSource(ClippingAudioSource(start: start, end: end, child: child));
      }
      await deckB.setLoopMode(LoopMode.one);
    }
    _deckBStreamCtl.add(_deckBState);
  }

  /// Simple tempo sync - adjust deck B to match deck A's BPM
  Future<void> syncDecks({bool syncToA = true}) async {
    // Use current BPM values stored in states to set speed.
    final aBpm = _deckAState.bpm;
    final bBpm = _deckBState.bpm;
    if (aBpm <= 0 || bBpm <= 0) return;
    if (syncToA) {
      final ratio = aBpm / bBpm;
      await deckB.setSpeed(ratio);
    } else {
      final ratio = bBpm / aBpm;
      await deckA.setSpeed(ratio);
    }
  }

  void setDeckABPM(double bpm) {
    _deckAState = _deckAState.copyWith(bpm: bpm);
    _deckAStreamCtl.add(_deckAState);
  }

  void setDeckBBPM(double bpm) {
    _deckBState = _deckBState.copyWith(bpm: bpm);
    _deckBStreamCtl.add(_deckBState);
  }

  /// Convenience getters for deck audio session ids (Android)
  int? get deckAAudioSessionId => deckA.androidAudioSessionId;
  int? get deckBAudioSessionId => deckB.androidAudioSessionId;

  String? get deckAFilePath => _deckAState.filePath;
  String? get deckBFilePath => _deckBState.filePath;
  double get deckAVol => _deckAState.volume;
  double get deckBVol => _deckBState.volume;
  double get deckABPM => _deckAState.bpm;
  double get deckBBPM => _deckBState.bpm;
  int get deckAPositionMillis => deckA.position.inMilliseconds;
  int get deckBPositionMillis => deckB.position.inMilliseconds;

  // A simple save session JSON object in memory or file could be added later

  /// Export a mix of the two decks to a WAV file using FFmpeg (offline render).
  /// Returns the output file path on success or throws on failure.
  Future<String> exportMix({String? outputPath}) async {
    final aPath = deckAFilePath;
    final bPath = deckBFilePath;
    if (aPath == null || bPath == null) {
      throw Exception('Both decks must have files loaded to export mix');
    }

    final la = ((1.0 - _crossfader) * _deckAState.volume).clamp(0.0, 1.0);
    final lb = ((_crossfader) * _deckBState.volume).clamp(0.0, 1.0);

    Directory outDir;
    if (outputPath == null) {
      try {
        outDir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      } catch (_) {
        outDir = await getTemporaryDirectory();
      }
    } else {
      outDir = Directory(p.dirname(outputPath));
    }
    final outFile = outputPath ?? p.join(outDir.path, 'mix_${DateTime.now().millisecondsSinceEpoch}.wav');

    // If both files are WAV 16-bit PCM, do a simple Dart mix; otherwise require FFmpeg.
    if (aPath.toLowerCase().endsWith('.wav') && bPath.toLowerCase().endsWith('.wav')) {
      return await _exportMixWav(aPath, bPath, outFile, la, lb);
    }

    throw Exception('Export not available for non-WAV input files without FFmpeg plugin.');
  }

  Future<String> _exportMixWav(String aPath, String bPath, String outPath, double la, double lb) async {
    // Read WAV files and parse PCM16LE data; this is a best-effort mix.
    final aFile = File(aPath);
    final bFile = File(bPath);
    final aBytes = await aFile.readAsBytes();
    final bBytes = await bFile.readAsBytes();

    final aInfo = _parseWavHeader(aBytes);
    final bInfo = _parseWavHeader(bBytes);

    if (aInfo == null || bInfo == null) throw Exception('Invalid or unsupported WAV file(s)');
    if (aInfo['bitsPerSample'] != 16 || bInfo['bitsPerSample'] != 16) throw Exception('Only 16-bit WAV supported');
    if (aInfo['channels'] != bInfo['channels'] || aInfo['sampleRate'] != bInfo['sampleRate']) throw Exception('Input WAV files must share sample rate and channel count');

    final aData = aBytes.sublist(aInfo['dataOffset'], aInfo['dataOffset'] + aInfo['dataLen']);
    final bData = bBytes.sublist(bInfo['dataOffset'], bInfo['dataOffset'] + bInfo['dataLen']);

    final aSamples = Int16List.view(Uint8List.fromList(aData).buffer);
    final bSamples = Int16List.view(Uint8List.fromList(bData).buffer);

    final maxLen = max(aSamples.length, bSamples.length);
    final outSamples = Int16List(maxLen);

    for (var i = 0; i < maxLen; i++) {
      final aS = i < aSamples.length ? (aSamples[i] * la) : 0.0;
      final bS = i < bSamples.length ? (bSamples[i] * lb) : 0.0;
      var sum = (aS + bS).round();
      if (sum > 32767) sum = 32767;
      if (sum < -32768) sum = -32768;
      outSamples[i] = sum;
    }

    // Create WAV header and write result
    final outFile = File(outPath);
    final wavBytes = _buildWavBytes(outSamples, sampleRate: aInfo['sampleRate'], channels: aInfo['channels']);
    await outFile.writeAsBytes(wavBytes);
    return outFile.path;
  }

  Map<String, dynamic>? _parseWavHeader(Uint8List bytes) {
    final reader = ByteData.view(bytes.buffer);
    if (bytes.length < 44) return null;
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') return null;
    // Find 'fmt ' chunk and 'data' chunk
    int offset = 12;
    int? fmtOffset, dataOffset;
    int? dataLen;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final len = reader.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ') { fmtOffset = offset + 8; }
      if (id == 'data') { dataOffset = offset + 8; dataLen = len; break; }
      offset += 8 + len;
    }
    if (fmtOffset == null || dataOffset == null) return null;
    final fmt = fmtOffset;
    final audioFormat = reader.getUint16(fmt, Endian.little);
    final channels = reader.getUint16(fmt + 2, Endian.little);
    final sampleRate = reader.getUint32(fmt + 4, Endian.little);
    final bitsPerSample = reader.getUint16(fmt + 14, Endian.little);
    return {
      'audioFormat': audioFormat, // 1 = PCM
      'channels': channels,
      'sampleRate': sampleRate,
      'bitsPerSample': bitsPerSample,
      'dataOffset': dataOffset,
      'dataLen': dataLen,
    };
  }

  Uint8List _buildWavBytes(Int16List samples, {required int sampleRate, required int channels}) {
    final byteRate = sampleRate * channels * 16 ~/ 8;
    final blockAlign = channels * 16 ~/ 8;
    final dataLen = samples.length * 2;
    final totalLen = 44 + dataLen;
    final bd = ByteData(totalLen);
    // RIFF header
    bd.setUint8(0, 'R'.codeUnitAt(0)); bd.setUint8(1, 'I'.codeUnitAt(0)); bd.setUint8(2, 'F'.codeUnitAt(0)); bd.setUint8(3, 'F'.codeUnitAt(0));
    bd.setUint32(4, totalLen - 8, Endian.little);
    bd.setUint8(8, 'W'.codeUnitAt(0)); bd.setUint8(9, 'A'.codeUnitAt(0)); bd.setUint8(10, 'V'.codeUnitAt(0)); bd.setUint8(11, 'E'.codeUnitAt(0));
    // fmt chunk
    bd.setUint8(12, 'f'.codeUnitAt(0)); bd.setUint8(13, 'm'.codeUnitAt(0)); bd.setUint8(14, 't'.codeUnitAt(0)); bd.setUint8(15, ' '.codeUnitAt(0));
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    // data chunk
    bd.setUint8(36, 'd'.codeUnitAt(0)); bd.setUint8(37, 'a'.codeUnitAt(0)); bd.setUint8(38, 't'.codeUnitAt(0)); bd.setUint8(39, 'a'.codeUnitAt(0));
    bd.setUint32(40, dataLen, Endian.little);
    int off = 44;
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(off, samples[i], Endian.little);
      off += 2;
    }
    return bd.buffer.asUint8List();
  }
}
