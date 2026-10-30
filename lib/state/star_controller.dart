import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../subsonic/subsonic_client.dart';

/// Favourite (star) state for songs. Songs are immutable and may come from a
/// stale cache, so changes made in this session are kept as overrides on top of
/// [Song.starred] and pushed to the server.
class StarController extends ChangeNotifier {
  SubsonicClient? _client;
  final Map<String, bool> _overrides = {};

  /// Called whenever the active server session changes.
  void attach(SubsonicClient? client) {
    if (identical(_client, client)) return;
    _client = client;
    _overrides.clear();
  }

  bool isStarred(Song song) => _overrides[song.id] ?? song.starred;

  /// Flips the favourite flag immediately and syncs it to the server. If the
  /// server call fails the flag is put back and the error is rethrown.
  Future<void> toggle(Song song) async {
    final client = _client;
    if (client == null) return;
    final before = isStarred(song);
    _overrides[song.id] = !before;
    notifyListeners();
    try {
      if (before) {
        await client.unstar(song.id);
      } else {
        await client.star(song.id);
      }
    } on Object {
      if (identical(client, _client)) {
        _overrides[song.id] = before;
        notifyListeners();
      }
      rethrow;
    }
  }
}
