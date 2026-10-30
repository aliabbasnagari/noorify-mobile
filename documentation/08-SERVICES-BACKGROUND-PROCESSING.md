# Noorify - Background Processing & Playback Session

## 1. Overview

Noorify is a Flutter app. It has no custom native Android Services, no
BroadcastReceivers, and no background Kotlin/Swift components of its own —
`android/app/src/main/kotlin/app/noorify/noorify/MainActivity.kt` only
extends `com.ryanheise.audioservice.AudioServiceActivity` (so the media
notification can reopen the app), which is itself part of the `audio_service`
plugin, not app-authored logic. Every background-ish capability the app has
comes from a Dart-level controller plus one plugin (`audio_service`) that
talks to the OS media-session APIs on its behalf.

There is no `SyncService`, `DownloaderService`, or `WebServerService`, and no
`WorkManager`-style scheduled background work. Library sync and downloads
only progress while the app process is alive (foreground or, on Android,
while the playback notification keeps the process around — see §3).

## 2. What Actually Runs in the Background

| Capability | Mechanism | Survives app being killed? |
|---|---|---|
| Audio playback + lock-screen/notification controls | `audio_service` (`PlayerController` is its `AudioHandler`) | Yes, while the OS keeps the playback notification/session alive |
| Library sync (`SyncController`) | Async paging loop on the main isolate, each page retried with backoff | No — only while the app process is running |
| Downloads (`DownloadController`) | `http` streaming on the main isolate, each attempt retried with backoff | No — only while the app process is running |
| Offline-collection re-sync | Triggered on load, not scheduled | No — runs once per app start/attach |
| Local database queries (`AppDatabase`, drift) | Runs on a background isolate that `drift_flutter` manages internally | N/A — not a long-running background task, just where the SQLite connection lives (see `11-THREADING-COROUTINES-ASYNC.md` §2a) |

There is no custom work-scheduling layer: nothing here uses `WorkManager`,
`BGTaskScheduler`, or platform channels. The one exception to "no Isolates" is
`drift_flutter`, which spawns and manages its own background isolate to host
the SQLite connection (see `11-THREADING-COROUTINES-ASYNC.md` §2a) — that's
internal to the database package, not app-authored background work, and
doesn't change anything about the table above (it's not a scheduled job,
just where queries execute). If a download or sync is in progress and the
app process is terminated, it simply stops and resumes (from scratch, or from
its last saved index/database rows) the next time the relevant controller is
attached.

## 3. Playback Session: `PlayerController` as the `AudioHandler`

Noorify's only real "service" is the media session that `audio_service` sets
up — and `PlayerController` is the handler driving it directly, not a plugin
wrapped around a separate player object:

```dart
class PlayerController extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  // ...
}
```

