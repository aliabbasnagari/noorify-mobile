import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../subsonic/subsonic_client.dart';
import 'playlists_revision.dart';

/// The server's playlists, artists and albums as Your Library lists them,
/// loaded once and shared by every view of the library (the desktop sidebar
/// and the phone's Library page), so they never disagree or fetch twice.
///
/// Each source loads on its own: if one request fails (or the server can't be
/// reached) the others still fill in, and [someFailed] says a retry is worth
/// offering. It reloads whenever [PlaylistsRevision] changes (a playlist was
/// created elsewhere) and on [refresh].
class LibraryData extends ChangeNotifier {
  LibraryData(this._revision) {
    _revision.addListener(refresh);
  }

  /// Albums are fetched A to Z in requests of this many...
  static const albumPageSize = 500;

  /// ...up to this many in all, so a huge library cannot keep loading forever.
  static const maxAlbums = 10000;

  final PlaylistsRevision _revision;

  SubsonicClient? _client;
  int _generation = 0;

  List<Playlist>? _playlists;
  List<Artist>? _artists;
  List<Album>? _albums;
  bool _loading = false;
  bool _someFailed = false;

  /// Null until the first successful load of that source.
  List<Playlist>? get playlists => _playlists;
  List<Artist>? get artists => _artists;
  List<Album>? get albums => _albums;

  bool get isLoading => _loading;

  /// True when the last load could not fetch every source.
  bool get someFailed => _someFailed;

  bool get hasAnyData =>
      _playlists != null || _artists != null || _albums != null;

  /// Called whenever the active server session changes.
  void attach(SubsonicClient? client) {
    if (identical(_client, client)) return;
    _client = client;
    _generation++;
    _playlists = null;
    _artists = null;
    _albums = null;
    _loading = false;
    _someFailed = false;
    // Attach runs during a provider update, so start the load afterwards:
    // loading notifies listeners, which must not happen mid-build.
    if (client != null) scheduleMicrotask(refresh);
  }

  /// Fetches every source again. Whatever loaded before stays in place while
  /// the new data is on its way, and is kept for a source that fails.
  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    final generation = ++_generation;
    _loading = true;
    _someFailed = false;
    notifyListeners();

    var failed = false;
    Future<T?> attempt<T>(Future<T> request) => request.then<T?>(
          (v) => v,
          onError: (Object _) {
            failed = true;
            return null;
          },
        );

    final results = await Future.wait<Object?>([
      attempt(client.getPlaylists()),
      attempt(client.getArtists()),
      attempt(_loadAlbums(client, generation, () => failed = true)),
    ]);
    // A newer refresh, or a different account, took over meanwhile.
    if (generation != _generation) return;

    _playlists = (results[0] as List<Playlist>?) ?? _playlists;
    _artists = (results[1] as List<Artist>?) ?? _artists;
    _albums = (results[2] as List<Album>?) ?? _albums;
    _someFailed = failed;
    _loading = false;
    notifyListeners();
  }

  /// Every album, A to Z, a page at a time. If a later page fails the albums
  /// already fetched are kept and [onPartial] is called, so the library shows
  /// most of what it has and offers a retry; if the first page fails the error
  /// is thrown like any other failed source.
  Future<List<Album>> _loadAlbums(
    SubsonicClient client,
    int generation,
    VoidCallback onPartial,
  ) async {
    final byId = <String, Album>{};
    var offset = 0;
    while (offset < maxAlbums) {
      final List<Album> page;
      try {
        page = await client.getAlbumList(
          AlbumListType.alphabetical,
          size: albumPageSize,
          offset: offset,
        );
      } on Object {
        if (offset == 0) rethrow;
        onPartial();
        break;
      }
      final before = byId.length;
      for (final a in page) {
        byId[a.id] = a;
      }
      // A short page is the last one; no new ids means the server ignored the
      // offset, and asking again would loop forever.
      if (page.length < albumPageSize || byId.length == before) break;
      // Superseded by a newer refresh: nobody will use these albums.
      if (generation != _generation) break;
      offset += albumPageSize;
    }
    return byId.values.toList();
  }

  @override
  void dispose() {
    _revision.removeListener(refresh);
    super.dispose();
  }
}
