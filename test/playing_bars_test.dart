import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/widgets/playing_bars.dart';

void main() {
  testWidgets('renders three bars and animates while playing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlayingBars(playing: true))),
    );
    expect(find.byType(Container), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 450));
    final midway =
        tester.widgetList<Container>(find.byType(Container)).map((c) {
      return (c.constraints as BoxConstraints).maxHeight;
    }).toList();

    // Mid-cycle the bars should not all be sitting at the frozen height.
    expect(midway.toSet().length, greaterThan(1));
  });

  testWidgets('freezes at a low height when not playing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlayingBars(playing: false))),
    );
    await tester.pump(const Duration(milliseconds: 450));

    final heights =
        tester.widgetList<Container>(find.byType(Container)).map((c) {
      return (c.constraints as BoxConstraints).maxHeight;
    }).toList();
    expect(heights, everyElement(closeTo(4.0, 0.01))); // 16 * 0.25
  });
}
