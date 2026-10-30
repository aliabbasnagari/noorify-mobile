import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noorify/ui/routing/app_router.dart';
import 'package:noorify/ui/widgets/quick_access.dart';

import 'support/test_app.dart';

/// Runs the real router with the real pages against a fake server: sign-in
/// gating, deep links, and opening pages inside the tab they were reached from.
void main() {
  late TestApp app;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, String> stored = savedLogin,
    bool restoreFirst = true,
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    app = await TestApp.create(stored: stored, restore: restoreFirst);
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
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

  testWidgets('opening an item records it in the recents history',
      (tester) async {
    await pumpApp(tester);
    expect(app.recents.openedAt('album:al1'), isNull);

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();

    expect(app.recents.openedAt('album:al1'), isNotNull);
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

  group('Home', () {
    testWidgets('shows the recent albums as quick-access tiles',
        (tester) async {
      await pumpApp(tester);

      final tiles = find.byType(QuickAccessGrid);
      expect(tiles, findsOneWidget);
      expect(find.descendant(of: tiles, matching: find.text('Test Album')),
          findsOneWidget);
      expect(find.descendant(of: tiles, matching: find.text('Odelay')),
          findsOneWidget);
    });

    testWidgets('a quick-access tile opens the album', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.descendant(
          of: find.byType(QuickAccessGrid), matching: find.text('Test Album')));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home/album/al1');
    });

    testWidgets('every shelf but Discover offers Show all', (tester) async {
      // Tall enough to build all four shelves at once.
      await pumpApp(tester, size: const Size(390, 2400));

      // Recently played, Newly added and Most played; Discover is shuffled.
      expect(find.text('Show all'), findsNWidgets(3));
      expect(find.text('Discover'), findsOneWidget);
    });

    testWidgets('Show all opens the full list behind that shelf',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Show all').first);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home/albums');
      expect(currentUri(tester).queryParameters['type'], 'recent');
      // The page is titled for the shelf, and lists its albums.
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Recently played')),
          findsOneWidget);
      expect(find.text('Test Album'), findsOneWidget);
      final request = app.requests
          .where((u) => u.pathSegments.last == 'getAlbumList2.view')
          .last;
      expect(request.queryParameters['type'], 'recent');
      expect(request.queryParameters['size'], '60');
    });

    testWidgets('the albums page without a type lists every album A to Z',
        (tester) async {
      startAt(tester, '/home/albums');

      await pumpApp(tester);

      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Albums')),
          findsOneWidget);
      expect(app.requests.last.queryParameters['type'], 'alphabeticalByName');
    });

    testWidgets('an unknown type falls back to every album', (tester) async {
      startAt(tester, '/home/albums?type=bogus');

      await pumpApp(tester);

      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Albums')),
          findsOneWidget);
    });
  });

  group('Your Library on a phone', () {
    Future<void> openLibrary(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Your Library'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the pinned rows, playlists and filter chips',
        (tester) async {
      await openLibrary(tester);

      for (final title in [
        'Favorites',
        'Songs',
        'Downloads',
        'Smart playlists',
        'Road trip',
        'Calm',
      ]) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      for (final chip in ['Playlists', 'Artists', 'Albums', 'Downloaded']) {
        expect(find.widgetWithText(FilterChip, chip), findsOneWidget,
            reason: chip);
      }
    });

    testWidgets('a shortcut row opens its page inside the Library tab',
        (tester) async {
      await openLibrary(tester);

      await tester.tap(find.text('Songs').last);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/library/songs');
    });

    testWidgets('Favorites opens the favorites page', (tester) async {
      await openLibrary(tester);

      await tester.tap(find.text('Favorites').last);
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/library/favorites');
    });

    testWidgets('a filter chip narrows the list', (tester) async {
      await openLibrary(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Artists'));
      await tester.pumpAndSettle();

      expect(find.text('Beck'), findsOneWidget);
      expect(find.text('Road trip'), findsNothing);
      expect(find.text('Songs'), findsNothing);
    });

    testWidgets('the header Create button opens the Create menu',
        (tester) async {
      await openLibrary(tester);

      // (The bottom bar's Create item has the same tooltip, so find the
      // header button by its icon.)
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Smart playlist'), findsOneWidget);
    });

    testWidgets('a new playlist shows up without leaving the page',
        (tester) async {
      await openLibrary(tester);
      final before = app.requests
          .where((u) => u.pathSegments.last == 'getPlaylists.view')
          .length;

      app.revision.bump();
      await tester.pumpAndSettle();

      final after = app.requests
          .where((u) => u.pathSegments.last == 'getPlaylists.view')
          .length;
      expect(after, before + 1);
    });
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

    await app.session.restore();
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/search/album/al1');
    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('a deep link while signed out waits for login, then opens',
      (tester) async {
    startAt(tester, '/library/album/al1');
    await pumpApp(tester, stored: const {});
    expect(loginText, findsOneWidget);

    await app.session.login('music.example.com', 'alice', 'sesame');
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/library/album/al1');
    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('signing out returns to the login page', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await app.session.logout();
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
