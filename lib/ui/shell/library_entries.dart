import '../../models/models.dart';
import '../../settings/settings_models.dart';
import '../../smart/smart_filter.dart';

/// What a row in Your Library opens.
///
/// [shortcut] rows are the fixed entries that used to be tiles on the Library
/// page (all songs, downloads and the smart playlists overview); see
/// [LibraryEntry.shortcutSongs] and friends.
enum LibraryKind { favorites, shortcut, playlist, smartPlaylist, artist, album }

/// The filter chips above the list. None selected shows everything.
enum LibraryFilter {
  playlists('Playlists'),
  artists('Artists'),
  albums('Albums'),
  downloaded('Downloaded');

  const LibraryFilter(this.label);
  final String label;
}

/// One row of Your Library.
class LibraryEntry {
  const LibraryEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverArt,
  });

  final LibraryKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String? coverArt;

  /// The ids of the [LibraryKind.shortcut] entries, in display order.
  static const shortcutSongs = 'songs';
  static const shortcutDownloads = 'downloads';
  static const shortcutSmart = 'smart';
  static const shortcutOrder = [
    shortcutSongs,
    shortcutDownloads,
    shortcutSmart,
  ];

  /// Where this entry sits among the rows that are always first (Favorites,
  /// then the shortcuts), or null for an ordinary row.
  int? get pinRank => switch (kind) {
        LibraryKind.favorites => 0,
        LibraryKind.shortcut => 1 + shortcutOrder.indexOf(id),
        _ => null,
      };

  bool get pinned => pinRank != null;

  /// Matches the keys `LibraryRecents` stores and the keys offline collections
  /// use (`album:al1`, `playlist:42`), so the three line up.
  String get key => switch (kind) {
        LibraryKind.favorites => 'favorites',
        LibraryKind.shortcut => 'shortcut:$id',
        LibraryKind.playlist => 'playlist:$id',
        LibraryKind.smartPlaylist => 'smart:$id',
        LibraryKind.artist => 'artist:$id',
        LibraryKind.album => 'album:$id',
      };

  /// The page this entry opens, relative to a tab (see `AppRoutes.branchPath`).
  String get detailPath => switch (kind) {
        LibraryKind.favorites => 'favorites',
        LibraryKind.shortcut => id,
        LibraryKind.playlist =>
          'playlist/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(title)}',
        LibraryKind.smartPlaylist => 'smart/${Uri.encodeComponent(id)}',
        LibraryKind.artist => 'artist/${Uri.encodeComponent(id)}',
        LibraryKind.album => 'album/${Uri.encodeComponent(id)}',
      };
}

/// Everything Your Library can list, in no particular order. [includeDownloads]
/// is false where downloads are not possible (a browser). Missing sources
/// (still loading, or the server was unreachable) are simply left out, so
/// Favorites, the shortcuts and smart playlists still show offline.
List<LibraryEntry> buildLibraryEntries({
  bool includeDownloads = true,
  List<Playlist> playlists = const [],
  List<SmartPlaylist> smartPlaylists = const [],
  List<Artist> artists = const [],
  List<Album> albums = const [],
}) =>
    [
      const LibraryEntry(
        kind: LibraryKind.favorites,
        id: 'favorites',
        title: 'Favorites',
        subtitle: 'Playlist • Starred songs',
      ),
      const LibraryEntry(
        kind: LibraryKind.shortcut,
        id: LibraryEntry.shortcutSongs,
        title: 'Songs',
        subtitle: 'Every song in your library',
      ),
      if (includeDownloads)
        const LibraryEntry(
          kind: LibraryKind.shortcut,
          id: LibraryEntry.shortcutDownloads,
          title: 'Downloads',
          subtitle: 'Available offline',
        ),
      const LibraryEntry(
        kind: LibraryKind.shortcut,
        id: LibraryEntry.shortcutSmart,
        title: 'Smart playlists',
        subtitle: 'Playlists made from rules',
      ),
      for (final p in playlists)
        LibraryEntry(
          kind: LibraryKind.playlist,
          id: p.id,
          title: p.name,
          subtitle: 'Playlist • ${_count(p.songCount, 'song')}',
          coverArt: p.coverArt,
        ),
      for (final p in smartPlaylists)
        LibraryEntry(
          kind: LibraryKind.smartPlaylist,
          id: p.id,
          title: p.title,
          subtitle: 'Smart playlist • ${_count(p.filter.rules.length, 'rule')}',
        ),
      for (final a in artists)
        LibraryEntry(
          kind: LibraryKind.artist,
          id: a.id,
          title: a.name,
          subtitle: 'Artist',
          coverArt: a.coverArt,
        ),
      for (final a in albums)
        LibraryEntry(
          kind: LibraryKind.album,
          id: a.id,
          title: a.name,
          subtitle: a.artist == null ? 'Album' : 'Album • ${a.artist}',
          coverArt: a.coverArt,
        ),
    ];

