// Local persistence for the on-device song index. Replaces a single
// hand-rolled JSON file with a real SQLite database (via drift), so syncing
// large libraries doesn't mean re-parsing/re-writing one giant string on
// every attach and every sync.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';

part 'app_database.g.dart';

/// One cached song per (owner, id). [owner] scopes rows to a server account
/// (`url|username`) so switching accounts never mixes libraries, without
/// needing a separate database file per account.
class SongEntries extends Table {
  TextColumn get owner => text()();
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get album => text().nullable()();
  TextColumn get albumId => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get coverArt => text().nullable()();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  IntColumn get track => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get suffix => text().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  TextColumn get genre => text().nullable()();
  IntColumn get bitRate => integer().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get userRating => integer().nullable()();
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get played => dateTime().nullable()();
  IntColumn get size => integer().nullable()();

  /// OpenSubsonic `replayGain` block, kept as opaque JSON since it is never
  /// queried on, only round-tripped.
  TextColumn get replayGainJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {owner, id};
}

/// One row per account, tracking when its song index was last fully synced.
class SyncStates extends Table {
  TextColumn get owner => text()();
  DateTimeColumn get lastSync => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {owner};
}

@DriftDatabase(tables: [SongEntries, SyncStates])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'noorify_library');

  /// Replaces the entire song index for [owner] with [songs] in one
  /// transaction (there is no delta/changed-since endpoint to sync against,
  /// so a full server page still means a full local replace).
  Future<void> replaceSongs(String owner, List<Song> songs) {
    return transaction(() async {
      await (delete(songEntries)..where((t) => t.owner.equals(owner))).go();
      await _insertBatch(owner, songs);
    });
  }

  /// Upserts a page of songs without touching rows outside this batch; used
  /// while a sync is still in progress so partial progress is never lost.
  Future<void> upsertSongs(String owner, List<Song> songs) =>
      _insertBatch(owner, songs);

  Future<void> _insertBatch(String owner, List<Song> songs) {
    if (songs.isEmpty) return Future.value();
    return batch((b) {
      b.insertAll(
        songEntries,
        [for (final s in songs) _toCompanion(owner, s)],
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<Song>> loadSongs(String owner) async {
    final rows =
        await (select(songEntries)..where((t) => t.owner.equals(owner))).get();
    return rows.map(_fromRow).toList();
  }

  Future<void> setLastSync(String owner, DateTime time) =>
      into(syncStates).insertOnConflictUpdate(
        SyncStatesCompanion.insert(owner: owner, lastSync: Value(time)),
      );

  Future<DateTime?> getLastSync(String owner) async {
    final row = await (select(syncStates)..where((t) => t.owner.equals(owner)))
        .getSingleOrNull();
    return row?.lastSync;
  }

  /// Drops all cached data for one account (e.g. on sign-out).
  Future<void> clearOwner(String owner) {
    return transaction(() async {
      await (delete(songEntries)..where((t) => t.owner.equals(owner))).go();
      await (delete(syncStates)..where((t) => t.owner.equals(owner))).go();
    });
  }

  SongEntriesCompanion _toCompanion(String owner, Song s) =>
      SongEntriesCompanion.insert(
        owner: owner,
        id: s.id,
        title: s.title,
        album: Value(s.album),
        albumId: Value(s.albumId),
        artist: Value(s.artist),
        artistId: Value(s.artistId),
        coverArt: Value(s.coverArt),
        duration: Value(s.duration),
        track: Value(s.track),
        year: Value(s.year),
        suffix: Value(s.suffix),
        starred: Value(s.starred),
        genre: Value(s.genre),
        bitRate: Value(s.bitRate),
        playCount: Value(s.playCount),
        userRating: Value(s.userRating),
        created: Value(s.created),
        played: Value(s.played),
        size: Value(s.size),
        replayGainJson: Value(
            s.replayGain == null ? null : jsonEncode(s.replayGain!.toJson())),
      );

  Song _fromRow(SongEntry row) => Song(
        id: row.id,
        title: row.title,
        album: row.album,
        albumId: row.albumId,
        artist: row.artist,
        artistId: row.artistId,
        coverArt: row.coverArt,
        duration: row.duration,
        track: row.track,
        year: row.year,
        suffix: row.suffix,
        starred: row.starred,
        genre: row.genre,
        bitRate: row.bitRate,
        playCount: row.playCount,
        userRating: row.userRating,
        created: row.created,
        played: row.played,
        size: row.size,
        replayGain: row.replayGainJson == null
            ? null
            : ReplayGainInfo.fromJson(
                jsonDecode(row.replayGainJson!) as Map<String, dynamic>),
      );
}
