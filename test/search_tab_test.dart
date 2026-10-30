import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/pages/search_tab.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;

  Future<void> pumpSearch(WidgetTester tester,
      {Size size = const Size(390, 844)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    app = await TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      app.providers(const MaterialApp(home: SearchTab())),
    );
    await tester.pump();
  }

  Future<void> afterDebounce(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  int searches() =>
      app.requests.where((u) => u.pathSegments.last == 'search3.view').length;

  testWidgets('on a phone the page has its own field, which sets the query',
      (tester) async {
    await pumpSearch(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search your library'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'first');
    await afterDebounce(tester);

    expect(app.searchQuery.text, 'first');
    expect(find.text('First Song'), findsOneWidget);
    expect(searches(), 1);
  });

  testWidgets('waits for a pause in typing before searching', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'f');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'fi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'fir');
    await afterDebounce(tester);

    expect(searches(), 1, reason: 'one request for the settled text');
    expect(app.requests.last.queryParameters['query'], 'fir');
  });

  testWidgets('a query set from outside fills the field and searches',
      (tester) async {
    await pumpSearch(tester);

    app.searchQuery.set('first');
    await afterDebounce(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'first',
    );
    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('text typed before the page existed is searched on arrival',
      (tester) async {
    app = await TestApp.create();
    addTearDown(app.dispose);
    app.searchQuery.set('first');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      app.providers(const MaterialApp(home: SearchTab())),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Song'), findsOneWidget);
  });

  testWidgets('the clear button empties the query and the results',
      (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'first');
    await afterDebounce(tester);
    expect(find.text('First Song'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(app.searchQuery.text, isEmpty);
    expect(find.text('First Song'), findsNothing);
    expect(find.text('Search your library'), findsOneWidget);
  });

  testWidgets('a blank query makes no request', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await afterDebounce(tester);

    expect(searches(), 0);
  });

  testWidgets('on desktop the page has no field and follows the top bar',
      (tester) async {
    await pumpSearch(tester, size: const Size(1440, 900));
    expect(find.byType(TextField), findsNothing);

    app.searchQuery.set('first');
    await afterDebounce(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('First Song'), findsOneWidget);
  });
}
