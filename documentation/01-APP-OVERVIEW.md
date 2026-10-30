# Noorify - App Overview

## 1. Application Information

| Property | Value |
|----------|-------|
| Package (pubspec) | `noorify` |
| Version | 0.1.0+1 |
| Dart SDK | `>=3.4.0 <4.0.0` |
| Flutter SDK | `>=3.41.0` |
| Android `applicationId` | `app.noorify.noorify` |
| iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER` | `app.noorify.noorify` |
| App Category | Audio / Music Player (Subsonic / OpenSubsonic client) |
| Target Platforms | Android, iOS, macOS, Windows, Linux (web scaffold present) |

Noorify is **not** a local-library player: it is a client for Subsonic- and
OpenSubsonic-compatible music servers (e.g. Navidrome). The server is the
source of truth for the library, metadata and tags; the app never scans local
files or edits tags itself.

## 2. Key Features (present in the code today)

### 2.1 Playback
- **Engine**: [`just_audio`](https://pub.dev/packages/just_audio) for
  decoding/transport, layered under
  [`audio_service`](https://pub.dev/packages/audio_service) for the OS media
  session. `just_audio` delegates decoding to the platform's native player
  (ExoPlayer on Android, AVPlayer on iOS/macOS) — Noorify bundles no custom
  codec or FFmpeg build of its own.
- **Background playback / media session**: `PlayerController`
  (`lib/state/player_controller.dart`) *is* the `AudioHandler` —
  `class PlayerController extends BaseAudioHandler with SeekHandler,
  ChangeNotifier` — registered once via `AudioService.init(builder: () =>
  PlayerController(), ...)` in `main.dart`. There is no separate handler class
  wrapping the player; the same controller drives in-app UI, the Android
  notification/lock-screen, headset buttons and Android Auto's transport
  controls.
- **Queue management**: `ConcatenatingAudioSource`-backed queue (play, play
  next, add to queue, reorder, remove) in `PlayerController`, mirrored to
  `audio_service`'s `queue`/`mediaItem` streams on every mutation.
- **Gapless-style transport**: shuffle, repeat (off/all/one), seek, "restart
  vs. previous" logic.
- **Crossfade**: a real overlapping crossfade (0–12s, off by default) between
  *sequential* (non-shuffled) tracks — see §2.2.
- **Offline-first streaming**: the queue prefers a locally downloaded file
  over the network stream URL when one exists (`DownloadController.localPath`).

### 2.2 Sound Processing
- **Equalizer**: Android-only, via `just_audio`'s `AndroidEqualizer` native
  audio effect; presets are defined and interpolated in pure Dart
  (`lib/audio/equalizer_presets.dart`) onto however many bands the device
  reports.
- **ReplayGain**: computed and applied in pure Dart
  (`lib/audio/replay_gain.dart`) as a volume attenuation, with positive gain
  realised through `AndroidLoudnessEnhancer` (Android-only) since player
  volume tops out at 1.0.
- **Fades**: software volume ramp at track start/end, driven off the position
  stream in `PlayerController`. In the final `crossfadeMs` of a track (when
  crossfade is enabled), this fade is superseded by the crossfade ramp below.
- **Crossfade**: a second, lazily-created `AudioPlayer` ramps in the next
  *sequential* track while the main player ramps out, then a position-synced
  seek hands playback back to the main player once its own gapless engine
  naturally advances — so there is only ever one audible copy. Known
  limitation: EQ, the loudness enhancer and ReplayGain only apply once a
  track has handed off to the main player, so the incoming track plays
  briefly unprocessed during the overlap window. Shuffled playback falls
  back to the plain edge fade (no crossfade peek-ahead across a shuffled
  order).
- **Skip silence**: toggles `just_audio`'s native skip-silence flag
  (Android/ExoPlayer only).
- Not implemented: parametric EQ/shelves, limiter/compressor, bass
  boost/virtualizer/crossfeed, DSD or bit-perfect USB output (`just_audio`
  itself has no Android effect classes for bass boost/virtualizer to wrap).

### 2.3 Library, Playlists & Sync
- **Subsonic/OpenSubsonic client**: `lib/subsonic/subsonic_client.dart` — REST
  calls over `http`, MD5 token authentication, JSON responses. Covers
  browsing, playlists, star/scrobble, genres, similar/top songs, bookmarks,
  structured lyrics, internet radio stations, and OpenSubsonic capability
  negotiation — see `09-API-CLIENT-DATA-MODELS.md` for the full method table.
- **Library sync**: `lib/state/sync_controller.dart` pages the server's whole
  song list and stores it in a local **SQLite database** (via
  [`drift`](https://pub.dev/packages/drift), `lib/data/local/app_database.dart`)
  scoped by account (`owner = <server url>|<username>`), so smart playlists
  can be evaluated on-device without re-querying the server each time. Each
  page is upserted as it arrives (so a sync interrupted partway through still
  leaves useful data), and the fetch itself retries with backoff on failure
  (`lib/util/retry.dart`) rather than aborting the whole sync on one dropped
  request.
- **Smart playlists**: `lib/smart/smart_filter.dart` is a pure-Dart rule
  engine (fields, operators, nested AND/OR groups, sort, limit) evaluated
  against the synced library cache.

### 2.4 Offline Downloads
- `lib/state/download_controller.dart` streams originals via the Subsonic
  `download` endpoint straight to disk (`path_provider`'s app-support
  directory), with a JSON index for persistence, up to 2 concurrent
  downloads, and per-song "kept because" source tracking (manual vs. an
  offline-pinned album/playlist). Each download attempt retries with backoff
  (`lib/util/retry.dart`) before being marked failed.
- Implemented in plain Dart/`http`; there is no native download manager,
  `WorkManager`, or background-transfer integration, so downloads only
  progress while the app process is alive.

### 2.5 Settings & Session
- **State management**: `provider` — `ChangeNotifier` controllers
  (`PlayerController`, `SessionController`, `SettingsController`,
  `DownloadController`, `SyncController`, `SmartPlaylistStore`) exposed via
  `MultiProvider`/`ChangeNotifierProvider` and consumed with
  `context.watch`/`context.read`.
- **Credentials**: stored with `flutter_secure_storage`.
- **Preferences**: persisted with `shared_preferences`.
- **Home layout**: configurable, re-orderable home-screen rows (Recently
  played, Newly added, Most played, Discover, Favorites) via
  `lib/settings/settings_models.dart`'s `HomeLayout`.

### 2.6 User Interface
- **Material 3** throughout (`lib/app.dart`), with the same Spotify-exact
  palette and flow as the `ui/` web app: explicit black/`#121212`/`#282828`
  dark and white/`#F6F6F6` light `ColorScheme`s (not `ColorScheme.fromSeed`),
  `#1DB954` green as `primary` in both, Manrope (`google_fonts`) as the text
  theme, and a user-selectable theme mode (system/light/dark, default dark)
  — see [07-UI-DESIGN-SYSTEM.md](07-UI-DESIGN-SYSTEM.md) for the full spec,
  now fully implemented.
