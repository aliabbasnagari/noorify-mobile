/// Decides when a track has been listened to for long enough to be reported to
/// the server as a play (Subsonic `scrobble` with `submission: true`).
///
/// A play counts once the listener has heard half the track or four minutes of
/// it, whichever comes first. Only continuous forward playback is counted, so
/// seeking ahead doesn't earn credit, and a track that restarts (repeat one, or
/// a seek back to the start) can be counted again.
class PlayTracker {
  static const _maxStep = Duration(seconds: 2);
  static const _restartWindow = Duration(seconds: 2);
  static const _cap = Duration(minutes: 4);

  int _listenedMs = 0;
  int? _lastPositionMs;
  bool _reported = false;

  /// Starts counting afresh, e.g. when the current track changes.
  void reset() {
    _listenedMs = 0;
    _lastPositionMs = null;
    _reported = false;
  }

  /// Feed every position update. Returns true exactly once per play, when the
  /// threshold is crossed.
  bool onPosition(int positionMs,
      {required int? durationMs, required bool playing}) {
    final last = _lastPositionMs;
    _lastPositionMs = positionMs;
    if (last == null) return false;

    final delta = positionMs - last;
    if (delta < 0 && positionMs < _restartWindow.inMilliseconds) {
      // Looped or restarted: a new play begins.
      _listenedMs = 0;
      _reported = false;
      return false;
    }
    if (!playing || delta <= 0 || delta > _maxStep.inMilliseconds) return false;

    _listenedMs += delta;
    if (_reported) return false;

    final half = durationMs != null && durationMs > 0 ? durationMs ~/ 2 : null;
    final threshold = half == null
        ? _cap.inMilliseconds
        : (half < _cap.inMilliseconds ? half : _cap.inMilliseconds);
    if (_listenedMs < threshold) return false;
    _reported = true;
    return true;
  }
}
