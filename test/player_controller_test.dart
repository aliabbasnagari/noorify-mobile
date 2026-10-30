import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/settings/settings_models.dart';
import 'package:noorify/state/download_controller.dart';
import 'package:noorify/state/player_controller.dart';
import 'package:noorify/state/settings_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio_player.dart';

class _FakeDownloads extends DownloadController {
  _FakeDownloads(this.paths);

  final Map<String, String> paths;

  @override
  String? localPath(String songId) => paths[songId];
}

/// Every fake player the controller created, in creation order: the main
/// player first, then the crossfade overlap player once one is needed.
List<FakeAudioPlayer> players = [];

FakeAudioPlayer get primary => players.first;
FakeAudioPlayer get overlap => players[1];

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );

  late List<Uri> requests;
  late SettingsController settings;
  late PlayerController player;

  Song song(String id, {int duration = 10, ReplayGainInfo? replayGain}) => Song(
        id: id,
        title: 'Title $id',
        artist: 'Artist',
        duration: duration,
        replayGain: replayGain,
      );

  List<String> queueIds() => player.queueSongs.map((s) => s.id).toList();

  /// Updates the playback settings and waits for them to apply.
  Future<void> configure(
      PlaybackSettings Function(PlaybackSettings) change) async {
    await settings.updatePlayback(change);
    await pumpEventQueue();
  }

  Uri streamedUri(AudioSource s) => (s as UriAudioSource).uri;

  List<Uri> scrobbles({required bool submission}) => [
        for (final r in requests)
          if (r.path.endsWith('/rest/scrobble.view') &&
              r.queryParameters['submission'] == '$submission')
            r,
      ];

  setUp(() async {
    // Keep the Android-only effect pipeline (equalizer, loudness enhancer)
    // out of these tests; it needs the native plugin.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    players = [];
    requests = [];
    player = PlayerController(playerFactory: ({audioPipeline}) {
      final p = FakeAudioPlayer();
      players.add(p);
      return p;
    });
    player.attach(SubsonicClient(
      config,
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return http.Response(
          jsonEncode({
            'subsonic-response': {'status': 'ok'},
          }),
          200,
        );
      }),
    ));
    settings = SettingsController(await SharedPreferences.getInstance());
    player.attachSettings(settings);
    await pumpEventQueue();
    primary.volumes.clear();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    player.dispose();
  });

  group('queue', () {
    test('playSongs loads the queue, announces it and starts playing',
        () async {
      await player.playSongs([song('a'), song('b'), song('c')], index: 1);

      expect(queueIds(), ['a', 'b', 'c']);
      expect(player.currentIndex, 1);
      expect(player.current?.id, 'b');
      expect(player.queue.value.map((m) => m.id), ['a', 'b', 'c']);
      expect(player.mediaItem.value?.id, 'b');
      expect(primary.initialIndex, 1);
      expect(
          (primary.source as ConcatenatingAudioSource).children, hasLength(3));
      expect(primary.playing, isTrue);
    });

    test('playSongs with shuffle turns shuffle on and reshuffles', () async {
      await player.playSongs([song('a'), song('b')], shuffle: true);

      expect(primary.shuffleModeEnabled, isTrue);
      expect(primary.shuffleCalls, 1);
    });

    test('playSongs ignores an empty list', () async {
      await player.playSongs(const []);

      expect(player.hasQueue, isFalse);
      expect(primary.source, isNull);
    });

    test('playNext inserts right after the current song', () async {
      await player.playSongs([song('a'), song('b'), song('c')]);

      await player.playNext(song('d'));

      expect(queueIds(), ['a', 'd', 'b', 'c']);
      expect(player.queue.value.map((m) => m.id), ['a', 'd', 'b', 'c']);
      expect(
          (primary.source as ConcatenatingAudioSource).children, hasLength(4));
    });

    test('playNext and addToQueue start playback when the queue is empty',
        () async {
      await player.playNext(song('a'));
      expect(queueIds(), ['a']);
      expect(primary.playing, isTrue);

      await player.stop();
      await player.addToQueue(song('b'));
      expect(queueIds(), ['b']);
    });

    test('addToQueue appends to the end', () async {
      await player.playSongs([song('a'), song('b')]);

      await player.addToQueue(song('c'));

      expect(queueIds(), ['a', 'b', 'c']);
    });

    test('removeAt drops one entry and ignores bad indexes', () async {
      await player.playSongs([song('a'), song('b'), song('c')]);

      await player.removeAt(1);
      await player.removeAt(7);
      await player.removeAt(-1);

      expect(queueIds(), ['a', 'c']);
      expect(
          (primary.source as ConcatenatingAudioSource).children, hasLength(2));
    });

    test('move reorders the queue and its audio source together', () async {
      await player.playSongs([song('a'), song('b'), song('c')]);

      await player.move(0, 2);

      expect(queueIds(), ['b', 'c', 'a']);
      expect(player.queue.value.map((m) => m.id), ['b', 'c', 'a']);
      final children = (primary.source as ConcatenatingAudioSource).children;
      expect(
        children.map((c) => streamedUri(c).queryParameters['id']),
        ['b', 'c', 'a'],
      );
    });

    test('skipTo jumps to the index from the start and plays', () async {
      await player.playSongs([song('a'), song('b'), song('c')]);
      await player.pause();

      await player.skipTo(2);

      expect(primary.seeks.last.position, Duration.zero);
      expect(primary.seeks.last.index, 2);
      expect(primary.playing, isTrue);
    });

    test('stop clears the queue and reports idle', () async {
      await player.playSongs([song('a'), song('b')]);

      await player.stop();

      expect(player.hasQueue, isFalse);
      expect(player.current, isNull);
      expect(player.queue.value, isEmpty);
      expect(player.mediaItem.value, isNull);
      expect(player.playbackState.value.processingState,
          AudioProcessingState.idle);
      expect(player.playbackState.value.playing, isFalse);
    });
  });

  group('transport', () {
    test('previous restarts the track after 3 seconds, else goes back',
        () async {
      await player.playSongs([song('a'), song('b')], index: 1);

      primary.position = const Duration(seconds: 4);
      await player.previous();
      expect(primary.seeks.last.position, Duration.zero);
      expect(primary.seekToPreviousCalls, 0);

      primary.position = const Duration(seconds: 2);
      await player.previous();
      expect(primary.seekToPreviousCalls, 1);
    });

    test('cycleRepeat goes off, all, one, off', () async {
      await player.playSongs([song('a')]);

      await player.cycleRepeat();
      expect(player.loopMode, LoopMode.all);
      await player.cycleRepeat();
      expect(player.loopMode, LoopMode.one);
      await player.cycleRepeat();
      expect(player.loopMode, LoopMode.off);
    });

    test('toggleShuffle reshuffles when turning on', () async {
      await player.playSongs([song('a'), song('b')]);

      await player.toggleShuffle();
      expect(player.shuffleEnabled, isTrue);
      expect(primary.shuffleCalls, 1);

      await player.toggleShuffle();
      expect(player.shuffleEnabled, isFalse);
      expect(primary.shuffleCalls, 1);
    });

    test('togglePlay pauses and resumes', () async {
      await player.playSongs([song('a')]);
      expect(player.isPlaying, isTrue);

      await player.togglePlay();
      expect(player.isPlaying, isFalse);

      await player.togglePlay();
      expect(player.isPlaying, isTrue);
    });

    test('OS media-session callbacks drive the same queue as the UI', () async {
      await player.playSongs([song('a'), song('b'), song('c')]);

      await player.skipToNext();
      expect(primary.seekToNextCalls, 1);

      await player.skipToQueueItem(2);
      expect(primary.seeks.last.index, 2);

      await player.seek(const Duration(seconds: 5));
      expect(primary.seeks.last.position, const Duration(seconds: 5));

      await player.pause();
      expect(primary.playing, isFalse);
      await player.play();
      expect(primary.playing, isTrue);
    });
  });

  group('media session', () {
    test('playbackState mirrors the player', () async {
      await player.playSongs([song('a'), song('b')], index: 1);

      var state = player.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.queueIndex, 1);
      expect(state.controls.map((c) => c.action), contains(MediaAction.pause));
      expect(state.repeatMode, AudioServiceRepeatMode.none);
      expect(state.shuffleMode, AudioServiceShuffleMode.none);

      await player.cycleRepeat();
      await player.toggleShuffle();
      await player.pause();

      state = player.playbackState.value;
      expect(state.playing, isFalse);
      expect(state.controls.map((c) => c.action), contains(MediaAction.play));
      expect(state.repeatMode, AudioServiceRepeatMode.all);
      expect(state.shuffleMode, AudioServiceShuffleMode.all);
    });

    test('a track change updates the media item and sends a now-playing ping',
        () async {
      await player.playSongs([song('a'), song('b')]);
      requests.clear();

      primary.emitIndex(1);
      await pumpEventQueue();

      expect(player.mediaItem.value?.id, 'b');
      expect(player.current?.id, 'b');
      final pings = scrobbles(submission: false);
      expect(pings, hasLength(1));
      expect(pings.single.queryParameters['id'], 'b');
    });

    test('a counted play is reported once, after half the track', () async {
      await player.playSongs([song('a', duration: 10)]);
      primary.duration = const Duration(seconds: 10);
      requests.clear();

      // Listen continuously for 8 s of a 10 s track; half is 5 s.
      for (var s = 0; s <= 8; s++) {
        primary.emitPosition(Duration(seconds: s));
      }
      await pumpEventQueue();

      final plays = scrobbles(submission: true);
      expect(plays, hasLength(1));
      expect(plays.single.queryParameters['id'], 'a');
    });

    test('nothing is reported when the track is not actually playing',
        () async {
      await player.playSongs([song('a', duration: 10)]);
      primary.duration = const Duration(seconds: 10);
      await player.pause();
      requests.clear();

      for (var s = 0; s <= 8; s++) {
        primary.emitPosition(Duration(seconds: s));
      }
      await pumpEventQueue();

      expect(scrobbles(submission: true), isEmpty);
    });
  });

  group('sources', () {
    test('a downloaded song plays from its local file, others stream',
        () async {
      final dir = await Directory.systemTemp.createTemp('noorify_player_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.mp3')..writeAsBytesSync([1, 2, 3]);
      player.attachDownloads(_FakeDownloads({
        'a': file.path,
        // Indexed, but the file is gone: must fall back to streaming.
        'c': '${dir.path}/missing.mp3',
      }));

      await player.playSongs([song('a'), song('b'), song('c')]);

      final children = (primary.source as ConcatenatingAudioSource).children;
      expect(streamedUri(children[0]).scheme, 'file');
      expect(streamedUri(children[1]).path, endsWith('/rest/stream.view'));
      expect(streamedUri(children[2]).path, endsWith('/rest/stream.view'));
    });
  });

  group('volume', () {
    test('fade in ramps the volume up over the start of a track', () async {
      await configure((c) => c.copyWith(fadeInMs: 1000));
      await player.playSongs([song('a', duration: 10)]);
      primary.volumes.clear();

      primary.emitPosition(const Duration(milliseconds: 500));
      await pumpEventQueue();

      expect(primary.volumes.last, closeTo(0.5, 0.01));
    });

    test('fade out ramps the volume down over the end of a track', () async {
      await configure((c) => c.copyWith(fadeOutMs: 2000));
      await player.playSongs([song('a', duration: 10)]);
      primary.volumes.clear();

      primary.emitPosition(const Duration(seconds: 9));
      await pumpEventQueue();

      expect(primary.volumes.last, closeTo(0.5, 0.01));
    });

    test('ReplayGain attenuates the volume for a tagged track', () async {
      await configure((c) => c.copyWith(replayGain: ReplayGainMode.track));
      primary.volumes.clear();

      await player.playSongs([
        song('a', replayGain: const ReplayGainInfo(trackGain: -6)),
      ]);
      await pumpEventQueue();

      expect(primary.volumes.last, closeTo(0.501, 0.01));
    });
  });

  group('user volume', () {
    test('scales the playback volume and is remembered in the settings',
        () async {
      await player.playSongs([song('a')]);
      primary.volumes.clear();

      await player.setUserVolume(0.5);
      await pumpEventQueue();

      expect(primary.volumes.last, closeTo(0.5, 0.01));
      expect(player.userVolume, 0.5);
      expect(settings.playback.volume, 0.5);
    });

    test('mute silences playback and unmute restores the level', () async {
      await player.playSongs([song('a')]);
      await player.setUserVolume(0.6);
      await pumpEventQueue();

      await player.toggleMute();
      await pumpEventQueue();
      expect(player.isMuted, isTrue);
      expect(primary.volumes.last, 0);
      expect(player.userVolume, 0.6, reason: 'the level is kept while muted');

      await player.toggleMute();
      await pumpEventQueue();
      expect(player.isMuted, isFalse);
      expect(primary.volumes.last, closeTo(0.6, 0.01));
    });

    test('moving the volume while muted unmutes', () async {
      await player.playSongs([song('a')]);
      await player.toggleMute();
      await pumpEventQueue();

      await player.setUserVolume(0.3);
      await pumpEventQueue();

      expect(player.isMuted, isFalse);
      expect(primary.volumes.last, closeTo(0.3, 0.01));
    });

    test('values outside 0..1 are clamped', () async {
      await player.setUserVolume(4);
      expect(player.userVolume, 1);
      await player.setUserVolume(-1);
      expect(player.userVolume, 0);
    });

    test('multiplies with a fade rather than replacing it', () async {
      await configure((c) => c.copyWith(fadeInMs: 1000));
      await player.playSongs([song('a', duration: 10)]);
      await player.setUserVolume(0.5);
      await pumpEventQueue();
      primary.volumes.clear();

      primary.emitPosition(const Duration(milliseconds: 500));
      await pumpEventQueue();

      // Half way through the fade-in (0.5) at half user volume (0.5).
      expect(primary.volumes.last, closeTo(0.25, 0.01));
    });

    test('notifies listeners so a volume slider can follow it', () async {
      var notified = 0;
      player.addListener(() => notified++);

      await player.setUserVolume(0.7);
      await pumpEventQueue();

      expect(notified, greaterThan(0));
    });

    test('also applies to the incoming track during a crossfade', () async {
      await configure((c) => c.copyWith(crossfadeMs: 4000));
      await player.playSongs([song('a'), song('b')]);
      await player.setUserVolume(0.5);
      await pumpEventQueue();

      primary.emitPosition(const Duration(milliseconds: 6500));
      await pumpEventQueue();
      primary.emitPosition(const Duration(seconds: 8));
      await pumpEventQueue();

      // Half way through the overlap both sit at 0.5 of a 0.5 user volume.
      expect(primary.volumes.last, closeTo(0.25, 0.01));
      expect(overlap.volumes.last, closeTo(0.25, 0.01));
    });
  });

  group('crossfade', () {
    const nearEnd = Duration(milliseconds: 6500); // 3.5 s left of 10 s

    setUp(() => configure((c) => c.copyWith(crossfadeMs: 4000)));

    test('overlaps the next track, ramps both volumes, then hands off',
        () async {
      await player.playSongs([song('a'), song('b'), song('c')]);

      primary.emitPosition(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(players, hasLength(1), reason: 'too early to crossfade');

      primary.emitPosition(nearEnd);
      await pumpEventQueue();
      expect(players, hasLength(2));
      expect(streamedUri(overlap.source!).queryParameters['id'], 'b');
      expect(overlap.volumes.first, 0);
      expect(overlap.playing, isTrue);

      // Halfway through the 4 s overlap both players sit at half volume.
      primary.volumes.clear();
      primary.emitPosition(const Duration(seconds: 8));
      await pumpEventQueue();
      expect(primary.volumes.last, closeTo(0.5, 0.01));
      expect(overlap.volumes.last, closeTo(0.5, 0.01));

      // The main player's gapless engine advances; the overlap hands over.
      overlap.position = const Duration(seconds: 3);
      primary.emitIndex(1);
      await pumpEventQueue();

      expect(primary.seeks.last.position, const Duration(seconds: 3));
      expect(overlap.stopCalls, 1);
      expect(primary.volumes.last, 1);
    });

    test('is not used while shuffling', () async {
      await player.playSongs([song('a'), song('b')]);
      primary.shuffleModeEnabled = true;

      primary.emitPosition(nearEnd);
      await pumpEventQueue();

      expect(players, hasLength(1));
    });

    test('has nothing to overlap on the last track without repeat', () async {
      await player.playSongs([song('a')]);

      primary.emitPosition(nearEnd);
      await pumpEventQueue();

      expect(players, hasLength(1));
    });

    test('with repeat-all the last track overlaps the first', () async {
      await player.playSongs([song('a'), song('b')], index: 1);
      primary.loopMode = LoopMode.all;

      primary.emitPosition(nearEnd);
      await pumpEventQueue();

      expect(players, hasLength(2));
      expect(streamedUri(overlap.source!).queryParameters['id'], 'a');
    });

    test('a manual skip mid-crossfade stops the overlap without seeking',
        () async {
      await player.playSongs([song('a'), song('b'), song('c')]);
      primary.emitPosition(nearEnd);
      await pumpEventQueue();
      expect(players, hasLength(2));
      primary.emitPosition(const Duration(seconds: 8));
      await pumpEventQueue();
      expect(primary.volumes.last, closeTo(0.5, 0.01));
      primary.seeks.clear();

      // The user jumped to "c", not the expected "b".
      primary.emitIndex(2);
      await pumpEventQueue();

      expect(primary.seeks, isEmpty);
      expect(overlap.stopCalls, 1);
      expect(primary.volumes.last, 1);
    });

    test('stop() during a crossfade silences the overlap player', () async {
      await player.playSongs([song('a'), song('b')]);
      primary.emitPosition(nearEnd);
      await pumpEventQueue();

      await player.stop();

      expect(overlap.stopCalls, 1);
    });
  });
}
