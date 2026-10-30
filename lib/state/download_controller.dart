import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../subsonic/subsonic_client.dart';
import '../util/retry.dart';

/// A collection (album or playlist) kept available offline. Songs added to it
/// later are fetched automatically; mirrors Symfonium's `AutoOfflineCache`
/// {id, mediaType, title}.
class OfflineCollection {
  const OfflineCollection(
      {required this.type, required this.id, required this.title});

  /// `album` or `playlist`.
  final String type;
  final String id;
  final String title;

  String get key => '$type:$id';

  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'title': title};

  factory OfflineCollection.fromJson(Map<String, dynamic> j) =>
      OfflineCollection(
        type: j['type'] as String,
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
      );
}

class DownloadedSong {
  DownloadedSong({
    required this.song,
    required this.fileName,
    required this.bytes,
    Set<String>? sources,
  }) : sources = sources ?? {};

  final Song song;
  final String fileName;
  final int bytes;

  /// Why the file is kept: `manual` or a collection key. The file is deleted
  /// when no source remains.
  final Set<String> sources;

  Map<String, dynamic> toJson() => {
        'song': song.toJson(),
        'fileName': fileName,
        'bytes': bytes,
        'sources': sources.toList(),
      };

  factory DownloadedSong.fromJson(Map<String, dynamic> j) => DownloadedSong(
        song: Song.fromJson(j['song'] as Map<String, dynamic>),
        fileName: j['fileName'] as String,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        sources: {for (final s in (j['sources'] as List? ?? const [])) '$s'},
      );
}

class _Job {
  _Job(this.song, this.sources);

  final Song song;
  final Set<String> sources;
}

/// Downloads original files with the Subsonic `download` endpoint and tracks
/// them in a JSON index next to the files.
class DownloadController extends ChangeNotifier {
  /// [directoryProvider] returns the folder downloads live in (default: the
  /// app-support directory) and [httpClientFactory] builds the client used for
  /// each download attempt. Both exist so tests can use a temp directory and a
  /// mock HTTP client.
  DownloadController({
    Future<Directory> Function()? directoryProvider,
    http.Client Function()? httpClientFactory,
  })  : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? http.Client.new;

  static const manualSource = 'manual';
  static const _maxConcurrent = 2;

  final Future<Directory> Function() _directoryProvider;
  final http.Client Function() _httpClientFactory;

  SubsonicClient? _client;
  Directory? _dir;

  final Map<String, DownloadedSong> _done = {};
  final Map<String, OfflineCollection> _collections = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _failed = {};
  final List<_Job> _pending = [];
  final Map<String, _Job> _active = {};
  int _running = 0;

  // --- Queries --------------------------------------------------------------

  List<DownloadedSong> get downloaded => _done.values.toList();
  List<OfflineCollection> get collections => _collections.values.toList();
  int get usedBytes => _done.values.fold(0, (sum, d) => sum + d.bytes);
  int get activeCount => _running + _pending.length;
  Map<String, String> get failures => Map.unmodifiable(_failed);

  bool isDownloaded(String songId) => _done.containsKey(songId);

  /// 0..1 while downloading (or -1 when the size is unknown); null otherwise.
  double? progress(String songId) => _progress[songId];

  bool isCollectionOffline(String type, String id) =>
      _collections.containsKey('$type:$id');

  String? localPath(String songId) {
    final d = _done[songId];
    final dir = _dir;
    return (d == null || dir == null) ? null : '${dir.path}/${d.fileName}';
  }

  // --- Lifecycle ------------------------------------------------------------

  void attach(SubsonicClient? client) {
    if (identical(_client, client)) return;
    _client = client;
    if (client != null) unawaited(_load());
  }

  Future<Directory> _ensureDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await _directoryProvider();
    final dir = Directory('${base.path}/downloads');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  File _indexFile(Directory dir) => File('${dir.path}/index.json');

