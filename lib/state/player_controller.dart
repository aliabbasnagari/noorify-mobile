import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/equalizer_presets.dart';
import '../audio/play_tracker.dart';
import '../audio/replay_gain.dart';
import '../models/models.dart';
import '../settings/settings_models.dart';
import '../subsonic/subsonic_client.dart';
import 'download_controller.dart';
import 'settings_controller.dart';

/// Creates a just_audio player; see [PlayerController.new].
typedef PlayerFactory = AudioPlayer Function({AudioPipeline? audioPipeline});

AudioPlayer _defaultPlayerFactory({AudioPipeline? audioPipeline}) =>
    AudioPlayer(audioPipeline: audioPipeline);

/// Playback queue + transport, backed by just_audio. Also an [AudioHandler]
/// (audio_service) so the OS media notification, lock screen, headset
/// buttons and Android Auto drive the same queue/transport as the in-app UI.
///
/// Also applies the playback settings: ReplayGain, fade in/out, skip silence
/// and the Android equalizer. Offline copies are preferred over streaming.
class PlayerController extends BaseAudioHandler
    with SeekHandler, ChangeNotifier {
  /// [playerFactory] builds both the main player and the lazily created
  /// crossfade overlap player; tests pass one that returns fakes.
  PlayerController({PlayerFactory? playerFactory})
      : _playerFactory = playerFactory ?? _defaultPlayerFactory {
    _player = _playerFactory(
      audioPipeline: _isAndroid
          ? AudioPipeline(androidAudioEffects: [_equalizer, _loudness])
          : null,
    );
    _subs.add(_player.currentIndexStream.listen(_onIndexChanged));
    _subs.add(_player.playerStateStream.listen((_) {
      notifyListeners();
      _broadcastPlaybackState();
    }));
    _subs.add(_player.loopModeStream.listen((_) {
      notifyListeners();
      _broadcastPlaybackState();
    }));
    _subs.add(_player.shuffleModeEnabledStream.listen((_) {
      notifyListeners();
      _broadcastPlaybackState();
    }));
    // Finer than the default 200ms so fades are smooth.
    _subs.add(
      _player
          .createPositionStream(
            minPeriod: const Duration(milliseconds: 50),
            maxPeriod: const Duration(milliseconds: 100),
          )
          .listen(_updateFade),
    );
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final PlayerFactory _playerFactory;
  late final AudioPlayer _player;
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudness = AndroidLoudnessEnhancer();
  final List<StreamSubscription<Object?>> _subs = [];

  /// Lazily-created second player used only during a crossfade's overlap
  /// window. It has no EQ/loudness pipeline of its own: those effects (and
  /// ReplayGain) only kick in once the handoff to [_player] completes, so a
  /// song briefly plays unprocessed while it is the incoming crossfade track.
  AudioPlayer? _overlapPlayer;
  bool _crossfading = false;
  // True from the moment the main player naturally advances past a
  // crossfaded track until the handoff (seeking it to match the overlap
  // player, then stopping the overlap player) finishes. Distinct from
  // [_crossfading] (the ramp itself) because that flips false synchronously
  // the instant the handoff starts, but the seek is async — without this,
  // the next position-stream tick (every 50-100ms) sees "not crossfading"
  // and runs the normal fade-in logic, which forces the main player back to
  // full volume while it's still sitting at position 0 pre-seek: audible as
  // the new track briefly "restarting" before snapping to the right spot.
  bool _finishingCrossfade = false;
  int? _crossfadeTotalMs;
  Song? _crossfadeExpectedSong;

  SubsonicClient? _client;
  SettingsController? _settings;
  DownloadController? _downloads;

  ConcatenatingAudioSource _source = ConcatenatingAudioSource(children: []);
  final List<Song> _queue = [];
  int? _index;
  String? _queueSource;

  /// Decides when the current track has been heard enough to report a play.
  final PlayTracker _plays = PlayTracker();

  double _fade = 1;
  double _lastVolume = -1;
  double _lastBoostDb = 0;

  PlaybackSettings get _playback =>
      _settings?.playback ?? const PlaybackSettings();

  /// The listener's own volume multiplier (0 while muted).
  double get _userGain => _playback.muted ? 0 : _playback.volume;

  // --- Wiring ---------------------------------------------------------------

  /// Called whenever the active server session changes.
  void attach(SubsonicClient? client) {
    if (identical(_client, client)) return;
    _client = client;
    if (client == null) unawaited(stop());
  }

  void attachSettings(SettingsController settings) {
    if (identical(_settings, settings)) return;
    _settings?.removeListener(_onSettingsChanged);
    _settings = settings..addListener(_onSettingsChanged);
    _onSettingsChanged();
  }

  void attachDownloads(DownloadController downloads) => _downloads = downloads;

  void _onSettingsChanged() {
    // Deferred: this can be reached from a provider update during build.
    scheduleMicrotask(() {
      unawaited(_applySettings());
      // The volume getters read the settings, so let listeners (a volume
      // slider) see the change.
      notifyListeners();
    });
  }

  // --- State ----------------------------------------------------------------

  List<Song> get queueSongs => List.unmodifiable(_queue);

  /// Where the queue was started from ("Road trip", "Search results"), for the
  /// queue panel's "Next from ..." heading, or null when unknown.
  String? get queueSource => _queueSource;
  int? get currentIndex => _index;
  Song? get current =>
      (_index != null && _index! >= 0 && _index! < _queue.length)
          ? _queue[_index!]
          : null;
  bool get hasQueue => _queue.isNotEmpty;
  bool get isPlaying => _player.playing;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  bool get shuffleEnabled => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;

  /// The listener's volume, 0..1, kept even while muted.
  double get userVolume => _playback.volume;
  bool get isMuted => _playback.muted;

  /// Sets the listener's volume. Moving it from silence also unmutes.
  Future<void> setUserVolume(double volume) async {
    await _settings?.updatePlayback(
      (c) => c.copyWith(volume: volume.clamp(0.0, 1.0), muted: false),
    );
  }

  Future<void> toggleMute() async {
    await _settings?.updatePlayback((c) => c.copyWith(muted: !c.muted));
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Uri? coverUri(String? coverArt, {int size = 600}) =>
      coverArt == null ? null : _client?.coverArtUrl(coverArt, size: size);

  // --- Queue building -------------------------------------------------------

  MediaItem _toMediaItem(Song s) => MediaItem(
        id: s.id,
        title: s.title,
        album: s.album,
        artist: s.artist,
        duration: s.duration > 0 ? Duration(seconds: s.duration) : null,
        artUri: coverUri(s.coverArt),
      );

  void _broadcastQueue() => queue.add(_queue.map(_toMediaItem).toList());

  AudioSource _toSource(Song s) {
    final client = _client;
    if (client == null) throw StateError('No active server session');
    final tag = _toMediaItem(s);
    // Prefer the offline copy when we have one.
    final local = _downloads?.localPath(s.id);
    if (local != null && File(local).existsSync()) {
      return AudioSource.file(local, tag: tag);
    }
    return AudioSource.uri(client.streamUrl(s.id), tag: tag);
  }

  /// Replaces the queue with [songs] and starts playing at [index]. [source]
  /// names where the songs came from, for the queue panel.
  Future<void> playSongs(
    List<Song> songs, {
    int index = 0,
    bool shuffle = false,
    String? source,
  }) async {
    if (songs.isEmpty) return;
    _queueSource = source;
    _queue
      ..clear()
      ..addAll(songs);
    _source = ConcatenatingAudioSource(children: songs.map(_toSource).toList());
    _index = index;
    _fade = 1;
    _broadcastQueue();
    mediaItem.add(_toMediaItem(songs[index]));
    notifyListeners();
    await _player.setAudioSource(_source, initialIndex: index);
    await _player.setShuffleModeEnabled(shuffle);
    if (shuffle) await _player.shuffle();
    // Audio effects only exist once a source is loaded.
    unawaited(_applySettings());
    unawaited(_player.play());
  }

  Future<void> playNext(Song song) async {
    if (!hasQueue) return playSongs([song]);
    final at = (_index ?? -1) + 1;
    _queue.insert(at, song);
    await _source.insert(at, _toSource(song));
    _broadcastQueue();
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    if (!hasQueue) return playSongs([song]);
    _queue.add(song);
    await _source.add(_toSource(song));
    _broadcastQueue();
    notifyListeners();
  }

  Future<void> removeAt(int i) async {
    if (i < 0 || i >= _queue.length) return;
    _queue.removeAt(i);
    await _source.removeAt(i);
    _broadcastQueue();
    notifyListeners();
  }

  Future<void> move(int from, int to) async {
    if (from == to) return;
    final song = _queue.removeAt(from);
    _queue.insert(to, song);
    await _source.move(from, to);
    _broadcastQueue();
    notifyListeners();
  }

  Future<void> skipTo(int i) async {
    await _player.seek(Duration.zero, index: i);
    unawaited(_player.play());
  }

  // --- Transport ------------------------------------------------------------

  Future<void> togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> skipToNext() => next();

  @override
  Future<void> skipToPrevious() => previous();

  @override
  Future<void> skipToQueueItem(int index) => skipTo(index);

  Future<void> next() => _player.seekToNext();

  /// Restarts the track when more than 3s in, otherwise goes to the previous.
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
  }

  Future<void> cycleRepeat() => _player.setLoopMode(switch (_player.loopMode) {
        LoopMode.off => LoopMode.all,
        LoopMode.all => LoopMode.one,
        LoopMode.one => LoopMode.off,
      });

  @override
  Future<void> stop() async {
    if (_crossfading || _finishingCrossfade) {
      _crossfading = false;
      _finishingCrossfade = false;
      _crossfadeTotalMs = null;
      _crossfadeExpectedSong = null;
      await _overlapPlayer?.stop();
    }
    await _player.stop();
    _plays.reset();
    _queue.clear();
    _queueSource = null;
    _source = ConcatenatingAudioSource(children: []);
    _index = null;
    _broadcastQueue();
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
      queueIndex: null,
    ));
    notifyListeners();
  }

  // --- Sound settings -------------------------------------------------------

  /// Equalizer bands of this device, or null when unsupported or nothing has
  /// been loaded yet (Android only exposes them once a source exists).
  Future<AndroidEqualizerParameters?> equalizerParameters() async {
    if (!_isAndroid || !hasQueue) return null;
    try {
      return await _equalizer.parameters.timeout(const Duration(seconds: 3));
    } on Object {
      return null;
    }
  }

  /// Applies [gains] immediately without persisting (used while dragging).
  Future<void> previewEqualizer(List<double> gains) async {
    final params = await equalizerParameters();
    if (params == null) return;
    await _equalizer.setEnabled(true);
    await _writeBands(params, gains);
  }

  Future<void> _writeBands(
      AndroidEqualizerParameters params, List<double> gains) async {
    final n = params.bands.length;
    for (var i = 0; i < n; i++) {
      final g = gainForBand(gains, i, n)
          .clamp(params.minDecibels, params.maxDecibels);
      await params.bands[i].setGain(g);
    }
  }

  Future<void> _applySettings() async {
    final p = _playback;
    try {
      if (_isAndroid && hasQueue) {
        await _player.setSkipSilenceEnabled(p.skipSilence);
        await _equalizer.setEnabled(p.eqEnabled);
        if (p.eqEnabled) {
          final params = await equalizerParameters();
          if (params != null) await _writeBands(params, p.eqGains);
        }
      }
      await _applyVolume();
    } on Object catch (e) {
      // Effects are best-effort; a device without them must still play.
      debugPrint('Applying audio settings failed: $e');
    }
  }

  /// Volume = ReplayGain (attenuation only) x fade factor x the listener's own
  /// volume. Positive ReplayGain is realised with the loudness enhancer
  /// because volume tops out at 1.0.
  Future<void> _applyVolume() async {
    final song = current;
    final p = _playback;
    final db = song == null
        ? 0.0
        : replayGainDb(song.replayGain, p.replayGain, p.preAmpDb);

    final boost = db > 0 ? db : 0.0;
    if (_isAndroid && boost != _lastBoostDb && hasQueue) {
      _lastBoostDb = boost;
      await _loudness.setEnabled(boost > 0);
      if (boost > 0) await _loudness.setTargetGain(boost);
    }

    final volume = (dbToVolume(db) * _fade * _userGain).clamp(0.0, 1.0);
    if ((volume - _lastVolume).abs() > 0.005) {
      _lastVolume = volume;
      await _player.setVolume(volume);
    }
  }

  /// Ramps volume at the start and end of each track, and drives the
  /// crossfade overlap (if enabled) in its final stretch.
  void _updateFade(Duration position) {
    final p = _playback;
    final posMs = position.inMilliseconds;
    final durMs = _player.duration?.inMilliseconds ??
        ((current?.duration ?? 0) > 0 ? current!.duration * 1000 : null);

    final song = current;
    if (song != null &&
        _plays.onPosition(posMs, durationMs: durMs, playing: _player.playing)) {
      // Best effort: reporting a play must never disturb playback.
      unawaited(_client?.scrobble(song.id).catchError((Object _) {}));
    }

    if (_crossfading) {
      _tickCrossfade(posMs, durMs);
      return;
    }
    if (_finishingCrossfade) {
      // Mid-handoff: the main player's position/volume are about to be
      // overwritten by _finishCrossfade. Let it finish rather than racing it
      // with the normal fade-in logic below.
      return;
    }

    var f = 1.0;
    if (p.fadeInMs > 0 || p.fadeOutMs > 0) {
      if (p.fadeInMs > 0 && posMs < p.fadeInMs) f = posMs / p.fadeInMs;
      if (p.fadeOutMs > 0 && durMs != null) {
        final remaining = durMs - posMs;
        if (remaining < p.fadeOutMs) {
          f = f < remaining / p.fadeOutMs ? f : remaining / p.fadeOutMs;
        }
      }
      f = f.clamp(0.0, 1.0);
    }
    if ((f - _fade).abs() > 0.01 || (f == 1 && _fade != 1)) {
      _fade = f;
      unawaited(_applyVolume());
    }

    if (p.crossfadeMs > 0 && durMs != null) {
      final remaining = durMs - posMs;
      if (remaining > 0 && remaining <= p.crossfadeMs) {
        final next = _peekNextSequential();
        if (next != null) unawaited(_startCrossfade(next, p.crossfadeMs));
      }
    }
  }

  /// The song that will play next under plain sequential/looped progression
  /// (i.e. not shuffled), or null if there isn't one. Crossfade is only
  /// attempted in this common case; shuffle keeps using the plain fade.
  Song? _peekNextSequential() {
    if (_player.shuffleModeEnabled) return null;
    final i = _index;
    if (i == null) return null;
    if (i + 1 < _queue.length) return _queue[i + 1];
    if (_player.loopMode == LoopMode.all && _queue.isNotEmpty) return _queue[0];
    return null;
  }

  /// Starts overlapping [next] on a second player, ramping it in while
  /// [_player] ramps out, over [totalMs].
  Future<void> _startCrossfade(Song next, int totalMs) async {
    if (_crossfading) return;
    _crossfading = true;
    _crossfadeTotalMs = totalMs;
    _crossfadeExpectedSong = next;
    final overlap = _overlapPlayer ??= _playerFactory();
    try {
      await overlap.setVolume(0);
      await overlap.setAudioSource(_toSource(next));
      unawaited(overlap.play());
    } on Object catch (e) {
      // Best effort: if the overlap player can't start, just let the
      // existing gapless transition (and fadeOutMs, if any) play out.
      debugPrint('Crossfade failed to start: $e');
      _crossfading = false;
      _crossfadeTotalMs = null;
      _crossfadeExpectedSong = null;
    }
  }

  void _tickCrossfade(int posMs, int? durMs) {
    final total = _crossfadeTotalMs;
    final overlap = _overlapPlayer;
    if (total == null || overlap == null || durMs == null) {
      _finishingCrossfade = true;
      unawaited(_finishCrossfade());
      return;
    }
    final remaining = durMs - posMs;
    final t = ((total - remaining) / total).clamp(0.0, 1.0);
    _fade = 1 - t;
    unawaited(_applyVolume());
    final next = _crossfadeExpectedSong;
    final nextDb = next == null
        ? 0.0
        : replayGainDb(
            next.replayGain, _playback.replayGain, _playback.preAmpDb);
    unawaited(overlap
        .setVolume((t * dbToVolume(nextDb) * _userGain).clamp(0.0, 1.0)));
  }

  /// Called once the main player naturally advances past the crossfaded
  /// track (via its own gapless engine). Hands off from the overlap player
  /// — already partway into the next track — by seeking the main player to
  /// match, so there is only ever one audible copy once this returns.
  Future<void> _finishCrossfade() async {
    final overlap = _overlapPlayer;
    final expected = _crossfadeExpectedSong;
    _crossfading = false;
    _crossfadeTotalMs = null;
    _crossfadeExpectedSong = null;
    if (overlap == null) {
      _finishingCrossfade = false;
      return;
    }
    try {
      if (expected != null && current?.id == expected.id) {
        await _player.seek(overlap.position);
      }
    } finally {
      await overlap.stop();
      _fade = 1;
      _finishingCrossfade = false;
      unawaited(_applyVolume());
    }
  }

  // --- Internals ------------------------------------------------------------

  void _onIndexChanged(int? i) {
    final wasCrossfading = _crossfading;
    _index = i;
    _plays.reset();
    final song = current;
    mediaItem.add(song == null ? null : _toMediaItem(song));
    _broadcastPlaybackState();
    notifyListeners();
    if (wasCrossfading) {
      // _finishCrossfade resets _fade and restores volume itself, only once
      // the handoff (seek + stopping the overlap player) actually completes.
      // Doing it here first would briefly play the new track from position 0
      // at full volume while that seek is still in flight.
      _finishingCrossfade = true;
      unawaited(_finishCrossfade());
    } else {
      _fade = 1;
      unawaited(_applyVolume());
    }
    if (song != null) {
      // Best effort: "now playing" ping; failures must never disturb playback.
      unawaited(
        _client?.scrobble(song.id, submission: false).catchError((Object _) {}),
      );
    }
  }

  /// Reflects the just_audio player's state to the OS media notification,
  /// lock screen, headset and Android Auto via [playbackState].
  void _broadcastPlaybackState() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _index,
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    unawaited(_overlapPlayer?.dispose());
    super.dispose();
  }
}
