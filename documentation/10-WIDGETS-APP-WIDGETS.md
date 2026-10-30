# Noorify - Home Screen Widgets (Not Yet Implemented)

## 1. Current State

Noorify has **no home screen widget support today**. This was verified directly
against the codebase:

- `pubspec.yaml` declares no widget-related package (no `home_widget`, no
  platform-channel widget bridge of any kind).
- `android/app/src/main/` contains only Flutter's stock generated files —
  `MainActivity.kt` (unmodified Flutter template) and
  `GeneratedPluginRegistrant.java`. There is no `AppWidgetProvider`, no widget
  `BroadcastReceiver`, and no `res/xml` widget-info declaration.
- There is no iOS WidgetKit extension target in `ios/`.

Anything below is a design reference for **if/when** this feature gets built,
not a description of existing functionality.

## 2. Why This Isn't a Simple Port

A native app (e.g. one written directly in Kotlin/Swift) can render a
home-screen widget as part of its own UI toolkit. Flutter cannot: home-screen
widgets are rendered by the host OS outside the Flutter engine, so Flutter can
only **supply data** to a native widget surface that still has to be built per
platform:

- **Android**: a real `AppWidgetProvider` (or a Jetpack Glance composable) and
  its widget-info XML, living in `android/app/src/main/kotlin/...` and
  `android/app/src/main/res/xml/`.
- **iOS**: a genuine WidgetKit extension target, written in Swift, added as a
  separate target in the Xcode project under `ios/`.

The standard cross-platform bridge for this in the Flutter ecosystem is the
[`home_widget`](https://pub.dev/packages/home_widget) package: the Dart side
calls `HomeWidget.saveWidgetData(...)` and `HomeWidget.updateWidget(...)` to
push data and trigger a refresh, but the native widget UI itself still has to
be written natively on each platform — `home_widget` does not generate it.
Noorify does not currently depend on this package or any equivalent.

## 3. Data Already Available for a Future Widget

If a now-playing widget were built, `PlayerController`
(`lib/state/player_controller.dart`) already exposes everything a simple
read-only widget would need:

| Data | Source |
|---|---|
| Current track | `PlayerController.current` (`Song?`) |
| Playing/paused | `PlayerController.isPlaying` |
| Position / duration | `PlayerController.positionStream` / `durationStream` |
| Cover art URL | `PlayerController.coverUri(song.coverArt)` |

Transport controls are also already implemented in Dart (`togglePlay()`,
`next()`, `previous()`), but wiring a *tap on a home-screen widget* back into
these calls is the hard part: it requires either

- a native widget action (Android `PendingIntent` / iOS `App Intent`) that
  wakes the Flutter engine in the background to execute a method-channel call,
  or
- a small amount of playback state/command handling duplicated natively so
  simple actions (play/pause/skip) work even when the Flutter isolate isn't
  running.

Neither exists today. This is a real engineering effort per platform, not a
configuration change.

## 4. If This Gets Built: A Starting Sketch

A reasonable first widget, scoped small:

- **Now Playing (small/medium)**: cover art, track title/artist, and a
  play/pause tap target. Read-only otherwise (no scrubbing, no skip) to avoid
  the background-wake complexity described above for a first version.
- Update triggered from `PlayerController` whenever `current`/`isPlaying`
  changes, pushed via `home_widget`'s `saveWidgetData` + `updateWidget`.
- Android: an `AppWidgetProvider` (or Glance) reading the pushed data.
- iOS: a WidgetKit `TimelineProvider` reading the same pushed data via the
  shared app-group container `home_widget` uses.

Resizable layouts, shortcut widgets, and interactive transport controls (the
kind native Symfonium offers) would be a later iteration once the basic
read-only widget and its native scaffolding exist on both platforms.