  Future<void> _load() async {
    try {
      final dir = await _ensureDir();
      final file = _indexFile(dir);
      if (!await file.exists()) return;
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _done.clear();
      _collections.clear();
      for (final d in (j['songs'] as List? ?? const [])) {
        final item = DownloadedSong.fromJson(d as Map<String, dynamic>);
        // Drop entries whose file vanished (e.g. cleared app storage).
        if (File('${dir.path}/${item.fileName}').existsSync()) {
          _done[item.song.id] = item;
        }
      }
      for (final c in (j['collections'] as List? ?? const [])) {
        final col = OfflineCollection.fromJson(c as Map<String, dynamic>);
        _collections[col.key] = col;
      }
      notifyListeners();
      unawaited(refreshCollections());
    } on Object {
      // Unreadable index: start empty rather than crash.
    }
  }

  /// Tail of the chain of index writes; see [_save].
  Future<void> _saving = Future.value();

  /// Persists the index. Writes run one at a time, because two downloads
  /// finishing together would otherwise write the same file concurrently and
  /// interleave into invalid JSON (which [_load] then discards, forgetting
  /// every download). The contents are read when each write runs, so the last
  /// one always reflects the latest state.
  Future<void> _save() {
    final next = _saving.then((_) => _writeIndex());
    _saving = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  /// Writes to a temp file and renames it over the index, so a crash mid-write
  /// can't leave a truncated index behind.
  Future<void> _writeIndex() async {
    final dir = await _ensureDir();
    final file = _indexFile(dir);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode({
      'songs': [for (final d in _done.values) d.toJson()],
      'collections': [for (final c in _collections.values) c.toJson()],
    }));
    await temp.rename(file.path);
  }

  // --- Downloading ----------------------------------------------------------

  Future<void> downloadSongs(List<Song> songs,
      {String source = manualSource}) async {
    var changed = false;
    for (final song in songs) {
      final existing = _done[song.id];
      if (existing != null) {
        changed |= existing.sources.add(source);
        continue;
      }
      // Already queued or in flight: just record the extra reason to keep it.
      final inFlight = _active[song.id] ??
          _pending.where((j) => j.song.id == song.id).firstOrNull;
      if (inFlight != null) {
        inFlight.sources.add(source);
      } else {
        _failed.remove(song.id);
        _pending.add(_Job(song, {source}));
      }
    }
    notifyListeners();
    if (changed) await _save();
    _pump();
  }

  void _pump() {
    while (_running < _maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _active[job.song.id] = job;
      _running++;
      unawaited(_run(job).whenComplete(() {
        _running--;
        notifyListeners();
        _pump();
      }));
    }
  }

  Future<void> _run(_Job job) async {
    final client = _client;
    if (client == null) return;
    final song = job.song;
    final dir = await _ensureDir();
    final fileName = '${song.id}.${song.suffix ?? 'audio'}'
        .replaceAll(RegExp(r'[^\w.\-]'), '_');
    final part = File('${dir.path}/$fileName.part');

    _progress[song.id] = -1;
    notifyListeners();
    try {
      // A flaky mobile connection is the common failure mode here, so retry
      // the whole attempt (there is no resume support) before giving up.
      final received =
          await withRetry(() => _attemptDownload(client, song, part));
      if (!identical(_active[song.id], job)) {
        // Cancelled by clearAll() while in flight: discard the result.
        if (await part.exists()) await part.delete();
        return;
      }
      await part.rename('${dir.path}/$fileName');
      _done[song.id] = DownloadedSong(
        song: song,
        fileName: fileName,
        bytes: received,
        sources: job.sources,
      );
      _failed.remove(song.id);
      await _save();
    } on Object catch (e) {
      _failed[song.id] = '$e';
      if (await part.exists()) await part.delete();
    } finally {
      _progress.remove(song.id);
      // A newer job for the same song may have replaced this one after a
      // clearAll(); only remove our own entry.
      if (identical(_active[song.id], job)) _active.remove(song.id);
    }
  }

