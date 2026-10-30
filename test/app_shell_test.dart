import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noorify/state/player_controller.dart';
import 'package:noorify/ui/app_shell.dart';
import 'package:noorify/ui/routing/app_routes.dart';
import 'package:provider/provider.dart';

import 'support/fake_audio_player.dart';

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

  /// The real shell on the real tab structure, with simple pages in place of
  /// the screens that need a server.
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final player = PlayerController(
      playerFactory: ({audioPipeline}) => FakeAudioPlayer(),
    );
    addTearDown(player.dispose);

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
            branch(2, 'Library')
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerController>.value(
        value: player,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  void resize(WidgetTester tester, Size size) =>
      tester.view.physicalSize = size;

  group('layout by window size', () {
    testWidgets('a phone gets a bottom bar with four destinations',
        (tester) async {
      await pumpApp(tester, const Size(390, 844));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
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
      await pumpApp(tester, const Size(820, 1180));

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.labelType, NavigationRailLabelType.all);
      expect(rail.destinations, hasLength(4));
    });

    testWidgets('a desktop window gets the extended rail', (tester) async {
      await pumpApp(tester, const Size(1440, 900));

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('settings is reachable from the rail but not the phone bar',
        (tester) async {
      await pumpApp(tester, const Size(1440, 900));
      expect(find.byTooltip('Settings'), findsOneWidget);

      resize(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Settings'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('selecting a destination shows that tab', (tester) async {
      await pumpApp(tester, const Size(390, 844));
      expect(find.text('Home taps: 0'), findsOneWidget);

      await tester.tap(find.text('Your Library'));
      await tester.pumpAndSettle();

      expect(find.text('Library taps: 0'), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.library);
    });

    testWidgets('Create opens the Create menu and does not change tab',
        (tester) async {
      await pumpApp(tester, const Size(390, 844));

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Smart playlist'), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.home);
    });

    testWidgets('a tab keeps its page and state while another tab is shown',
        (tester) async {
      await pumpApp(tester, const Size(390, 844));
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
      await pumpApp(tester, const Size(390, 844));
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
      await pumpApp(tester, const Size(390, 844));
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
        const Size(820, 1180), // compact -> medium
        const Size(1440, 900), // medium -> expanded
        const Size(390, 844), // expanded -> compact
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
      await pumpApp(tester, const Size(390, 844));
      await tester.tap(find.text('Home taps: 0'));
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search taps: 0'));
      await tester.pump();
      await tester.tap(find.text('Search taps: 1'));
      await tester.pump();

      resize(tester, const Size(1440, 900));
      await tester.pumpAndSettle();

      expect(find.text('Search taps: 2'), findsOneWidget);
      // Switch back to Home on the rail: it kept its tap too.
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail), matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.text('Home taps: 1'), findsOneWidget);
    });
  });
}

/// Pushes a location the way the UI does (without waiting for it to close).
void unawaitedPush(GoRouter router, String location) {
  // ignore: discarded_futures
  router.push<void>(location);
}
