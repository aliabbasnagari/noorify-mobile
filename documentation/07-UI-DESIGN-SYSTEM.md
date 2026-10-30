# Noorify - UI & Design System

## 1. Overview

Noorify's UI is built entirely with Flutter's stock **Material 3** widgets —
there is no bespoke design-system package, no custom theming DSL, and no
platform-native UI (no Jetpack Compose, no SwiftUI). A small set of shared
widgets (cover art, song rows, the mini player, an offline toggle) are reused
across pages; everything else is composed directly from `Scaffold`, `ListView`,
`AppBar`, `ListTile` and friends. State flows into the widget tree through
`provider`'s `ChangeNotifier` controllers.

**Design direction.** The `ui/` web app has already been re-themed to be
visually almost identical to Spotify (see `ui/src/index.css`,
`ui/src/components/theme-provider.tsx` and the components referenced
throughout this doc). The mobile app follows the same palette and the same
UX flow. **All 8 items of the implementation checklist in §11 are now done.**
Sections below still use **Today**/**Target** headings as they did while this
was a forward-looking spec; "Today" now means the implemented state, and
"Target" sub-sections describe what was built to satisfy them. Section 2.1 is
kept only as a before/after diff baseline — it no longer describes the
running app.

## 2. Theming

### 2.1 Before (kept as a diff baseline only)

This was `lib/app.dart` (`NoorifyApp`) before the rework in §2.2-2.4; it no
longer matches the code:

```dart
MaterialApp(
  title: 'Noorify',
  themeMode: ThemeMode.system,
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF7C4DFF)),
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(0xFF7C4DFF),
      brightness: Brightness.dark,
    ),
  ),
  home: const _Root(),
)
```

A single purple seed (`0xFF7C4DFF`) feeds Material 3's automatic tonal-palette
generator for both light and dark, following `ThemeMode.system` with no
in-app override.

### 2.2 Implemented: Spotify-exact palette

Spotify's palette is **hand-authored swatches**, not a seed-generated tonal
ramp — `ColorScheme.fromSeed` can't reproduce it, because a seed algorithm
derives every other color from one hue and Spotify's dark surfaces
(`#000000` → `#121212` → `#282828`) are flat steps of near-black, not
chroma-derived tones. `lib/app.dart` now builds two `ColorScheme`s explicitly
(via `ColorScheme.dark()`/`.light()` with overrides), using the exact hex
values already chosen for `ui/` (`ui/src/index.css`) so the two apps match
pixel for pixel in spirit:

| Token (web CSS var) | Dark value | Light value | Flutter `ColorScheme` field |
|---|---|---|---|
| `--background` | `#000000` | `#FFFFFF` | `scaffoldBackgroundColor` / `colorScheme.surface` (base) |
| `--card` | `#121212` | `#F6F6F6` | `colorScheme.surfaceContainer` (cards, sheets, the mini player) |
| `--popover` | `#282828` | `#FFFFFF` | `colorScheme.surfaceContainerHigh` (menus, dialogs, bottom sheets that float above a card) |
| `--primary` | `#1DB954` | `#1DB954` | `colorScheme.primary` (same green in both themes — Spotify's brand color doesn't change with theme) |
| `--primary-foreground` | `#000000` | `#000000` | `colorScheme.onPrimary` (black icon/text on the green play button, same in both themes) |
| `--foreground` | `#FFFFFF` | `#0A0A0A` | `colorScheme.onSurface` |
| `--muted-foreground` | `#A7A7A7` | `#6A6A6A` | secondary text (track subtitles, timestamps) — closest Material slot is `colorScheme.onSurfaceVariant` |
| `--secondary` | `#282828` | `#EFEFEF` | `colorScheme.secondaryContainer` (chips, selected row backgrounds) |
| `--destructive` | `#F15E6C` | `#D1293D` | `colorScheme.error` |
| `--border` | ~10% white | ~10% black | `colorScheme.outlineVariant` |

```dart
const _spotifyGreen = Color(0xFF1DB954);

final darkScheme = ColorScheme.dark(
  surface: Colors.black,
  surfaceContainer: const Color(0xFF121212),
  surfaceContainerHigh: const Color(0xFF282828),
  primary: _spotifyGreen,
  onPrimary: Colors.black,
  onSurface: Colors.white,
  onSurfaceVariant: const Color(0xFFA7A7A7),
  secondaryContainer: const Color(0xFF282828),
  error: const Color(0xFFF15E6C),
  outlineVariant: Colors.white.withValues(alpha: 0.10),
);

final lightScheme = ColorScheme.light(
  surface: Colors.white,
  surfaceContainer: const Color(0xFFF6F6F6),
  surfaceContainerHigh: Colors.white,
  primary: _spotifyGreen,
  onPrimary: Colors.black,
  onSurface: const Color(0xFF0A0A0A),
  onSurfaceVariant: const Color(0xFF6A6A6A),
  secondaryContainer: const Color(0xFFEFEFEF),
  error: const Color(0xFFD1293D),
  outlineVariant: Colors.black.withValues(alpha: 0.10),
);
```

Dark stays the default theme (matching `ui/`'s "Dark (Spotify-exact, default)"
comment in `theme-provider.tsx`), but unlike the web app's Solarized pair,
there's no need to port Solarized to mobile unless asked — just Dark + Light.

### 2.3 Implemented: manual theme switching, not just `ThemeMode.system`

The web app lets the user pick a theme explicitly (`theme-provider.tsx`
wraps `next-themes`; light/dark/Solarized are all selectable, independent of
the OS setting). The mobile app matches that with a `AppThemeMode` enum
(`system`/`light`/`dark`, no Solarized) in `lib/settings/settings_models.dart`,
persisted by `SettingsController` (default: `dark`) and exposed as a
segmented-button picker in `settings_page.dart`'s new "Appearance" section.
`NoorifyApp` maps it onto Flutter's own `ThemeMode` for `MaterialApp`.

### 2.4 Typography

`ui/` uses Geist Variable (`@fontsource-variable/geist`), a clean geometric
sans close in spirit to Spotify's own (non-licensable) Circular typeface.
Flutter has no bundled equivalent — the default is the platform system font
(Roboto/San Francisco). `lib/app.dart` now sets `GoogleFonts.manropeTextTheme()`
as the app's `textTheme` (Manrope, a comparable geometric sans) rather than
shipping Geist's font files directly (no official Flutter-ready distribution
of Geist exists). `google_fonts` is pinned to `^8.0.0` (see the comment in
`pubspec.yaml` for the two separate reasons neither side of that range
works): 9.0.0 depends on the separate `material_ui` package, whose
`TextTheme` is a distinct type from this Flutter SDK's own
`package:flutter/material.dart` `TextTheme` and fails to type-check against
it; versions below 8.0.0 (e.g. 6.2.1) compile fine for native/VM targets
(`flutter analyze`/`flutter test` won't catch it) but fail an actual
`flutter build web` — they use `FontWeight` as a literal key in a top-level
`const` map, and dart2js rejects `FontWeight`'s non-trivial `operator ==` as
not "primitive" enough for const-map canonicalization. Both are worth
re-checking when upgrading Flutter or `google_fonts`.

### 2.5 Root widget

`_Root` (also in `app.dart`) watches `SessionController` and switches between
three states: a centered `CircularProgressIndicator` while a saved session is
being restored, `LoginPage` when signed out, and `HomeShell` when signed in.
Unchanged by the theming work above.

## 3. Navigation

### 3.1 Before (kept as a diff baseline only)

`lib/ui/home_shell.dart` used to be a single `Scaffold` with an
`IndexedStack` of **four** tabs (Home, Library, Playlists, Search) under a
Material `NavigationBar`, and a `MiniPlayer` docked above it.

### 3.2 Implemented: Spotify's 3-tab mobile flow

`ui/`'s `MobileTabBar` (`ui/src/components/layout/mobile-tab-bar.tsx`)
documents the reasoning this was ported from: *"Spotify's own mobile web nav
is exactly these three tabs (Home/Search/Your Library) — everything else
(Albums/Artists/Songs/Radio/Playlists) lives inside the Library tab rather
than each getting its own bottom-bar slot, which wouldn't fit at phone width
anyway."* `home_shell.dart` now has three tabs:

| Index | Destination | Page |
|---|---|---|
| 0 | Home | `HomeTab` (unchanged) |
| 1 | Search | `SearchTab` (unchanged) |
| 2 | Your Library | `LibraryTab`, restructured into the hub below |

`PlaylistsTab` is no longer a top-level destination — the file was deleted;
its content (server playlists + the "new playlist" action) now lives inside
`LibraryTab`.

### 3.3 Implemented: "Your Library" hub

Ported from the pattern in `ui/src/pages/library-page.tsx`: a header ("Your
Library"), a small grid of section tiles, and a list of the user's playlists
below with a "create playlist" action. `LibraryTab` is now a `ListView` whose
first child is a `GridView` (2 columns — the full `grid-cols-2
sm:grid-cols-4` responsive breakpoint wasn't ported, since phone width is the
only target so far) of tappable tiles pushing to the new `AlbumListPage`,
`ArtistListPage`, `SongListPage` (also new — the first UI consumer of
`SyncController`'s library cache beyond smart playlists), `DownloadsPage` and
`SmartPlaylistsView`, followed by the server playlist list `playlists_tab.dart`
used to own. There is no Radio tile/page yet — `SubsonicClient` already has
`getInternetRadioStations()` etc. (see `09-API-CLIENT-DATA-MODELS.md`), but
wiring a station into `PlayerController`'s queue (which expects a `Song`
resolved to a Subsonic `stream` URL, not an arbitrary external stream URL)
is real playback-engine work, deliberately deferred rather than half-built
alongside a navigation rework.

### 3.4 Drill-down routing

Still `Navigator.of(context).push(MaterialPageRoute(...))` for album, artist,
playlist, queue, settings, etc. — no named-route table or router package.
What changed: `HomeShell` now gives each of the 3 tabs its own nested
`Navigator` (keyed by a `GlobalKey<NavigatorState>`, one per tab, wrapping
`IndexedStack`'s children) instead of one Navigator for the whole shell.
This was needed because with a single shared Navigator, pushing *any* page
covered the `MiniPlayer`/`NavigationBar` below it, not just the full-screen
Now Playing route — so browsing into an album made the mini player
disappear. `Navigator.of(context).push(...)` calls throughout the app are
unchanged and automatically resolve to the correct tab's own Navigator (the
nearest ancestor), so no call site needed to change. The system back button
is handled by a `PopScope` in `HomeShell`: pop the active tab's own stack
first, then fall back to the Home tab, then exit.

One consequence worth knowing: `showDialog` defaults to the *root* Navigator
but `showModalBottomSheet` defaults to the *nearest* one — now a tab-local
Navigator for anything opened from inside a tab. Anywhere a bottom sheet in
turn opens a dialog (`showAddToPlaylistSheet`'s "New playlist" prompt) both
calls now explicitly pass `useRootNavigator: true` so they share one
Navigator/Overlay hierarchy; mixing the two hierarchies there caused a
cross-navigator Flutter framework assertion in practice. Keep this in mind
before adding a new sheet-that-opens-a-dialog flow.

## 4. The mini player and Now Playing screen

### 4.1 Before (kept as a diff baseline only)

`MiniPlayer` used to be a static compact bar with previous/play-pause/next
buttons, a 2px `LinearProgressIndicator`, and a square cover. `now_playing_page.dart`
was a plain full-screen view: art, transport controls, a position slider, no
background treatment.

### 4.2 Implemented: Spotify's mini player

Ported from `ui/src/components/layout/player-bar.tsx`'s mobile block
(`player-bar-mobile`) — checked directly against that component's source,
not just inferred, which turned up one correction from this doc's earlier
draft (below):

- A **2px progress line** spanning the full width, directly above the bar
  content, filled from 0% to `currentTime / duration` in the primary green
  (the default `LinearProgressIndicator` color under the new §2.2 scheme) —
  not a slider.
- **Spinning cover art**: a circular cover image that rotates continuously
  (one full turn every 12s) while playing, and **freezes at its current
  angle** on pause (not reset to upright) — an `AnimationController` driving
  a `RotationTransition`, started/stopped (not reset) via `repeat()`/`stop()`,
  with a `ValueKey(song.id)` so a new track's art starts upright.
- Title (truncated, one line) + artist (truncated, muted color) next to the
  art; tapping the row opens the full Now Playing screen.
- A single circular **play/pause button**, and — the correction — its icon is
  colored `colorScheme.surface` (the `--background` token: white in light
  mode, black in dark), **not** `colorScheme.onPrimary`. The live component
  explicitly overrides the button's default `text-primary-foreground` with
  `text-background`/`fill-background` on the icon itself; this doc's original
  draft assumed `onPrimary` (black in both themes) without checking that.
- **No previous/next buttons** — the actual mobile bar in `ui/` only ever
  renders art+text (as a tap target) and the one play/pause button; this
  doc's original draft implied they existed ("everywhere else ... uses plain
  icons") but the live component has no "everywhere else" to speak of. Full
  transport is one tap away via Now Playing.

This whole bar sits exactly where `MiniPlayer` sat before (above the
`NavigationBar`), composing directly with the §3 navigation change.

### 4.3 Implemented: Now Playing hero background

Ported from `ui/src/components/library/art-hero-background.tsx` +
`ui/src/lib/color-extraction.ts` (also used on the web's album/artist detail
pages, not only Now Playing — porting it there too would be a natural, small
follow-up): extract the dominant, saturation-weighted color from the current
cover art and render a vertical gradient from that color down to the theme
background, behind the Now Playing content. Two details worth porting
exactly:

- **Weighting, not a plain average** on the web: pixels are weighted by
  `saturation² + 0.05` before averaging RGB (see `dominantColorFromPixels` in
  `color-extraction.ts`), so a busy or desaturated cover still yields a color
  that reads as "vibrant" rather than muddy grey, skipping near-transparent
  pixels (`alpha < 200`). The Flutter port (`ArtHeroBackground` in
  `lib/ui/widgets/art_hero_background.dart`) uses `palette_generator`'s own
  swatch selection instead of re-implementing that exact formula —
  `vibrantColor ?? dominantColor ?? mutedColor` — per the recommendation
  below; the two algorithms aim at the same "vibrant, not muddy" result but
  aren't pixel-identical.
- **No jank on navigation**: a neutral gradient is visible immediately, and
  the tinted layer cross-fades in via opacity once the color is ready/cached
  — never a blank flash while extraction runs.

`palette_generator` (`PaletteGenerator.fromImageProvider`) is the standard
Flutter equivalent of the web's canvas-pixel-sampling approach, used instead
of hand-rolling pixel math in Dart; the extracted `Color` is cached per
cover-art URL in an in-memory `Map<String, Color?>` (mirroring the web's
`cache` map) so revisiting a track never redoes the extraction. Note:
`palette_generator` is marked discontinued on pub.dev but still resolves and
analyzes cleanly against the Flutter SDK this project uses — worth
re-checking on a future Flutter upgrade.

## 5. "Currently playing" indicator

### 5.1 Implemented: animated equalizer bars

Ported from `ui/src/components/library/playing-bars.tsx`: wherever a song row
would show a track number, the row for the track currently loaded in the
player instead shows three thin vertical bars in the primary color,
animating up and down while playing, frozen at 25% height when paused.
`PlayingBars` (`lib/ui/widgets/playing_bars.dart`) uses a single looping
`AnimationController` and a sine wave with a per-bar phase offset rather than
three separately-delayed CSS keyframe animations — same continuous
stagger-and-pulse feel, a simpler Flutter-native mechanism to get there. It's
swapped in for the track-number `Text` in `SongTile` whenever that row's song
id matches `PlayerController.current?.id`, driven by `PlayerController.isPlaying`
so it freezes (rather than keeps pulsing) when that track is current but
paused.

## 6. Shelves (home rows) on mobile

`ui/src/components/library/shelf.tsx` measures available width and shows
**exactly as many cards as fit, with no horizontal scrolling** — that's a
desktop/tablet-width behavior. At phone width, real Spotify's mobile app
(and `ui/`'s own narrow-viewport fallback) instead makes each shelf a
**horizontally scrollable row** (fixed card width, `ListView` with
`scrollDirection: Axis.horizontal`), since there's rarely room for more than
1–2 cards' width to begin with. `AlbumShelf` (`lib/ui/widgets/album_widgets.dart`)
already does this (a horizontal scroller) — keep that behavior; it's the
`Shelf`-style "fit without scrolling" layout that should **not** be ported to
phone width, since it doesn't apply there. No change needed here beyond
restyling the cards themselves to the new palette (§2).

## 7. Page inventory

All under `lib/ui/pages/` unless noted.

| Page | Purpose |
|---|---|
| `login_page.dart` (`lib/ui/login_page.dart`) | Server URL / username / password form; creates the `SubsonicClient` session |
| `home_tab.dart` | Renders the configurable home shelves (`AlbumShelf` rows) per `HomeLayout`, plus the settings entry point |
| `library_tab.dart` | The "Your Library" hub (§3.3): a tile grid (Albums/Artists/Songs/Downloads/Smart Playlists) + the server playlist list, absorbing what `playlists_tab.dart` used to own |
| `album_list_page.dart` | New: standalone `Scaffold` around `PagedAlbumGrid`, pushed to from the Library hub |
| `artist_list_page.dart` | New: standalone artist list (extracted from the old `library_tab.dart`), pushed to from the Library hub |
| `song_list_page.dart` | New: flat list of every song from `SyncController`'s library cache, with a shuffle-all action |
| `search_tab.dart` | Debounced search box over the Subsonic `search3`-style results (artists/albums/songs) |
| `album_page.dart` | One album's track list, play/queue actions, and an `OfflineSwitch` |
| `artist_page.dart` | An artist's albums, via `AlbumShelf`/`AlbumCard` widgets |
| `playlist_page.dart` | One server playlist's track list, with offline toggle |
| `now_playing_page.dart` | Full-screen now-playing view: art, transport controls, position slider, and the color-extracted hero gradient background (§4.3) |
| `queue_sheet.dart` | `DraggableScrollableSheet` listing the current play queue (reorder/remove) |
| `equalizer_page.dart` | Reads device EQ bands via `PlayerController.equalizerParameters()` and lets the user drag `eqPresets` gains live before committing them to settings |
| `home_layout_page.dart` | Reorders, hides, and resizes the home-tab shelves (`HomeLayout`/`HomeRowConfig`) |
| `smart_filter_editor.dart` | Builds/edits a `SmartPlaylist`'s rules (field, operator, value) |
| `smart_playlist_page.dart` | Evaluates one smart playlist against the synced library and lists matches |
| `smart_playlists_view.dart` | List of saved smart playlists + "new smart playlist" FAB; reached from the Library hub, not a standalone `Playlists` tab |
| `downloads_page.dart` | Lists downloaded songs/offline collections, storage used, failures |
| `settings_page.dart` | Appearance (theme picker, §2.3), ReplayGain mode, pre-amp, fade in/out, crossfade, skip-silence, equalizer entry, library sync, downloads entry, home-layout entry, sign out |

`playlists_tab.dart` no longer exists — deleted when its content moved into
`library_tab.dart`.

## 8. Shared widgets

`lib/ui/widgets/`:

| Widget | Purpose |
|---|---|
| `cover_art.dart` (`CoverArt`) | Square cover art via `cached_network_image`, with a placeholder when there's no art or no network image yet |
| `song_tile.dart` (`SongTile`) | Standard song row: cover, title/artist, tap-to-play, trailing menu; shows `PlayingBars` instead of the track number when this row is the current track (§5) |
| `album_widgets.dart` (`AlbumCard`, `AlbumShelf`, `PagedAlbumGrid`) | Album cover + title/artist card, a horizontally-scrolling shelf of cards for home rows, and a paged grid for the Library tab |
| `mini_player.dart` (`MiniPlayer`) | Spinning circular art, thin progress line, single filled play/pause button (§4.2) |
| `playing_bars.dart` (`PlayingBars`) | Animated 3-bar equalizer for the currently-playing row (§5) |
| `art_hero_background.dart` (`ArtHeroBackground`) | `palette_generator`-based dominant-color extraction + in-memory cache feeding the Now Playing hero gradient (§4.3) |
| `offline_switch.dart` (`OfflineSwitch`) | "Available offline" toggle for an album/playlist; keeps an `OfflineCollection` in sync via `DownloadController` |

There is no icon set or spacing scale beyond Flutter's default
`Theme.of(context).textTheme`/`colorScheme` — components pull directly from
the ambient `ThemeData`, now the explicit Spotify-exact one from §2.

## 9. State → UI pattern

Unchanged by the Spotify rework. Every page is a thin view over a
`ChangeNotifier` controller exposed with `provider`. The three read styles
used throughout:

- `context.watch<T>()` — subscribe to the whole controller and rebuild this
  widget whenever it calls `notifyListeners()`.
- `context.read<T>()` — grab the controller once (e.g. inside a callback)
  without subscribing to rebuilds.
- `context.select<T, V>((t) => ...)` — subscribe to one derived value only,
  used where the rest of the controller's state is irrelevant to this widget
  (e.g. `OfflineSwitch` only cares whether its one collection is offline).

Real example, `HomeTab` (`lib/ui/pages/home_tab.dart`):

```dart
@override
Widget build(BuildContext context) {
  final layout = context.watch<SettingsController>().home;
  return Scaffold(
    body: ListView(
      children: [
        for (final row in layout.rows)
          if (row.visible && homeRowTypes.containsKey(row.id))
            AlbumShelf(
              key: ValueKey('${row.id}:${row.count}'),
              title: homeRowTitles[row.id]!,
              type: homeRowTypes[row.id]!,
              count: row.count,
            ),
      ],
    ),
  );
}
```

`HomeTab` watches `SettingsController`; whenever `HomeLayoutPage` calls
`settings.setHome(...)`, `SettingsController.notifyListeners()` fires and
`HomeTab` rebuilds its list of shelves automatically. There's no manual
event bus or imperative refresh call — the rebuild is a direct consequence of
Provider's listener mechanism.

## 10. Home-layout customization

Unchanged by the Spotify rework. `lib/settings/settings_models.dart` defines
`HomeLayout`/`HomeRowConfig`: an ordered list of shelves (`recent`, `newest`,
`frequent`, `random`, `starred`), each with a `visible` flag and an item
`count`. `HomeLayoutPage` lets the user reorder, show/hide, and resize these;
`HomeTab` renders exactly the rows that are visible, in order, each as an
`AlbumShelf` keyed on `id:count` so changing the count triggers a fresh fetch
for that row only. This is Noorify's equivalent of a "customizable home
screen", implemented entirely as Flutter widgets reacting to a persisted
settings object, not as any kind of native Android/iOS feature.

## 11. Implementation checklist — all done

1. ✅ Replaced `ColorScheme.fromSeed` with explicit dark/light `ColorScheme`s
   using the hex table in §2.2.
2. ✅ Added a theme-mode setting + picker (§2.3) — no Solarized/theme-id, as
   scoped.
3. ✅ Added `google_fonts` (pinned `^8.0.0`) and set Manrope as the app
   `textTheme` (§2.4).
4. ✅ Collapsed `HomeShell`'s nav from 4 tabs to 3 (Home/Search/Library) and
   deleted `PlaylistsTab` as a standalone destination (§3.2).
5. ✅ Rebuilt `LibraryTab` as the "Your Library" hub (§3.3), plus three new
   pages (`AlbumListPage`, `ArtistListPage`, `SongListPage`) to push to from
   it. No Radio tile yet — see §3.3's note on why that was deferred.
6. ✅ Rebuilt `MiniPlayer`: spinning circular art, thin progress line, single
   filled play/pause button — checked against the live `ui/` component,
   which also meant dropping previous/next buttons and fixing the icon
   color (§4.2).
7. ✅ Added `ArtHeroBackground` (`palette_generator`-based) and wired it into
   `now_playing_page.dart` as a hero gradient background (§4.3).
8. ✅ Added `PlayingBars` and wired it into `SongTile` for the current track
   (§5).

Natural follow-ups, not part of this checklist: a Radio tile/page (needs
`PlayerController` to support playing an arbitrary stream URL, not just a
`Song`); porting `ArtHeroBackground` to `album_page.dart`/`artist_page.dart`
(it's already used there on the web); a tablet/desktop-width adaptive layout
(this checklist and the mobile nav rework in §3 were phone-width only).
