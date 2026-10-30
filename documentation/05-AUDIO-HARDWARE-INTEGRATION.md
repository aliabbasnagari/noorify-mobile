# Noorify - Audio Hardware & Platform Integration

## 1. Overview

Noorify does not implement any custom native audio-hardware integration. What
it gets — system media-session controls, headset/Bluetooth media-button
handling, basic audio routing — comes for free from `just_audio` +
`audio_service` and the host OS. There is no custom Bluetooth receiver, no
USB-audio path, no Wear OS companion, no Chromecast/DLNA integration, and no
Android Auto browsable library tree in this codebase. This doc describes
what's real today and, separately, what a contributor would reach for to add
the rest.

## 2. System Media Session (what's actually wired up)

`PlayerController` *is* the `audio_service` `AudioHandler` —
`class PlayerController extends BaseAudioHandler with SeekHandler,
ChangeNotifier` (`lib/state/player_controller.dart`) — not a wrapper around
one. `main.dart` constructs it through `AudioService.init` before the app
runs, and that single instance is then handed to `provider` like any other
controller:

```dart
final playerController = await AudioService.init(
  builder: () => PlayerController(),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'app.noorify.playback',
    androidNotificationChannelName: 'Noorify playback',
    androidNotificationOngoing: true,
  ),
);
// ...
ChangeNotifierProxyProvider3<SessionController, SettingsController,
    DownloadController, PlayerController>(
  create: (_) => playerController,
  update: (_, session, settings, downloads, player) => player!
    ..attach(session.client)
    ..attachSettings(settings)
    ..attachDownloads(downloads),
),
```

This is the entire "hardware integration" surface: `audio_service` registers
a foreground media-playback service and media-button receiver, which
Flutter's tooling merges into `android/app/src/main/AndroidManifest.xml`. The
manifest entries are unchanged from before this migration — they were already
`audio_service`'s own native classes, since the previous `just_audio_background`
dependency was itself a thin Dart-only wrapper around `audio_service` with no
native code of its own:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Background playback + media notification (audio_service). -->
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
    </intent-filter>
</service>

<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</receiver>
```

Nothing here is app-authored Kotlin — `AudioService` and
`MediaButtonReceiver` ship inside the `audio_service` plugin. On the Dart
side, `PlayerController` broadcasts state to them via three things it
overrides/pushes from `BaseAudioHandler`:

- `play()` / `pause()` / `seek(Duration)` / `skipToNext()` /
  `skipToPrevious()` / `skipToQueueItem(int)` — overridden to delegate
  straight to the existing `_player`/queue methods, so there is exactly one
  code path for "in-app button" vs. "notification/lock-screen/headset/Android
  Auto button."
- `mediaItem`/`queue` (the `BehaviorSubject`s `audio_service` exposes) — pushed
  from `_toMediaItem(Song)` whenever the queue or current index changes, so
  the notification/lock-screen art, title and artist always match what's
  playing.
- `playbackState` — rebuilt in `_broadcastPlaybackState()` on every
  `playerStateStream`/`loopModeStream`/`shuffleModeEnabledStream`/
  `currentIndexStream` event, mapping `just_audio`'s `ProcessingState`/
  `LoopMode`/shuffle flag onto `audio_service`'s
  `AudioProcessingState`/`AudioServiceRepeatMode`/`AudioServiceShuffleMode`.

Through this, the app gets:

- A lock-screen / notification transport (play, pause, skip, seek) — see
  above.
- Hardware media-button handling — a wired headset button or a Bluetooth
  headset's play/pause/next button reaches `PlayerController` via
  `MediaButtonReceiver` → `BaseAudioHandler.click()`'s default
  play/pause/skip routing, exactly like any other Android media app.
- Audio-focus bookkeeping handled by `just_audio` itself: `AudioPlayer`
  defaults to `handleInterruptions: true`, which configures an
  `AudioSessionConfiguration.music()` `audio_session` and auto-pauses on a
  phone call/other app's audio and on "becoming noisy" (headphones
  unplugged), resuming afterward — no app-level `AudioFocusRequest` or
  `audio_session` configuration code was needed.
- On iOS/macOS, the equivalent system now-playing / Control Center /
  lock-screen integration via `AVAudioSession` + `MPNowPlayingInfoCenter`,
  again managed by the plugin, not by app code.
- Android Auto's "now playing" transport controls (play/pause/skip/seek) work
  out of the box through the same `AudioHandler` — see §4 for what's still
  missing for a full browsable library tree.

Bluetooth audio output itself (A2DP, codec selection, pairing) is handled
entirely by the OS's Bluetooth stack before audio ever reaches the app —
Noorify just plays to "the active output device," whatever the OS currently
routes to (speaker, wired headset, or a paired Bluetooth device).

## 3. What This Codebase Does NOT Implement

Be explicit about this rather than assuming parity with native Symfonium:

| Area | Status |
|------|--------|
| Custom Bluetooth connection-state handling | Not implemented — no `BroadcastReceiver`/platform-channel code; relies entirely on OS + plugin defaults |
| USB audio (class-compliant DACs, bit-perfect output) | Not implemented |
| DSD / direct digital output | Not implemented (no DSD support at all, see [03](03-AUDIO-DECODING-FFMPEG.md)) |
| Chromecast / DLNA / cast renderers | Not implemented |
| Android Auto | Now-playing transport (play/pause/skip/seek) works via the `AudioHandler` (§2); a browsable library tree (`getChildren`/`subscribeToChildren`) is not implemented, so Auto can control playback but can't browse artists/albums/playlists from the car head unit |
| Wear OS companion | Not implemented |
| Low-latency / pro-audio output modes | Not implemented — whatever latency `just_audio`'s backend defaults to |
| Device-specific handling (foldables, DeX, etc.) | Not implemented — standard responsive Flutter layout only |

None of these are stubbed out or half-built; they simply don't exist yet. Any
of the native snippets in the previous revision of this doc (custom
`BtHeadsetReceiver`, `UsbAttachProxyActivity`, `ChromecastOptionsProvider`,
`PhoneWearableListenerService`, etc.) described Symfonium's native Kotlin
implementation, not Noorify's.

## 4. Where to Look If You're Adding One of These

If a future contributor wants to add real hardware integration, the
Flutter-ecosystem entry points are:

- **Bluetooth device/state awareness**: a plugin like `flutter_blue_plus` (for
  BLE) is unrelated to A2DP audio routing; for *audio-route* awareness
  specifically, `just_audio`'s own `handleInterruptions`/`audio_session`
  handling (§2) already covers the common pause/duck cases. True custom
  profile handling would require a platform channel into Android's
  `BluetoothA2dp`/`AudioDeviceCallback` APIs.
- **USB/DSD audio**: there is no mature cross-platform Flutter plugin for
  USB-audio-class output; this would require a custom Android platform
  channel (via `AudioTrack`/`AudioDeviceInfo`) and has no iOS equivalent
  (iOS doesn't expose USB-audio-class host mode the same way).
- **Android Auto (browsable library)**: the `MediaBrowserService`/transport
  plumbing already exists (§2) and Auto can already play/pause/skip/seek;
  what's missing is overriding `PlayerController.getChildren`/
  `subscribeToChildren` to expose a browsable tree (e.g. Home shelves, Library,
  playlists) — the server data is already there via `SubsonicClient`, this is
  purely a matter of mapping it onto `audio_service`'s `MediaItem` browse API.
- **Chromecast**: would need a dedicated plugin (e.g. a Cast SDK wrapper) —
  none is in `pubspec.yaml` today.

In every case, the right move is a Flutter plugin or platform channel scoped
to the feature, not a return to native-first architecture.
