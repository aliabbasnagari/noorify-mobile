import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/routing/app_routes.dart';

void main() {
  String? redirect(
    String location, {
    bool restoring = false,
    bool loggedIn = false,
  }) =>
      appRedirect(
        restoring: restoring,
        loggedIn: loggedIn,
        location: Uri.parse(location),
      );

  String? fromOf(String? redirectTarget) =>
      redirectTarget == null ? null : Uri.parse(redirectTarget).queryParameters['from'];

  group('while the saved session is restored', () {
    test('every page shows the loading page and remembers the target', () {
      final target = redirect('/library/album/42', restoring: true);

      expect(Uri.parse(target!).path, AppRoutes.loading);
      expect(fromOf(target), '/library/album/42');
    });

    test('the loading page itself is left alone', () {
      expect(redirect('/loading?from=%2Fhome', restoring: true), isNull);
    });

    test('the root and gate pages are not remembered', () {
      expect(redirect('/', restoring: true), AppRoutes.loading);
      expect(redirect('/login', restoring: true), AppRoutes.loading);
    });
  });

  group('when signed out', () {
    test('deep links go to the login page and are remembered', () {
      final target = redirect('/search/artist/9');

      expect(Uri.parse(target!).path, AppRoutes.login);
      expect(fromOf(target), '/search/artist/9');
    });

    test('the login page itself is left alone', () {
      expect(redirect('/login'), isNull);
      expect(redirect('/login?from=%2Fhome'), isNull);
    });

    test('the loading page hands its remembered target on to login', () {
      final target = redirect('/loading?from=%2Flibrary%2Fsongs');

      expect(Uri.parse(target!).path, AppRoutes.login);
      expect(fromOf(target), '/library/songs');
    });

    test('with nothing remembered the login page has no target', () {
      expect(redirect('/loading'), AppRoutes.login);
      expect(redirect('/'), AppRoutes.login);
    });
  });

  group('when signed in', () {
    test('ordinary pages are left alone', () {
      expect(redirect('/home', loggedIn: true), isNull);
      expect(redirect('/library/album/42', loggedIn: true), isNull);
      expect(redirect('/now-playing', loggedIn: true), isNull);
    });

    test('the login and loading pages lead to the remembered page', () {
      expect(redirect('/login?from=%2Flibrary%2Falbum%2F42', loggedIn: true),
          '/library/album/42');
      expect(redirect('/loading?from=%2Fsearch', loggedIn: true), '/search');
    });

    test('with nothing remembered they lead Home, as does the root', () {
      expect(redirect('/login', loggedIn: true), AppRoutes.home);
      expect(redirect('/loading', loggedIn: true), AppRoutes.home);
      expect(redirect('/', loggedIn: true), AppRoutes.home);
    });

    test('a remembered target that could loop or leave the app is ignored', () {
      for (final bad in [
        '%2F%2Fevil.example.com',
        'https%3A%2F%2Fevil.example.com',
        '%2Flogin',
        '%2Floading',
        '%2F',
        'relative%2Fpath',
      ]) {
        expect(redirect('/login?from=$bad', loggedIn: true), AppRoutes.home,
            reason: bad);
      }
    });
  });

  test('a page with a query string survives the sign-in round trip', () {
    const original = '/library/playlist/7?name=Road%20trip%20%26%20more';

    final toLogin = redirect(original);
    final back = redirect(toLogin!, loggedIn: true);

    expect(Uri.parse(back!).path, '/library/playlist/7');
    expect(Uri.parse(back).queryParameters['name'], 'Road trip & more');
  });

  test('branchPath prefixes a detail page with its tab', () {
    expect(AppRoutes.branchPath(0, 'album/1'), '/home/album/1');
    expect(AppRoutes.branchPath(1, 'settings'), '/search/settings');
    expect(AppRoutes.branchPath(2, 'smart/new'), '/library/smart/new');
  });
}
