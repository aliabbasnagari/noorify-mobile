import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class SubsonicException implements Exception {
  SubsonicException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

class ServerConfig {
  const ServerConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;
}

/// Album list orderings supported by `getAlbumList2`.
enum AlbumListType {
  newest('newest'),
  recent('recent'),
  frequent('frequent'),
  random('random'),
  alphabetical('alphabeticalByName'),
  starred('starred');

  const AlbumListType(this.apiValue);
  final String apiValue;

  /// The type whose Dart name is [name] (as used in page URLs), or null.
  static AlbumListType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// Minimal Subsonic / OpenSubsonic REST client using token authentication.
class SubsonicClient {
  SubsonicClient(this.config, {http.Client? httpClient, String? salt})
      : _http = httpClient ?? http.Client(),
        // One salt per client keeps cover-art / stream URLs stable so image
        // caches can be hit.
        _salt = salt ?? _randomSalt();

  static const apiVersion = '1.16.1';
  static const clientName = 'noorify';

  final ServerConfig config;
  final http.Client _http;
  final String _salt;

  static String _randomSalt() {
    final rnd = Random.secure();
    return List.generate(12, (_) => rnd.nextInt(16).toRadixString(16)).join();
  }

  Map<String, dynamic> _auth() => {
        'u': config.username,
        't': md5.convert(utf8.encode(config.password + _salt)).toString(),
        's': _salt,
        'v': apiVersion,
        'c': clientName,
        'f': 'json',
      };

  /// Builds a REST URL. Values may be strings or lists (repeated parameters).
  Uri buildUri(String method, [Map<String, Object?> params = const {}]) {
    final base = Uri.parse(config.url);
    final query = <String, dynamic>{..._auth()};
    params.forEach((key, value) {
      if (value == null) return;
      query[key] =
          value is Iterable ? value.map((e) => '$e').toList() : '$value';
    });
    final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(
      path: '$basePath/rest/$method.view',
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    final http.Response res;
    try {
      res = await _http
          .get(buildUri(method, params))
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw SubsonicException('Could not reach server: $e');
    }
    if (res.statusCode != 200) {
      throw SubsonicException('Server returned HTTP ${res.statusCode}');
    }
    final Map<String, dynamic> root;
    try {
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      root = body['subsonic-response'] as Map<String, dynamic>;
    } on Object {
      throw SubsonicException(
          'Unexpected response; is this a Subsonic server?');
    }
    if (root['status'] != 'ok') {
      final err = root['error'] as Map<String, dynamic>?;
      throw SubsonicException(
        (err?['message'] ?? 'Unknown server error') as String,
        code: err?['code'] as int?,
      );
    }
    return root;
  }

  static List<Map<String, dynamic>> _maps(Object? v) =>
      (v as List? ?? const []).cast<Map<String, dynamic>>();

  // --- URLs -----------------------------------------------------------------

  Uri streamUrl(String id, {int? maxBitRate}) =>
      buildUri('stream', {'id': id, 'maxBitRate': maxBitRate});

  Uri coverArtUrl(String id, {int size = 300}) =>
      buildUri('getCoverArt', {'id': id, 'size': size});

  /// Original, untranscoded file (used for offline downloads).
  Uri downloadUrl(String id) => buildUri('download', {'id': id});

  // --- Browsing -------------------------------------------------------------

  Future<void> ping() => _call('ping');

  Future<List<Artist>> getArtists() async {
    final root = await _call('getArtists');
    final indexes = _maps((root['artists'] as Map?)?['index']);
    return [
      for (final idx in indexes)
        for (final a in _maps(idx['artist'])) Artist.fromJson(a),
    ];
  }

  Future<Artist> getArtist(String id) async =>
      Artist.fromJson((await _call('getArtist', {'id': id}))['artist']);

  /// Biography, picture and similar artists for [artistId] (`getArtistInfo2`).
  /// What comes back depends on the server's metadata sources, so any part may
  /// be missing; an artist with nothing known gives an empty [ArtistInfo].
  Future<ArtistInfo> getArtistInfo(String artistId,
      {int similarCount = 12}) async {
    final root =
        await _call('getArtistInfo2', {'id': artistId, 'count': similarCount});
    return ArtistInfo.fromJson(
        (root['artistInfo2'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int size = 30,
    int offset = 0,
  }) async {
    final root = await _call('getAlbumList2', {
      'type': type.apiValue,
      'size': size,
      'offset': offset,
    });
    return _maps((root['albumList2'] as Map?)?['album'])
        .map(Album.fromJson)
        .toList();
  }

  Future<Album> getAlbum(String id) async =>
      Album.fromJson((await _call('getAlbum', {'id': id}))['album']);

  Future<SearchResults> search(String query, {int count = 20}) async {
    final root = await _call('search3', {
      'query': query,
      'artistCount': count,
      'albumCount': count,
      'songCount': count,
    });
    return SearchResults.fromJson(
      (root['searchResult3'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// Pages through every song using the "empty search3 query" convention
  /// (Navidrome, Gonic, Airsonic-Advanced). Some servers want `*` instead.
  Future<List<Song>> getSongsPage({
    required int offset,
    int size = 500,
    String query = '',
  }) async {
    final root = await _call('search3', {
      'query': query,
      'artistCount': 0,
      'albumCount': 0,
      'songCount': size,
      'songOffset': offset,
    });
    final result = (root['searchResult3'] as Map<String, dynamic>?) ?? const {};
    return _maps(result['song']).map(Song.fromJson).toList();
  }

  Future<List<Song>> getStarredSongs() async {
    final root = await _call('getStarred2');
    return _maps((root['starred2'] as Map?)?['song'])
        .map(Song.fromJson)
        .toList();
  }

  Future<List<Genre>> getGenres() async {
    final root = await _call('getGenres');
    return _maps((root['genres'] as Map?)?['genre'])
        .map(Genre.fromJson)
        .toList();
  }

  /// Songs similar to the given artist/album/song id (OpenSubsonic, ID3-based).
  Future<List<Song>> getSimilarSongs(String id, {int count = 50}) async {
    final root = await _call('getSimilarSongs2', {'id': id, 'count': count});
    return _maps((root['similarSongs2'] as Map?)?['song'])
        .map(Song.fromJson)
        .toList();
  }

  Future<List<Song>> getTopSongs(String artist, {int count = 50}) async {
    final root = await _call('getTopSongs', {'artist': artist, 'count': count});
    return _maps((root['topSongs'] as Map?)?['song'])
        .map(Song.fromJson)
        .toList();
  }

  // --- Bookmarks --------------------------------------------------------

  Future<List<Bookmark>> getBookmarks() async {
    final root = await _call('getBookmarks');
    return _maps((root['bookmarks'] as Map?)?['bookmark'])
        .map(Bookmark.fromJson)
        .toList();
  }

  Future<void> createBookmark(String id, {String? comment, int position = 0}) =>
      _call('createBookmark',
          {'id': id, 'comment': comment, 'position': position});

  Future<void> deleteBookmark(String id) => _call('deleteBookmark', {'id': id});

  // --- Lyrics -------------------------------------------------------------

  /// Structured (optionally time-synced) lyrics for a song (OpenSubsonic).
  Future<List<StructuredLyric>> getLyrics(String songId) async {
    final root = await _call('getLyricsBySongId', {'id': songId});
    return _maps((root['lyricsList'] as Map?)?['structuredLyrics'])
        .map(StructuredLyric.fromJson)
        .toList();
  }

  // --- Internet radio -------------------------------------------------------

  Future<List<RadioStation>> getInternetRadioStations() async {
    final root = await _call('getInternetRadioStations');
    return _maps(
            (root['internetRadioStations'] as Map?)?['internetRadioStation'])
        .map(RadioStation.fromJson)
        .toList();
  }

  Future<void> createInternetRadio(String name, String streamUrl,
          {String? homepageUrl}) =>
      _call('createInternetRadioStation', {
        'name': name,
        'streamUrl': streamUrl,
        'homepageUrl': homepageUrl,
      });

  Future<void> updateInternetRadio(String id, String name, String streamUrl,
          {String? homepageUrl}) =>
      _call('updateInternetRadioStation', {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'homepageUrl': homepageUrl,
      });

  Future<void> deleteInternetRadio(String id) =>
      _call('deleteInternetRadioStation', {'id': id});

  // --- Capability negotiation -------------------------------------------

  /// Maps extension name to the list of supported versions.
  Future<Map<String, List<int>>> getOpenSubsonicExtensions() async {
    final root = await _call('getOpenSubsonicExtensions');
    final list = (root['openSubsonicExtensions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return {
      for (final e in list)
        (e['name'] as String): (e['versions'] as List? ?? const [])
            .map((v) => (v as num).toInt())
            .toList(),
    };
  }

  // --- Playlists ------------------------------------------------------------

  Future<List<Playlist>> getPlaylists() async {
    final root = await _call('getPlaylists');
    return _maps((root['playlists'] as Map?)?['playlist'])
        .map(Playlist.fromJson)
        .toList();
  }

  Future<Playlist> getPlaylist(String id) async =>
      Playlist.fromJson((await _call('getPlaylist', {'id': id}))['playlist']);

  Future<void> createPlaylist(String name, {List<String> songIds = const []}) =>
      _call('createPlaylist', {'name': name, 'songId': songIds});

  Future<void> addToPlaylist(String playlistId, List<String> songIds) =>
      _call('updatePlaylist', {
        'playlistId': playlistId,
        'songIdToAdd': songIds,
      });

  Future<void> removeFromPlaylist(String playlistId, List<int> indexes) =>
      _call('updatePlaylist', {
        'playlistId': playlistId,
        'songIndexToRemove': indexes,
      });

  /// Puts the songs of a playlist in the order of [songIds], which must be
  /// all of its songs. There is no "move" call, so this replaces the contents
  /// in one request (`createPlaylist` with an existing `playlistId`), which
  /// cannot leave the playlist half-changed if it fails.
  Future<void> reorderPlaylist(String playlistId, List<String> songIds) =>
      _call('createPlaylist', {'playlistId': playlistId, 'songId': songIds});

  Future<void> renamePlaylist(String playlistId, String name) =>
      _call('updatePlaylist', {'playlistId': playlistId, 'name': name});

  Future<void> deletePlaylist(String id) => _call('deletePlaylist', {'id': id});

  // --- Annotation -----------------------------------------------------------

  Future<void> star(String id) => _call('star', {'id': id});

  Future<void> unstar(String id) => _call('unstar', {'id': id});

  /// Reports playback. `submission: false` only updates "now playing".
  Future<void> scrobble(String id, {bool submission = true}) =>
      _call('scrobble', {'id': id, 'submission': submission});
}
