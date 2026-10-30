import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/audio/equalizer_presets.dart';
import 'package:noorify/audio/replay_gain.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/settings/settings_models.dart';

void main() {
  group('replayGainDb', () {
    const info = ReplayGainInfo(
      trackGain: -7,
      albumGain: -5,
      trackPeak: 0.9,
      albumPeak: 1.0,
      fallbackGain: -3,
    );

    test('off is always 0 dB', () {
      expect(replayGainDb(info, ReplayGainMode.off, 6), 0);
    });

    test('track and album modes pick their own gain plus pre-amp', () {
      expect(replayGainDb(info, ReplayGainMode.track, 0), -7);
      expect(replayGainDb(info, ReplayGainMode.album, 2), -3);
    });

    test('falls back to the other gain, then fallbackGain', () {
      expect(
          replayGainDb(
              const ReplayGainInfo(albumGain: -4), ReplayGainMode.track, 0),
          -4);
      expect(
          replayGainDb(
              const ReplayGainInfo(fallbackGain: -3), ReplayGainMode.album, 0),
          -3);
      expect(replayGainDb(const ReplayGainInfo(), ReplayGainMode.album, 0), 0);
    });

    test('untagged tracks only get the pre-amp', () {
      expect(replayGainDb(null, ReplayGainMode.track, 1.5), 1.5);
    });

    test('positive gain is limited so the peak does not clip', () {
      const loud = ReplayGainInfo(trackGain: 6, trackPeak: 0.5);
      // Headroom for a 0.5 peak is about 6.02 dB.
      expect(replayGainDb(loud, ReplayGainMode.track, 0), closeTo(6.0, 0.1));
      const hot = ReplayGainInfo(trackGain: 6, trackPeak: 0.9);
      expect(replayGainDb(hot, ReplayGainMode.track, 0), closeTo(0.915, 0.01));
    });
  });

  test('dbToVolume attenuates and never exceeds 1', () {
    expect(dbToVolume(0), 1);
    expect(dbToVolume(6), 1);
    expect(dbToVolume(-20), closeTo(0.1, 1e-9));
    expect(dbToVolume(-6), closeTo(math.pow(10, -6 / 20), 1e-9));
  });

  group('equalizer projection', () {
    test('same length is returned as is', () {
      expect(projectGains([1, 2, 3], 3), [1, 2, 3]);
    });

    test('interpolates onto more bands and keeps the endpoints', () {
      final g = projectGains([0, 10], 5);
      expect(g.first, 0);
      expect(g.last, 10);
      expect(g[2], closeTo(5, 1e-9));
    });

    test('down-samples and handles degenerate input', () {
      expect(projectGains([0, 4, 8], 2), [0, 8]);
      expect(projectGains([], 5), List.filled(5, 0.0));
      expect(projectGains([3, 6], 1), [3]);
    });

    test('every preset has five anchor points', () {
      for (final p in eqPresets) {
        expect(p.gains, hasLength(5), reason: p.name);
      }
    });
  });

  group('settings serialization', () {
    test('playback settings round-trip', () {
      const s = PlaybackSettings(
        replayGain: ReplayGainMode.album,
        preAmpDb: -2.5,
        fadeInMs: 1500,
        fadeOutMs: 3000,
        crossfadeMs: 4000,
        skipSilence: true,
        eqEnabled: true,
        eqGains: [1, -2, 0, 3, 0],
      );
      final copy = PlaybackSettings.fromJson(s.toJson());
      expect(copy.toJson(), s.toJson());
    });

    test('missing or invalid values use safe defaults', () {
      final s = PlaybackSettings.fromJson({'replayGain': 'bogus'});
      expect(s.replayGain, ReplayGainMode.off);
      expect(s.fadeInMs, 0);
      expect(s.crossfadeMs, 0);
      expect(s.eqGains, isEmpty);
    });

    test('home layout keeps stored order and adds new rows', () {
      final layout = HomeLayout.fromJson({
        'rows': [
          {'id': 'random', 'visible': false, 'count': 10},
          {'id': 'removed-in-this-version'},
          {'id': 'recent'},
        ],
      });
      expect(layout.rows.map((r) => r.id).take(2), ['random', 'recent']);
      expect(layout.rows.first.visible, isFalse);
      expect(layout.rows.first.count, 10);
      expect(layout.rows.map((r) => r.id),
          isNot(contains('removed-in-this-version')));
      // Rows missing from storage come back with defaults.
      expect(layout.rows.map((r) => r.id), containsAll(homeRowTitles.keys));
    });
  });

  test('Song JSON round-trips including ReplayGain', () {
    final song = Song(
      id: '1',
      title: 'T',
      genre: 'Jazz',
      playCount: 4,
      starred: true,
      created: DateTime.utc(2026, 1, 2),
      replayGain: const ReplayGainInfo(trackGain: -6.5, trackPeak: 0.98),
    );
    final copy = Song.fromJson(song.toJson());
    expect(copy.genre, 'Jazz');
    expect(copy.starred, isTrue);
    expect(copy.created, DateTime.utc(2026, 1, 2));
    expect(copy.replayGain?.trackGain, -6.5);
    expect(copy.replayGain?.trackPeak, 0.98);
  });
}
