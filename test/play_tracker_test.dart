import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/audio/play_tracker.dart';

void main() {
  /// Plays [seconds] of a track in 1 s steps starting at [from], returning how
  /// many times the tracker reported a play.
  int listen(
    PlayTracker t, {
    required int seconds,
    int from = 0,
    int? durationMs = 200000,
    bool playing = true,
  }) {
    var reports = 0;
    for (var s = 0; s <= seconds; s++) {
      if (t.onPosition((from + s) * 1000,
          durationMs: durationMs, playing: playing)) {
        reports++;
      }
    }
    return reports;
  }

  test('reports once after half the track has been heard', () {
    final t = PlayTracker();
    expect(listen(t, seconds: 90, durationMs: 200000), 0);
    // 100 s is half of a 200 s track; keep listening continuously past it.
    expect(listen(t, from: 91, seconds: 60, durationMs: 200000), 1);
  });

  test('long tracks are reported after four minutes, not half', () {
    final t = PlayTracker();
    // 20 minute track: half would be 10 minutes, the cap is 4.
    expect(listen(t, seconds: 230, durationMs: 1200000), 0);
    expect(listen(t, from: 231, seconds: 30, durationMs: 1200000), 1);
  });

  test('unknown duration falls back to the four minute cap', () {
    final t = PlayTracker();
    expect(listen(t, seconds: 230, durationMs: null), 0);
    expect(listen(t, from: 231, seconds: 20, durationMs: null), 1);
  });

  test('paused time does not count', () {
    final t = PlayTracker();
    expect(listen(t, seconds: 150, playing: false), 0);
  });

  test('seeking ahead does not earn credit', () {
    final t = PlayTracker();
    t.onPosition(0, durationMs: 200000, playing: true);
    t.onPosition(1000, durationMs: 200000, playing: true);
    // Jump to 150 s: far more than one polling step.
    expect(t.onPosition(150000, durationMs: 200000, playing: true), isFalse);
    expect(t.onPosition(151000, durationMs: 200000, playing: true), isFalse);
  });

  test('reset starts a new track from zero', () {
    final t = PlayTracker();
    expect(listen(t, seconds: 150), 1);
    t.reset();
    expect(listen(t, seconds: 50), 0);
  });

  test('a restart or repeat-one loop can be reported again', () {
    final t = PlayTracker();
    expect(listen(t, seconds: 150), 1);
    // Position wraps back to the start, as it does under repeat one.
    expect(listen(t, seconds: 150), 1);
  });
}
