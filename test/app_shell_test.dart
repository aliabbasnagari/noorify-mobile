import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/ui/app_shell.dart';
import 'package:noorify/ui/routing/app_routes.dart';
import 'package:noorify/ui/shell/library_sidebar.dart';
import 'package:noorify/ui/shell/player_bar.dart';
import 'package:noorify/ui/shell/queue_panel.dart';
import 'package:noorify/ui/shell/top_bar.dart';
import 'package:noorify/ui/widgets/mini_player.dart';

import 'support/test_app.dart';

/// A page with state of its own, to prove a resize doesn't rebuild it.
class _CounterPage extends StatefulWidget {
  const _CounterPage(this.label);

  final String label;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.label)),
        body: Center(
          child: TextButton(
            onPressed: () => setState(() => taps++),
            child: Text('${widget.label} taps: $taps'),
          ),
        ),
      );
}

void main() {
  late GoRouter router;
  late TestApp app;

  /// The real shell on the real tab structure, with simple pages in place of
  /// the screens, so these tests are about the shell and not the pages.
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    app = await TestApp.create();
    addTearDown(app.dispose);

    final keys = [
      for (final p in AppRoutes.branches)
        GlobalKey<NavigatorState>(debugLabel: p),
    ];
    StatefulShellBranch branch(int i, String label) => StatefulShellBranch(
          navigatorKey: keys[i],
          routes: [
            GoRoute(
              path: AppRoutes.branches[i],
              builder: (_, __) => _CounterPage(label),
              routes: [
                GoRoute(
                  path: 'album/:id',
                  builder: (_, s) =>
                      _CounterPage('Album ${s.pathParameters['id']}'),
                ),
              ],
            ),
          ],
        );

    router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) =>
              AppShell(navigationShell: shell, branchKeys: keys),
          branches: [
            branch(0, 'Home'),
            branch(1, 'Search'),
            branch(2, 'Library'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  void resize(WidgetTester tester, Size size) =>
      tester.view.physicalSize = size;

  const phone = Size(390, 844);
  const tablet = Size(820, 1180);
  const desktop = Size(1440, 900);

  group('layout by window size', () {
    testWidgets('a phone gets a bottom bar with four destinations',
        (tester) async {
      await pumpApp(tester, phone);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.byType(PlayerBar), findsNothing);
      for (final label in ['Home', 'Search', 'Your Library', 'Create']) {
        expect(
            find.descendant(
                of: find.byType(NavigationBar), matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
    });

    testWidgets('a portrait tablet gets a rail with labels under the icons',
        (tester) async {
      await pumpApp(tester, tablet);

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.labelType, NavigationRailLabelType.all);
      expect(rail.destinations, hasLength(4));
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.byType(PlayerBar), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets(
        'a desktop window gets the top bar, sidebar, queue and player bar',
        (tester) async {
      await pumpApp(tester, desktop);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(MiniPlayer), findsNothing);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.byType(LibrarySidebar), findsOneWidget);
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.byType(PlayerBar), findsOneWidget);
      // The page itself still shows, in the middle.
      expect(find.text('Home taps: 0'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('selecting a destination shows that tab', (tester) async {
      await pumpApp(tester, phone);
      expect(find.text('Home taps: 0'), findsOneWidget);

      await tester.tap(find.text('Your Library'));
      await tester.pumpAndSettle();

      expect(find.text('Library taps: 0'), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.library);
    });

    testWidgets('Create opens the Create menu and does not change tab',
        (tester) async {
      await pumpApp(tester, phone);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Smart playlist'), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('a tab keeps its page and state while another tab is shown',
        (tester) async {
      await pumpApp(tester, phone);
      await tester.tap(find.text('Home taps: 0'));
      await tester.pump();
      expect(find.text('Home taps: 1'), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Home taps: 1'), findsOneWidget);
    });

    testWidgets('tapping the current tab returns it to its first page',
        (tester) async {
      await pumpApp(tester, phone);
      unawaitedPush(router, '/home/album/7');
      await tester.pumpAndSettle();
      expect(find.text('Album 7 taps: 0'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Album 7 taps: 0'), findsNothing);
      expect(find.text('Home taps: 0'), findsOneWidget);
    });
  });

  group('resizing keeps the app where it was', () {
    testWidgets('the open page and its state survive every layout change',
        (tester) async {
      await pumpApp(tester, phone);
      await tester.tap(find.text('Your Library'));
      await tester.pumpAndSettle();
      unawaitedPush(router, '/library/album/7');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Album 7 taps: 0'));
      await tester.pump();
      await tester.tap(find.text('Album 7 taps: 1'));
      await tester.pump();
      expect(find.text('Album 7 taps: 2'), findsOneWidget);

      for (final size in [
        tablet, // compact -> medium
        desktop, // medium -> expanded
        phone, // expanded -> compact
      ]) {
        resize(tester, size);
        await tester.pumpAndSettle();

        expect(find.text('Album 7 taps: 2'), findsOneWidget,
            reason: 'page state lost at $size');
        expect(router.state.uri.path, '/library/album/7');
      }
    });

    testWidgets('every tab keeps its own state across a resize',
        (tester) async {
      await pumpApp(tester, phone);
      await tester.tap(find.text('Home taps: 0'));
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search taps: 0'));
      await tester.pump();
      await tester.tap(find.text('Search taps: 1'));
      await tester.pump();

      resize(tester, desktop);
      await tester.pumpAndSettle();

      expect(find.text('Search taps: 2'), findsOneWidget);
      // The top bar's Home button returns to Home, which kept its tap.
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home taps: 1'), findsOneWidget);
    });

    testWidgets('the queue keeps playing across a resize', (tester) async {
      await pumpApp(tester, phone);
      await app.player.playSongs(const [
        Song(id: 'a', title: 'A'),
        Song(id: 'b', title: 'B'),
      ]);
      await tester.pump();

      resize(tester, desktop);
      await tester.pumpAndSettle();

      expect(app.audio.playing, isTrue);
      expect(app.player.queueSongs, hasLength(2));
    });
  });
}

/// Pushes a location the way the UI does (without waiting for it to close).
void unawaitedPush(GoRouter router, String location) {
  // ignore: discarded_futures
  router.push<void>(location);
}