- **Navigation**: `HomeShell` (`lib/ui/home_shell.dart`) — a 3-tab
  Home/Search/Library `NavigationBar` (Spotify's own mobile nav shape) with a
  persistent `MiniPlayer` above it. Library is a "Your Library" hub: section
  tiles (Albums/Artists/Songs/Downloads/Smart Playlists) plus the server
  playlist list, which used to be its own `Playlists` tab.
- **Mini player / Now Playing**: spinning circular art that freezes on
  pause, a thin green progress line, a single filled play/pause button
  (`lib/ui/widgets/mini_player.dart`); a dominant-color hero gradient behind
  the Now Playing screen's content, extracted from the cover art via
  `palette_generator` and cached per track (`lib/ui/widgets/art_hero_background.dart`).
  `SongTile` shows an animated `PlayingBars` indicator in place of the track
  number for whichever row is currently playing.
- **Art**: `cached_network_image` for album/artist art served from the
  Subsonic `getCoverArt` endpoint.

## 3. Architecture Overview

```
lib/
├── app.dart                      # MaterialApp, theming, root routing (_Root)
├── main.dart                     # Entry point, provider wiring
├── models/
│   └── models.dart                # Song/Album/Artist/Playlist/Genre/
│                                   #  RadioStation/Bookmark/StructuredLyric
├── subsonic/
│   └── subsonic_client.dart       # Subsonic/OpenSubsonic REST client
├── data/
│   └── local/
│       ├── app_database.dart      # drift database (SongEntries, SyncStates)
│       └── app_database.g.dart    # drift codegen output (build_runner)
├── settings/
│   └── settings_models.dart       # PlaybackSettings, HomeLayout, HomeRowConfig
├── smart/
│   └── smart_filter.dart          # Smart-playlist rule engine
├── audio/
│   ├── equalizer_presets.dart     # EQ preset bands + interpolation
│   └── replay_gain.dart           # ReplayGain -> volume/dB math
├── util/
│   └── retry.dart                 # withRetry() exponential-backoff helper
├── state/                         # ChangeNotifier controllers (Provider)
│   ├── player_controller.dart     # Queue + transport + sound settings +
│   │                               #  AudioHandler (audio_service)
│   ├── session_controller.dart    # Login/session restore
│   ├── settings_controller.dart   # Settings persistence
│   ├── download_controller.dart   # Offline downloads
│   ├── sync_controller.dart       # Library sync -> local SQLite (drift)
│   └── smart_playlist_store.dart  # Saved smart playlists
└── ui/
    ├── home_shell.dart            # 3-tab (Home/Search/Library) shell + MiniPlayer
    ├── login_page.dart
    ├── pages/                     # One file per screen: album/artist/song
    │                               #  list pages, library hub, downloads,
    │                               #  equalizer, home/search tabs, now
    │                               #  playing, queue, settings, smart
    │                               #  filter editor
    └── widgets/                   # Reusable widgets: song tile, cover art,
                                    #  mini player, playing bars, art hero
                                    #  background, offline switch, ...
```

Platform folders (`android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`)
are the stock Flutter project scaffolding — there is no app-authored native
Kotlin, Swift, or NDK/JNI code. The one line that isn't Flutter's own default
template is `MainActivity.kt` extending `audio_service`'s
`AudioServiceActivity` instead of `FlutterActivity` directly (so the media
notification can reopen the app) — that class ships inside the plugin, not
hand-written here.

## 4. External Dependencies (`pubspec.yaml`)

| Package | Purpose |
|---------|---------|
| `provider` | App-wide state management (`ChangeNotifier` + `InheritedWidget`) |
| `http` | REST calls to the Subsonic/OpenSubsonic server |
| `crypto` | MD5 token hashing for Subsonic auth |
| `just_audio` | Cross-platform audio playback engine |
| `audio_service` | OS media session/notification, lock screen, headset buttons, Android Auto — `PlayerController` is its `AudioHandler` |
| `drift` / `drift_flutter` | Local SQLite database (library sync cache) |
| `google_fonts` | Manrope text theme (pinned `^8.0.0`, see 07-UI-DESIGN-SYSTEM.md §2.4) |
| `palette_generator` | Dominant-color extraction for the Now Playing hero background (discontinued upstream but still resolves/analyzes cleanly) |
| `cached_network_image` | Cached album/artist art loading |
| `flutter_secure_storage` | Secure credential storage |
| `rxdart` | Stream composition utilities |
| `shared_preferences` | Lightweight key-value settings persistence |
| `path_provider` | Filesystem paths for the offline-download cache |

Dev-only: `drift_dev` + `build_runner` generate `app_database.g.dart`;
`sqlite3` backs an in-memory database in tests (`test/app_database_test.dart`).

## 5. Not Implemented (do not assume these exist)

- Local file scanning or on-device tag editing.
- Custom native audio decoding (FFmpeg, DSD, bit-perfect USB).
- Home-screen widgets (Android App Widgets / iOS WidgetKit).
- Chromecast/DLNA/UPnP renderers.
- A native background sync or download service distinct from the Flutter
  process lifecycle.
