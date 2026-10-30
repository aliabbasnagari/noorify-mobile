import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/ui/routing/app_router.dart';
import 'package:noorify/ui/widgets/cover_art.dart';

import 'support/test_app.dart';

/// The Now Playing page stacks the artwork over the controls on a phone and
/// puts them side by side in a wide, landscape window.
void main() {
  Future<void> openNowPlaying(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.defaultRouteNameTestValue = '/now-playing';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    final app = await TestApp.create();
    addTearDown(app.dispose);
    await app.player.playSongs(
      const [Song(id: 's1', title: 'Loud Song', artist: 'Beck', duration: 200)],
    );
    final router = buildAppRouter(session: app.session);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      app.providers(MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f.first);

  testWidgets('a phone stacks the artwork above the title', (tester) async {
    await openNowPlaying(tester, const Size(390, 800));

    final art = rectOf(tester, find.byType(CoverArt));
    final title = rectOf(tester, find.text('Loud Song'));

    expect(art.bottom, lessThanOrEqualTo(title.top));
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  testWidgets('a wide landscape window puts the artwork beside the controls',
      (tester) async {
    await openNowPlaying(tester, const Size(1280, 720));

    final art = rectOf(tester, find.byType(CoverArt));
    final title = rectOf(tester, find.text('Loud Song'));

    expect(art.right, lessThanOrEqualTo(title.left));
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  testWidgets('a wide but tall window still stacks, in a bounded column',
      (tester) async {
    await openNowPlaying(tester, const Size(900, 1300));

    final art = rectOf(tester, find.byType(CoverArt));
    final title = rectOf(tester, find.text('Loud Song'));

    expect(art.bottom, lessThanOrEqualTo(title.top));
    expect(art.width, lessThanOrEqualTo(560));
  });
}
