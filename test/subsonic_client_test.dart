import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/state/session_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com/base/',
    username: 'alice',
    password: 'sesame',
  );

  group('SubsonicClient URLs', () {
    test('uses token auth with salt and never sends the password', () {
      final client = SubsonicClient(config, salt: 'c19b2d');
      final uri = client.buildUri('ping');

      expect(uri.path, '/base/rest/ping.view');
      expect(uri.queryParameters['u'], 'alice');
      expect(uri.queryParameters['s'], 'c19b2d');
      expect(
        uri.queryParameters['t'],
        md5.convert(utf8.encode('sesamec19b2d')).toString(),
      );
      expect(uri.queryParameters['f'], 'json');
      expect(uri.toString(), isNot(contains('sesame')));
      expect(uri.queryParameters.containsKey('p'), isFalse);
    });

    test('repeats list parameters', () {
      final client = SubsonicClient(config, salt: 'x');
      final uri = client.buildUri('createPlaylist', {
        'name': 'Mix',
        'songId': ['1', '2', '3'],
      });
      expect(uri.queryParametersAll['songId'], ['1', '2', '3']);
    });

    test('streamUrl and coverArtUrl are stable for one client', () {
      final client = SubsonicClient(config);
      expect(client.streamUrl('42'), client.streamUrl('42'));
      expect(
        client.coverArtUrl('al-1', size: 200).queryParameters['size'],
        '200',
      );
    });
  });

  group('SubsonicClient responses', () {
    SubsonicClient clientReplying(String body, {int status = 200}) =>
        SubsonicClient(
          config,
          httpClient: MockClient((_) async => http.Response(body, status)),
        );

    test('parses an album with songs', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'album': {
            'id': 'a1',
            'name': 'Album',
            'artist': 'Artist',
            'song': [
              {'id': 's1', 'title': 'One', 'duration': 61, 'track': 1},
              {'id': 's2', 'title': 'Two', 'duration': 90, 'track': 2},
            ],
          },
        },
      }));
      final album = await client.getAlbum('a1');
      expect(album.songs.map((s) => s.title), ['One', 'Two']);
      expect(album.songs.first.duration, 61);
    });

    test('surfaces server errors', () {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'failed',
          'error': {'code': 40, 'message': 'Wrong username or password'},
        },
      }));
      expect(
        client.ping(),
        throwsA(isA<SubsonicException>()
            .having((e) => e.code, 'code', 40)
            .having((e) => e.message, 'message', contains('Wrong'))),
      );
    });

    test('rejects non-Subsonic responses', () {
      final client = clientReplying('<html>nope</html>');
      expect(client.ping(), throwsA(isA<SubsonicException>()));
    });

    test('song pages request an offset and parse OpenSubsonic fields',
        () async {
      late Uri requested;
      final client = SubsonicClient(
        config,
        httpClient: MockClient((req) async {
          requested = req.url;
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'searchResult3': {
                  'song': [
                    {
                      'id': 's1',
                      'title': 'One',
                      'genre': 'Jazz',
                      'playCount': 7,
                      'replayGain': {'trackGain': -6.2, 'trackPeak': 0.97},
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );
      final songs = await client.getSongsPage(offset: 1000, size: 500);
      expect(requested.path, endsWith('/rest/search3.view'));
      expect(requested.queryParameters['songOffset'], '1000');
      expect(requested.queryParameters['songCount'], '500');
      expect(songs.single.genre, 'Jazz');
      expect(songs.single.playCount, 7);
      expect(songs.single.replayGain?.trackGain, -6.2);
    });

    test('download URL targets the original file endpoint', () {
      final client = SubsonicClient(config, salt: 'x');
      final uri = client.downloadUrl('42');
      expect(uri.path, endsWith('/rest/download.view'));
      expect(uri.queryParameters['id'], '42');
    });

    test('empty playlist list parses to empty', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {'status': 'ok', 'playlists': {}},
      }));
      expect(await client.getPlaylists(), isEmpty);
    });

    test('getGenres parses names and counts', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'genres': {
            'genre': [
              {'value': 'Jazz', 'songCount': 12, 'albumCount': 3},
            ],
          },
        },
      }));
      final genres = await client.getGenres();
      expect(genres.single.name, 'Jazz');
      expect(genres.single.songCount, 12);
      expect(genres.single.albumCount, 3);
    });

    test('getSimilarSongs calls similarSongs2 and parses songs', () async {
      late Uri requested;
      final client = SubsonicClient(
        config,
        httpClient: MockClient((req) async {
          requested = req.url;
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'similarSongs2': {
                  'song': [
                    {'id': 's1', 'title': 'One'},
                  ],
                },
              },
            }),
            200,
          );
        }),
      );
      final songs = await client.getSimilarSongs('ar-1', count: 10);
      expect(requested.path, endsWith('/rest/getSimilarSongs2.view'));
      expect(requested.queryParameters['id'], 'ar-1');
      expect(requested.queryParameters['count'], '10');
      expect(songs.single.title, 'One');
    });

    test('getTopSongs parses songs', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'topSongs': {
            'song': [
              {'id': 's1', 'title': 'Hit'},
            ],
          },
        },
      }));
      final songs = await client.getTopSongs('The Beatles');
      expect(songs.single.title, 'Hit');
    });

    test('getBookmarks parses position and nested song entry', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'bookmarks': {
            'bookmark': [
              {
                'position': 42000,
                'comment': 'resume here',
                'entry': {'id': 's1', 'title': 'One'},
              },
            ],
          },
        },
      }));
      final bookmarks = await client.getBookmarks();
      expect(bookmarks.single.position, 42000);
      expect(bookmarks.single.comment, 'resume here');
      expect(bookmarks.single.song.title, 'One');
    });

    test('getLyrics parses structured lyric lines', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'lyricsList': {
            'structuredLyrics': [
              {
                'displayArtist': 'Artist',
                'displayTitle': 'Title',
                'synced': true,
                'line': [
                  {'start': 0, 'value': 'La la'},
                  {'start': 2000, 'value': 'La la la'},
                ],
              },
            ],
          },
        },
      }));
      final lyrics = await client.getLyrics('s1');
      expect(lyrics.single.synced, isTrue);
      expect(lyrics.single.lines, hasLength(2));
      expect(lyrics.single.lines[1].startMs, 2000);
    });

    test('getInternetRadioStations parses stations', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'internetRadioStations': {
            'internetRadioStation': [
              {'id': 'r1', 'name': 'My Station', 'streamUrl': 'http://stream'},
            ],
          },
        },
      }));
      final stations = await client.getInternetRadioStations();
      expect(stations.single.name, 'My Station');
      expect(stations.single.streamUrl, 'http://stream');
    });

    test('getOpenSubsonicExtensions maps names to version lists', () async {
      final client = clientReplying(jsonEncode({
        'subsonic-response': {
          'status': 'ok',
          'openSubsonicExtensions': [
            {
              'name': 'songLyrics',
              'versions': [1, 2]
            },
          ],
        },
      }));
      final ext = await client.getOpenSubsonicExtensions();
      expect(ext['songLyrics'], [1, 2]);
    });
  });

  group('SessionController.normalizeUrl', () {
    test('adds scheme and strips trailing slashes', () {
      expect(SessionController.normalizeUrl('music.example.com//'),
          'https://music.example.com');
      expect(SessionController.normalizeUrl(' http://host:4533/ '),
          'http://host:4533');
    });
  });
}
