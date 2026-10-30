# Noorify - Asynchronous Programming in Dart

## 1. Overview

Noorify is written in Dart/Flutter, not Kotlin, so it has no coroutines,
`suspend` functions, or `Dispatchers`. Dart's concurrency model is a
single-threaded event loop per isolate: `async`/`await`, `Future`, and
`Stream` are the only tools *app code* uses for asynchronous work. There is
no `Isolate` or `compute()` call anywhere app-authored in `lib/` — every
network call, file I/O operation, and settings persistence op runs
interleaved on the app's single (main) isolate. The one exception, entirely
internal to a dependency, is the local database — see §2a.

## 2. Dart's Event Loop vs. Kotlin Coroutines

| Concept | Kotlin | Dart (Noorify) |
|---|---|---|
| Unit of concurrency | Coroutine (cooperative, scheduled onto threads via a `Dispatcher`) | `Future`/`async` function body (cooperative, scheduled onto one isolate's event loop) |
| True parallelism | Coroutines can run on a thread pool (`Dispatchers.IO`, etc.) | Only across separate `Isolate`s, each with its own memory — **not used in this codebase** |
| Cancellation | `Job`/`CoroutineScope` cancellation | No built-in cancellation for `Future`; this codebase guards against stale work with identity checks instead (see §5) |
| Streams of values over time | `Flow` | `Stream` (used extensively — see §3) |
| Fire-and-forget | `scope.launch { }` | `unawaited(future)` (see §4) |

In practice: a single Dart isolate runs one microtask/event-loop queue.
`await`ing a `Future` yields control back to that loop rather than blocking a
thread, which is enough for everything Noorify currently does (network
requests, file I/O, timers) because none of it is CPU-bound.

## 2a. The One Background Isolate: `drift_flutter`

`lib/data/local/app_database.dart`'s `AppDatabase` opens its connection with
`driftDatabase(name: 'noorify_library')` from the `drift_flutter` package.
That helper spawns and owns a background isolate to host the actual SQLite
connection (`Isolate.spawn` inside `drift_flutter`'s `native.dart`), and
every query from `AppDatabase` is transparently proxied to it — `await
db.loadSongs(owner)` still reads like ordinary single-isolate `async`/`await`
from call sites in `SyncController`, but the SQL itself doesn't run on the
main isolate. This is dependency-internal plumbing, not an app-authored
`Isolate.spawn`/`compute()` call, and it doesn't change anything about how
`SyncController`/`DownloadController` are written — it's mentioned here only
so §1's "no Isolate usage" claim doesn't quietly become wrong.

## 3. Streams: `PlayerController`'s Core Wiring

`PlayerController` (`lib/state/player_controller.dart`) is built almost
entirely around subscribing to `just_audio`'s streams and converting them
into `ChangeNotifier` updates. All subscriptions are collected in one list so
they can be torn down together:

```dart
final List<StreamSubscription<Object?>> _subs = [];

PlayerController() {
  _player = AudioPlayer(/* ... */);
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
  // Finer than the default 200ms so fades (and crossfade) are smooth.
  _subs.add(
    _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 50),
          maxPeriod: const Duration(milliseconds: 100),
        )
        .listen(_updateFade),
  );
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
```

The position stream is intentionally polled more frequently
(50–100ms instead of `just_audio`'s default ~200ms) because it drives both
the fade-in/fade-out volume ramp and the crossfade ramp (`_updateFade`, see
`03-AUDIO-DECODING-FFMPEG.md` §5), which need finer granularity than UI
progress-bar updates would. `_broadcastPlaybackState()` (new since the
`audio_service` migration) pushes the same state to the OS media session on
every one of these events — see `05-AUDIO-HARDWARE-INTEGRATION.md` §2.

## 4. `unawaited()` and `scheduleMicrotask()`

Noorify uses `unawaited()` (from `dart:async`, via `package:flutter/foundation.dart`'s
re-export) wherever a `Future` is deliberately started without the caller
waiting for it — typically because the operation is best-effort and must
never block or fail playback:

```dart
void _onIndexChanged(int? i) {
  final wasCrossfading = _crossfading;
  _index = i;
  _fade = 1;
  if (wasCrossfading) unawaited(_finishCrossfade());
  final song = current;
  mediaItem.add(song == null ? null : _toMediaItem(song));
  _broadcastPlaybackState();
  notifyListeners();
  unawaited(_applyVolume());
  if (song != null) {
    // Best effort: "now playing" ping; failures must never disturb playback.
    unawaited(
      _client?.scrobble(song.id, submission: false).catchError((Object _) {}),
    );
  }
}
```

(`wasCrossfading`/`_finishCrossfade()` are the crossfade handoff described in
`03-AUDIO-DECODING-FFMPEG.md` §5.1; `mediaItem.add`/`_broadcastPlaybackState()`
are the `audio_service` broadcasts from `05-AUDIO-HARDWARE-INTEGRATION.md`
§2 — both fit naturally into this same event-driven callback, no extra
concurrency machinery needed.)

`scheduleMicrotask()` is used once, to defer applying settings changes that
might otherwise be triggered from inside a Flutter `build()`/Provider update:

```dart
void _onSettingsChanged() {
  // Deferred: this can be reached from a provider update during build.
  scheduleMicrotask(() => unawaited(_applySettings()));
}
```

Neither pattern spawns a thread or an isolate — both simply control *when*,
within the single event loop, a `Future` starts running.

## 5. Guarding Against Stale Async Work

Because there's no structured-concurrency scope to cancel (unlike a Kotlin
`CoroutineScope`), controllers that run multi-step async sequences guard
themselves by re-checking identity after every `await`, so that a session
change mid-operation doesn't let a stale result overwrite current state.
`SyncController.sync()` (`lib/state/sync_controller.dart`) pages the whole
library this way:

```dart
Future<void> sync() async {
  final client = _client;
  final owner = _owner;
  if (client == null || owner == null || _syncing) return;
  _syncing = true;
  notifyListeners();
  try {
    final byId = <String, Song>{};
    var offset = 0;
    while (true) {
      final page = await withRetry(
        () => client.getSongsPage(offset: offset, size: _pageSize, query: query),
      );
      // ... accumulate page ...
      if (!identical(client, _client)) return; // session changed mid-sync
      await _db.upsertSongs(owner, page); // durable even if sync is interrupted later
      if (page.length < _pageSize || byId.length == before) break;
      offset += _pageSize;
    }
    if (!identical(client, _client)) return;
    _songs = byId.values.toList();
    _lastSync = DateTime.now();
    await _db.replaceSongs(owner, _songs); // drops rows for songs removed server-side
    await _db.setLastSync(owner, _lastSync!);
  } on Object catch (e) {
    _error = e;
  } finally {
    _syncing = false;
    notifyListeners();
  }
}
```

The `while (true)` loop keeps `await`ing the next page until the server
returns a short page or stops yielding new IDs — there's no fixed page count,
and the loop is the only thing standing in for what a coroutine's structured
`for` + suspend would do in Kotlin. `withRetry()` (§7a) now wraps the one
`await` that can transiently fail; the `identical(client, _client)` checks
are unchanged from before and still do all the "session changed mid-flight"
guarding.

## 6. Manual Concurrency Limiting: The Download Queue

`DownloadController` (`lib/state/download_controller.dart`) needs bounded
parallelism (at most a couple of downloads in flight at once) without any
coroutine dispatcher or thread pool to lean on. It implements this with a
small hand-rolled job queue built from plain `Future`s:

```dart
static const _maxConcurrent = 2;
final List<_Job> _pending = [];
final Map<String, _Job> _active = {};
int _running = 0;

void _pump() {
  while (_running < _maxConcurrent && _pending.isNotEmpty) {
    final job = _pending.removeAt(0);
    _active[job.song.id] = job;
    _running++;
    unawaited(_run(job).whenComplete(() {
      _running--;
      notifyListeners();
      _pump(); // pull the next job once a slot frees up
    }));
  }
}
```

Each job streams its HTTP response body chunk by chunk into a file, with UI
progress notifications throttled to roughly 1% steps so `notifyListeners()`
isn't called on every chunk:

```dart
await for (final chunk in response.stream) {
  sink.add(chunk);
  received += chunk.length;
  if (total > 0) {
    final p = received / total;
    if (p - (_progress[song.id] ?? 0) > 0.01) {
      _progress[song.id] = p;
      notifyListeners();
    }
  }
}
```

This all still runs on the single main isolate — "concurrency" here means
multiple in-flight `Future`s interleaved on one event loop (bounded by
`_maxConcurrent`), not parallel execution on separate threads.

## 7. Error Handling Convention

Rather than coroutine exception propagation or a `Result` type, Noorify's
controllers consistently wrap best-effort async work in a broad
`on Object catch (e)` so that one failure (a dropped connection, a device
without audio effects, a corrupt cache file) can't crash playback or the UI:

```dart
Future<void> _applySettings() async {
  final p = _playback;
  try {
    // ...
  } on Object catch (e) {
    // Effects are best-effort; a device without them must still play.
    debugPrint('Applying audio settings failed: $e');
  }
}
```

The same pattern appears when loading a possibly-corrupt local cache
(`SyncController._load()`, `DownloadController._load()`): a failure is
swallowed and treated as "nothing cached yet" rather than propagated. This is
a deliberate app-wide convention, not Dart-enforced — it shows up because
background-ish operations (sync, settings, cache loads) should degrade
gracefully rather than surface to the user as a hard failure.

## 7a. Retrying Transient Failures: `withRetry()`

`lib/util/retry.dart` is a small, generic helper used by both
`SyncController` (page fetches) and `DownloadController` (each download
attempt) to tell a *transient* failure (a dropped mobile connection) apart
from a real one, without pulling in a retry/backoff package for one function:

```dart
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } on Object {
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(initialDelay * (1 << (attempt - 1)));
    }
  }
}
```

This is the same "cooperative, single-isolate" style as everything else in
this doc — `Future<void>.delayed` yields back to the event loop rather than
blocking anything, and doubling the delay each attempt (`1 << (attempt - 1)`:
500ms, 1s, 2s by default) is plain arithmetic, not a scheduler feature. It
deliberately retries *any* exception uniformly rather than classifying
network-vs-server errors — simpler, and bounded to a worst case of a few
seconds of extra latency before a real failure (e.g. a bad song id) still
surfaces. `DownloadController._run()` wraps its retry around a whole download
attempt (`_attemptDownload`, which truncates and re-writes the `.part` file
from byte 0 each time) rather than trying to resume a partial transfer — there
is no resume support, so "retry" means "start this attempt over."

## 8. State Propagation: `ChangeNotifier` + `provider`

All of the above eventually calls `notifyListeners()`, which is how async
work results reach the UI. Widgets subscribe with `context.watch<T>()` (to
rebuild on change) or read once with `context.read<T>()` (to call a method
without subscribing). There's no separate "post to main thread" step the way
Kotlin coroutines need `Dispatchers.Main` — Dart's single isolate means
`notifyListeners()` called from inside an `await`ed callback already runs on
the same event loop Flutter's widget tree lives on.

## 9. If Noorify Ever Needs Real Parallelism

None of Noorify's *app-authored* work is CPU-bound enough to need it, but
Dart's escape hatch for genuine parallel execution is spawning a separate
`Isolate` (or the `compute()` helper, which does this for a single function
call). As of this codebase, no app code does this directly — the only
background isolate in the app is the one `drift_flutter` manages internally
for `AppDatabase` (§2a), which already keeps `SyncController`'s database
reads/writes off the main isolate without any app-authored isolate code.
`DownloadController`'s JSON encode/decode of its download index (`index.json`)
is small enough that it still happens inline on the main isolate.
