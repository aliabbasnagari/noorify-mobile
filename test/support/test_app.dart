import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/data/local/app_database.dart';
import 'package:noorify/state/download_controller.dart';
import 'package:noorify/state/library_data.dart';
import 'package:noorify/state/library_recents.dart';
import 'package:noorify/state/player_controller.dart';
import 'package:noorify/state/playlists_revision.dart';
import 'package:noorify/state/search_query.dart';
import 'package:noorify/state/session_controller.dart';
import 'package:noorify/state/settings_controller.dart';
import 'package:noorify/state/smart_playlist_store.dart';
import 'package:noorify/state/star_controller.dart';
import 'package:noorify/state/sync_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';
import 'package:noorify/ui/adaptive/platform_caps.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_player.dart';

const savedLogin = {
  'server_url': 'https://music.example.com',
  'server_user': 'alice',
  'server_pass': 'sesame',
};

http.Response _ok(Map<String, dynamic> body) => http.Response(
      jsonEncode({
        'subsonic-response': {'status': 'ok', ...body},
      }),
      200,
    );

/// A fake Subsonic server with a small library: one artist (Beck), two albums
/// (Test Album and Odelay), one song and two playlists (Road trip and Calm).
http.Response defaultServer(http.Request request) {
  switch (request.url.pathSegments.last) {
    case 'getAlbumList2.view':
      return _ok({
        'albumList2': {
          'album': [
            {
              'id': 'al1',
              'name': 'Test Album',
              'artist': 'Test Artist',
              'songCount': 1,
            },
            {'id': 'al2', 'name': 'Odelay', 'artist': 'Beck', 'songCount': 1},
          ],
        },
      });
    case 'getAlbum.view':
      return _ok({
        'album': {
          'id': 'al1',
          'name': 'Test Album',
          'artist': 'Test Artist',
          'songCount': 1,
          'duration': 60,
          'song': [
            {'id': 's1', 'title': 'First Song', 'duration': 60, 'track': 1},
          ],
        },
      });
    case 'getArtists.view':
      return _ok({
        'artists': {
          'index': [
            {
              'name': 'B',
              'artist': [
                {'id': 'a1', 'name': 'Beck', 'albumCount': 1},
              ],
            },
          ],
        },
      });
    case 'getPlaylists.view':
      return _ok({
        'playlists': {
          'playlist': [
            {'id': 'p1', 'name': 'Road trip', 'songCount': 3, 'duration': 100},
            {'id': 'p2', 'name': 'Calm', 'songCount': 1, 'duration': 30},
          ],
        },
      });
    case 'getPlaylist.view':
      return _ok({
        'playlist': {
          'id': request.url.queryParameters['id'],
          'name': 'Road trip',
          'songCount': 0,
          'entry': <Object>[],
        },
      });
    case 'search3.view':
      return _ok({
        'searchResult3': {
          'song': [
            {
              'id': 's1',
              'title': 'First Song',
              'artist': 'Test Artist',
              'duration': 60,
            },
          ],
        },
      });
    default:
      return _ok({});
  }
}

/// Every controller the app's pages read, wired to a fake server and a fake
/// audio player, for widget tests. Build one with [TestApp.create] and wrap
/// the widget under test in [providers].
class TestApp {
  TestApp._({
    required this.session,
    required this.player,
    required this.settings,
    required this.recents,
    required this.library,
    required this.searchQuery,
    required this.stars,
    required this.revision,
    required this.smartPlaylists,
    required this.downloads,
    required this.sync,
    required this.database,
    required this.players,
    required this.requests,
    required this.caps,
  });

  final SessionController session;
  final PlayerController player;
  final SettingsController settings;
  final LibraryRecents recents;
  final LibraryData library;
  final SearchQuery searchQuery;
  final StarController stars;
  final PlaylistsRevision revision;
  final SmartPlaylistStore smartPlaylists;
  final DownloadController downloads;
  final SyncController sync;
  final AppDatabase database;

  /// Every fake audio player the controller created (main first).
  final List<FakeAudioPlayer> players;

  /// Every request the fake server received.
  final List<Uri> requests;

  /// What the platform under test can do (see [PlatformCaps]).
  final PlatformCaps caps;

  FakeAudioPlayer get audio => players.first;

  /// [stored] is what the secure storage holds (empty means signed out);
  /// [restore] finishes restoring the session before returning.
  static Future<TestApp> create({
    Map<String, String> stored = savedLogin,
    bool restore = true,
    http.Response Function(http.Request request) server = defaultServer,
    PlatformCaps? caps,
  }) async {
    FlutterSecureStorage.setMockInitialValues({...stored});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final requests = <Uri>[];
    final players = <FakeAudioPlayer>[];
    final session = SessionController(
      storage: const FlutterSecureStorage(),
      clientFactory: (config) => SubsonicClient(
        config,
        httpClient: MockClient((r) async {
          requests.add(r.url);
          return server(r);
        }),
      ),
    );
    final player = PlayerController(playerFactory: ({audioPipeline}) {
      final p = FakeAudioPlayer();
      players.add(p);
      return p;
    });
    final settings = SettingsController(prefs);
    final database = AppDatabase.withExecutor(NativeDatabase.memory());
    final revision = PlaylistsRevision();

    final app = TestApp._(
      session: session,
      player: player,
      settings: settings,
      recents: LibraryRecents(prefs),
      library: LibraryData(revision),
      searchQuery: SearchQuery(),
      stars: StarController(),
      revision: revision,
      smartPlaylists: SmartPlaylistStore(prefs),
      downloads: DownloadController(),
      sync: SyncController(database),
      database: database,
      players: players,
      requests: requests,
      caps: caps ?? PlatformCaps.current(),
    );

    if (restore) await session.restore();
    // What main.dart's proxy providers do when the session changes.
    player
      ..attach(session.client)
      ..attachSettings(settings);
    app.stars.attach(session.client);
    app.library.attach(session.client);
    return app;
  }

  /// Wraps [child] in providers for every controller.
  Widget providers(Widget child) => MultiProvider(
        providers: [
          Provider<PlatformCaps>.value(value: caps),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<PlaylistsRevision>.value(value: revision),
          ChangeNotifierProvider<SearchQuery>.value(value: searchQuery),
          ChangeNotifierProvider<LibraryRecents>.value(value: recents),
          ChangeNotifierProvider<LibraryData>.value(value: library),
          ChangeNotifierProvider<SmartPlaylistStore>.value(
              value: smartPlaylists),
          ChangeNotifierProvider<StarController>.value(value: stars),
          ChangeNotifierProvider<DownloadController>.value(value: downloads),
          ChangeNotifierProvider<SyncController>.value(value: sync),
          ChangeNotifierProvider<PlayerController>.value(value: player),
        ],
        child: child,
      );

  /// Releases what the app holds; register with `addTearDown`.
  Future<void> dispose() async {
    player.dispose();
    library.dispose();
    await database.close();
  }
}