It's constructed once, in `lib/main.dart`, through `AudioService.init` before
`runApp` — this is what replaces the old `JustAudioBackground.init(...)` call:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final playerController = await AudioService.init(
    builder: () => PlayerController(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.noorify.playback',
      androidNotificationChannelName: 'Noorify playback',
      androidNotificationOngoing: true,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(/* ... MultiProvider with playerController passed through, see §4 ... */);
}
```

`AudioService.init` is responsible for everything a hand-rolled
`MediaBrowserService`/`ExoPlayer`/`MediaSession` stack would otherwise need
on Android, and the iOS/macOS equivalent (`AVAudioSession` + remote command
center) on Apple platforms:

- A foreground/ongoing notification with transport controls (play/pause/
  skip), driven by `androidNotificationOngoing: true`.
- Lock-screen and headset/Bluetooth media-button controls, and Android Auto's
  now-playing transport.
- Keeping the Android process alive as a foreground service while audio is
  playing, so playback survives the app being backgrounded.

`PlayerController` supplies both the metadata and the transport logic itself.
Each queue entry is wrapped in a `MediaItem` tag when its `AudioSource` is
built, and pushed to `audio_service`'s `mediaItem`/`queue` streams whenever
the queue or current index changes, so the notification/lock-screen populate
from the same data as the in-app UI:

```dart
MediaItem _toMediaItem(Song s) => MediaItem(
      id: s.id,
      title: s.title,
      album: s.album,
      artist: s.artist,
      duration: s.duration > 0 ? Duration(seconds: s.duration) : null,
      artUri: coverUri(s.coverArt),
    );

AudioSource _toSource(Song s) {
  final tag = _toMediaItem(s);
  final local = _downloads?.localPath(s.id);
  if (local != null && File(local).existsSync()) {
    return AudioSource.file(local, tag: tag);
  }
  return AudioSource.uri(client.streamUrl(s.id), tag: tag);
}
```

Transport commands that arrive from the notification, lock screen, Android
Auto, or a Bluetooth headset are routed by `audio_service` straight into
`BaseAudioHandler` overrides that delegate to the same `AudioPlayer`/queue
methods the in-app UI calls:

```dart
@override
Future<void> play() => _player.play();
@override
Future<void> pause() => _player.pause();
@override
Future<void> seek(Duration position) => _player.seek(position);
@override
Future<void> skipToNext() => next();
@override
Future<void> skipToPrevious() => previous();
@override
Future<void> skipToQueueItem(int index) => skipTo(index);
```

There's no separate code path for "in-app" vs. "external" controls — and no
separate `AudioSession` configuration either: `just_audio`'s `AudioPlayer`
defaults to `handleInterruptions: true`, which already configures a
music-category `audio_session`, pauses/resumes for phone calls and other
apps' audio, and pauses on "becoming noisy" (headphones unplugged), all
without any code in this app.

## 4. Controller Wiring: Session-Driven, Not Lifecycle-Driven

Rather than Android `Service` lifecycles (`onCreate`/`onStartCommand`/
`onDestroy`), Noorify's background-ish controllers are plain
`ChangeNotifier`s wired together with `provider` in `lib/main.dart`. Each one
exposes an `attach(SubsonicClient?)` method, and a `ChangeNotifierProxyProvider`
re-invokes it whenever the active session changes (login, logout, or restore
on app start):

```dart
ChangeNotifierProxyProvider<SessionController, SyncController>(
  create: (_) => SyncController(),
  update: (_, session, sync) => sync!..attach(session.client),
),
ChangeNotifierProxyProvider<SessionController, DownloadController>(
  create: (_) => DownloadController(),
  update: (_, session, downloads) => downloads!..attach(session.client),
),
ChangeNotifierProxyProvider3<SessionController, SettingsController,
    DownloadController, PlayerController>(
  // playerController was already built by AudioService.init in main() (§3);
  // create here just hands Provider that existing instance.
  create: (_) => playerController,
  update: (_, session, settings, downloads, player) => player!
    ..attach(session.client)
    ..attachSettings(settings)
    ..attachDownloads(downloads),
),
```

`SessionController` (`lib/state/session_controller.dart`) owns the single
`SubsonicClient?` for the logged-in server and calls `notifyListeners()` after
`restore()`, `login()`, and `logout()`. That's the only trigger that
re-attaches the other controllers — there's no separate background-task
lifecycle to reason about. `attach()` is cheap and idempotent
(`if (identical(_client, client)) return;`), so a Provider rebuild for an
unrelated reason doesn't restart sync or reload downloads.

`PlayerController.dispose()` is the one real cleanup hook, and it only runs
when the provider itself is torn down (i.e. the app is shutting down), not on
every login/logout:

```dart
@override
void dispose() {
  _settings?.removeListener(_onSettingsChanged);
  for (final s in _subs) {
    s.cancel();
  }
  _player.dispose();
  super.dispose();
}
```

## 5. Downloads and Sync Are Not Scheduled Jobs

`DownloadController` (`lib/state/download_controller.dart`) and
`SyncController` (`lib/state/sync_controller.dart`) both do their work as
plain `Future`-based async code triggered by `attach()` or an explicit user
action (`downloadSongs`, `sync`, `refreshCollections`) — not as scheduled
background jobs. See
[11-THREADING-COROUTINES-ASYNC.md](11-THREADING-COROUTINES-ASYNC.md) for how
that async code is actually structured (the manual concurrency-limited
download queue, the paging loop, stream subscriptions, etc.).

Practically, this means:

- Starting a download or a library sync and then killing the app stops that
  work; it resumes next time (downloads re-queue from the persisted
  `index.json`; sync re-pages from scratch).
- There is no Android `WorkManager` entry, no iOS `BGAppRefreshTask`, and no
  periodic background sync — everything is user- or session-triggered.
- Offline-collection re-sync (`DownloadController.refreshCollections()`) runs
  once, when a `SubsonicClient` is attached — not on a timer.

## 6. What Would Be Needed to Go Further

If Noorify ever needs real OS-scheduled background work (e.g. periodic
library sync even while the app is closed), the Flutter-ecosystem path would
be a plugin like `workmanager` (Android `WorkManager` + iOS
`BGTaskScheduler`) invoking a Dart callback in a background isolate. No such
plugin is in `pubspec.yaml` today, and no background isolate entry point
exists in the codebase — this section is a pointer for future work, not a
description of anything implemented.
