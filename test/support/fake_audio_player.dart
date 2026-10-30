import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// A stand-in for just_audio's [AudioPlayer] that needs no native plugin.
///
/// It implements only the members `PlayerController` uses, records the calls
/// made to it, and lets a test push events (index, player state, position)
/// through the same streams the real player exposes. Streams are synchronous
/// so a test sees the controller's reaction right after emitting.
class FakeAudioPlayer extends Fake implements AudioPlayer {
  final _index = StreamController<int?>.broadcast(sync: true);
  final _state = StreamController<PlayerState>.broadcast(sync: true);
  final _loop = StreamController<LoopMode>.broadcast(sync: true);
  final _shuffle = StreamController<bool>.broadcast(sync: true);
  final _position = StreamController<Duration>.broadcast(sync: true);

  // --- Readable player state (settable by tests) ------------------------------

  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  bool shuffleModeEnabled = false;
  @override
  LoopMode loopMode = LoopMode.off;
  @override
  Duration position = Duration.zero;
  @override
  Duration bufferedPosition = Duration.zero;
  @override
  double speed = 1;
  @override
  Duration? duration;

  // --- Recorded calls -----------------------------------------------------------

  AudioSource? source;
  int? initialIndex;
  int shuffleCalls = 0;
  int stopCalls = 0;
  int seekToNextCalls = 0;
  int seekToPreviousCalls = 0;
  bool disposed = false;
  final List<({Duration? position, int? index})> seeks = [];
  final List<double> volumes = [];

  // --- Streams the controller subscribes to -------------------------------------

  @override
  Stream<int?> get currentIndexStream => _index.stream;
  @override
  Stream<PlayerState> get playerStateStream => _state.stream;
  @override
  Stream<LoopMode> get loopModeStream => _loop.stream;
  @override
  Stream<bool> get shuffleModeEnabledStream => _shuffle.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();

  @override
  Stream<Duration> createPositionStream({
    int steps = 800,
    Duration minPeriod = const Duration(milliseconds: 200),
    Duration maxPeriod = const Duration(milliseconds: 200),
  }) =>
      _position.stream;

  // --- Test helpers -------------------------------------------------------------

  /// The player moved to queue index [i] (as it does when a track ends).
  void emitIndex(int? i) => _index.add(i);

  /// Playback reached [at]; also what [position] now reports.
  void emitPosition(Duration at) {
    position = at;
    _position.add(at);
  }

  void _emitState() => _state.add(PlayerState(playing, processingState));

  // --- AudioPlayer API ----------------------------------------------------------

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    this.source = source;
    this.initialIndex = initialIndex;
    processingState = ProcessingState.ready;
    return duration;
  }

  @override
  Future<void> play() async {
    playing = true;
    processingState = ProcessingState.ready;
    _emitState();
  }

  @override
  Future<void> pause() async {
    playing = false;
    _emitState();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
    processingState = ProcessingState.idle;
    _emitState();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add((position: position, index: index));
    if (position != null) this.position = position;
  }

  @override
  Future<void> seekToNext() async => seekToNextCalls++;

  @override
  Future<void> seekToPrevious() async => seekToPreviousCalls++;

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loopMode = mode;
    _loop.add(mode);
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    shuffleModeEnabled = enabled;
    _shuffle.add(enabled);
  }

  @override
  Future<void> shuffle() async => shuffleCalls++;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async => disposed = true;
}
