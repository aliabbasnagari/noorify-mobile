import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Opening pages from anywhere in the UI.
///
/// A detail page opens inside the tab the caller is in (so the mini player
/// and navigation stay visible), which is why these resolve the current tab
/// instead of using one fixed path per page.
extension AppNavigation on BuildContext {
  /// Index of the tab this widget is inside, or 0 outside the tab shell.
  int get _branchIndex =>
      StatefulNavigationShell.maybeOf(this)?.currentIndex ?? 0;

  Future<T?> _open<T extends Object?>(String detail) =>
      push<T>(AppRoutes.branchPath(_branchIndex, detail));

  Future<void> openAlbum(String id) =>
      _open('album/${Uri.encodeComponent(id)}');

  Future<void> openArtist(String id) =>
      _open('artist/${Uri.encodeComponent(id)}');

  Future<void> openPlaylist(String id, String name) => _open(
      'playlist/${Uri.encodeComponent(id)}?name=${Uri.encodeQueryComponent(name)}');

  Future<void> openAlbums() => _open('albums');
  Future<void> openArtists() => _open('artists');
  Future<void> openSongs() => _open('songs');
  Future<void> openFavorites() => _open('favorites');
  Future<void> openDownloads() => _open('downloads');
  Future<void> openSmartPlaylists() => _open('smart');
  Future<void> openNewSmartPlaylist() => _open('smart/new');

  Future<void> openSmartPlaylist(String id) =>
      _open('smart/${Uri.encodeComponent(id)}');

  Future<void> editSmartPlaylist(String id) =>
      _open('smart/${Uri.encodeComponent(id)}/edit');

  Future<void> openSettings() => _open('settings');
  Future<void> openEqualizer() => _open('settings/equalizer');
  Future<void> openHomeLayout() => _open('settings/home-layout');

  /// The full-screen player, above everything including the shell.
  Future<void> openNowPlaying() => push<void>(AppRoutes.nowPlaying);

  /// Closes the top page, or goes Home when there is nothing to close (for
  /// example after a browser refresh landed directly on this page).
  void closeOrHome() {
    if (canPop()) {
      pop();
    } else {
      go(AppRoutes.home);
    }
  }
}
