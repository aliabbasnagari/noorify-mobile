# Noorify - Music Library & Metadata

## 1. Overview

Noorify has no local music library. It is a client for Subsonic- and
OpenSubsonic-compatible servers (e.g. Navidrome): every artist, album, song,
playlist and piece of metadata is fetched over the REST API in
`lib/subsonic/subsonic_client.dart` and decoded into the plain Dart models in
`lib/models/models.dart`. There is no on-device scanner, no local tag
reading/writing, and no bundled TagLib — tagging is entirely the server's
responsibility.

What the app *does* keep on-device is a cache: a local SQLite snapshot of the
song library for evaluating smart playlists offline, and a JSON index of
downloaded files for offline playback. Both are described below.

## 2. Metadata Flow

```
Subsonic/OpenSubsonic server
        │  JSON (getArtists, getAlbumList2, getAlbum, search3, ...)
        ▼
SubsonicClient (lib/subsonic/subsonic_client.dart)
        │  Song.fromJson / Album.fromJson / Artist.fromJson / Playlist.fromJson
        ▼
Dart models (lib/models/models.dart)
        │  held by ChangeNotifier controllers (Provider) or returned directly
        ▼
UI (lib/ui/pages/*.dart) — album/artist/playlist pages, song tiles, search
```

Every field a user sees — title, artist, album, genre, year, track number,
duration, bitrate, play count, star/favorite, user rating, file size,
ReplayGain — is whatever the server reported for that song; Noorify never
infers or extracts it from the audio file itself.

### 2.1 Song fields (`lib/models/models.dart`)

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Server-assigned, stable per song |
| `title` | `String` | Falls back to `name` or `'Unknown'` |
| `album` / `albumId` | `String?` | |
| `artist` / `artistId` | `String?` | |
| `coverArt` | `String?` | Cover-art id, resolved via `coverArtUrl` |
| `duration` | `int` | Seconds |
| `track`, `year` | `int?` | |
| `suffix` | `String?` | File extension, used to name downloaded files |
| `starred` | `bool` | Favorite flag |
| `genre` | `String?` | |
| `bitRate` | `int?` | kbps |
| `playCount` | `int` | |
| `userRating` | `int?` | 1–5 |
| `created` | `DateTime?` | When the song was added to the server library |
| `played` | `DateTime?` | Last-played time (OpenSubsonic/Navidrome extension) |
| `size` | `int?` | Bytes |
| `replayGain` | `ReplayGainInfo?` | See below |

`Song.toJson()` round-trips the same shape, which is what lets the sync and
download caches (section 3) persist songs to disk and read them straight
back with `Song.fromJson`.

### 2.2 ReplayGain (`ReplayGainInfo`)

Parsed from the OpenSubsonic `replayGain` block: `trackGain`, `albumGain`,
`trackPeak`, `albumPeak`, `baseGain`, `fallbackGain` (all optional, gains in
dB). `PlayerController` uses this alongside the user's ReplayGain setting
(off/track/album + pre-amp) to compute playback volume — see
`03-AUDIO-DECODING-FFMPEG.md` for how that's applied.

### 2.3 Album, Artist, Playlist, SearchResults

`Album` (id, name, artist, coverArt, songCount, duration, year, genre,
embedded `songs`), `Artist` (id, name, coverArt, albumCount, embedded
`albums`) and `Playlist` (id, name, songCount, duration, coverArt, embedded
`songs`) are thin wrappers over the equivalent Subsonic JSON objects.
`SearchResults` bundles the three lists returned by `search3`.

### 2.3a Genres, radio stations, bookmarks, lyrics

