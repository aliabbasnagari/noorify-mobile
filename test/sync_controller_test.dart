import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/data/local/app_database.dart';
import 'package:noorify/state/sync_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );
  const owner = 'https://music.example.com|alice';

  late AppDatabase db;

  setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  SubsonicClient clientWithSongs(int count) => SubsonicClient(
        config,
        httpClient: MockClient((_) async {
          final body = {
            'subsonic-response': {
              'status': 'ok',
              'searchResult3': {
                'song': [
                  for (var i = 0; i < count; i++) {'id': 's$i', 'title': 'T$i'},
                ],
              },
            },
          };
          return http.Response(jsonEncode(body), 200);
        }),
      );

  test('sync stores the library and clear wipes it from memory and disk',
      () async {
    final sync = SyncController(db)..attach(clientWithSongs(3));
    await sync.sync();
    expect(sync.songs, hasLength(3));
    expect(await db.loadSongs(owner), hasLength(3));
    expect(await db.getLastSync(owner), isNotNull);

    await sync.clear();

    expect(sync.songs, isEmpty);
    expect(sync.lastSync, isNull);
    expect(await db.loadSongs(owner), isEmpty);
    expect(await db.getLastSync(owner), isNull);
  });

  test('clear leaves other accounts alone', () async {
    const other = 'https://music.example.com|bob';
    final sync = SyncController(db)..attach(clientWithSongs(2));
    await sync.sync();
    await db.replaceSongs(other, await db.loadSongs(owner));

    await sync.clear();

    expect(await db.loadSongs(other), hasLength(2));
  });

  test('clear with no session is a no-op', () async {
    final sync = SyncController(db);
    await sync.clear();
    expect(sync.songs, isEmpty);
  });
}
