import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When each library item (playlist, album, artist, smart playlist, Favorites)
/// was last opened on this device, so Your Library can sort "Recents" first.
/// Keys look like `playlist:42`, `album:al1` or `favorites`.
class LibraryRecents extends ChangeNotifier {
  LibraryRecents(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _opened.addAll({
          for (final e in decoded.entries) e.key: (e.value as num).toInt(),
        });
      }
    } on Object {
      // Unreadable history is not worth failing startup over.
      _opened.clear();
    }
  }

  static const _key = 'library.recents';

  /// Only the most recent items are remembered.
  static const maxEntries = 200;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Map<String, int> _opened = {};

  /// Milliseconds since the epoch of each key's last open.
  Map<String, int> get all => Map.unmodifiable(_opened);

  int? openedAt(String key) => _opened[key];

  /// Records that [key] was just opened.
  ///
  /// Pages call this from `initState`, where notifying listeners (the library
  /// sidebar) would rebuild widgets mid-build, so listeners are told on the
  /// next microtask instead.
  void touch(String key) {
    _opened[key] = _clock().millisecondsSinceEpoch;
    if (_opened.length > maxEntries) {
      final oldest = _opened.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final e in oldest.take(_opened.length - maxEntries)) {
        _opened.remove(e.key);
      }
    }
    unawaited(_prefs.setString(_key, jsonEncode(_opened)));
    scheduleMicrotask(notifyListeners);
  }

  /// Forgets everything (used on sign-out).
  Future<void> clear() async {
    _opened.clear();
    notifyListeners();
    await _prefs.remove(_key);
  }
}
