import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

/// The album, playlist and favorites pages: the hero header, the action row,
/// the track list and the page-specific actions, through the real router.
void main() {
  late TestApp app;

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  Map<String, dynamic> song(String id, String title,
          {int duration = 100, bool starred = false}) =>
      {
        'id': id,
        'title': title,
        'artist': 'Test Artist',
        'duration': duration,
        'track': 1,
        if (starred) 'starred': '2026-01-01T00:00:00Z',
      };

  Future<void> openPage(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 1400),
    http.Response Function(http.Request)? server,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    app = await TestApp.create(server: server ?? defaultServer);
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).routeInformationProvider.value.uri.path;
  }

  List<Uri> requestsTo(String endpoint) =>
      app.requests.where((u) => u.pathSegments.last == endpoint).toList();

  /// A server where the album has [songs] tracks and the artist has another
  /// album, and where `getArtist` works.
  http.Response Function(http.Request) albumServer({int songs = 2}) =>
      (request) {
        switch (request.url.pathSegments.last) {
          case 'getAlbum.view':
            return ok({
              'album': {
                'id': 'al1',
                'name': 'Test Album',
                'artist': 'Test Artist',
                'artistId': 'a1',
                'year': 2024,
                'songCount': songs,
                'duration': 100 * songs,
                'song': [
                  for (var i = 0; i < songs; i++) song('s$i', 'Song $i'),
                ],
              },
            });
          case 'getArtist.view':
            return ok({
              'artist': {
                'id': 'a1',
                'name': 'Test Artist',
                'album': [
                  {'id': 'al1', 'name': 'Test Album'},
                  {'id': 'al3', 'name': 'Mellow Gold'},
                ],
              },
            });
        }
        return defaultServer(request);
      };

  group('album page', () {
    testWidgets('shows the cover header with the details of the album',
        (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Test Album'), findsWidgets);
      expect(find.text('Test Artist'), findsWidgets);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('4 min'), findsNothing,
          reason: 'two 100 second songs are 3 min');
      expect(find.text('3 min'), findsOneWidget);
    });

    testWidgets('a one-track release is a single', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer(songs: 1));

      expect(find.text('Single'), findsOneWidget);
      expect(find.text('1 song'), findsOneWidget);
    });

    testWidgets('Play starts the album and names it as the source',
        (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();

      expect(app.player.queueSongs.map((s) => s.id), ['s0', 's1']);
      expect(app.player.queueSource, 'Test Album');
      expect(app.audio.playing, isTrue);
    });

    testWidgets('Shuffle starts the album shuffled', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      await tester.tap(find.byTooltip('Shuffle'));
      await tester.pump();

      expect(app.audio.shuffleModeEnabled, isTrue);
      expect(app.player.queueSource, 'Test Album');
    });

    testWidgets('choosing a track plays from it', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      await tester.tap(find.text('Song 1'));
      await tester.pump();

      expect(app.player.currentIndex, 1);
      expect(app.player.current?.id, 's1');
    });

    testWidgets('has the download and add-to-playlist buttons', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      expect(find.byTooltip('Download'), findsOneWidget);
      expect(find.byTooltip('Add album to playlist'), findsOneWidget);
    });

    testWidgets('the artist name opens the artist page in the same tab',
        (tester) async {
      await openPage(tester, '/library/album/al1', server: albumServer());

      await tester.tap(find.text('Test Artist').first);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/library/artist/a1');
    });

    testWidgets('shows more by the artist, without the current album',
        (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      expect(find.text('More by Test Artist'), findsOneWidget);
      expect(find.text('Mellow Gold'), findsOneWidget);
      // The album being viewed is not offered again in the shelf.
      expect(
        find.descendant(
            of: find.byType(ListView).last, matching: find.text('Test Album')),
        findsNothing,
      );
    });

    testWidgets('See discography opens the artist page', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      await tester.tap(find.text('See discography'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home/artist/a1');
    });

    testWidgets('no shelf when the artist has no other albums', (tester) async {
      await openPage(
        tester,
        '/home/album/al1',
        server: (request) {
          if (request.url.pathSegments.last == 'getArtist.view') {
            return ok({
              'artist': {
                'id': 'a1',
                'name': 'Test Artist',
                'album': [
                  {'id': 'al1', 'name': 'Test Album'},
                ],
              },
            });
          }
          return albumServer()(request);
        },
      );

      expect(find.textContaining('More by'), findsNothing);
    });

    testWidgets('no shelf when the artist cannot be loaded', (tester) async {
      await openPage(
        tester,
        '/home/album/al1',
        server: (request) => request.url.pathSegments.last == 'getArtist.view'
            ? http.Response('nope', 500)
            : albumServer()(request),
      );

      expect(find.textContaining('More by'), findsNothing);
      expect(find.text('Song 0'), findsOneWidget,
          reason: 'the page still works');
    });

    testWidgets('a wide window shows the track table headings', (tester) async {
      await openPage(tester, '/home/album/al1',
          size: const Size(1100, 900), server: albumServer());

      expect(find.text('#'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('a phone does not show them', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      expect(find.text('#'), findsNothing);
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('records the album as recently opened', (tester) async {
      await openPage(tester, '/home/album/al1', server: albumServer());

      expect(app.recents.openedAt('album:al1'), isNotNull);
    });
  });

  group('playlist page', () {
    var serverName = 'Road trip';
    var songs = <Map<String, dynamic>>[];
    var rejectReorder = false;

    http.Response playlistServer(http.Request request) {
      switch (request.url.pathSegments.last) {
        case 'getPlaylist.view':
          return ok({
            'playlist': {
              'id': 'p1',
              'name': serverName,
              'songCount': songs.length,
              'entry': songs,
            },
          });
        case 'updatePlaylist.view':
          final name = request.url.queryParameters['name'];
          if (name != null) serverName = name;
        case 'createPlaylist.view':
          if (rejectReorder) {
            return http.Response(
              jsonEncode({
                'subsonic-response': {
                  'status': 'failed',
                  'error': {'code': 0, 'message': 'not allowed'},
                },
              }),
              200,
            );
          }
          // Keep what the client saved, as a server would.
          final ids = request.url.queryParametersAll['songId'] ?? const [];
          songs = [
            for (final id in ids) songs.firstWhere((s) => s['id'] == id)
          ];
      }
      return defaultServer(request);
    }

    setUp(() {
      serverName = 'Road trip';
      rejectReorder = false;
      songs = [song('s1', 'First Song'), song('s2', 'Second Song')];
    });

    testWidgets('shows the header with the song count and length',
        (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Road trip'), findsWidgets);
      expect(find.text('2 songs • 3 min'), findsOneWidget);
      expect(find.text('First Song'), findsOneWidget);
    });

    testWidgets('Play starts it with the playlist as the source',
        (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();

      expect(app.player.queueSongs.map((s) => s.id), ['s1', 's2']);
      expect(app.player.queueSource, 'Road trip');
    });

    /// The titles of the songs in the page, top to bottom.
    List<String> titlesInOrder(WidgetTester tester) {
      final rows = [
        for (final t in ['First Song', 'Second Song', 'Third Song'])
          if (find.text(t).evaluate().isNotEmpty)
            (t, tester.getTopLeft(find.text(t).first).dy),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      return [for (final r in rows) r.$1];
    }

    Future<void> startReordering(WidgetTester tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);
      await tester.tap(find.byTooltip('Reorder songs'));
      await tester.pumpAndSettle();
    }

    testWidgets('a playlist of one song has nothing to reorder',
        (tester) async {
      songs = [song('s1', 'First Song')];
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      expect(find.byTooltip('Reorder songs'), findsNothing);
    });

    testWidgets('Reorder songs swaps the rows for draggable ones and back',
        (tester) async {
      await startReordering(tester);

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byTooltip('Done reordering'), findsOneWidget);

      await tester.tap(find.byTooltip('Done reordering'));
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byTooltip('Reorder songs'), findsOneWidget);
    });

    testWidgets('moving a song shows the new order and saves it',
        (tester) async {
      await startReordering(tester);

      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 1);
      await tester.pumpAndSettle();

      expect(titlesInOrder(tester), ['Second Song', 'First Song']);
      final save = requestsTo('createPlaylist.view').single;
      expect(save.queryParameters['playlistId'], 'p1');
      expect(save.queryParametersAll['songId'], ['s2', 's1']);

      // Playing afterwards uses the new order.
      await tester.tap(find.byTooltip('Done reordering'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(app.player.queueSongs.map((s) => s.id), ['s2', 's1']);
    });

    testWidgets('dragging a handle moves the row', (tester) async {
      await startReordering(tester);

      // Press the first handle, drag it past the second row in steps, let go.
      final gesture = await tester
          .startGesture(tester.getCenter(find.byIcon(Icons.drag_handle).first));
      await tester.pump(const Duration(milliseconds: 100));
      for (var step = 0; step < 8; step++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titlesInOrder(tester), ['Second Song', 'First Song']);
      expect(requestsTo('createPlaylist.view'), hasLength(1));
    });

    testWidgets('a move to the same place saves nothing', (tester) async {
      await startReordering(tester);

      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(1, 1);
      await tester.pumpAndSettle();

      expect(requestsTo('createPlaylist.view'), isEmpty);
      expect(titlesInOrder(tester), ['First Song', 'Second Song']);
    });

    testWidgets('if the server refuses, the order goes back and says why',
        (tester) async {
      rejectReorder = true;
      await startReordering(tester);

      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 1);
      await tester.pumpAndSettle();

      expect(titlesInOrder(tester), ['First Song', 'Second Song']);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('not allowed'), findsOneWidget);
    });

    testWidgets('removing a song afterwards uses the saved positions',
        (tester) async {
      await startReordering(tester);
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done reordering'));
      await tester.pumpAndSettle();

      // The first row is now "Second Song" (server index 0 after the save).
      await tester.tap(find.byType(PopupMenuButton<Object>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      final removal = requestsTo('updatePlaylist.view').last;
      expect(removal.queryParametersAll['songIndexToRemove'], ['0']);
    });

    testWidgets('an empty playlist says so and cannot be played',
        (tester) async {
      songs = [];
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      expect(find.text('This playlist is empty'), findsOneWidget);
      expect(find.text('No songs yet'), findsOneWidget);
      final play = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.play_arrow));
      expect(play.onPressed, isNull);
    });

    testWidgets('renaming asks for the new name and updates the page',
        (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byTooltip('Rename playlist'));
      await tester.pumpAndSettle();
      // The dialog starts with the current name.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Road trip',
      );
      await tester.enterText(find.byType(TextField), 'Night drive');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final rename = requestsTo('updatePlaylist.view').single;
      expect(rename.queryParameters['playlistId'], 'p1');
      expect(rename.queryParameters['name'], 'Night drive');
      expect(find.text('Night drive'), findsWidgets);
      expect(find.text('Road trip'), findsNothing);
    });

    testWidgets('renaming refreshes the library lists', (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);
      final before = requestsTo('getPlaylists.view').length;

      await tester.tap(find.byTooltip('Rename playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Night drive');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(requestsTo('getPlaylists.view').length, before + 1);
    });

    testWidgets('cancelling a rename changes nothing', (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byTooltip('Rename playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Night drive');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(requestsTo('updatePlaylist.view'), isEmpty);
      expect(find.text('Road trip'), findsWidgets);
    });

    testWidgets('keeping the same name sends nothing', (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byTooltip('Rename playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(requestsTo('updatePlaylist.view'), isEmpty);
    });

    testWidgets('deleting confirms, then removes it and leaves the page',
        (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);
      // Open from Home so there is a page to return to.
      final context = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(context).canPop(), isTrue);

      await tester.tap(find.byTooltip('Delete playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Road trip"?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
          requestsTo('deletePlaylist.view').single.queryParameters['id'], 'p1');
      expect(currentPath(tester), '/home');
    });

    testWidgets('cancelling the delete keeps the playlist', (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byTooltip('Delete playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(requestsTo('deletePlaylist.view'), isEmpty);
      expect(currentPath(tester), '/home/playlist/p1');
    });

    testWidgets('removing a song sends its position', (tester) async {
      await openPage(tester, '/home/playlist/p1?name=Road+trip',
          server: playlistServer);

      await tester.tap(find.byType(PopupMenuButton<Object>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      final remove = requestsTo('updatePlaylist.view').single;
      expect(remove.queryParametersAll['songIndexToRemove'], ['1']);
    });
  });

  group('favorites page', () {
    late List<Map<String, dynamic>> starred;

    http.Response favoritesServer(http.Request request) {
      if (request.url.pathSegments.last == 'getStarred2.view') {
        return ok({
          'starred2': {'song': starred},
        });
      }
      return defaultServer(request);
    }

    setUp(() {
      starred = [
        song('s1', 'First Song', starred: true),
        song('s2', 'Second Song', starred: true),
      ];
    });

    testWidgets('shows the heart cover, the title and the starred songs',
        (tester) async {
      await openPage(tester, '/library/favorites', server: favoritesServer);

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsWidgets);
      expect(find.text('2 songs • 3 min'), findsOneWidget);
      expect(find.text('First Song'), findsOneWidget);
      expect(find.text('Second Song'), findsOneWidget);
    });

    testWidgets('Play starts them with Favorites as the source',
        (tester) async {
      await openPage(tester, '/library/favorites', server: favoritesServer);

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();

      expect(app.player.queueSongs.map((s) => s.id), ['s1', 's2']);
      expect(app.player.queueSource, 'Favorites');
    });

    testWidgets('a song unstarred while open drops out of the list',
        (tester) async {
      await openPage(tester, '/library/favorites', server: favoritesServer);

      final shown = await app.session.client!.getStarredSongs();
      await app.stars.toggle(shown.first);
      await tester.pumpAndSettle();

      expect(find.text('First Song'), findsNothing);
      expect(find.text('Second Song'), findsOneWidget);
      expect(find.text('1 song • 1 min'), findsOneWidget);
    });

    testWidgets('with no favorites it explains how to add some',
        (tester) async {
      starred = [];
      await openPage(tester, '/library/favorites', server: favoritesServer);

      expect(find.text('No songs yet'), findsOneWidget);
      expect(find.textContaining('Add to favorites'), findsOneWidget);
      final play = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.play_arrow));
      expect(play.onPressed, isNull);
    });

    testWidgets('opening it is recorded for the Recents sort', (tester) async {
      await openPage(tester, '/library/favorites', server: favoritesServer);

      expect(app.recents.openedAt('favorites'), isNotNull);
    });
  });
}
