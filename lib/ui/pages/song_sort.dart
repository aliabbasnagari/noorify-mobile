import '../../models/models.dart';

/// What the Songs page can be ordered by.
enum SongSort {
  title('Title'),
  artist('Artist'),
  album('Album'),
  duration('Length');

  const SongSort(this.label);
  final String label;
}

/// [songs] ordered by [sort], ascending or not. Text compares ignoring case;
/// ties fall back to the title so the order is stable. Returns a new list.
List<Song> sortSongs(
  List<Song> songs,
  SongSort sort, {
  bool ascending = true,
}) {
  String text(String? s) => (s ?? '').toLowerCase();
  int byTitle(Song a, Song b) => text(a.title).compareTo(text(b.title));

  int compare(Song a, Song b) {
    final primary = switch (sort) {
      SongSort.title => byTitle(a, b),
      SongSort.artist => text(a.artist).compareTo(text(b.artist)),
      SongSort.album => text(a.album).compareTo(text(b.album)),
      SongSort.duration => a.duration.compareTo(b.duration),
    };
    return primary != 0 ? primary : byTitle(a, b);
  }

  final sorted = [...songs]..sort(compare);
  return ascending ? sorted : sorted.reversed.toList();
}
