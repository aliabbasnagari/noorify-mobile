import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/widgets/art_hero_background.dart';

void main() {
  testWidgets('renders only the neutral gradient when there is no art',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
          home: Scaffold(body: ArtHeroBackground(imageUrl: null))),
    );
    await tester.pump();

    final opacity =
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0);
  });
}