/// The [LibraryEntry.key] of the library item the page at [path] shows, or null
/// when it is not one (Home, Search, Settings, the album list...). [path] is a
/// route path such as `/library/album/al1`; the tab it sits under is ignored,
/// so an album opened from Home still counts as open.
String? libraryEntryKeyForPath(String path) {
  final segments = Uri.parse(path).pathSegments;
  if (segments.length < 2) return null;
  final page = segments.sublist(1);
  final id = page.length > 1 ? page[1] : null;

  switch (page[0]) {
    case 'favorites':
      return 'favorites';
    case LibraryEntry.shortcutSongs:
      return 'shortcut:${LibraryEntry.shortcutSongs}';
    case LibraryEntry.shortcutDownloads:
      return 'shortcut:${LibraryEntry.shortcutDownloads}';
    case 'smart':
      if (id == null) return 'shortcut:${LibraryEntry.shortcutSmart}';
      return id == 'new' ? null : 'smart:$id';
    case 'playlist':
      return id == null ? null : 'playlist:$id';
    case 'artist':
      return id == null ? null : 'artist:$id';
    case 'album':
      return id == null ? null : 'album:$id';
  }
  return null;
}

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// The entries to show for the chosen [filter], search [query] and [sort].
///
/// [opened] maps entry keys to when they were last opened (milliseconds), and
/// [offlineKeys] are the keys kept for offline use. Favorites and the
/// shortcuts are always first, in that order. Under [LibrarySort.recents],
/// opened items come next, most recent first, then the rest A to Z. The
/// shortcuts only show when no filter is chosen.
List<LibraryEntry> visibleLibraryEntries(
  List<LibraryEntry> entries, {
  LibraryFilter? filter,
  String query = '',
  LibrarySort sort = LibrarySort.recents,
  Map<String, int> opened = const {},
  Set<String> offlineKeys = const {},
}) {
  final needle = query.trim().toLowerCase();
  final shown = [
    for (final e in entries)
      if (_matchesFilter(e, filter, offlineKeys) &&
          (needle.isEmpty ||
              e.title.toLowerCase().contains(needle) ||
              e.subtitle.toLowerCase().contains(needle)))
        e,
  ];

  int byTitle(LibraryEntry a, LibraryEntry b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  shown.sort((a, b) {
    final ar = a.pinRank;
    final br = b.pinRank;
    if (ar != null || br != null) {
      if (ar == null) return 1;
      if (br == null) return -1;
      return ar.compareTo(br);
    }
    if (sort == LibrarySort.recents) {
      final at = opened[a.key];
      final bt = opened[b.key];
      if (at != null && bt != null && at != bt) return bt.compareTo(at);
      if ((at != null) != (bt != null)) return at != null ? -1 : 1;
    }
    return byTitle(a, b);
  });
  return shown;
}

bool _matchesFilter(
    LibraryEntry e, LibraryFilter? filter, Set<String> offlineKeys) {
  switch (filter) {
    case null:
      return true;
    case LibraryFilter.playlists:
      return e.kind == LibraryKind.favorites ||
          e.kind == LibraryKind.playlist ||
          e.kind == LibraryKind.smartPlaylist;
    case LibraryFilter.artists:
      return e.kind == LibraryKind.artist;
    case LibraryFilter.albums:
      return e.kind == LibraryKind.album;
    case LibraryFilter.downloaded:
      return offlineKeys.contains(e.key);
  }
}
