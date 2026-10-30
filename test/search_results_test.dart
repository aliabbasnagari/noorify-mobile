import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

/// What the Search page shows once a search has results: scope chips, the top
/// result card, and the per-type views.
void main() {
  late TestApp app;

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  /// A server whose search finds one artist, two albums and two songs. Songs
  /// "Loser" and "Devil's Haircut" are on the album "Odelay".
  http.Response Function(http.Request) searchServer({
    bool artists = true,
    bool songsWithAlbum = true,
  }) =>
      (request) {
        switch (request.url.pathSegments.last) {
          case 'search3.view':
            return ok({
              'searchResult3': {
                if (artists)
                  'artist': [
                    {'id': 'a1', 'name': 'Beck', 'albumCount': 2},
                  ],
                'album': [
                  {'id': 'al2', 'name': 'Odelay', 'artist': 'Beck'},
                  {'id': 'al3', 'name': 'Mutations', 'artist': 'Beck'},
                ],
                'song': [
                  {
                    'id': 's1',
                    'title': 'Loser',
                    'artist': 'Beck',
                    if (songsWithAlbum) 'albumId': 'al2',
                    'duration': 200,
                  },
                  {
                    'id': 's2',
                    'title': "Devil's Haircut",
                    'artist': 'Beck',
                    'duration': 190,
                  },
                ],
              },
            });
          case 'getAlbum.view':
            return ok({
              'album': {
                'id': request.url.queryParameters['id'],
                'name': 'Odelay',
                'artist': 'Beck',
                'song': [
                  {'id': 's1', 'title': 'Loser', 'duration': 200},
                  {'id': 's2', 'title': "Devil's Haircut", 'duration': 190},
                ],
              },
            });
        }
        return defaultServer(request);
      };

  Future<void> search(
    WidgetTester tester,
    String text, {
    http.Response Function(http.Request)? server,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2000);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.defaultRouteNameTestValue = '/search';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    app = await TestApp.create(server: server ?? searchServer());
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Lets requests finish while the mini player's art spins after playback
  /// starts (so `pumpAndSettle` would never return).
  Future<void> settleWhilePlaying(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String currentPath(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).routeInformationProvider.value.uri.path;
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  /// Scrolls the chip row to [label] first: on a narrow window it overflows.
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.ensureVisible(chip(label));
    await tester.tap(chip(label));
  }

  /// Whether a [ChoiceChip] is the selected one.
  bool selected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(chip(label)).selected;

  group('scope chips', () {
    testWidgets('appear once there are results, with All selected',
        (tester) async {
      await search(tester, 'beck');

      for (final label in ['All', 'Songs', 'Albums', 'Artists']) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      expect(selected(tester, 'All'), isTrue);
    });

    testWidgets('are not shown before searching', (tester) async {
      await search(tester, '');

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Search your library'), findsOneWidget);
    });

    testWidgets('All shows each kind under its own heading', (tester) async {
      await search(tester, 'beck');

      expect(find.text('Artists'), findsNWidgets(2)); // chip + heading
      expect(find.text('Albums'), findsNWidgets(2));
      expect(find.text('Songs'), findsNWidgets(2));
      expect(find.text('Odelay'), findsOneWidget);
      expect(find.text('Loser'), findsOneWidget);
    });

    testWidgets('Songs shows only songs and drops the headings and card',
        (tester) async {
      await search(tester, 'beck');

      await tapChip(tester, 'Songs');
      await tester.pumpAndSettle();

      expect(selected(tester, 'Songs'), isTrue);
      expect(find.text('Loser'), findsOneWidget);
      expect(find.text("Devil's Haircut"), findsOneWidget);
      expect(find.text('Odelay'), findsNothing);
      expect(find.text('Mutations'), findsNothing);
      expect(find.text('Artist'), findsNothing);
      expect(find.text('Songs'), findsOneWidget, reason: 'only the chip');
    });

    testWidgets('Albums shows only albums', (tester) async {
      await search(tester, 'beck');

      await tapChip(tester, 'Albums');
      await tester.pumpAndSettle();

      expect(find.text('Odelay'), findsOneWidget);
      expect(find.text('Mutations'), findsOneWidget);
      expect(find.text('Loser'), findsNothing);
      expect(find.text('Album • Beck'), findsNWidgets(2));
    });

    testWidgets('Artists shows only artists', (tester) async {
      await search(tester, 'beck');

      await tapChip(tester, 'Artists');
      await tester.pumpAndSettle();

      expect(find.text('Beck'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Loser'), findsNothing);
      expect(find.text('Odelay'), findsNothing);
    });

    testWidgets('a scope with no results says so', (tester) async {
      await search(tester, 'beck', server: searchServer(artists: false));

      await tapChip(tester, 'Artists');
      await tester.pumpAndSettle();

      expect(find.text('No artists'), findsOneWidget);
    });

    testWidgets('the chosen scope is kept when the search text changes',
        (tester) async {
      await search(tester, 'beck');
      await tapChip(tester, 'Songs');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beck 2');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(selected(tester, 'Songs'), isTrue);
      expect(find.text('Loser'), findsOneWidget);
    });

    testWidgets('tapping a row in a scope still opens or plays it',
        (tester) async {
      await search(tester, 'beck');
      await tapChip(tester, 'Albums');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mutations'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/search/album/al3');
    });
  });

  group('top result', () {
    testWidgets('an artist searched by name is the top result', (tester) async {
      await search(tester, 'beck');

      // "Beck" is in the card, in the Artists row, and as the artist of each
      // of the two songs; the "Artist" label is in the card and the row.
      expect(find.text('Beck'), findsNWidgets(4));
      expect(find.text('Artist'), findsNWidgets(2));
      expect(find.byTooltip('Play'), findsNothing,
          reason: 'an artist card opens the artist instead');
    });

    testWidgets('opening an artist card goes to the artist page',
        (tester) async {
      await search(tester, 'beck');

      await tester.tap(find.text('Beck').first);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/search/artist/a1');
    });

    testWidgets('a song searched by title is the top result with its artist',
        (tester) async {
      await search(tester, 'loser');

      expect(find.text('Song • Beck'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('Play on a song card plays just that song', (tester) async {
      await search(tester, 'loser');

      await tester.tap(find.byTooltip('Play'));
      await settleWhilePlaying(tester);

      expect(app.player.queueSongs.map((s) => s.id), ['s1']);
      expect(app.player.queueSource, 'Search results');
    });

    testWidgets('opening a song card goes to its album', (tester) async {
      await search(tester, 'loser');

      await tester.tap(find.text('Song • Beck'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/search/album/al2');
    });

    testWidgets('a song with no album plays when its card is opened',
        (tester) async {
      await search(tester, 'loser',
          server: searchServer(songsWithAlbum: false));

      await tester.tap(find.text('Song • Beck'));
      await settleWhilePlaying(tester);

      expect(app.player.queueSongs.map((s) => s.id), ['s1']);
    });

    testWidgets('an album searched by name is the top result', (tester) async {
      await search(tester, 'odelay');

      expect(find.text('Album • Beck'), findsWidgets);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('Play on an album card plays the whole album', (tester) async {
      await search(tester, 'odelay');

      await tester.tap(find.byTooltip('Play'));
      await settleWhilePlaying(tester);

      expect(app.player.queueSongs.map((s) => s.id), ['s1', 's2']);
      expect(app.player.queueSource, 'Odelay');
      final request = app.requests
          .where((u) => u.pathSegments.last == 'getAlbum.view')
          .single;
      expect(request.queryParameters['id'], 'al2');
    });

    testWidgets('opening an album card goes to the album', (tester) async {
      await search(tester, 'odelay');

      // The first "Album • Beck" is the card (it sits above the list).
      await tester.tap(find.text('Album • Beck').first);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/search/album/al2');
    });

    testWidgets('the card is only shown under All', (tester) async {
      await search(tester, 'loser');
      expect(find.text('Song • Beck'), findsOneWidget);

      await tapChip(tester, 'Songs');
      await tester.pumpAndSettle();

      expect(find.text('Song • Beck'), findsNothing);
    });
  });
}
