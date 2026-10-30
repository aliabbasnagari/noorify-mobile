import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../smart/smart_filter.dart';

/// Local store of smart playlists (rules live on-device; the server only
/// provides the songs they are evaluated against).
class SmartPlaylistStore extends ChangeNotifier {
  SmartPlaylistStore(this._prefs) {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        _items.addAll([
          for (final j in jsonDecode(raw) as List)
            SmartPlaylist.fromJson(j as Map<String, dynamic>),
        ]);
      }
    } on Object {
      _items.clear();
    }
  }

  static const _key = 'smart_playlists';

  final SharedPreferences _prefs;
  final List<SmartPlaylist> _items = [];

  List<SmartPlaylist> get items => List.unmodifiable(_items);

  SmartPlaylist? byId(String id) => _items.where((p) => p.id == id).firstOrNull;

  Future<void> upsert(SmartPlaylist playlist) async {
    final i = _items.indexWhere((p) => p.id == playlist.id);
    if (i >= 0) {
      _items[i] = playlist;
    } else {
      _items.add(playlist);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(
        _key, jsonEncode([for (final p in _items) p.toJson()]));
  }
}
