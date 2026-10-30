import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/settings/settings_models.dart';
import 'package:noorify/smart/smart_filter.dart';
import 'package:noorify/ui/shell/library_entries.dart';

void main() {
  final entries = buildLibraryEntries(
    playlists: const [
      Playlist(id: 'p1', name: 'Road trip', songCount: 12),
      Playlist(id: 'p2', name: 'Calm', songCount: 1),
    ],
    smartPlaylists: const [
      SmartPlaylist(
        id: 's1',
        title: 'Jazz',
        filter: SmartFilter(rules: [
          SmartRule(SmartField.genre, SmartOperator.contains, 'jazz'),
        ]),
      ),
    ],
    artists: const [
      Artist(id: 'a1', name: 'Beck'),
      Artist(id: 'a2', name: 'abba'),
    ],
    albums: const [
      Album(id: 'al1', name: 'Odelay', artist: 'Beck'),
      Album(id: 'al2', name: 'Untitled'),
    ],
  );

  List<String> titles(List<LibraryEntry> l) => [for (final e in l) e.title];

  group('buildLibraryEntries', () {
    test('always includes Favorites, even with nothing loaded', () {
      final empty = buildLibraryEntries();

      expect(titles(empty), ['Favorites']);
      expect(empty.single.pinned, isTrue);
      expect(empty.single.kind, LibraryKind.favorites);
    });

    test('describes each kind in its subtitle', () {
      String subtitleOf(String title) =>
          entries.firstWhere((e) => e.title == title).subtitle;

      expect(subtitleOf('Road trip'), 'Playlist • 12 songs');
      expect(subtitleOf('Calm'), 'Playlist • 1 song');
      expect(subtitleOf('Jazz'), 'Smart playlist • 1 rule');
      expect(subtitleOf('Beck'), 'Artist');
      expect(subtitleOf('Odelay'), 'Album • Beck');
      expect(subtitleOf('Untitled'), 'Album');
    });

    test('keys line up with the recents and offline-collection keys', () {
      String keyOf(String title) =>
          entries.firstWhere((e) => e.title == title).key;

      expect(keyOf('Favorites'), 'favorites');
      expect(keyOf('Road trip'), 'playlist:p1');
      expect(keyOf('Jazz'), 'smart:s1');
      expect(keyOf('Beck'), 'artist:a1');
      expect(keyOf('Odelay'), 'album:al1');
    });

    test('detail paths target the right page and escape their parts', () {
      String pathOf(String title) =>
          entries.firstWhere((e) => e.title == title).detailPath;

      expect(pathOf('Favorites'), 'favorites');
      expect(pathOf('Road trip'), 'playlist/p1?name=Road+trip');
      expect(pathOf('Jazz'), 'smart/s1');
      expect(pathOf('Beck'), 'artist/a1');
      expect(pathOf('Odelay'), 'album/al1');

      const odd = LibraryEntry(
        kind: LibraryKind.playlist,
        id: 'a/b c',
        title: 'Rock & Roll',
        subtitle: '',
      );
      expect(odd.detailPath, 'playlist/a%2Fb%20c?name=Rock+%26+Roll');
    });
  });

  group('visibleLibraryEntries filters', () {
    test('no filter shows everything', () {
      expect(visibleLibraryEntries(entries), hasLength(entries.length));
    });

    test('Playlists covers Favorites, playlists and smart playlists', () {
      final shown = visibleLibraryEntries(entries,
          filter: LibraryFilter.playlists, sort: LibrarySort.alphabetical);

      expect(titles(shown), ['Favorites', 'Calm', 'Jazz', 'Road trip']);
    });

    test('Artists and Albums show only their own kind', () {
      expect(
          titles(visibleLibraryEntries(entries,
              filter: LibraryFilter.artists, sort: LibrarySort.alphabetical)),
          ['abba', 'Beck']);
      expect(
          titles(visibleLibraryEntries(entries,
              filter: LibraryFilter.albums, sort: LibrarySort.alphabetical)),
          ['Odelay', 'Untitled']);
    });

    test('Downloaded shows only items kept offline', () {
      final shown = visibleLibraryEntries(
        entries,
        filter: LibraryFilter.downloaded,
        offlineKeys: {'album:al1', 'playlist:p2', 'album:gone'},
        sort: LibrarySort.alphabetical,
      );

      expect(titles(shown), ['Calm', 'Odelay']);
    });

    test('search matches title or subtitle, ignoring case', () {
      expect(
          titles(visibleLibraryEntries(entries, query: 'ROAD')), ['Road trip']);
      // "Beck" is in the artist's title and in the album's subtitle.
      expect(
          titles(visibleLibraryEntries(entries,
              query: 'beck', sort: LibrarySort.alphabetical)),
          ['Beck', 'Odelay']);
      expect(visibleLibraryEntries(entries, query: 'nothing here'), isEmpty);
      expect(visibleLibraryEntries(entries, query: '   '),
          hasLength(entries.length));
    });

    test('filter and search combine', () {
      final shown = visibleLibraryEntries(entries,
          filter: LibraryFilter.albums, query: 'odel');

      expect(titles(shown), ['Odelay']);
    });
  });

  group('visibleLibraryEntries sorting', () {
    test('alphabetical ignores case, with Favorites pinned first', () {
      final shown =
          visibleLibraryEntries(entries, sort: LibrarySort.alphabetical);

      expect(titles(shown), [
        'Favorites',
        'abba',
        'Beck',
        'Calm',
        'Jazz',
        'Odelay',
        'Road trip',
        'Untitled',
      ]);
    });

    test('recents puts opened items first, newest first, then A to Z', () {
      final shown = visibleLibraryEntries(
        entries,
        sort: LibrarySort.recents,
        opened: {'album:al1': 100, 'playlist:p1': 300, 'artist:a1': 200},
      );

      expect(titles(shown), [
        'Favorites',
        'Road trip', // 300
        'Beck', // 200
        'Odelay', // 100
        'abba',
        'Calm',
        'Jazz',
        'Untitled',
      ]);
    });

    test('Favorites stays on top even when it is not the most recent', () {
      final shown = visibleLibraryEntries(
        entries,
        sort: LibrarySort.recents,
        opened: {'playlist:p2': 999, 'favorites': 1},
      );

      expect(shown.first.title, 'Favorites');
      expect(shown[1].title, 'Calm');
    });

    test('recents with nothing opened falls back to A to Z', () {
      final recents = visibleLibraryEntries(entries, sort: LibrarySort.recents);
      final alpha =
          visibleLibraryEntries(entries, sort: LibrarySort.alphabetical);

      expect(titles(recents), titles(alpha));
    });

    test('items opened at the same moment keep a stable A to Z order', () {
      final shown = visibleLibraryEntries(
        entries,
        opened: {'artist:a1': 50, 'artist:a2': 50},
      );

      expect(titles(shown).sublist(1, 3), ['abba', 'Beck']);
    });
  });
}
