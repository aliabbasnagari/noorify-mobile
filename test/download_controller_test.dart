import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/state/download_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

/// A fake server for the `download` endpoint. It can hold a download open
/// (to observe concurrency and cancellation), fail the first N attempts, or
/// answer with an error body instead of audio.
class _DownloadServer {
  final Map<String, Completer<void>> gates = {};
  final Map<String, int> failuresLeft = {};
  final Map<String, int> hits = {};
  String contentType = 'audio/mpeg';
  int inFlight = 0;
  int maxInFlight = 0;

  Future<http.Response> handle(http.Request request) async {
    final id = request.url.queryParameters['id']!;
    hits[id] = (hits[id] ?? 0) + 1;
    inFlight++;
    maxInFlight = math.max(maxInFlight, inFlight);
    try {
      await gates[id]?.future;
      if ((failuresLeft[id] ?? 0) > 0) {
        failuresLeft[id] = failuresLeft[id]! - 1;
        throw http.ClientException('connection dropped');
      }
      return http.Response.bytes(
        List.filled(100, 7),
        200,
        headers: {'content-type': contentType},
      );
    } finally {
      inFlight--;
    }
  }
}

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );

  late Directory root;
  late _DownloadServer server;
  late List<Song> albumSongs;

  Song song(String id) => Song(id: id, title: 'Title $id', suffix: 'mp3');

  /// The folder the controller keeps its files in.
  Directory downloadsDir() => Directory('${root.path}/downloads');

  List<String> filesOnDisk() => downloadsDir().existsSync()
      ? [
          for (final f in downloadsDir().listSync())
            f.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ]
      : [];

  DownloadController newController() => DownloadController(
        directoryProvider: () async => root,
        httpClientFactory: () => MockClient(server.handle),
      );

  SubsonicClient newClient() => SubsonicClient(
        config,
        httpClient: MockClient((req) async {
          // Only getAlbum is needed, for refreshing offline collections.
          final body = {
            'subsonic-response': {
              'status': 'ok',
              'album': {
                'id': 'al1',
                'name': 'Album',
                'song': [for (final s in albumSongs) s.toJson()],
              },
            },
          };
          return http.Response(jsonEncode(body), 200);
        }),
      );

  /// Real time: the controller does real file IO and real retry delays.
  Future<void> until(bool Function() condition, {int seconds = 10}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!condition()) {
      if (DateTime.now().isAfter(end)) fail('timed out waiting for condition');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> idle(DownloadController d) => until(() => d.activeCount == 0);

  Future<DownloadController> attached() async {
    final d = newController()..attach(newClient());
    // attach() loads the (possibly empty) index asynchronously.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return d;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('noorify_downloads_');
    server = _DownloadServer();
    albumSongs = [];
  });

  tearDown(() => root.delete(recursive: true));

  group('downloading', () {
    test('saves the file, indexes it and reports its size', () async {
      final d = await attached();

      await d.downloadSongs([song('s1')]);
      await idle(d);

      expect(d.isDownloaded('s1'), isTrue);
      expect(File(d.localPath('s1')!).lengthSync(), 100);
      expect(d.usedBytes, 100);
      expect(d.downloaded.single.sources, {DownloadController.manualSource});
      expect(d.failures, isEmpty);
      final index = jsonDecode(
          File('${downloadsDir().path}/index.json').readAsStringSync());
      expect((index['songs'] as List).single['song']['id'], 's1');
    });

    test('runs at most two downloads at a time', () async {
      final d = await attached();
      final ids = ['s1', 's2', 's3', 's4', 's5'];
      for (final id in ids) {
        server.gates[id] = Completer<void>();
      }

      await d.downloadSongs([for (final id in ids) song(id)]);
      await until(() => server.inFlight == 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.inFlight, 2);
      expect(d.activeCount, 5);

      for (final id in ids) {
        server.gates[id]!.complete();
      }
      await idle(d);

      expect(server.maxInFlight, 2);
      expect(d.downloaded.map((s) => s.song.id), unorderedEquals(ids));
    });

    test('retries a download that fails once', () async {
      final d = await attached();
      server.failuresLeft['s1'] = 1;

      await d.downloadSongs([song('s1')]);
      await idle(d);

      expect(d.isDownloaded('s1'), isTrue);
      expect(server.hits['s1'], 2);
      expect(d.failures, isEmpty);
    });

    test('gives up after three attempts and cleans up the partial file',
        () async {
      final d = await attached();
      server.failuresLeft['s1'] = 99;

      await d.downloadSongs([song('s1')]);
      await idle(d);

      expect(d.isDownloaded('s1'), isFalse);
      expect(d.failures.keys, ['s1']);
      expect(server.hits['s1'], 3);
      expect(filesOnDisk().where((f) => f.endsWith('.part')), isEmpty);
    });

    test('treats a 200 response with an error body as a failure', () async {
      final d = await attached();
      server.contentType = 'application/json';

      await d.downloadSongs([song('s1')]);
      await idle(d);

      expect(d.isDownloaded('s1'), isFalse);
      expect(d.failures['s1'], contains('refused'));
    });

    test('asking again for a song already kept only adds a reason', () async {
      final d = await attached();
      await d.downloadSongs([song('s1')]);
      await idle(d);

      await d.downloadSongs([song('s1')], source: 'album:al1');

      expect(server.hits['s1'], 1);
      expect(d.downloaded.single.sources,
          {DownloadController.manualSource, 'album:al1'});
    });
  });

  group('offline collections', () {
    const album = OfflineCollection(type: 'album', id: 'al1', title: 'Album');

    test('removing a collection deletes only songs nothing else keeps',
        () async {
      final d = await attached();
      await d.downloadSongs([song('s1')]); // also kept manually
      await idle(d);
      await d.setCollectionOffline(album, [song('s1'), song('s2')]);
      await idle(d);
      final s2File = d.localPath('s2')!;
      expect(d.isCollectionOffline('album', 'al1'), isTrue);

      await d.removeCollection(album.key);

      expect(d.isCollectionOffline('album', 'al1'), isFalse);
      expect(d.isDownloaded('s1'), isTrue);
      expect(d.isDownloaded('s2'), isFalse);
      expect(File(s2File).existsSync(), isFalse);
    });

    test('refresh downloads new songs and drops ones removed server-side',
        () async {
      final d = await attached();
      await d.setCollectionOffline(album, [song('s1'), song('s2')]);
      await idle(d);

      albumSongs = [song('s1'), song('s3')];
      await d.refreshCollections();
      await idle(d);

      expect(d.isDownloaded('s1'), isTrue);
      expect(d.isDownloaded('s2'), isFalse);
      expect(d.isDownloaded('s3'), isTrue);
    });
  });

  group('persistence', () {
    test('a new controller reloads the index and prunes missing files',
        () async {
      final first = await attached();
      await first.downloadSongs([song('s1'), song('s2')]);
      await idle(first);
      File(first.localPath('s2')!).deleteSync();

      final second = await attached();

      expect(second.isDownloaded('s1'), isTrue);
      expect(second.isDownloaded('s2'), isFalse);
    });

    test('removeSong deletes the file and forgets the song', () async {
      final d = await attached();
      await d.downloadSongs([song('s1')]);
      await idle(d);
      final path = d.localPath('s1')!;

      await d.removeSong('s1');

      expect(d.isDownloaded('s1'), isFalse);
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('clearAll', () {
    test('removes every file, song and collection', () async {
      final d = await attached();
      await d.setCollectionOffline(
        const OfflineCollection(type: 'album', id: 'al1', title: 'Album'),
        [song('s1'), song('s2')],
      );
      await idle(d);

      await d.clearAll();

      expect(d.downloaded, isEmpty);
      expect(d.collections, isEmpty);
      expect(filesOnDisk().where((f) => f.endsWith('.mp3')), isEmpty);
      final reloaded = await attached();
      expect(reloaded.downloaded, isEmpty);
      expect(reloaded.collections, isEmpty);
    });

    test('abandons a download that is still in flight', () async {
      final d = await attached();
      server.gates['s1'] = Completer<void>();
      await d.downloadSongs([song('s1')]);
      await until(() => server.inFlight == 1);

      await d.clearAll();
      server.gates['s1']!.complete();
      await until(() => server.inFlight == 0);
      await idle(d);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(d.isDownloaded('s1'), isFalse);
      expect(d.downloaded, isEmpty);
      expect(
        filesOnDisk().where((f) => f.endsWith('.mp3') || f.endsWith('.part')),
        isEmpty,
      );
    });
  });
}
