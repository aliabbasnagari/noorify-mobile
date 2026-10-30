import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/ui/pages/search_top_result.dart';

void main() {
  const beck = Artist(id: 'a1', name: 'Beck');
  const abba = Artist(id: 'a2', name: 'ABBA');
  const odelay = Album(id: 'al1', name: 'Odelay');
  const abbaGold = Album(id: 'al2', name: 'ABBA Gold');
  const loser = Song(id: 's1', title: 'Loser');
  const waterloo = Song(id: 's2', title: 'Waterloo');

  SearchResults results({
    List<Artist> artists = const [],
    List<Album> albums = const [],
    List<Song> songs = const [],
  }) =>
      SearchResults(artists: artists, albums: albums, songs: songs);

  test('no results gives no top result', () {
    expect(topSearchResult(results(), 'anything'), isNull);
  });

  test('an exact name match wins, ignoring case and spaces', () {
    final top = topSearchResult(
      results(artists: [abba], albums: [abbaGold], songs: [waterloo]),
      '  abba ',
    );

    expect(top!.kind, TopResultKind.artist);
    expect(top.artist, abba);
  });

  test('an exact match beats an earlier, merely related result', () {
    final top = topSearchResult(
      results(artists: [beck], albums: [odelay], songs: [loser]),
      'loser',
    );

    expect(top!.kind, TopResultKind.song);
    expect(top.song, loser);
  });

  test('an exact album match beats a prefix match on an artist', () {
    final top = topSearchResult(
      results(
          artists: [abba],
          albums: [abbaGold, const Album(id: 'x', name: 'AB')]),
      'ab',
    );

    expect(top!.album?.name, 'AB');
  });

  test('without an exact match, a name starting with the query wins', () {
    final top = topSearchResult(
      results(artists: [beck], albums: [abbaGold], songs: [waterloo]),
      'abba',
    );

    expect(top!.kind, TopResultKind.album);
    expect(top.album, abbaGold);
  });

  test('otherwise it is the first artist, then album, then song', () {
    expect(
      topSearchResult(
              results(artists: [beck], albums: [odelay], songs: [loser]),
              'zzz')!
          .artist,
      beck,
    );
    expect(
      topSearchResult(results(albums: [odelay], songs: [loser]), 'zzz')!.album,
      odelay,
    );
    expect(topSearchResult(results(songs: [loser]), 'zzz')!.song, loser);
  });

  test('a blank query still picks something', () {
    final top = topSearchResult(results(albums: [odelay]), '   ');

    expect(top!.album, odelay);
  });

  test('the title is the name of whatever was chosen', () {
    expect(const TopResult.artist(beck).title, 'Beck');
    expect(const TopResult.album(odelay).title, 'Odelay');
    expect(const TopResult.song(loser).title, 'Loser');
  });
}
