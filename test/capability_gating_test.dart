import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:noorify/ui/adaptive/platform_caps.dart';
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

/// Screens offer only what the platform can do: no equalizer on iOS, no
/// downloads in a browser (see [PlatformCaps]).
void main() {
  const android = PlatformCaps(isWeb: false, platform: TargetPlatform.android);
  const windows = PlatformCaps(isWeb: false, platform: TargetPlatform.windows);
  const web = PlatformCaps(isWeb: true, platform: TargetPlatform.windows);

  http.Response ok(Map<String, dynamic> body) => http.Response(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...body},
        }),
        200,
      );

  http.Response server(http.Request request) {
    if (request.url.pathSegments.last == 'getAlbum.view') {
      return ok({
        'album': {
          'id': 'al1',
          'name': 'Test Album',
          'artist': 'Test Artist',
          'songCount': 1,
          'duration': 100,
          'song': [
            {
              'id': 's0',
              'title': 'Song 0',
              'artist': 'Test Artist',
              'duration': 100,
              'track': 1,
            },
          ],
        },
      });
    }
    return defaultServer(request);
  }

  Future<void> openPage(
    WidgetTester tester,
    String location,
    PlatformCaps caps,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    final app = await TestApp.create(server: server, caps: caps);
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  group('settings', () {
    testWidgets('Android shows skip silence, the equalizer and downloads',
        (tester) async {
      await openPage(tester, '/home/settings', android);

      expect(find.text('Skip silence'), findsOneWidget);
      expect(find.text('Equalizer'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
    });

    testWidgets('desktop keeps downloads but has no Android audio effects',
        (tester) async {
      await openPage(tester, '/home/settings', windows);

      expect(find.text('Skip silence'), findsNothing);
      expect(find.text('Equalizer'), findsNothing);
      expect(find.text('Downloads'), findsOneWidget);
    });

    testWidgets('a browser has no audio effects and no downloads',
        (tester) async {
      await openPage(tester, '/home/settings', web);

      expect(find.text('Skip silence'), findsNothing);
      expect(find.text('Equalizer'), findsNothing);
      expect(find.text('Downloads'), findsNothing);
      expect(find.textContaining('this browser'), findsOneWidget);
    });
  });

  group('library', () {
    testWidgets('offers the Downloads shortcut and chip where downloads work',
        (tester) async {
      await openPage(tester, '/library', android);

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);
    });

    testWidgets('a browser has neither', (tester) async {
      await openPage(tester, '/library', web);

      expect(find.text('Downloads'), findsNothing);
      expect(find.text('Downloaded'), findsNothing);
      expect(find.text('Playlists'), findsOneWidget,
          reason: 'the other chips are unaffected');
    });
  });

  group('album page', () {
    testWidgets('has the offline toggle where downloads work', (tester) async {
      await openPage(tester, '/home/album/al1', android);

      expect(find.byTooltip('Download'), findsOneWidget);
    });

    testWidgets('a browser has no offline toggle', (tester) async {
      await openPage(tester, '/home/album/al1', web);

      expect(find.text('Test Album'), findsWidgets);
      expect(find.byTooltip('Download'), findsNothing);
    });

    testWidgets('the song menu offers Download only where downloads work',
        (tester) async {
      await openPage(tester, '/home/album/al1', android);
      await tester.tap(find.byType(PopupMenuButton<Object>).first);
      await tester.pumpAndSettle();
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Play next'), findsOneWidget);
    });

    testWidgets('and not in a browser', (tester) async {
      await openPage(tester, '/home/album/al1', web);
      await tester.tap(find.byType(PopupMenuButton<Object>).first);
      await tester.pumpAndSettle();
      expect(find.text('Download'), findsNothing);
      expect(find.text('Play next'), findsOneWidget);
    });
  });
}
