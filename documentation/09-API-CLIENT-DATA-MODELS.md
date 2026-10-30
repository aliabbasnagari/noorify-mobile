# Noorify - API Client & Data Models

## 1. Overview

Noorify's only connection to the outside world is the `SubsonicClient` in
`lib/subsonic/subsonic_client.dart`: a minimal, dependency-light Subsonic /
OpenSubsonic REST client built on the `http` package. It has no code
generation, no retrofit-style annotations, no GraphQL — every call builds a
URL, issues a `GET`, and decodes the `subsonic-response` JSON envelope by
hand into the plain Dart classes in `lib/models/models.dart`.

## 2. Authentication & Request Building

`ServerConfig` holds the three pieces of state a session needs: `url`,
`username`, `password`. `SubsonicClient` generates one random 12-hex-char
salt per client instance (`Random.secure()`) and reuses it for every
request, which keeps cover-art/stream URLs for a given song stable so
`cached_network_image`/HTTP caches can actually hit:

```dart
Map<String, dynamic> _auth() => {
  'u': config.username,
  't': md5.convert(utf8.encode(config.password + _salt)).toString(),
  's': _salt,
  'v': apiVersion,       // '1.16.1'
  'c': clientName,       // 'noorify'
  'f': 'json',
};
```

`buildUri(method, params)` appends `/rest/<method>.view` to the configured
server URL and merges the auth map with the call's own parameters; list
values are serialized as repeated query parameters (e.g. multiple `songId`
entries for `createPlaylist`).

## 3. Request Execution & Error Handling

All GET calls go through a single private `_call(method, params)`:

1. `http.get(...)` with a 20s timeout; a network failure is wrapped as
   `SubsonicException('Could not reach server: ...')`.
2. Non-200 HTTP status → `SubsonicException('Server returned HTTP ...')`.
3. The body is parsed as JSON and unwrapped at `subsonic-response`; anything
   that isn't valid JSON in that shape → `SubsonicException('Unexpected
   response; is this a Subsonic server?')`.
4. `subsonic-response.status != 'ok'` → `SubsonicException` built from the
   server's `error.message`/`error.code`.

Every public method is a thin wrapper around `_call` plus a `Song`/`Album`/
`Artist`/`Playlist`/`SearchResults` factory constructor — there is no
separate "repository" or caching layer inside the client itself; callers
(the `state/` controllers) decide what to cache.

## 4. Method Surface

| Method | Subsonic endpoint | Returns |
|---|---|---|
| `ping()` | `ping` | — (throws on failure) |
| `getArtists()` | `getArtists` | `List<Artist>` (flattened out of the A–Z index) |
| `getArtist(id)` | `getArtist` | `Artist` (with embedded albums) |
| `getAlbumList(type, {size, offset})` | `getAlbumList2` | `List<Album>` |
| `getAlbum(id)` | `getAlbum` | `Album` (with embedded songs) |
| `search(query, {count})` | `search3` | `SearchResults` |
| `getSongsPage({offset, size, query})` | `search3` (song-only paging) | `List<Song>` |
| `getStarredSongs()` | `getStarred2` | `List<Song>` |
| `getPlaylists()` | `getPlaylists` | `List<Playlist>` |
| `getPlaylist(id)` | `getPlaylist` | `Playlist` (with embedded songs) |
| `createPlaylist(name, {songIds})` | `createPlaylist` | — |
| `addToPlaylist(playlistId, songIds)` | `updatePlaylist` (`songIdToAdd`) | — |
| `removeFromPlaylist(playlistId, indexes)` | `updatePlaylist` (`songIndexToRemove`) | — |
| `deletePlaylist(id)` | `deletePlaylist` | — |
| `star(id)` / `unstar(id)` | `star` / `unstar` | — |
| `scrobble(id, {submission})` | `scrobble` | — (`submission: false` = "now playing" only) |
| `getGenres()` | `getGenres` | `List<Genre>` |
| `getSimilarSongs(id, {count})` | `getSimilarSongs2` (ID3-based) | `List<Song>` |
| `getTopSongs(artist, {count})` | `getTopSongs` | `List<Song>` |
| `getBookmarks()` | `getBookmarks` | `List<Bookmark>` |
| `createBookmark(id, {comment, position})` | `createBookmark` | — |
| `deleteBookmark(id)` | `deleteBookmark` | — |
| `getLyrics(songId)` | `getLyricsBySongId` (OpenSubsonic, structured) | `List<StructuredLyric>` |
| `getInternetRadioStations()` | `getInternetRadioStations` | `List<RadioStation>` |
| `createInternetRadio(name, streamUrl, {homepageUrl})` | `createInternetRadioStation` | — |
| `updateInternetRadio(id, name, streamUrl, {homepageUrl})` | `updateInternetRadioStation` | — |
| `deleteInternetRadio(id)` | `deleteInternetRadioStation` | — |
| `getOpenSubsonicExtensions()` | `getOpenSubsonicExtensions` | `Map<String, List<int>>` (extension name → supported versions) |

Plus three URL builders that don't make a request themselves — callers
(`PlayerController`, `DownloadController`, cover-art widgets) fetch or stream
from them directly:

