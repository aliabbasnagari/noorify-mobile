import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  Map<String, dynamic> song(int i) => {
        'id': 't$i',
        'title': 'Hit $i',
        'artist': 'Beck',
        'duration': 200,
      };

  /// A server for one artist, "Beck", whose pieces can each be replaced.
  http.Response Function(http.Request) artistServer({
    int topSongs = 3,
    bool topFails = false,
    bool infoFails = false,
    List<Map<String, dynamic>>? albums,
    Map<String, dynamic>? info,
  }) =>
      (request) {
        switch (request.url.pathSegments.last) {
          case 'getArtist.view':
            return ok({
              'artist': {
                'id': 'a1',
                'name': 'Beck',
                'album': albums ??
                    [
                      {'id': 'al1', 'name': 'First Record'},
                      {'id': 'al2', 'name': 'Second Record'},
                    ],
              },
            });
          case 'getTopSongs.view':
            if (topFails) return http.Response('boom', 500);
            return ok({
              'topSongs': {
                'song': [for (var i = 0; i < topSongs; i++) song(i)],
              },
            });
          case 'getArtistInfo2.view':
            if (infoFails) return http.Response('boom', 500);
            return ok({'artistInfo2': info ?? {}});
          case 'getAlbum.view':
            return ok({
              'album': {
                'id': request.url.queryParameters['id'],
                'name': 'First Record',
                'song': [
                  {'id': 'x1', 'title': 'Album Track', 'duration': 100},
                ],
              },
            });
        }
        return defaultServer(request);
      };

  Future<void> openArtist(
    WidgetTester tester, {
    required http.Response Function(http.Request) server,
    Size size = const Size(390, 2400),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.defaultRouteNameTestValue = '/home/artist/a1';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    app = await TestApp.create(server: server);
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  /// Lets pending requests finish. Once something plays the mini player's art
  /// spins forever, so `pumpAndSettle` would never return.
  Future<void> settleWhilePlaying(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String currentPath(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).routeInformationProvider.value.uri.path;
  }

  group('header and albums', () {
    testWidgets('shows the artist, how many albums, and the albums',
        (tester) async {
      await openArtist(tester, server: artistServer());

      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Beck'), findsWidgets);
      expect(find.text('2 albums'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('First Record'), findsOneWidget);
      expect(find.text('Second Record'), findsOneWidget);
    });

    testWidgets('one album is "1 album"', (tester) async {
      await openArtist(
        tester,
        server: artistServer(albums: [
          {'id': 'al1', 'name': 'First Record'},
        ]),
      );

      expect(find.text('1 album'), findsOneWidget);
    });

    testWidgets('an album opens inside the same tab', (tester) async {
      await openArtist(tester, server: artistServer());

      await tester.tap(find.text('Second Record'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home/album/al2');
    });

    testWidgets('an artist with no albums says so and cannot be played',
        (tester) async {
      await openArtist(tester, server: artistServer(albums: [], topSongs: 0));

      expect(find.text('No albums'), findsOneWidget);
      final play = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.play_arrow));
      expect(play.onPressed, isNull);
    });

    testWidgets('opening the page is recorded for Recents', (tester) async {
      await openArtist(tester, server: artistServer());

      expect(app.recents.openedAt('artist:a1'), isNotNull);
    });
  });

  group('popular songs', () {
    testWidgets('lists the top songs and plays from the one chosen',
        (tester) async {
      await openArtist(tester, server: artistServer());
      expect(find.text('Popular'), findsOneWidget);

      await tester.tap(find.text('Hit 1'));
      await tester.pump();

      expect(app.player.queueSongs.map((s) => s.id), ['t0', 't1', 't2']);
      expect(app.player.currentIndex, 1);
      expect(app.player.queueSource, 'Beck');
    });

    testWidgets('shows five and offers the rest', (tester) async {
      await openArtist(tester, server: artistServer(topSongs: 8));

      expect(find.text('Hit 4'), findsOneWidget);
      expect(find.text('Hit 5'), findsNothing);

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Hit 7'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Hit 5'), findsNothing);
    });

    testWidgets('five or fewer have no Show more', (tester) async {
      await openArtist(tester, server: artistServer(topSongs: 5));

      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('Play and Shuffle use the popular songs', (tester) async {
      await openArtist(tester, server: artistServer());

      await tester.tap(find.byTooltip('Play'));
      await settleWhilePlaying(tester);
      expect(app.player.queueSongs.map((s) => s.id), ['t0', 't1', 't2']);
      expect(app.audio.shuffleModeEnabled, isFalse);

      await tester.tap(find.byTooltip('Shuffle'));
      await settleWhilePlaying(tester);
      expect(app.audio.shuffleModeEnabled, isTrue);
    });

    testWidgets('with no popular songs, Play uses the first album',
        (tester) async {
      await openArtist(tester, server: artistServer(topSongs: 0));
      expect(find.text('Popular'), findsNothing);

      await tester.tap(find.byTooltip('Play'));
      await settleWhilePlaying(tester);

      expect(app.player.queueSongs.map((s) => s.id), ['x1']);
      expect(app.player.queueSource, 'Beck');
      final request = app.requests
          .where((u) => u.pathSegments.last == 'getAlbum.view')
          .single;
      expect(request.queryParameters['id'], 'al1');
    });

    testWidgets('a failing request just leaves Popular out', (tester) async {
      await openArtist(tester, server: artistServer(topFails: true));

      expect(find.text('Popular'), findsNothing);
      expect(find.text('First Record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('similar artists and biography', () {
    final fullInfo = {
      'biography': 'Beck is <a href="https://x.example">an</a> artist.<br/>'
          'Folk &amp; rock.',
      'similarArtist': [
        {'id': 'a2', 'name': 'Beirut'},
        {'id': 'a3', 'name': 'Bon Iver'},
      ],
    };

    testWidgets('shows the biography with its markup removed', (tester) async {
      await openArtist(tester, server: artistServer(info: fullInfo));

      expect(find.text('About'), findsOneWidget);
      expect(find.text('Beck is an artist.\nFolk & rock.'), findsOneWidget);
      expect(find.text('Read more'), findsNothing,
          reason: 'a short biography needs no toggle');
    });

    testWidgets('a long biography is cut with Read more', (tester) async {
      final long = List.filled(60, 'word').join(' '); // 299 characters
      await openArtist(
        tester,
        server: artistServer(info: {'biography': long}),
      );

      expect(find.textContaining('…'), findsOneWidget);
      expect(find.text(long), findsNothing);

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text(long), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text(long), findsNothing);
    });

    testWidgets('lists similar artists, and each opens its page',
        (tester) async {
      await openArtist(tester, server: artistServer(info: fullInfo));

      expect(find.text('Fans also like'), findsOneWidget);
      expect(find.text('Beirut'), findsOneWidget);
      expect(find.text('Bon Iver'), findsOneWidget);

      await tester.tap(find.text('Beirut'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home/artist/a2');
    });

    testWidgets('an artist the server knows nothing about has neither section',
        (tester) async {
      await openArtist(tester, server: artistServer(info: {}));

      expect(find.text('About'), findsNothing);
      expect(find.text('Fans also like'), findsNothing);
    });

    testWidgets('a failing info request just leaves them out', (tester) async {
      await openArtist(tester, server: artistServer(infoFails: true));

      expect(find.text('About'), findsNothing);
      expect(find.text('Fans also like'), findsNothing);
      expect(find.text('First Record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('if the artist itself cannot be loaded, it offers a retry',
      (tester) async {
    await openArtist(
      tester,
      server: (request) => request.url.pathSegments.last == 'getArtist.view'
          ? http.Response('boom', 500)
          : artistServer()(request),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Popular'), findsNothing);
  });
}
