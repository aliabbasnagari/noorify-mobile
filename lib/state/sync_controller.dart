import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import '../models/models.dart';
import '../subsonic/subsonic_client.dart';
import '../util/retry.dart';

/// Keeps an on-device index of every song so smart playlists can be evaluated
/// locally. Counterpart of Symfonium's SyncService: the server is paged once
/// and the result is cached in a local SQLite database (scoped by account),
/// rather than a single flat file.
class SyncController extends ChangeNotifier {
  SyncController(this._db);

  static const _pageSize = 500;

  final AppDatabase _db;

  SubsonicClient? _client;
  List<Song> _songs = const [];
  bool _syncing = false;
  Object? _error;
  DateTime? _lastSync;

  List<Song> get songs => _songs;
  bool get isSyncing => _syncing;
  Object? get error => _error;
  DateTime? get lastSync => _lastSync;

  String? get _owner => _ownerOf(_client);

  static String? _ownerOf(SubsonicClient? c) =>
      c == null ? null : '${c.config.url}|${c.config.username}';

  void attach(SubsonicClient? client) {
    if (identical(_client, client)) return;
    _client = client;
    _songs = const [];
    _lastSync = null;
    _error = null;
    // Loading is async, so listeners are notified outside the build phase
    // this method is called from.
    if (client != null) unawaited(_load(client));
  }

  Future<void> _load(SubsonicClient client) async {
    final owner = _ownerOf(client)!;
    try {
      final songs = await _db.loadSongs(owner);
      final lastSync = await _db.getLastSync(owner);
      if (!identical(client, _client)) return;
      _songs = songs;
      _lastSync = lastSync;
      notifyListeners();
    } on Object {
      // A missing or corrupt cache just means "not synced yet".
    }
  }

  /// Downloads the whole song list. Safe to call repeatedly.
  Future<void> sync() async {
    final client = _client;
    final owner = _owner;
    if (client == null || owner == null || _syncing) return;
    _syncing = true;
    _error = null;
    notifyListeners();

    try {
      final byId = <String, Song>{};
      var query = '';
      var offset = 0;
      while (true) {
        final page = await withRetry(
          () => client.getSongsPage(
              offset: offset, size: _pageSize, query: query),
        );
        if (page.isEmpty && offset == 0 && query.isEmpty) {
          // Some servers need a wildcard instead of an empty query.
          query = '*';
          continue;
        }
        final before = byId.length;
        for (final s in page) {
          byId[s.id] = s;
        }
        // No new ids means the server ignored songOffset; stop instead of
        // looping forever.
        if (page.length < _pageSize || byId.length == before) break;
        offset += _pageSize;
        if (!identical(client, _client)) return;
        await _db.upsertSongs(owner, page);
        _songs = byId.values.toList();
        notifyListeners();
      }
      if (!identical(client, _client)) return;
      _songs = byId.values.toList();
      _lastSync = DateTime.now();
      await _db.replaceSongs(owner, _songs);
      await _db.setLastSync(owner, _lastSync!);
    } on Object catch (e) {
      _error = e;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