| Method | Purpose |
|---|---|
| `streamUrl(id, {maxBitRate})` | Transcoded/streamed playback URL |
| `coverArtUrl(id, {size})` | Cover art image URL |
| `downloadUrl(id)` | Original, untranscoded file (used for offline downloads) |

`getAlbumList` takes an `AlbumListType` enum (`newest`, `recent`, `frequent`,
`random`, `alphabetical`, `starred`) that maps to `getAlbumList2`'s `type`
values — this backs the configurable home-screen rows described in
`settings_models.dart`'s `HomeLayout`.

`getSongsPage` deliberately reuses `search3` rather than a dedicated
"list all songs" endpoint, since Subsonic has none; it pages with
`songOffset`/`songCount` and falls back from an empty query to `*` for
servers that require a non-empty search term. It exists specifically to
feed `SyncController`'s library cache (see `06-MUSIC-LIBRARY-METADATA.md`).

The genres/similar-songs/top-songs/bookmarks/lyrics/radio/extensions methods
were added against, and verified directly on, Navidrome's actual
`server/subsonic/` handlers (`GetGenres`, `GetSimilarSongs2`, `GetTopSongs`,
bookmarks/radio/`GetLyricsBySongId` in `media_retrieval.go`,
`GetOpenSubsonicExtensions`) rather than assumed from the Subsonic spec —
Navidrome doesn't implement every optional Subsonic/OpenSubsonic endpoint
(e.g. there is no tag-writing endpoint at all), so this client only grows
methods for calls the backend actually serves.

## 5. Data Models (`lib/models/models.dart`)

Plain, immutable-by-convention Dart classes — no `freezed`, no
`json_serializable`, no build-runner codegen. Each has a hand-written
`fromJson` factory (defensive about missing/`null` fields, e.g. falling back
`title ?? name ?? 'Unknown'`) and, where a model needs to round-trip through
a local cache, a matching `toJson`.

| Class | Key fields | Round-trips via `toJson`? |
|---|---|---|
| `Song` | id, title, album(Id), artist(Id), coverArt, duration, track, year, suffix, starred, genre, bitRate, playCount, userRating, created, played, size, `replayGain` | Yes — used by the sync and download caches |
| `ReplayGainInfo` | trackGain, albumGain, trackPeak, albumPeak, baseGain, fallbackGain (all `double?`, dB) | Yes |
| `Album` | id, name, artist(Id), coverArt, songCount, duration, year, genre, embedded `songs` | No |
| `Artist` | id, name, coverArt, albumCount, embedded `albums` | No |
| `Playlist` | id, name, songCount, duration, coverArt, embedded `songs` (from the `entry` JSON key) | No |
| `SearchResults` | `artists`, `albums`, `songs` lists; `isEmpty` getter | No |
| `Genre` | name, songCount, albumCount | No |
| `RadioStation` | id, name, streamUrl, homepageUrl | No |
| `Bookmark` | embedded `Song`, position (ms), comment, created, changed | No |
| `StructuredLyric` / `LyricLine` | displayArtist, displayTitle, lang, synced, `lines: List<LyricLine>` (`{startMs, value}`) | No |

`Song.toJson`/`fromJson` are the only pair that need to survive a disk
round-trip, since `SyncController` and `DownloadController` both persist
lists of songs as JSON and reconstruct them on the next app launch.

## 6. Wiring the Client into the App

There is exactly one live `SubsonicClient` at a time, owned by
`SessionController` (`lib/state/session_controller.dart`): it creates the
client on `login()`/`restore()` (validating it with a `ping()` first),
persists the three credential fields with `flutter_secure_storage`, and
clears it on `logout()`.

Every other controller that needs network access doesn't hold its own
client — it exposes an `attach(SubsonicClient? client)` method and is wired
up in `main.dart` with `provider`'s `ChangeNotifierProxyProvider`, so it's
automatically re-attached whenever `SessionController.client` changes
(including to `null` on logout):

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
  create: (_) => PlayerController(),
  update: (_, session, settings, downloads, player) => player!
    ..attach(session.client)
    ..attachSettings(settings)
    ..attachDownloads(downloads),
),
```

`PlayerController.attach`, `DownloadController.attach` and
`SyncController.attach` all guard against redundant calls with
`identical(_client, client)`, and treat `attach(null)` as "the session ended"
(e.g. `PlayerController` stops playback). This proxy-provider pattern is the
entire "dependency injection" story in the app — there is no service
locator, no GetIt, no manual singleton registry.

## 7. Error Surfacing

`SubsonicException` is the only exception type the client throws for
server/network problems; it carries a human-readable `message` and an
optional Subsonic `code`. Callers generally catch it at the UI boundary
(e.g. the login screen shows `SubsonicException.toString()` directly) or
swallow it deliberately for best-effort background work (e.g.
`PlayerController`'s "now playing" scrobble ping, which must never disturb
playback if the server is unreachable).

`SyncController` and `DownloadController` wrap their network calls in
`withRetry()` (`lib/util/retry.dart`) before any `SubsonicException` reaches
their own error handling — a transient failure (a dropped mobile connection
mid-page or mid-download) gets up to 3 attempts with exponential backoff
before it's treated as a real error. This is the only place in the codebase
with retry logic; the client itself stays a thin, single-attempt wrapper.
