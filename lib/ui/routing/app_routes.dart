/// Path constants and the sign-in redirect rule. Kept free of Flutter widgets
/// so the redirect logic can be unit tested directly.
abstract final class AppRoutes {
  static const loading = '/loading';
  static const login = '/login';
  static const nowPlaying = '/now-playing';

  static const home = '/home';
  static const search = '/search';
  static const library = '/library';

  /// The three tab roots, in the order the shell shows them. Every detail page
  /// (album, artist, settings, ...) lives under one of these, so it opens
  /// inside the tab it was reached from and the player and navigation stay on
  /// screen.
  static const branches = [home, search, library];

  /// A detail page path inside the tab at [branchIndex], e.g.
  /// `branchPath(2, 'album/42')` is `/library/album/42`.
  static String branchPath(int branchIndex, String detail) =>
      '${branches[branchIndex]}/$detail';
}

/// Where to send the user given the session state, or null to stay put.
///
/// * While the saved session is being restored, everything shows the loading
///   page, remembering where the user was heading in `from`.
/// * Signed out, everything shows the login page (again remembering `from`).
/// * Signed in, the loading page, the login page and `/` all lead to `from`,
///   or Home when there is none.
///
/// Because the pages are real URLs, a browser refresh on `/library/album/42`
/// lands back on that album once the session is restored.
String? appRedirect({
  required bool restoring,
  required bool loggedIn,
  required Uri location,
}) {
  final path = location.path;
  final from = location.queryParameters['from'];

  if (restoring) {
    if (path == AppRoutes.loading) return null;
    return _withFrom(AppRoutes.loading, from: _headingFor(location));
  }

  if (!loggedIn) {
    if (path == AppRoutes.login) return null;
    final target = path == AppRoutes.loading ? from : _headingFor(location);
    return _withFrom(AppRoutes.login, from: target);
  }

  if (path == AppRoutes.login || path == AppRoutes.loading || path == '/') {
    return _safeTarget(from) ?? AppRoutes.home;
  }
  return null;
}

/// The location the user was trying to reach, or null when there is nothing
/// worth returning to (the root, or one of the gate pages themselves).
String? _headingFor(Uri location) {
  final path = location.path;
  if (path == '/' || path == AppRoutes.login || path == AppRoutes.loading) {
    return null;
  }
  return location.toString();
}

/// Only follow `from` when it is an in-app path that is not itself a gate page,
/// so a crafted or stale value can never cause a redirect loop.
String? _safeTarget(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      path == '/' ||
      path == AppRoutes.login ||
      path == AppRoutes.loading) {
    return null;
  }
  return from;
}

String _withFrom(String path, {String? from}) => from == null
    ? path
    : Uri(path: path, queryParameters: {'from': from}).toString();
