import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';
import '../../state/smart_playlist_store.dart';
import '../../subsonic/subsonic_client.dart';
import '../app_shell.dart';
import '../login_page.dart';
import '../pages/album_list_page.dart';
import '../pages/album_page.dart';
import '../pages/artist_list_page.dart';
import '../pages/artist_page.dart';
import '../pages/downloads_page.dart';
import '../pages/equalizer_page.dart';
import '../pages/favorites_page.dart';
import '../pages/home_layout_page.dart';
import '../pages/home_tab.dart';
import '../pages/library_tab.dart';
import '../pages/now_playing_page.dart';
import '../pages/playlist_page.dart';
import '../pages/search_tab.dart';
import '../pages/settings_page.dart';
import '../pages/smart_filter_editor.dart';
import '../pages/smart_playlist_page.dart';
import '../pages/smart_playlists_view.dart';
import '../widgets/records_open.dart';
import '../pages/song_list_page.dart';
import 'app_routes.dart';

/// Builds the app's router.
///
/// The three tabs are one `StatefulShellRoute`: each tab keeps its own page
/// stack alive while another tab is showing, exactly as the old per-tab
/// `Navigator`s did, but every page now has a URL, so the browser's back
/// button, refresh and deep links work on web and desktop gets back/forward.
///
/// [session] gates everything: the loading and login pages are shown until a
/// session exists, and [GoRouter.refreshListenable] re-runs the redirect when
/// it changes (sign in, sign out, restore finishing).
GoRouter buildAppRouter({
  required SessionController session,
  GlobalKey<NavigatorState>? rootNavigatorKey,
  String initialLocation = AppRoutes.home,
}) {
  // Pages are opened with `push` so each tab keeps its back stack, but by
  // default go_router leaves the address bar on the page underneath. With this
  // on, the URL always names the page being shown, so a browser refresh or a
  // copied link lands on the same page.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final rootKey =
      rootNavigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');
  final branchKeys = [
    for (final path in AppRoutes.branches)
      GlobalKey<NavigatorState>(debugLabel: 'branch $path'),
  ];

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: session,
    redirect: (context, state) => appRedirect(
      restoring: session.isRestoring,
      loggedIn: session.isLoggedIn,
      location: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.nowPlaying,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => const MaterialPage<void>(
          fullscreenDialog: true,
          child: NowPlayingPage(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(navigationShell: shell, branchKeys: branchKeys),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchKeys[0],
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomeTab(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[1],
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, __) => const SearchTab(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[2],
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, __) => const LibraryTab(),
                routes: _detailRoutes(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text("That page doesn't exist")),
    ),
  );
}

/// Pages reachable from any tab. Each tab mounts its own copy under its prefix
/// (`/home/album/42`, `/library/album/42`, ...), so a page opens inside the tab
/// it was reached from.
List<RouteBase> _detailRoutes() => [
      GoRoute(
        path: 'album/:id',
        builder: (_, state) => RecordsOpen(
          libraryKey: 'album:${state.pathParameters['id']}',
          child: AlbumPage(albumId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: 'artist/:id',
        builder: (_, state) => RecordsOpen(
          libraryKey: 'artist:${state.pathParameters['id']}',
          child: ArtistPage(artistId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: 'playlist/:id',
        builder: (_, state) => RecordsOpen(
          libraryKey: 'playlist:${state.pathParameters['id']}',
          child: PlaylistPage(
            playlistId: state.pathParameters['id']!,
            name: state.uri.queryParameters['name'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: 'albums',
        builder: (_, state) => AlbumListPage(
          type: AlbumListType.fromName(state.uri.queryParameters['type']) ??
              AlbumListType.alphabetical,
        ),
      ),
      GoRoute(path: 'artists', builder: (_, __) => const ArtistListPage()),
      GoRoute(path: 'songs', builder: (_, __) => const SongListPage()),
      GoRoute(
        path: 'favorites',
        builder: (_, __) => const RecordsOpen(
          libraryKey: 'favorites',
          child: FavoritesPage(),
        ),
      ),
      GoRoute(path: 'downloads', builder: (_, __) => const DownloadsPage()),
      GoRoute(
        path: 'smart',
        builder: (_, __) => const SmartPlaylistsView(),
        routes: [
          // Declared before ':id' so "new" is not read as an id.
          GoRoute(path: 'new', builder: (_, __) => const SmartFilterEditor()),
          GoRoute(
            path: ':id',
            builder: (_, state) => RecordsOpen(
              libraryKey: 'smart:${state.pathParameters['id']}',
              child: SmartPlaylistPage(playlistId: state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final playlist = context
                      .read<SmartPlaylistStore>()
                      .byId(state.pathParameters['id']!);
                  if (playlist == null) {
                    return Scaffold(
                      appBar: AppBar(),
                      body: const Center(child: Text('Playlist removed')),
                    );
                  }
                  return SmartFilterEditor(existing: playlist);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: 'settings',
        builder: (_, __) => const SettingsPage(),
        routes: [
          GoRoute(path: 'equalizer', builder: (_, __) => const EqualizerPage()),
          GoRoute(
              path: 'home-layout', builder: (_, __) => const HomeLayoutPage()),
        ],
      ),
    ];