`lib/models/models.dart` also has thin wrappers for the newer parts of the
Subsonic/OpenSubsonic method surface (see
`09-API-CLIENT-DATA-MODELS.md` for the matching `SubsonicClient` methods):
`Genre` (name, songCount, albumCount), `RadioStation` (id, name, streamUrl,
homepageUrl), `Bookmark` (an embedded `Song`, position in ms, comment,
created/changed), and `StructuredLyric`/`LyricLine` (display artist/title,
language, `synced` flag, and a list of `{startMs, value}` lines from
OpenSubsonic's `getLyricsBySongId`). None of these round-trip through
`toJson` — they're always fetched live, never cached locally.

### 2.4 Cover art

Art is never stored as raw bytes in a model — `coverArt` is just an id.
Screens resolve it to a URL with `SubsonicClient.coverArtUrl(id, size: ...)`
and load it with `cached_network_image`, which handles on-disk/in-memory
caching. There is no custom image pipeline or native decoding involved.

## 3. On-Device Caching

Noorify keeps two independent, disposable on-device caches — neither is a
real "library"; both get rebuilt from the server.

### 3.1 Library sync cache (`lib/state/sync_controller.dart` + `lib/data/local/app_database.dart`)

`SyncController.sync()` pages the entire song library with
`SubsonicClient.getSongsPage` (500 songs per page, via a `search3` call with
an empty/`*` query and `songOffset`, retried with backoff on failure via
`lib/util/retry.dart`) and stores the result in a local **SQLite database**
via [`drift`](https://pub.dev/packages/drift), not a flat JSON file. The
schema (`AppDatabase` in `lib/data/local/app_database.dart`) is two tables:

- `SongEntries` — one row per `(owner, songId)`, mirroring every `Song`
  field (ReplayGain is kept as an opaque JSON column since it's never
  queried on, only round-tripped).
- `SyncStates` — one row per `owner`, tracking `lastSync`.

`owner` is `"<server url>|<username>"` on every row, so multiple accounts can
share one database file without leaking one account's library into another's
smart-playlist results — there's no need to ignore/evict a mismatched cache
file the way a single-account JSON blob would have required. Each page is
upserted into `SongEntries` as it arrives (`AppDatabase.upsertSongs`), and the
full set replaces the table (`AppDatabase.replaceSongs`, delete + batch
insert in one transaction) once the whole sync completes — this also removes
rows for songs that no longer exist on the server. This cache exists purely
so smart playlists (section 4) can be evaluated locally without re-querying
the server for every rule change — it is not used for browsing
artists/albums, which always go straight to the server.

### 3.2 Download index (`lib/state/download_controller.dart`)

Separately, every offline-downloaded file is tracked in `index.json` next to
the downloaded audio files, recording the `Song` metadata, file name, byte
size, and *why* it's kept (`manual`, or the key of an offline-pinned
album/playlist). Each download attempt retries with backoff
(`lib/util/retry.dart`) before being recorded as failed. This is what lets
the `downloaded` smart-playlist field
(section 4) work, and what `PlayerController` checks to prefer a local file
over streaming. See `09-API-CLIENT-DATA-MODELS.md` and
`08-SERVICES-BACKGROUND-PROCESSING.md` for the download mechanics.

## 4. Smart Playlists (`lib/smart/smart_filter.dart`)

A pure-Dart rule engine evaluated against the library sync cache — there is
no server-side smart-filter support; everything below runs on-device.

### 4.1 Fields

| Field | Type | Matched against |
|---|---|---|
| `title`, `artist`, `album`, `genre` | text | `Song` string fields |
| `year`, `duration` (seconds), `bitRate` (kbps), `playCount`, `userRating` (1–5) | number | `Song` numeric fields |
| `starred` | flag | `Song.starred` |
| `downloaded` | flag | Looked up via `SmartContext.isDownloaded(songId)`, backed by `DownloadController` |
| `added` | date | `Song.created` |
| `lastPlayed` | date | `Song.played` |

### 4.2 Operators (per field type, `operatorsFor(FieldType)`)

| Field type | Operators |
|---|---|
| text | contains, does not contain, is, is not, starts with, ends with |
| number | is, is not, is greater than, is less than |
| flag | is yes, is no |
| date | in the last (days), not in the last (days) |

### 4.3 Structure

A `SmartFilter` has a top-level `merge` rule (`all`/`any`), a list of
`SmartNode`s, an ordered `sort` list (`{field, ascending}`, where `field` can
be any `SmartField` name or the sentinel `"random"` to shuffle instead of
sort), and a `limit` (`0` = unlimited). Each `SmartNode` is either:

- a `SmartRule` — `{field, operator, value}`, or
- a `SmartGroup` — its own `merge` rule plus nested child `SmartNode`s,

so filters can express arbitrary AND/OR trees, not just a flat rule list.
`SmartFilter.apply(songs, context)` filters, then sorts (or shuffles), then
truncates to `limit`. `SmartPlaylist` wraps a named `SmartFilter` with an id
for persistence; saved smart playlists are held by
`lib/state/smart_playlist_store.dart` and edited in
`lib/ui/pages/smart_filter_editor.dart`.

The field/operator set here is Noorify's own design, not something read off
a server API — see `ui-mobile/docs/symfonium-findings.md` for the research
notes that originally shaped this feature's scope.

## 5. What's Not Implemented

- No local file scanning, tag reading, or tag editing of any kind.
- No bundled TagLib or any other native metadata-extraction library.
- No server-side smart-playlist evaluation — everything in section 4 runs
  against the local sync cache in Dart.
- No persistent background sync — `SyncController.sync()` only runs while
  the app process is alive and must be triggered again (e.g. from Settings)
  to pick up server-side library changes.
- No incremental/delta sync — the Subsonic API has no "songs changed since"
  endpoint, so every `sync()` call re-pages the entire library rather than
  fetching only what changed. The local database makes storing the result
  cheap; it doesn't make the fetch itself incremental.
- No offline-first browsing. Only the Songs page (`SongListPage`, via
  `SyncController`'s cache) and downloaded files actually work offline.
  Albums, Artists, Playlists and the Home shelves all fetch live from the
  server on every visit with no fallback, so they show a "you're offline"
  message (`lib/ui/util.dart`'s `isConnectivityError`/`ErrorRetry`) rather
  than cached results when there's no connection. Making those genuinely
  offline-first would mean extending `AppDatabase` to cache albums/artists/
  playlists too, not just songs — a real scope decision, not a quick fix.
