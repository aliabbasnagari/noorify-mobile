import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/ui/routing/app_router.dart';
import 'package:noorify/ui/shell/library_sidebar.dart';
import 'package:noorify/ui/widgets/album_widgets.dart';
import 'package:noorify/ui/widgets/library_browser.dart';

import 'support/test_app.dart';

/// The desktop layout (window 1024 dp or wider) with the real router and
/// pages: top bar, library sidebar, queue panel and player bar.
void main() {
  late TestApp app;

  Future<void> pumpDesktop(WidgetTester tester,
      {Size size = const Size(1440, 1100)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    app = await TestApp.create();
    addTearDown(app.dispose);
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  Uri currentUri(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).routeInformationProvider.value.uri;
  }

  final topSearchField = find.byWidgetPredicate((w) =>
      w is TextField &&
      w.decoration?.hintText == 'What do you want to listen to?');

  /// Text inside the library sidebar only (the same names also appear on the
  /// Home page's album cards).
  Finder inSidebar(String text) => find.descendant(
      of: find.byType(LibrarySidebar), matching: find.text(text));

  /// Vertical position of a sidebar row, to compare ordering.
  double rowTop(WidgetTester tester, String title) =>
      tester.getTopLeft(inSidebar(title)).dy;

  const songs = [
    Song(id: 'a', title: 'Alpha', artist: 'Artist A', duration: 100),
    Song(id: 'b', title: 'Bravo', artist: 'Artist B', duration: 100),
    Song(id: 'c', title: 'Charlie', artist: 'Artist C', duration: 100),
  ];

  group('library sidebar', () {
    testWidgets('lists Favorites, playlists, artists and albums',
        (tester) async {
      await pumpDesktop(tester);

      expect(find.text('Your Library'), findsOneWidget);
      for (final title in ['Favorites', 'Road trip', 'Calm', 'Beck']) {
        expect(inSidebar(title), findsOneWidget, reason: title);
      }
      expect(inSidebar('Playlist • 3 songs'), findsOneWidget);
      expect(inSidebar('Artist'), findsOneWidget);
    });

    testWidgets('choosing a row opens that page from Home', (tester) async {
      await pumpDesktop(tester);

      await tester.tap(inSidebar('Road trip'));
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/home/playlist/p1');
      expect(currentUri(tester).queryParameters['name'], 'Road trip');
    });

    /// Whether the sidebar row titled [title] is highlighted as open.
    bool isOpen(WidgetTester tester, String title) => tester
        .widget<ListTile>(find.ancestor(
            of: inSidebar(title), matching: find.byType(ListTile)))
        .selected;

    testWidgets('the open page is highlighted, and only that one',
        (tester) async {
      await pumpDesktop(tester);
      expect(isOpen(tester, 'Road trip'), isFalse);

      await tester.tap(inSidebar('Road trip'));
      await tester.pumpAndSettle();

      expect(isOpen(tester, 'Road trip'), isTrue);
      expect(isOpen(tester, 'Calm'), isFalse);
      expect(isOpen(tester, 'Favorites'), isFalse);

      await tester.tap(inSidebar('Calm'));
      await tester.pumpAndSettle();

      expect(isOpen(tester, 'Calm'), isTrue);
      expect(isOpen(tester, 'Road trip'), isFalse);
    });

    testWidgets('the highlight goes when the page is left', (tester) async {
      await pumpDesktop(tester);
      await tester.tap(inSidebar('Road trip'));
      await tester.pumpAndSettle();
      expect(isOpen(tester, 'Road trip'), isTrue);

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();

      expect(isOpen(tester, 'Road trip'), isFalse);
    });

    testWidgets('an album opened from a card is highlighted too',
        (tester) async {
      await pumpDesktop(tester);

      // The Home page's album card, not the sidebar row.
      final card = find.widgetWithText(AlbumCard, 'Test Album').first;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/home/album/al1');
      expect(isOpen(tester, 'Test Album'), isTrue);
    });

    testWidgets('the collapsed strip outlines the open item', (tester) async {
      await pumpDesktop(tester);
      await tester.tap(inSidebar('Road trip'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse your library'));
      await tester.pumpAndSettle();

      final frames = tester
          .widgetList<SelectedFrame>(find.byType(SelectedFrame))
          .where((f) => f.selected);
      expect(frames, hasLength(1));
    });

    testWidgets('a filter chip narrows the list and tapping it again clears it',
        (tester) async {
      await pumpDesktop(tester);
      expect(inSidebar('Road trip'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Artists'));
      await tester.pumpAndSettle();
      expect(inSidebar('Road trip'), findsNothing);
      expect(inSidebar('Beck'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Artists'));
      await tester.pumpAndSettle();
      expect(inSidebar('Road trip'), findsOneWidget);
    });

    testWidgets('searching within the library filters the rows',
        (tester) async {
      await pumpDesktop(tester);

      await tester.tap(find.byTooltip('Search in your library'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, '').last.hitTestable(), 'calm');
      await tester.pumpAndSettle();

      expect(inSidebar('Calm'), findsOneWidget);
      expect(inSidebar('Road trip'), findsNothing);
      expect(inSidebar('Beck'), findsNothing);
    });

    testWidgets('an opened item moves to the top of Recents', (tester) async {
      await pumpDesktop(tester);
      // Alphabetically "Beck" comes before "Test Album".
      expect(rowTop(tester, 'Beck'), lessThan(rowTop(tester, 'Test Album')));

      await tester.ensureVisible(inSidebar('Test Album'));
      await tester.tap(inSidebar('Test Album'));
      await tester.pumpAndSettle();

      expect(app.recents.openedAt('album:al1'), isNotNull);
      expect(rowTop(tester, 'Test Album'), lessThan(rowTop(tester, 'Beck')));
      // Favorites stays pinned above it.
      expect(
          rowTop(tester, 'Favorites'), lessThan(rowTop(tester, 'Test Album')));
    });

    testWidgets('sorting alphabetically ignores the opened order',
        (tester) async {
      await pumpDesktop(tester);
      await tester.ensureVisible(inSidebar('Test Album'));
      await tester.tap(inSidebar('Test Album'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alphabetical').last);
      await tester.pumpAndSettle();

      expect(rowTop(tester, 'Beck'), lessThan(rowTop(tester, 'Test Album')));
      expect(app.settings.shell.librarySort.name, 'alphabetical');
    });

    testWidgets('the view can be switched to a grid and remembered',
        (tester) async {
      await pumpDesktop(tester);
      expect(inSidebar('Playlist • 3 songs'), findsOneWidget);

      await tester.tap(find.byTooltip('View as'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      // Grid shows art only, so the subtitles are gone.
      expect(inSidebar('Playlist • 3 songs'), findsNothing);
      expect(app.settings.shell.libraryView.name, 'grid');
    });

    testWidgets('it collapses to cover art and expands again', (tester) async {
      await pumpDesktop(tester);

      await tester.tap(find.byTooltip('Collapse your library'));
      await tester.pumpAndSettle();
      expect(find.text('Your Library'), findsNothing);
      expect(find.byTooltip('Expand your library'), findsOneWidget);
      expect(app.settings.shell.sidebarCollapsed, isTrue);

      await tester.tap(find.byTooltip('Expand your library'));
      await tester.pumpAndSettle();
      expect(find.text('Your Library'), findsOneWidget);
      expect(app.settings.shell.sidebarCollapsed, isFalse);
    });

    testWidgets('a playlist created elsewhere appears without a reload',
        (tester) async {
      await pumpDesktop(tester);
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

  group('create menu', () {
    testWidgets('the sidebar plus button offers a popup, not a sheet',
        (tester) async {
      await pumpDesktop(tester);

      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Smart playlist'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('choosing Smart playlist opens the rule editor',
        (tester) async {
      await pumpDesktop(tester);

      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart playlist'));
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/home/smart/new');
      expect(find.text('New smart playlist'), findsOneWidget);
    });
  });

  group('top bar', () {
    testWidgets('the Home button returns to Home from a page', (tester) async {
      await pumpDesktop(tester);
      await tester.tap(inSidebar('Road trip'));
      await tester.pumpAndSettle();
      expect(currentUri(tester).path, '/home/playlist/p1');

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/home');
    });

    testWidgets('typing in the search field shows results on the Search tab',
        (tester) async {
      await pumpDesktop(tester);

      await tester.enterText(topSearchField, 'first');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/search');
      expect(app.searchQuery.text, 'first');
      // The song is both the top result and a row in the list.
      expect(find.text('First Song'), findsNWidgets(2));
    });

    testWidgets('clearing the field clears the results', (tester) async {
      await pumpDesktop(tester);
      await tester.enterText(topSearchField, 'first');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      // The song is both the top result and a row in the list.
      expect(find.text('First Song'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(app.searchQuery.text, isEmpty);
      expect(find.text('First Song'), findsNothing);
      expect(find.text('Search your library'), findsOneWidget);
    });

    testWidgets('the Search page has no field of its own on desktop',
        (tester) async {
      await pumpDesktop(tester);
      await tester.enterText(topSearchField, 'first');
      await tester.pumpAndSettle();

      // Only the top bar's field exists.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the account menu offers settings, sync and sign out',
        (tester) async {
      await pumpDesktop(tester);

      await tester.tap(find.byTooltip('Account: alice'));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sync library'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(currentUri(tester).path, '/home/settings');
    });
  });

  group('queue panel', () {
    testWidgets('is open and empty at first, with a way to start',
        (tester) async {
      await pumpDesktop(tester);

      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Add to your queue'), findsOneWidget);

      await tester.tap(find.text('Find something to play'));
      await tester.pumpAndSettle();
      expect(currentUri(tester).path, '/search');
    });

    testWidgets('shows what is playing and what comes next from the source',
        (tester) async {
      await pumpDesktop(tester);

      await app.player.playSongs(songs, source: 'Road trip');
      await tester.pumpAndSettle();

      expect(find.text('Now playing'), findsOneWidget);
      expect(find.text('Next from: Road trip'), findsOneWidget);
      // "Alpha" is playing: it shows in the panel and the player bar.
      expect(find.text('Alpha'), findsNWidgets(2));
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('without a known source the heading is generic',
        (tester) async {
      await pumpDesktop(tester);

      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      expect(find.text('Next in queue'), findsOneWidget);
    });

    testWidgets('removing an upcoming song takes it out of the queue',
        (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs, source: 'Road trip');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove from queue').first);
      await tester.pumpAndSettle();

      expect(app.player.queueSongs.map((s) => s.id), ['a', 'c']);
      expect(find.text('Bravo'), findsNothing);
    });

    testWidgets('dragging an upcoming song reorders the real queue',
        (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();
      expect(app.player.queueSongs.map((s) => s.id), ['a', 'b', 'c']);

      // Long-press "Bravo" and drag it below "Charlie". The panel hides the
      // song already playing, so its row positions are offset by one from the
      // queue's.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Bravo')));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(app.player.queueSongs.map((s) => s.id), ['a', 'c', 'b']);
      expect(app.player.current?.id, 'a',
          reason: 'the playing song is untouched');
    });

    testWidgets('choosing an upcoming song jumps to it', (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Charlie'));
      await tester.pumpAndSettle();

      expect(app.audio.seeks.last.index, 2);
    });

    testWidgets('can be closed and reopened from the player bar',
        (tester) async {
      await pumpDesktop(tester);
      expect(find.text('Add to your queue'), findsOneWidget);

      await tester.tap(find.byTooltip('Close queue'));
      await tester.pumpAndSettle();
      expect(find.text('Add to your queue'), findsNothing);
      expect(app.settings.shell.queuePanelOpen, isFalse);

      await tester.tap(find.byTooltip('Show queue'));
      await tester.pumpAndSettle();
      expect(find.text('Add to your queue'), findsOneWidget);
      expect(app.settings.shell.queuePanelOpen, isTrue);
    });
  });

  group('player bar', () {
    IconButton button(WidgetTester tester, String tooltip) => tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, _icon[tooltip]!));

    testWidgets('its controls are disabled until something is queued',
        (tester) async {
      await pumpDesktop(tester);

      for (final tooltip in ['Previous', 'Next', 'Shuffle', 'Repeat']) {
        expect(button(tester, tooltip).onPressed, isNull, reason: tooltip);
      }
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('shows the song and its transport once playing',
        (tester) async {
      await pumpDesktop(tester);

      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      expect(find.text('Artist A'), findsNWidgets(2)); // bar and queue panel
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(button(tester, 'Next').onPressed, isNotNull);
    });

    testWidgets('play/pause, next and previous drive the player',
        (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(app.audio.playing, isFalse);
      expect(find.byTooltip('Play'), findsOneWidget);

      await tester.tap(find.byTooltip('Next'));
      await tester.pump();
      expect(app.audio.seekToNextCalls, 1);

      await tester.tap(find.byTooltip('Previous'));
      await tester.pump();
      expect(app.audio.seekToPreviousCalls, 1);
    });

    testWidgets('the volume slider sets the listener volume', (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();
      app.audio.volumes.clear();

      final slider = find.byType(Slider).last;
      await tester.drag(slider, const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(app.player.userVolume, lessThan(0.5));
      expect(app.audio.volumes.last, lessThan(0.5));
    });

    testWidgets('mute silences playback and unmute restores it',
        (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mute'));
      await tester.pumpAndSettle();
      expect(app.player.isMuted, isTrue);
      expect(app.audio.volumes.last, 0);
      expect(find.byTooltip('Unmute'), findsOneWidget);

      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(app.player.isMuted, isFalse);
      expect(app.audio.volumes.last, 1);
    });

    testWidgets('the favourite heart stars the playing song', (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();

      expect(app.stars.isStarred(songs.first), isTrue);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    });

    testWidgets('Open Now Playing opens the full-screen player',
        (tester) async {
      await pumpDesktop(tester);
      await app.player.playSongs(songs);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open Now Playing'));
      await tester.pumpAndSettle();

      expect(currentUri(tester).path, '/now-playing');
    });
  });

  testWidgets('a narrower window falls back to the rail and mini player',
      (tester) async {
    await pumpDesktop(tester);
    await app.player.playSongs(songs);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(820, 1180);
    // The mini player's art spins while playing, so this never fully settles.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Your Library'), findsOneWidget); // the rail destination
    expect(find.text('Next from: Road trip'), findsNothing);
    expect(app.audio.playing, isTrue);
  });
}

const _icon = {
  'Previous': Icons.skip_previous,
  'Next': Icons.skip_next,
  'Shuffle': Icons.shuffle,
  'Repeat': Icons.repeat,
};
