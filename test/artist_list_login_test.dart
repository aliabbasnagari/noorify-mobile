import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noorify/ui/login_page.dart';
import 'package:noorify/ui/routing/app_router.dart';

import 'support/test_app.dart';

void main() {
  group('artist list', () {
    Future<void> openArtists(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.defaultRouteNameTestValue = '/library/artists';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      final app = await TestApp.create();
      addTearDown(app.dispose);
      final router = buildAppRouter(session: app.session);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        app.providers(MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a phone gets a dense list', (tester) async {
      await openArtists(tester, const Size(390, 800));

      expect(find.widgetWithText(ListTile, 'Beck'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('a wide window gets a grid of round portraits', (tester) async {
      await openArtists(tester, const Size(1200, 800));

      // The library sidebar beside the page also lists the artist, so look
      // inside the grid.
      final grid = find.byType(GridView);
      expect(grid, findsOneWidget);
      expect(find.descendant(of: grid, matching: find.byType(ClipOval)),
          findsOneWidget);
      expect(find.descendant(of: grid, matching: find.text('Beck')),
          findsOneWidget);
      expect(find.descendant(of: grid, matching: find.text('1 albums')),
          findsOneWidget);
      expect(find.descendant(of: grid, matching: find.byType(ListTile)),
          findsNothing);
    });

    testWidgets('tapping a portrait opens the artist', (tester) async {
      await openArtists(tester, const Size(1200, 800));

      await tester.tap(find.descendant(
          of: find.byType(GridView), matching: find.text('Beck')));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      expect(
        GoRouter.of(context).routeInformationProvider.value.uri.path,
        '/library/artist/a1',
      );
    });
  });

  group('login page', () {
    Future<void> openLogin(WidgetTester tester) async {
      final app = await TestApp.create();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        app.providers(const MaterialApp(home: LoginPage())),
      );
    }

    final plainHttpHint = find.textContaining('Plain http is not encrypted');

    testWidgets('warns when the server address is plain http', (tester) async {
      await openLogin(tester);
      expect(plainHttpHint, findsNothing);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'), 'http://nas.local');
      await tester.pump();

      expect(plainHttpHint, findsOneWidget);
    });

    testWidgets('does not warn for https, and the warning clears again',
        (tester) async {
      await openLogin(tester);
      final url = find.widgetWithText(TextFormField, 'Server URL');

      await tester.enterText(url, 'https://music.example.com');
      await tester.pump();
      expect(plainHttpHint, findsNothing);

      await tester.enterText(url, 'HTTP://nas.local');
      await tester.pump();
      expect(plainHttpHint, findsOneWidget, reason: 'the scheme is any case');

      await tester.enterText(url, 'https://nas.local');
      await tester.pump();
      expect(plainHttpHint, findsNothing);
    });

    testWidgets('requires every field', (tester) async {
      await openLogin(tester);

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.text('Enter the server URL'), findsOneWidget);
      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });
  });
}