  /// One attempt at downloading [song] into [part]. Returns the byte count.
  Future<int> _attemptDownload(
      SubsonicClient client, Song song, File part) async {
    final httpClient = _httpClientFactory();
    try {
      _progress[song.id] = -1;
      final response = await httpClient
          .send(http.Request('GET', client.downloadUrl(song.id)));
      if (response.statusCode != 200) {
        throw SubsonicException('Server returned HTTP ${response.statusCode}');
      }
      // Subsonic reports errors (bad id, no permission) as a 200 with a
      // JSON/XML body instead of audio.
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('json') ||
          contentType.contains('xml') ||
          contentType.contains('text/')) {
        throw SubsonicException('Server refused the download');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            // Throttle UI updates to roughly 1% steps.
            final p = received / total;
            if (p - (_progress[song.id] ?? 0) > 0.01) {
              _progress[song.id] = p;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }
      if (received == 0) {
        throw SubsonicException('Server returned an empty file');
      }
      return received;
    } finally {
      httpClient.close();
    }
  }

  // --- Removal --------------------------------------------------------------

  /// Deletes the file regardless of what asked for it. Songs that belong to an
  /// offline collection are fetched again on the next refresh.
  Future<void> removeSong(String songId) async {
    final d = _done.remove(songId);
    _pending.removeWhere((j) => j.song.id == songId);
    notifyListeners();
    if (d == null) return;
    await _deleteFile(d);
    await _save();
  }

  /// Removes every download and offline collection. Downloads still in flight
  /// are abandoned: their result is discarded when they finish.
  Future<void> clearAll() async {
    final all = _done.values.toList();
    _done.clear();
    _collections.clear();
    _pending.clear();
    _active.clear();
    _failed.clear();
    notifyListeners();
    for (final d in all) {
      await _deleteFile(d);
    }
    await _save();
  }

  Future<void> _deleteFile(DownloadedSong d) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}/${d.fileName}');
    if (await file.exists()) await file.delete();
  }

  // --- Offline collections --------------------------------------------------

  Future<void> setCollectionOffline(
      OfflineCollection collection, List<Song> songs) async {
    _collections[collection.key] = collection;
    notifyListeners();
    await _save();
    await downloadSongs(songs, source: collection.key);
  }

  Future<void> removeCollection(String key) async {
    if (_collections.remove(key) == null) return;
    _pending
        .removeWhere((j) => j.sources.length == 1 && j.sources.contains(key));
    for (final j in _pending) {
      j.sources.remove(key);
    }
    await _dropSource(key, keep: const {});
    notifyListeners();
    await _save();
  }

  /// Removes [source] from songs not in [keep]; deletes songs left without
  /// any source.
  Future<void> _dropSource(String source, {required Set<String> keep}) async {
    for (final d in _done.values.toList()) {
      if (keep.contains(d.song.id) || !d.sources.remove(source)) continue;
      if (d.sources.isEmpty) {
        _done.remove(d.song.id);
        await _deleteFile(d);
      }
    }
  }

  /// Re-syncs every offline collection with the server: new songs are
  /// downloaded, songs removed from the collection are cleaned up.
  Future<void> refreshCollections() async {
    final client = _client;
    if (client == null) return;
    for (final c in collections) {
      try {
        final songs = c.type == 'album'
            ? (await client.getAlbum(c.id)).songs
            : (await client.getPlaylist(c.id)).songs;
        // Removed (or everything cleared) while the request was in flight.
        if (!_collections.containsKey(c.key)) continue;
        await _dropSource(c.key, keep: {for (final s in songs) s.id});
        await downloadSongs(songs, source: c.key);
      } on Object {
        // Offline or the collection was deleted server-side: keep what we have.
      }
    }
    notifyListeners();
    await _save();
  }
}
