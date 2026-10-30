import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/adaptive/layout.dart';

void main() {
  group('ArtGridDelegate', () {
    const delegate = ArtGridDelegate(bodyHeight: 60);

    test('fits as many tiles as keep each under the maximum width', () {
      expect(delegate.columnsFor(900), 5);
      expect(delegate.columnsFor(1400), 7);
      expect(delegate.columnsFor(320), 2);
    });

    test('never has fewer than one column', () {
      expect(delegate.columnsFor(50), 1);
      expect(delegate.columnsFor(0), 1);
    });

    test('tiles fill the width exactly and stay within the maximum', () {
      for (final width in [320.0, 390.0, 700.0, 900.0, 1234.0, 1920.0]) {
        final columns = delegate.columnsFor(width);
        final tile = (width - 12 * (columns - 1)) / columns;

        expect(tile, lessThanOrEqualTo(190), reason: 'at $width');
        expect(tile * columns + 12 * (columns - 1), closeTo(width, 1e-9));
      }
    });

    test('a tile is as tall as its art plus the text', () {
      final layout = delegate.getLayout(
        const SliverConstraints(
          axisDirection: AxisDirection.down,
          growthDirection: GrowthDirection.forward,
          userScrollDirection: ScrollDirection.idle,
          scrollOffset: 0,
          precedingScrollExtent: 0,
          overlap: 0,
          remainingPaintExtent: 800,
          crossAxisExtent: 900,
          crossAxisDirection: AxisDirection.right,
          viewportMainAxisExtent: 800,
          remainingCacheExtent: 800,
          cacheOrigin: 0,
        ),
      ) as SliverGridRegularTileLayout;

      expect(layout.crossAxisCount, 5);
      expect(layout.childCrossAxisExtent, closeTo(170.4, 0.01));
      expect(layout.childMainAxisExtent,
          closeTo(layout.childCrossAxisExtent + 60, 1e-9));
    });

    test('relayouts only when its settings change', () {
      expect(delegate.shouldRelayout(const ArtGridDelegate(bodyHeight: 60)),
          isFalse);
      expect(delegate.shouldRelayout(const ArtGridDelegate(bodyHeight: 90)),
          isTrue);
      expect(
          delegate.shouldRelayout(
              const ArtGridDelegate(bodyHeight: 60, maxTileWidth: 150)),
          isTrue);
    });
  });

  group('artCardBodyHeight', () {
    testWidgets('grows with the text size', (tester) async {
      late double normal;
      late double large;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(builder: (context) {
                normal = artCardBodyHeight(context);
                return const SizedBox();
              }),
              MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Builder(builder: (context) {
                  large = artCardBodyHeight(context);
                  return const SizedBox();
                }),
              ),
            ],
          ),
        ),
      );

      expect(normal, 60);
      expect(large, 120);
    });
  });

  testWidgets('ContentFrame centres its child and caps the width',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2000, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ContentFrame(
          maxWidth: 1000,
          child: SizedBox.expand(key: ValueKey('content')),
        ),
      ),
    );

    final box = tester.getRect(find.byKey(const ValueKey('content')));
    expect(box.width, 1000);
    expect(box.center.dx, 1000);
  });

  group('AdaptiveShelf', () {
    Future<void> pumpShelf(
      WidgetTester tester, {
      required Size size,
      int items = 12,
      VoidCallback? onShowAll,
      double textScale = 1,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: AdaptiveShelf(
                title: 'Newly added',
                itemCount: items,
                onShowAll: onShowAll,
                itemBuilder: (_, i, width) => SizedBox(
                  key: ValueKey('card$i'),
                  width: width,
                  child: Text('Card $i'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double cardWidth(WidgetTester tester, int i) =>
        tester.getSize(find.byKey(ValueKey('card$i'))).width;

    testWidgets('on a phone cards are a fixed width and there are no arrows',
        (tester) async {
      await pumpShelf(tester, size: const Size(390, 844));

      expect(cardWidth(tester, 0), 150);
      expect(find.byTooltip('Scroll right'), findsNothing);
      expect(find.byTooltip('Scroll left'), findsNothing);
      expect(find.text('Newly added'), findsOneWidget);
    });

    testWidgets('on a wide window the cards stretch to fill the row',
        (tester) async {
      await pumpShelf(tester, size: const Size(1200, 800));

      // The row is 1200 - 2 * 24 wide, which fits six cards of up to 190.
      const row = 1200 - 48.0;
      final width = cardWidth(tester, 0);
      expect(width, lessThanOrEqualTo(190));
      expect(width, greaterThan(150));
      expect(tester.getRect(find.byKey(const ValueKey('card5'))).right,
          closeTo(24 + row, 0.5),
          reason: 'six cards exactly fill the row');
      expect(tester.getRect(find.byKey(const ValueKey('card6'))).left,
          greaterThan(24 + row),
          reason: 'the seventh starts off screen');
    });

    testWidgets('arrows page through the rest and enable as you go',
        (tester) async {
      await pumpShelf(tester, size: const Size(1200, 800));
      IconButton arrow(String tooltip) =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton,
              tooltip == 'Next' ? Icons.chevron_right : Icons.chevron_left));

      double offset() => tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      expect(arrow('Previous').onPressed, isNull);
      expect(arrow('Next').onPressed, isNotNull);
      expect(offset(), 0);

      await tester.tap(find.byTooltip('Scroll right'));
      await tester.pumpAndSettle();

      // One page is six cards plus their gaps.
      expect(offset(), greaterThan(900));
      expect(arrow('Previous').onPressed, isNotNull);

      // Page to the end: Next switches off.
      for (var i = 0; i < 5; i++) {
        if (arrow('Next').onPressed == null) break;
        await tester.tap(find.byTooltip('Scroll right'));
        await tester.pumpAndSettle();
      }
      expect(arrow('Next').onPressed, isNull);
    });

    testWidgets('no arrows are enabled when everything already fits',
        (tester) async {
      await pumpShelf(tester, size: const Size(1200, 800), items: 3);

      final next = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(next.onPressed, isNull);
    });

    testWidgets('Show all appears only when given, and calls back',
        (tester) async {
      await pumpShelf(tester, size: const Size(390, 844));
      expect(find.text('Show all'), findsNothing);

      var tapped = 0;
      await pumpShelf(tester,
          size: const Size(390, 844), onShowAll: () => tapped++);
      await tester.tap(find.text('Show all'));

      expect(tapped, 1);
    });

    testWidgets('large text does not overflow the cards', (tester) async {
      await pumpShelf(tester, size: const Size(390, 844), textScale: 2);
      expect(tester.takeException(), isNull);

      await pumpShelf(tester, size: const Size(1200, 800), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shelf grows taller with the text size', (tester) async {
      await pumpShelf(tester, size: const Size(390, 844));
      final normal = tester.getSize(find.byType(ListView)).height;

      await pumpShelf(tester, size: const Size(390, 844), textScale: 2);
      final large = tester.getSize(find.byType(ListView)).height;

      expect(large, greaterThan(normal));
    });
  });
}
