import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/state/download_controller.dart';
import 'package:noorify/state/player_controller.dart';
import 'package:noorify/state/playlists_revision.dart';
import 'package:noorify/state/session_controller.dart';
import 'package:noorify/state/settings_controller.dart';
import 'package:noorify/state/smart_playlist_store.dart';
import 'package:noorify/state/star_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';
import 'package:noorify/ui/routing/app_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio_player.dart';

/// Runs the real router with the real pages against a fake server: sign-in
/// gating, deep links, and opening pages inside the tab they were reached from.
void main() {
  const savedLogin = {
    'server_url': 'https://music.example.com',
    'server_user': 'alice',
    'server_pass': 'sesame',
  };

  late SessionController session;
  late PlayerController player;

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  /// A server with one album, one song and one playlist.
  http.Response serve(http.Request request) {
    switch (request.url.pathSegments.last) {
      case 'getAlbumList2.view':
        return ok({
          'albumList2': {
            'album': [
              {
                'id': 'al1',
                'name': 'Test Album',
                'artist': 'Test Artist',
                'songCount': 1,
              },
            ],
          },
        });
      case 'getAlbum.view':
        return ok({
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
      case 'getPlaylists.view':
        return ok({
          'playlists': {
            'playlist': [
              {
                'id': 'p1',
                'name': 'Road trip',
                'songCount': 3,
                'duration': 100
              },
            ],
          },
        });
      default:
        return ok({});
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, String> stored = savedLogin,
    bool restoreFirst = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    FlutterSecureStorage.setMockInitialValues({...stored});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    session = SessionController(
      storage: const FlutterSecureStorage(),
      clientFactory: (config) =>
          SubsonicClient(config, httpClient: MockClient((r) async => serve(r))),
    );
    player = PlayerController(
      playerFactory: ({audioPipeline}) => FakeAudioPlayer(),
    );
    addTearDown(player.dispose);
    if (restoreFirst) await session.restore();

    final router = buildAppRouter(session: session);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
          ChangeNotifierProvider(create: (_) => PlaylistsRevision()),
          ChangeNotifierProvider(create: (_) => SmartPlaylistStore(prefs)),
          ChangeNotifierProvider(create: (_) => StarController()),
          // Never attached to a client in these tests, so it touches no files.
          ChangeNotifierProvider(create: (_) => DownloadController()),
          ChangeNotifierProvider<PlayerController>.value(value: player),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // The loading page's spinner never stops animating, so it can't settle.
    if (restoreFirst) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// The address the router reports to the platform, i.e. what a browser's
  /// address bar would show.
  Uri currentUri(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).routeInformationProvider.value.uri;
  }

  String currentPath(WidgetTester tester) => currentUri(tester).path;

  void startAt(WidgetTester tester, String location) {
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  final loginText = find.text('Connect to your Subsonic / OpenSubsonic server');

  testWidgets('signed out, the app shows the login page', (tester) async {
    await pumpApp(tester, stored: const {});

    expect(loginText, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(currentPath(tester), '/login');
  });

  testWidgets('signed in, the app opens on Home with the bottom bar',
      (tester) async {
    await pumpApp(tester);

    expect(currentPath(tester), '/home');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Newly added'), findsOneWidget);
    expect(loginText, findsNothing);
  });

  testWidgets('an album opened from Home stays inside the Home tab',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/home/album/al1');
    expect(find.text('First Song'), findsOneWidget);
    // The navigation stays on screen under the page, with Home still selected.
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/home');
    expect(find.text('First Song'), findsNothing);
  });

  testWidgets('a playlist opens inside the Library tab with its name',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Your Library'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Road trip'));
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/library/playlist/p1');
    expect(currentUri(tester).queryParameters['name'], 'Road trip');
  });

  testWidgets('a deep link opens that page in the right tab', (tester) async {
    startAt(tester, '/library/album/al1');

    await pumpApp(tester);

    expect(currentPath(tester), '/library/album/al1');
    expect(find.text('First Song'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets(
      'a deep link opened while the session is restoring lands there afterwards',
      (tester) async {
    startAt(tester, '/search/album/al1');
    await pumpApp(tester, restoreFirst: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('First Song'), findsNothing);

    await session.restore();
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/search/album/al1');
    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('a deep link while signed out waits for login, then opens',
      (tester) async {
    startAt(tester, '/library/album/al1');
    await pumpApp(tester, stored: const {});
    expect(loginText, findsOneWidget);

    await session.login('music.example.com', 'alice', 'sesame');
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/library/album/al1');
    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('signing out returns to the login page', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await session.logout();
    await tester.pumpAndSettle();

    expect(loginText, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('an unknown address shows a friendly page', (tester) async {
    startAt(tester, '/nowhere/at/all');

    await pumpApp(tester);

    expect(find.text("That page doesn't exist"), findsOneWidget);
  });
}
