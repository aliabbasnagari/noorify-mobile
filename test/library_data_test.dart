import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/state/library_data.dart';
import 'package:noorify/state/playlists_revision.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );

  late PlaylistsRevision revision;
  late LibraryData data;

  /// Endpoints the fake server should fail, and every request it saw.
  late Set<String> failing;
  late List<String> requested;

  /// When set, requests to this endpoint wait for the completer.
  late Map<String, Completer<void>> gates;

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  SubsonicClient newClient({String playlistName = 'Road trip'}) =>
      SubsonicClient(
        config,
        httpClient: MockClient((req) async {
          final endpoint = req.url.pathSegments.last;
          requested.add(endpoint);
          await gates[endpoint]?.future;
          if (failing.contains(endpoint)) throw http.ClientException('down');
          switch (endpoint) {
            case 'getPlaylists.view':
              return ok({
                'playlists': {
                  'playlist': [
                    {'id': 'p1', 'name': playlistName},
                  ],
                },
              });
            case 'getArtists.view':
              return ok({
                'artists': {
                  'index': [
                    {
                      'name': 'B',
                      'artist': [
                        {'id': 'a1', 'name': 'Beck'},
                      ],
                    },
                  ],
                },
              });
            case 'getAlbumList2.view':
              return ok({
                'albumList2': {
                  'album': [
                    {'id': 'al1', 'name': 'Odelay'},
                  ],
                },
              });
          }
          return ok({});
        }),
      );

  int count(String endpoint) => requested.where((e) => e == endpoint).length;

  setUp(() {
    revision = PlaylistsRevision();
    data = LibraryData(revision);
    failing = {};
    requested = [];
    gates = {};
  });

  tearDown(() => data.dispose());

  test('attaching a client loads playlists, artists and albums', () async {
    expect(data.hasAnyData, isFalse);

    data.attach(newClient());
    await pumpEventQueue();

    expect(data.playlists!.single.name, 'Road trip');
    expect(data.artists!.single.name, 'Beck');
    expect(data.albums!.single.name, 'Odelay');
    expect(data.isLoading, isFalse);
    expect(data.someFailed, isFalse);
    expect(data.hasAnyData, isTrue);
  });

  test('albums are requested A to Z, a page at a time', () async {
    final requests = <Uri>[];
    data.attach(SubsonicClient(
      config,
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return ok({});
      }),
    ));
    await pumpEventQueue();

    final albumRequest =
        requests.firstWhere((u) => u.pathSegments.last == 'getAlbumList2.view');
    expect(albumRequest.queryParameters['type'], 'alphabeticalByName');
    expect(
        albumRequest.queryParameters['size'], '${LibraryData.albumPageSize}');
  });

  group('albums past the first page', () {
    /// A server holding [total] albums that honours `offset` and `size`, or
    /// (with [honourOffset] false) always answers with the first page. A page
    /// at an offset in [failAt] is an error.
    MockClient albumServer(
      int total, {
      bool honourOffset = true,
      Set<int> failAt = const {},
      List<int>? offsets,
    }) =>
        MockClient((req) async {
          if (req.url.pathSegments.last != 'getAlbumList2.view') {
            return ok({});
          }
          final offset = honourOffset
              ? int.parse(req.url.queryParameters['offset'] ?? '0')
              : 0;
          offsets?.add(offset);
          if (failAt.contains(offset)) return http.Response('boom', 500);
          final size = int.parse(req.url.queryParameters['size']!);
          final end = (offset + size).clamp(0, total);
          return ok({
            'albumList2': {
              'album': [
                for (var i = offset; i < end; i++)
                  {'id': 'al$i', 'name': 'Album $i'},
              ],
            },
          });
        });

    SubsonicClient clientFor(MockClient mock) =>
        SubsonicClient(config, httpClient: mock);

    test('are all loaded, one request per page', () async {
      final offsets = <int>[];
      data.attach(clientFor(albumServer(1200, offsets: offsets)));
      await pumpEventQueue();

      expect(data.albums, hasLength(1200));
      expect(offsets, [0, 500, 1000]);
      expect(data.someFailed, isFalse);
    });

    test('an exact multiple of the page size costs one extra, empty request',
        () async {
      final offsets = <int>[];
      data.attach(clientFor(albumServer(1000, offsets: offsets)));
      await pumpEventQueue();

      expect(data.albums, hasLength(1000));
      expect(offsets, [0, 500, 1000]);
    });

    test('a server that ignores the offset does not loop forever', () async {
      final offsets = <int>[];
      data.attach(
          clientFor(albumServer(900, honourOffset: false, offsets: offsets)));
      await pumpEventQueue();

      expect(data.albums, hasLength(500));
      expect(offsets, [0, 0]);
    });

    test('a failed later page keeps the albums already loaded and flags it',
        () async {
      data.attach(clientFor(albumServer(1200, failAt: {500})));
      await pumpEventQueue();

      expect(data.albums, hasLength(500));
      expect(data.someFailed, isTrue);
      expect(data.isLoading, isFalse);
    });

    test('a failed first page leaves the albums unloaded', () async {
      data.attach(clientFor(albumServer(1200, failAt: {0})));
      await pumpEventQueue();

      expect(data.albums, isNull);
      expect(data.someFailed, isTrue);
    });

    test('stops at the overall cap', () async {
      final offsets = <int>[];
      data.attach(clientFor(albumServer(20000, offsets: offsets)));
      await pumpEventQueue();

      expect(data.albums, hasLength(LibraryData.maxAlbums));
      expect(offsets.last, LibraryData.maxAlbums - LibraryData.albumPageSize);
    });
  });

  test('loading never notifies during attach, only afterwards', () async {
    var notified = 0;
    data.addListener(() => notified++);

    data.attach(newClient());
    expect(notified, 0, reason: 'attach runs during a provider update');

    await pumpEventQueue();
    expect(notified, greaterThan(0));
  });

  test('a failing source leaves the others, and flags a retry', () async {
    failing = {'getArtists.view'};

    data.attach(newClient());
    await pumpEventQueue();

    expect(data.playlists, isNotNull);
    expect(data.albums, isNotNull);
    expect(data.artists, isNull);
    expect(data.someFailed, isTrue);
  });

  test('when nothing can be reached, there is no data and a retry is offered',
      () async {
    failing = {'getPlaylists.view', 'getArtists.view', 'getAlbumList2.view'};

    data.attach(newClient());
    await pumpEventQueue();

    expect(data.hasAnyData, isFalse);
    expect(data.someFailed, isTrue);
    expect(data.isLoading, isFalse);
  });

  test('a failed refresh keeps what was loaded before', () async {
    data.attach(newClient());
    await pumpEventQueue();
    failing = {'getPlaylists.view'};

    await data.refresh();

    expect(data.playlists!.single.name, 'Road trip');
    expect(data.someFailed, isTrue);
  });

  test('retry after a failure fills in the missing source', () async {
    failing = {'getArtists.view'};
    data.attach(newClient());
    await pumpEventQueue();
    expect(data.artists, isNull);

    failing = {};
    await data.refresh();

    expect(data.artists!.single.name, 'Beck');
    expect(data.someFailed, isFalse);
  });

  test('a playlist created elsewhere triggers a reload', () async {
    data.attach(newClient());
    await pumpEventQueue();
    expect(count('getPlaylists.view'), 1);

    revision.bump();
    await pumpEventQueue();

    expect(count('getPlaylists.view'), 2);
  });

  test('a different account clears the old lists first', () async {
    data.attach(newClient(playlistName: 'First account'));
    await pumpEventQueue();
    expect(data.playlists!.single.name, 'First account');

    gates['getPlaylists.view'] = Completer<void>();
    data.attach(newClient(playlistName: 'Second account'));

    expect(data.playlists, isNull, reason: 'never show another account');
    gates['getPlaylists.view']!.complete();
    await pumpEventQueue();
    expect(data.playlists!.single.name, 'Second account');
  });

  test('a slow load from an old account cannot overwrite the new one',
      () async {
    gates['getPlaylists.view'] = Completer<void>();
    data.attach(newClient(playlistName: 'Old account'));
    await pumpEventQueue();
    final oldGate = gates['getPlaylists.view']!;

    gates = {};
    data.attach(newClient(playlistName: 'New account'));
    await pumpEventQueue();
    expect(data.playlists!.single.name, 'New account');

    oldGate.complete();
    await pumpEventQueue();

    expect(data.playlists!.single.name, 'New account');
  });

  test('signing out clears everything and stops loading', () async {
    data.attach(newClient());
    await pumpEventQueue();

    data.attach(null);
    await pumpEventQueue();

    expect(data.hasAnyData, isFalse);
    expect(data.isLoading, isFalse);
    final before = requested.length;
    await data.refresh();
    expect(requested.length, before, reason: 'no client, no requests');
  });

  test('disposing stops it listening to playlist changes', () async {
    data.attach(newClient());
    await pumpEventQueue();
    data.dispose();

    // Would throw (notify after dispose) if it were still listening.
    revision.bump();
    await pumpEventQueue();

    // Replace the disposed instance so tearDown has something valid.
    data = LibraryData(revision);
  });
}
