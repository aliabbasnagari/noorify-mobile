import '../../models/models.dart';

enum TopResultKind { artist, album, song }

/// The single best match for a search, shown first in a card.
class TopResult {
  const TopResult.artist(Artist this.artist)
      : kind = TopResultKind.artist,
        album = null,
        song = null;

  const TopResult.album(Album this.album)
      : kind = TopResultKind.album,
        artist = null,
        song = null;

  const TopResult.song(Song this.song)
      : kind = TopResultKind.song,
        artist = null,
        album = null;

  final TopResultKind kind;
  final Artist? artist;
  final Album? album;
  final Song? song;

  String get title => artist?.name ?? album?.name ?? song!.title;
}

/// Picks the best match for [query] among [results], or null when there are
/// none.
///
/// A result whose name is exactly the query wins; failing that, one whose name
/// starts with it; failing that, the first result in the order artist, album,
/// song (artists first because someone searching a name usually wants the
/// artist). Within each step artists beat albums beat songs.
TopResult? topSearchResult(SearchResults results, String query) {
  final q = query.trim().toLowerCase();

  TopResult? firstMatching(bool Function(String name) matches) {
    for (final a in results.artists) {
      if (matches(a.name.toLowerCase())) return TopResult.artist(a);
    }
    for (final a in results.albums) {
      if (matches(a.name.toLowerCase())) return TopResult.album(a);
    }
    for (final s in results.songs) {
      if (matches(s.title.toLowerCase())) return TopResult.song(s);
    }
    return null;
  }

  if (q.isNotEmpty) {
    final exact = firstMatching((name) => name == q);
    if (exact != null) return exact;
    final prefix = firstMatching((name) => name.startsWith(q));
    if (prefix != null) return prefix;
  }

  if (results.artists.isNotEmpty) {
    return TopResult.artist(results.artists.first);
  }
  if (results.albums.isNotEmpty) return TopResult.album(results.albums.first);
  if (results.songs.isNotEmpty) return TopResult.song(results.songs.first);
  return null;
}
