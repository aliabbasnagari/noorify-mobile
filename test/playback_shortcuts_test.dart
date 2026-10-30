import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/state/player_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';
import 'package:noorify/ui/widgets/playback_shortcuts.dart';
import 'package:provider/provider.dart';

import 'support/fake_audio_player.dart';

void main() {
  late FakeAudioPlayer fake;
  late PlayerController player;

  /// A widget test that always clears the platform override before it ends:
  /// the test framework verifies it is unset before any tear-down callback
  /// runs, so `addTearDown` is too late.
  void shellTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

  Future<void> pumpShell(WidgetTester tester, {bool withQueue = true}) async {
    // Keep the Android-only effect pipeline out of the controller.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    fake = FakeAudioPlayer();
    player = PlayerController(playerFactory: ({audioPipeline}) => fake);
    addTearDown(player.dispose);
    player.attach(SubsonicClient(const ServerConfig(
      url: 'https://music.example.com',
      username: 'alice',
      password: 'sesame',
    )));
    if (withQueue) {
      await player.playSongs([
        const Song(id: 'a', title: 'A', duration: 10),
        const Song(id: 'b', title: 'B', duration: 10),
      ]);
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerController>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: PlaybackShortcuts(child: Center(child: TextField())),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  shellTest('space pauses and resumes playback', (tester) async {
    await pumpShell(tester);
    expect(fake.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fake.playing, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(fake.playing, isTrue);
  });

  shellTest('space does nothing when the queue is empty', (tester) async {
    await pumpShell(tester, withQueue: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(fake.playing, isFalse);
    expect(fake.source, isNull);
  });

  shellTest('space is left to the text field while typing', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fake.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(fake.playing, isTrue, reason: 'typing a space must not pause');
  });

  shellTest('ctrl+right and ctrl+left skip tracks', (tester) async {
    await pumpShell(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(fake.seekToNextCalls, 1);

    // Under 3 s into the track, "previous" goes to the previous track.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(fake.seekToPreviousCalls, 1);
  });

  shellTest('plain arrow keys are not hijacked', (tester) async {
    await pumpShell(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(fake.seekToNextCalls, 0);
    expect(fake.seekToPreviousCalls, 0);
  });
}
