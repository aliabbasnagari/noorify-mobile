import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:noorify/models/models.dart';
import 'package:noorify/ui/pages/song_sort.dart';
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

void main() {
  group('sortSongs', () {
    const songs = [
      Song(id: '1', title: 'beta', artist: 'Zed', album: 'Y', duration: 30),
      Song(id: '2', title: 'Alpha', artist: 'amy', album: 'X', duration: 90),
      Song(id: '3', title: 'Gamma', album: 'Z', duration: 60),
      Song(id: '4', title: 'alpha', artist: 'amy', album: 'X', duration: 90),
    ];

    List<String> ids(List<Song> l) => [for (final s in l) s.id];

    test('by title ignores case, and ties keep a stable order', () {
      expect(ids(sortSongs(songs, SongSort.title)), ['2', '4', '1', '3']);
    });

    test(
        'by artist ignores case, puts a missing artist first, and ties '
        'fall back to the title', () {
      expect(ids(sortSongs(songs, SongSort.artist)), ['3', '2', '4', '1']);
    });

    test('by album and by length', () {
      expect(ids(sortSongs(songs, SongSort.album)), ['2', '4', '1', '3']);
      expect(ids(sortSongs(songs, SongSort.duration)), ['1', '3', '2', '4']);
    });

    test('descending is the exact reverse', () {
      expect(ids(sortSongs(songs, SongSort.duration, ascending: false)),
          ['4', '2', '3', '1']);
    });

    test('returns a new list and leaves the input alone', () {
      final input = [...songs];
      final out = sortSongs(input, SongSort.title);

      expect(identical(out, input), isFalse);
      expect(ids(input), ['1', '2', '3', '4']);
    });

    test('handles an empty list', () {
      expect(sortSongs(const [], SongSort.title), isEmpty);
    });
  });

  group('songs page', () {
    late TestApp app;

    http.Response server(http.Request request) {
      if (request.url.pathSegments.last == 'search3.view') {
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'searchResult3': {
                'song': [
                  {
                    'id': 's1',
                    'title': 'Charlie',
                    'artist': 'Aaron',
                    'duration': 30
                  },
                  {
                    'id': 's2',
                    'title': 'Alpha',
                    'artist': 'Zoe',
                    'duration': 90
                  },
                  {
                    'id': 's3',
                    'title': 'Bravo',
                    'artist': 'Mia',
                    'duration': 60
                  },
                ],
              },
            },
          }),
          200,
        );
      }
      return defaultServer(request);
    }

    Future<void> openSongs(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.defaultRouteNameTestValue = '/library/songs';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      app = await TestApp.create(server: server);
      addTearDown(app.dispose);
      // Real database work, so it runs outside the fake-async test zone.
      app.sync.attach(app.session.client);
      await tester.runAsync(() => app.sync.sync());
      final router = buildAppRouter(session: app.session);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        app.providers(MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
    }

    /// Taps a sort chip, scrolling the row to it first if it is off screen.
    Future<void> chooseSort(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    /// The song titles from top to bottom.
    List<String> shown(WidgetTester tester) {
      final titles = ['Alpha', 'Bravo', 'Charlie'];
      final found = [
        for (final t in titles)
          if (find.text(t).evaluate().isNotEmpty)
            (t, tester.getTopLeft(find.text(t).first).dy),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      return [for (final f in found) f.$1];
    }

    testWidgets('starts in title order', (tester) async {
      await openSongs(tester);

      expect(shown(tester), ['Alpha', 'Bravo', 'Charlie']);
    });

    testWidgets('a column chip reorders, and choosing it again reverses',
        (tester) async {
      await openSongs(tester);

      await chooseSort(tester, 'Artist');
      expect(shown(tester), ['Charlie', 'Bravo', 'Alpha'],
          reason: 'Aaron, Mia, Zoe');

      await chooseSort(tester, 'Artist');
      expect(shown(tester), ['Alpha', 'Bravo', 'Charlie']);

      await chooseSort(tester, 'Length');
      expect(shown(tester), ['Charlie', 'Bravo', 'Alpha'],
          reason: '30s, 60s, 90s');
    });

    testWidgets('playing a song queues the songs in the shown order',
        (tester) async {
      await openSongs(tester);
      await chooseSort(tester, 'Length');

      await tester.tap(find.text('Bravo'));
      await tester.pump();

      expect(app.player.queueSongs.map((s) => s.id), ['s1', 's3', 's2']);
      expect(app.player.current?.id, 's3');
      expect(app.player.queueSource, 'Songs');
    });
  });
}
