import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/settings/settings_models.dart';
import 'package:noorify/state/library_recents.dart';
import 'package:noorify/state/search_query.dart';
import 'package:noorify/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('LibraryRecents', () {
    LibraryRecents recents({DateTime Function()? clock}) =>
        LibraryRecents(prefs, clock: clock);

    test('remembers when an item was opened', () {
      var now = DateTime.fromMillisecondsSinceEpoch(1000);
      final r = recents(clock: () => now);

      r.touch('album:al1');
      now = DateTime.fromMillisecondsSinceEpoch(5000);
      r.touch('playlist:p1');

      expect(r.openedAt('album:al1'), 1000);
      expect(r.openedAt('playlist:p1'), 5000);
      expect(r.openedAt('artist:none'), isNull);
    });

    test('opening an item again updates its time', () {
      var now = DateTime.fromMillisecondsSinceEpoch(1000);
      final r = recents(clock: () => now);
      r.touch('album:al1');

      now = DateTime.fromMillisecondsSinceEpoch(9000);
      r.touch('album:al1');

      expect(r.openedAt('album:al1'), 9000);
      expect(r.all, hasLength(1));
    });

    test('the history survives a restart', () async {
      final first =
          recents(clock: () => DateTime.fromMillisecondsSinceEpoch(42));
      first.touch('favorites');
      await pumpEventQueue();

      final second = recents();

      expect(second.openedAt('favorites'), 42);
    });

    test('only the most recent entries are kept', () {
      var millis = 0;
      final r =
          recents(clock: () => DateTime.fromMillisecondsSinceEpoch(millis++));

      for (var i = 0; i < LibraryRecents.maxEntries + 5; i++) {
        r.touch('album:$i');
      }

      expect(r.all, hasLength(LibraryRecents.maxEntries));
      expect(r.openedAt('album:0'), isNull, reason: 'the oldest are dropped');
      expect(r.openedAt('album:${LibraryRecents.maxEntries + 4}'), isNotNull);
    });

    test('listeners are told on the next microtask, not mid-build', () async {
      final r = recents();
      var notified = 0;
      r.addListener(() => notified++);

      r.touch('album:al1');
      expect(notified, 0, reason: 'touch is called from initState');

      await pumpEventQueue();
      expect(notified, 1);
    });

    test('clear forgets everything, including what was saved', () async {
      final r = recents();
      r.touch('album:al1');
      await pumpEventQueue();

      await r.clear();

      expect(r.all, isEmpty);
      expect(recents().all, isEmpty);
    });

    test('unreadable saved history is ignored', () async {
      await prefs.setString('library.recents', 'not json {');

      expect(recents().all, isEmpty);
    });
  });

  group('ShellLayoutSettings', () {
    test('defaults suit a first run', () {
      const s = ShellLayoutSettings();

      expect(s.sidebarCollapsed, isFalse);
      expect(s.queuePanelOpen, isTrue);
      expect(s.libraryView, LibraryViewMode.list);
      expect(s.librarySort, LibrarySort.recents);
    });

    test('round-trips through JSON', () {
      const s = ShellLayoutSettings(
        sidebarCollapsed: true,
        queuePanelOpen: false,
        libraryView: LibraryViewMode.grid,
        librarySort: LibrarySort.alphabetical,
      );

      final copy = ShellLayoutSettings.fromJson(s.toJson());

      expect(copy.toJson(), s.toJson());
    });

    test('missing or unknown values fall back to the defaults', () {
      final s = ShellLayoutSettings.fromJson({
        'libraryView': 'hologram',
        'librarySort': 7,
      });

      expect(s.libraryView, LibraryViewMode.list);
      expect(s.librarySort, LibrarySort.recents);
      expect(s.queuePanelOpen, isTrue);
    });
  });

  group('SettingsController shell layout', () {
    test('updateShell persists, and a new controller reads it back', () async {
      final first = SettingsController(prefs);
      var notified = 0;
      first.addListener(() => notified++);

      await first.updateShell((s) => s.copyWith(
            sidebarCollapsed: true,
            libraryView: LibraryViewMode.compact,
          ));

      expect(first.shell.sidebarCollapsed, isTrue);
      expect(notified, 1);
      final second = SettingsController(prefs);
      expect(second.shell.sidebarCollapsed, isTrue);
      expect(second.shell.libraryView, LibraryViewMode.compact);
      expect(second.shell.queuePanelOpen, isTrue);
    });

    test('corrupt saved layout falls back to the defaults', () async {
      await prefs.setString('settings.shell', '[1, 2');

      final c = SettingsController(prefs);

      expect(c.shell.queuePanelOpen, isTrue);
      expect(c.shell.sidebarCollapsed, isFalse);
    });
  });

  group('SearchQuery', () {
    test('notifies when the text changes and not when it does not', () {
      final q = SearchQuery();
      var notified = 0;
      q.addListener(() => notified++);

      q.set('abba');
      q.set('abba');
      q.set('abba!');

      expect(q.text, 'abba!');
      expect(notified, 2);
    });

    test('clear empties the text', () {
      final q = SearchQuery()..set('x');

      q.clear();

      expect(q.text, isEmpty);
    });
  });
}
