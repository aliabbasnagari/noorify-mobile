import '../../models/models.dart';
import '../../settings/settings_models.dart';
import '../../smart/smart_filter.dart';

/// What a row in Your Library opens.
enum LibraryKind { favorites, playlist, smartPlaylist, artist, album }

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

  /// Favorites is pinned to the top whatever the sort.
  bool get pinned => kind == LibraryKind.favorites;

  /// Matches the keys `LibraryRecents` stores and the keys offline collections
  /// use (`album:al1`, `playlist:42`), so the three line up.
  String get key =>
      kind == LibraryKind.favorites ? 'favorites' : '${_prefix(kind)}:$id';

  static String _prefix(LibraryKind kind) => switch (kind) {
        LibraryKind.favorites => 'favorites',
        LibraryKind.playlist => 'playlist',
        LibraryKind.smartPlaylist => 'smart',
        LibraryKind.artist => 'artist',
        LibraryKind.album => 'album',
      };

  /// The page this entry opens, relative to a tab (see `AppRoutes.branchPath`).
  String get detailPath => switch (kind) {
        LibraryKind.favorites => 'favorites',
        LibraryKind.playlist =>
          'playlist/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(title)}',
        LibraryKind.smartPlaylist => 'smart/${Uri.encodeComponent(id)}',
        LibraryKind.artist => 'artist/${Uri.encodeComponent(id)}',
        LibraryKind.album => 'album/${Uri.encodeComponent(id)}',
      };
}

/// Everything Your Library can list, in no particular order. Missing sources
/// (still loading, or the server was unreachable) are simply left out, so
/// Favorites and smart playlists still show offline.
List<LibraryEntry> buildLibraryEntries({
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

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// The entries to show for the chosen [filter], search [query] and [sort].
///
/// [opened] maps entry keys to when they were last opened (milliseconds), and
/// [offlineKeys] are the keys kept for offline use. Favorites is always first.
/// Under [LibrarySort.recents], opened items come first, most recent first,
/// then the rest A to Z.
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
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
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
