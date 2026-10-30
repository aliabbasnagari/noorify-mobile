import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/adaptive/window_class.dart';

void main() {
  group('WindowClass.forWidth', () {
    test('phones are compact', () {
      expect(WindowClass.forWidth(0), WindowClass.compact);
      expect(WindowClass.forWidth(360), WindowClass.compact);
      expect(WindowClass.forWidth(599.9), WindowClass.compact);
    });

    test('tablets in portrait are medium', () {
      expect(WindowClass.forWidth(600), WindowClass.medium);
      expect(WindowClass.forWidth(820), WindowClass.medium);
      expect(WindowClass.forWidth(1023.9), WindowClass.medium);
    });

    test('landscape tablets, desktop and wide web are expanded', () {
      expect(WindowClass.forWidth(1024), WindowClass.expanded);
      expect(WindowClass.forWidth(1280), WindowClass.expanded);
      expect(WindowClass.forWidth(3840), WindowClass.expanded);
    });

    test('the boolean helpers match the class', () {
      expect(WindowClass.compact.isCompact, isTrue);
      expect(WindowClass.compact.isExpanded, isFalse);
      expect(WindowClass.medium.isMedium, isTrue);
      expect(WindowClass.expanded.isExpanded, isTrue);
    });
  });

  testWidgets('of(context) follows the window as it is resized',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    WindowClass? seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          seen = WindowClass.of(context);
          return const SizedBox();
        }),
      ),
    );

    for (final (size, expected) in [
      (const Size(390, 844), WindowClass.compact),
      (const Size(820, 1180), WindowClass.medium),
      (const Size(1440, 900), WindowClass.expanded),
      (const Size(500, 900), WindowClass.compact),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(seen, expected, reason: '$size');
    }
  });
}
