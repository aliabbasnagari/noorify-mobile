import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

/// Requests the fake server received during the current test.
List<Uri> requests = [];

/// The one request a test expects the client to have made.
Uri get sent => requests.single;

String endpoint(Uri u) => u.pathSegments.last;

/// Checks the requests the client sends for every mutating call, and the
/// parsing of the read calls `subsonic_client_test.dart` doesn't cover.
void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );

  /// A client whose server answers every call with [body] inside the standard
  /// `subsonic-response` envelope.
  SubsonicClient clientReplying([Map<String, dynamic>? body]) {
    requests = [];
    return SubsonicClient(
      config,
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return http.Response(
          jsonEncode({
            'subsonic-response': {'status': 'ok', ...?body},
          }),
          200,
        );
      }),
    );
  }

  group('playlists', () {
    test('createPlaylist sends the name and one songId per song', () async {
      await clientReplying().createPlaylist('Mix', songIds: ['1', '2']);

      expect(endpoint(sent), 'createPlaylist.view');
      expect(sent.queryParameters['name'], 'Mix');
      expect(sent.queryParametersAll['songId'], ['1', '2']);
    });

    test('createPlaylist with no songs sends no songId', () async {
      await clientReplying().createPlaylist('Empty');

      expect(sent.queryParametersAll.containsKey('songId'), isFalse);
    });

    test('addToPlaylist uses updatePlaylist with songIdToAdd', () async {
      await clientReplying().addToPlaylist('p1', ['7', '8']);

      expect(endpoint(sent), 'updatePlaylist.view');
      expect(sent.queryParameters['playlistId'], 'p1');
      expect(sent.queryParametersAll['songIdToAdd'], ['7', '8']);
    });

    test('removeFromPlaylist uses updatePlaylist with song indexes', () async {
      await clientReplying().removeFromPlaylist('p1', [0, 3]);

      expect(endpoint(sent), 'updatePlaylist.view');
      expect(sent.queryParameters['playlistId'], 'p1');
      expect(sent.queryParametersAll['songIndexToRemove'], ['0', '3']);
    });

    test('renamePlaylist uses updatePlaylist with the new name', () async {
      await clientReplying().renamePlaylist('p1', 'Night drive');

      expect(endpoint(sent), 'updatePlaylist.view');
      expect(sent.queryParameters['playlistId'], 'p1');
      expect(sent.queryParameters['name'], 'Night drive');
      expect(sent.queryParametersAll.containsKey('songIdToAdd'), isFalse);
    });

    test('reorderPlaylist replaces the songs, in order, in one request',
        () async {
      await clientReplying().reorderPlaylist('p1', ['s3', 's1', 's2']);

      expect(endpoint(sent), 'createPlaylist.view');
      expect(sent.queryParameters['playlistId'], 'p1');
      expect(sent.queryParametersAll['songId'], ['s3', 's1', 's2']);
      expect(sent.queryParametersAll.containsKey('name'), isFalse,
          reason: 'a name would make a new playlist');
    });

    test('deletePlaylist sends the id', () async {
      await clientReplying().deletePlaylist('p1');

      expect(endpoint(sent), 'deletePlaylist.view');
      expect(sent.queryParameters['id'], 'p1');
    });

    test('getPlaylist reads the entry list as songs', () async {
      final playlist = await clientReplying({
        'playlist': {
          'id': 'p1',
          'name': 'Road trip',
          'songCount': 2,
          'entry': [
            {'id': 's1', 'title': 'One'},
            {'id': 's2', 'title': 'Two'},
          ],
        },
      }).getPlaylist('p1');

      expect(sent.queryParameters['id'], 'p1');
      expect(playlist.name, 'Road trip');
      expect(playlist.songs.map((s) => s.id), ['s1', 's2']);
    });
  });

  group('annotation', () {
    test('star and unstar send the song id to their own endpoints', () async {
      final client = clientReplying();

      await client.star('s1');
      await client.unstar('s2');

      expect(requests.map(endpoint), ['star.view', 'unstar.view']);
      expect(requests.map((r) => r.queryParameters['id']), ['s1', 's2']);
    });

    test('scrobble counts as a play by default', () async {
      await clientReplying().scrobble('s1');

      expect(endpoint(sent), 'scrobble.view');
      expect(sent.queryParameters['id'], 's1');
      expect(sent.queryParameters['submission'], 'true');
    });

    test('scrobble with submission false is only "now playing"', () async {
      await clientReplying().scrobble('s1', submission: false);

      expect(sent.queryParameters['submission'], 'false');
    });

    test('getStarredSongs reads the starred songs', () async {
      final songs = await clientReplying({
        'starred2': {
          'song': [
            {'id': 's1', 'title': 'One', 'starred': '2026-01-01T00:00:00Z'},
          ],
        },
      }).getStarredSongs();

      expect(endpoint(sent), 'getStarred2.view');
      expect(songs.single.id, 's1');
      expect(songs.single.starred, isTrue);
    });

    test('getStarredSongs is empty when nothing is starred', () async {
      expect(await clientReplying({'starred2': {}}).getStarredSongs(), isEmpty);
    });
  });

  group('bookmarks', () {
    test('createBookmark sends the song, position and comment', () async {
      await clientReplying()
          .createBookmark('s1', comment: 'chapter 2', position: 90000);

      expect(endpoint(sent), 'createBookmark.view');
      expect(sent.queryParameters['id'], 's1');
      expect(sent.queryParameters['position'], '90000');
      expect(sent.queryParameters['comment'], 'chapter 2');
    });

    test('createBookmark leaves the comment out when there is none', () async {
      await clientReplying().createBookmark('s1');

      expect(sent.queryParameters['position'], '0');
      expect(sent.queryParameters.containsKey('comment'), isFalse);
    });

    test('deleteBookmark sends the song id', () async {
      await clientReplying().deleteBookmark('s1');

      expect(endpoint(sent), 'deleteBookmark.view');
      expect(sent.queryParameters['id'], 's1');
    });
  });

  group('internet radio', () {
    test('createInternetRadio sends name, stream and homepage URLs', () async {
      await clientReplying().createInternetRadio(
        'FM',
        'https://radio.example.com/live',
        homepageUrl: 'https://radio.example.com',
      );

      expect(endpoint(sent), 'createInternetRadioStation.view');
      expect(sent.queryParameters['name'], 'FM');
      expect(
          sent.queryParameters['streamUrl'], 'https://radio.example.com/live');
      expect(sent.queryParameters['homepageUrl'], 'https://radio.example.com');
    });

    test('createInternetRadio leaves the homepage out when there is none',
        () async {
      await clientReplying()
          .createInternetRadio('FM', 'https://r.example/live');

      expect(sent.queryParameters.containsKey('homepageUrl'), isFalse);
    });

    test('updateInternetRadio sends the station id and new details', () async {
      await clientReplying()
          .updateInternetRadio('r1', 'FM 2', 'https://r.example/2');

      expect(endpoint(sent), 'updateInternetRadioStation.view');
      expect(sent.queryParameters['id'], 'r1');
      expect(sent.queryParameters['name'], 'FM 2');
      expect(sent.queryParameters['streamUrl'], 'https://r.example/2');
    });

    test('deleteInternetRadio sends the station id', () async {
      await clientReplying().deleteInternetRadio('r1');

      expect(endpoint(sent), 'deleteInternetRadioStation.view');
      expect(sent.queryParameters['id'], 'r1');
    });
  });

  group('failures', () {
    test('a failed write surfaces the server message and code', () {
      final client = SubsonicClient(
        config,
        httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'subsonic-response': {
                  'status': 'failed',
                  'error': {'code': 50, 'message': 'User is not authorized'},
                },
              }),
              200,
            )),
      );

      expect(
        client.deletePlaylist('p1'),
        throwsA(isA<SubsonicException>()
            .having((e) => e.code, 'code', 50)
            .having((e) => e.message, 'message', 'User is not authorized')),
      );
    });

    test('a network error is reported as unreachable', () {
      final client = SubsonicClient(
        config,
        httpClient: MockClient((_) async => throw http.ClientException('down')),
      );

      expect(
        client.star('s1'),
        throwsA(isA<SubsonicException>().having(
            (e) => e.message, 'message', startsWith('Could not reach server'))),
      );
    });
  });

  group('artist info', () {
    test('reads the biography, picture and similar artists', () async {
      final info = await clientReplying({
        'artistInfo2': {
          'biography':
              'Beck is an <a href="https://x.example">American</a> artist.<br/>'
                  'Rock &amp; folk.',
          'lastFmUrl': 'https://last.fm/music/Beck',
          'smallImageUrl': 'https://img.example/s.jpg',
          'mediumImageUrl': 'https://img.example/m.jpg',
          'largeImageUrl': 'https://img.example/l.jpg',
          'similarArtist': [
            {'id': 'a2', 'name': 'Beirut', 'albumCount': 3},
            {'id': 'a3', 'name': 'Bon Iver'},
          ],
        },
      }).getArtistInfo('a1', similarCount: 5);

      expect(endpoint(sent), 'getArtistInfo2.view');
      expect(sent.queryParameters['id'], 'a1');
      expect(sent.queryParameters['count'], '5');
      expect(info.biography, 'Beck is an American artist.\nRock & folk.');
      expect(info.imageUrl, 'https://img.example/l.jpg');
      expect(info.lastFmUrl, 'https://last.fm/music/Beck');
      expect(info.similarArtists.map((a) => a.name), ['Beirut', 'Bon Iver']);
      expect(info.similarArtists.first.albumCount, 3);
      expect(info.isEmpty, isFalse);
    });

    test('falls back to a smaller picture when the large one is missing',
        () async {
      final info = await clientReplying({
        'artistInfo2': {'smallImageUrl': 'https://img.example/s.jpg'},
      }).getArtistInfo('a1');

      expect(info.imageUrl, 'https://img.example/s.jpg');
    });

    test('an artist the server knows nothing about gives empty info', () async {
      final info =
          await clientReplying({'artistInfo2': {}}).getArtistInfo('a1');

      expect(info.isEmpty, isTrue);
      expect(info.biography, isNull);
      expect(info.similarArtists, isEmpty);
    });

    test('a response with no artistInfo2 at all is also empty', () async {
      expect((await clientReplying().getArtistInfo('a1')).isEmpty, isTrue);
    });

    test('blank text fields count as missing', () async {
      final info = await clientReplying({
        'artistInfo2': {
          'biography': '   ',
          'lastFmUrl': '',
          'largeImageUrl': '  ',
        },
      }).getArtistInfo('a1');

      expect(info.isEmpty, isTrue);
    });

    test('a biography that is only markup is treated as missing', () async {
      final info = await clientReplying({
        'artistInfo2': {'biography': '<a href="x"></a><br/>'},
      }).getArtistInfo('a1');

      expect(info.biography, isNull);
    });

    test('plainText decodes the common entities and tidies line ends', () {
      expect(ArtistInfo.plainText('Tom &amp; Jerry &quot;live&quot; &#39;99'),
          'Tom & Jerry "live" \'99');
      expect(ArtistInfo.plainText('a  \nb'), 'a\nb');
      expect(ArtistInfo.plainText(null), isNull);
    });

    test('a server error is reported like any other call', () {
      final client = SubsonicClient(
        config,
        httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'subsonic-response': {
                  'status': 'failed',
                  'error': {'code': 70, 'message': 'Artist not found'},
                },
              }),
              200,
            )),
      );

      expect(
        client.getArtistInfo('nope'),
        throwsA(isA<SubsonicException>().having((e) => e.code, 'code', 70)),
      );
    });
  });

  group('browsing reads', () {
    test('getArtists flattens the A-Z index', () async {
      final artists = await clientReplying({
        'artists': {
          'index': [
            {
              'name': 'A',
              'artist': [
                {'id': 'a1', 'name': 'Abba', 'albumCount': 3},
              ],
            },
            {
              'name': 'B',
              'artist': [
                {'id': 'b1', 'name': 'Beck'},
                {'id': 'b2', 'name': 'Bjork'},
              ],
            },
          ],
        },
      }).getArtists();

      expect(endpoint(sent), 'getArtists.view');
      expect(artists.map((a) => a.name), ['Abba', 'Beck', 'Bjork']);
      expect(artists.first.albumCount, 3);
    });

    test('getAlbumList sends type, size and offset and parses albums',
        () async {
      final albums = await clientReplying({
        'albumList2': {
          'album': [
            {'id': 'al1', 'name': 'One', 'artist': 'X', 'songCount': 9},
          ],
        },
      }).getAlbumList(AlbumListType.alphabetical, size: 60, offset: 120);

      expect(endpoint(sent), 'getAlbumList2.view');
      expect(sent.queryParameters['type'], 'alphabeticalByName');
      expect(sent.queryParameters['size'], '60');
      expect(sent.queryParameters['offset'], '120');
      expect(albums.single.name, 'One');
      expect(albums.single.songCount, 9);
    });

    test('every AlbumListType maps to its getAlbumList2 value', () {
      expect(
        {for (final t in AlbumListType.values) t: t.apiValue},
        {
          AlbumListType.newest: 'newest',
          AlbumListType.recent: 'recent',
          AlbumListType.frequent: 'frequent',
          AlbumListType.random: 'random',
          AlbumListType.alphabetical: 'alphabeticalByName',
          AlbumListType.starred: 'starred',
        },
      );
    });

    test('search sends the query with per-type counts and parses all three',
        () async {
      final results = await clientReplying({
        'searchResult3': {
          'artist': [
            {'id': 'a1', 'name': 'Abba'},
          ],
          'album': [
            {'id': 'al1', 'name': 'Arrival'},
          ],
          'song': [
            {'id': 's1', 'title': 'Dancing Queen'},
          ],
        },
      }).search('abba', count: 5);

      expect(endpoint(sent), 'search3.view');
      expect(sent.queryParameters['query'], 'abba');
      expect(sent.queryParameters['artistCount'], '5');
      expect(sent.queryParameters['albumCount'], '5');
      expect(sent.queryParameters['songCount'], '5');
      expect(results.artists.single.name, 'Abba');
      expect(results.albums.single.name, 'Arrival');
      expect(results.songs.single.title, 'Dancing Queen');
      expect(results.isEmpty, isFalse);
    });

    test('search with no matches is empty', () async {
      final results = await clientReplying({'searchResult3': {}}).search('zzz');

      expect(results.isEmpty, isTrue);
    });

    test('getArtist reads the artist with their albums', () async {
      final artist = await clientReplying({
        'artist': {
          'id': 'a1',
          'name': 'Abba',
          'album': [
            {'id': 'al1', 'name': 'Arrival'},
          ],
        },
      }).getArtist('a1');

      expect(sent.queryParameters['id'], 'a1');
      expect(artist.albums.single.name, 'Arrival');
    });

    test('ping succeeds on an ok response', () async {
      await clientReplying().ping();

      expect(endpoint(sent), 'ping.view');
    });
  });
}
