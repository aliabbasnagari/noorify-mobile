// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SongEntriesTable extends SongEntries
    with TableInfo<$SongEntriesTable, SongEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumIdMeta =
      const VerificationMeta('albumId');
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
      'album_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artistIdMeta =
      const VerificationMeta('artistId');
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
      'artist_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coverArtMeta =
      const VerificationMeta('coverArt');
  @override
  late final GeneratedColumn<String> coverArt = GeneratedColumn<String>(
      'cover_art', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<int> track = GeneratedColumn<int>(
      'track', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
      'suffix', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _starredMeta =
      const VerificationMeta('starred');
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
      'starred', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("starred" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bitRateMeta =
      const VerificationMeta('bitRate');
  @override
  late final GeneratedColumn<int> bitRate = GeneratedColumn<int>(
      'bit_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _playCountMeta =
      const VerificationMeta('playCount');
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
      'play_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _userRatingMeta =
      const VerificationMeta('userRating');
  @override
  late final GeneratedColumn<int> userRating = GeneratedColumn<int>(
      'user_rating', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdMeta =
      const VerificationMeta('created');
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
      'created', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _playedMeta = const VerificationMeta('played');
  @override
  late final GeneratedColumn<DateTime> played = GeneratedColumn<DateTime>(
      'played', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _replayGainJsonMeta =
      const VerificationMeta('replayGainJson');
  @override
  late final GeneratedColumn<String> replayGainJson = GeneratedColumn<String>(
      'replay_gain_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        owner,
        id,
        title,
        album,
        albumId,
        artist,
        artistId,
        coverArt,
        duration,
        track,
        year,
        suffix,
        starred,
        genre,
        bitRate,
        playCount,
        userRating,
        created,
        played,
        size,
        replayGainJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SongEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    if (data.containsKey('album_id')) {
      context.handle(_albumIdMeta,
          albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta));
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('artist_id')) {
      context.handle(_artistIdMeta,
          artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta));
    }
    if (data.containsKey('cover_art')) {
      context.handle(_coverArtMeta,
          coverArt.isAcceptableOrUnknown(data['cover_art']!, _coverArtMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('track')) {
      context.handle(
          _trackMeta, track.isAcceptableOrUnknown(data['track']!, _trackMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('suffix')) {
      context.handle(_suffixMeta,
          suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta));
    }
    if (data.containsKey('starred')) {
      context.handle(_starredMeta,
          starred.isAcceptableOrUnknown(data['starred']!, _starredMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('bit_rate')) {
      context.handle(_bitRateMeta,
          bitRate.isAcceptableOrUnknown(data['bit_rate']!, _bitRateMeta));
    }
    if (data.containsKey('play_count')) {
      context.handle(_playCountMeta,
          playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta));
    }
    if (data.containsKey('user_rating')) {
      context.handle(
          _userRatingMeta,
          userRating.isAcceptableOrUnknown(
              data['user_rating']!, _userRatingMeta));
    }
    if (data.containsKey('created')) {
      context.handle(_createdMeta,
          created.isAcceptableOrUnknown(data['created']!, _createdMeta));
    }
    if (data.containsKey('played')) {
      context.handle(_playedMeta,
          played.isAcceptableOrUnknown(data['played']!, _playedMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('replay_gain_json')) {
      context.handle(
          _replayGainJsonMeta,
          replayGainJson.isAcceptableOrUnknown(
              data['replay_gain_json']!, _replayGainJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, id};
  @override
  SongEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongEntry(
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
      albumId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_id']),
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      artistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_id']),
      coverArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_art']),
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      track: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}track']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year']),
      suffix: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suffix']),
      starred: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}starred'])!,
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      bitRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bit_rate']),
      playCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}play_count'])!,
      userRating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_rating']),
      created: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created']),
      played: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}played']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size']),
      replayGainJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}replay_gain_json']),
    );
  }

  @override
  $SongEntriesTable createAlias(String alias) {
    return $SongEntriesTable(attachedDatabase, alias);
  }
}

class SongEntry extends DataClass implements Insertable<SongEntry> {
  final String owner;
  final String id;
  final String title;
  final String? album;
  final String? albumId;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int duration;
  final int? track;
  final int? year;
  final String? suffix;
  final bool starred;
  final String? genre;
  final int? bitRate;
  final int playCount;
  final int? userRating;
  final DateTime? created;
  final DateTime? played;
  final int? size;

  /// OpenSubsonic `replayGain` block, kept as opaque JSON since it is never
  /// queried on, only round-tripped.
  final String? replayGainJson;
  const SongEntry(
      {required this.owner,
      required this.id,
      required this.title,
      this.album,
      this.albumId,
      this.artist,
      this.artistId,
      this.coverArt,
      required this.duration,
      this.track,
      this.year,
      this.suffix,
      required this.starred,
      this.genre,
      this.bitRate,
      required this.playCount,
      this.userRating,
      this.created,
      this.played,
      this.size,
      this.replayGainJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    if (!nullToAbsent || coverArt != null) {
      map['cover_art'] = Variable<String>(coverArt);
    }
    map['duration'] = Variable<int>(duration);
    if (!nullToAbsent || track != null) {
      map['track'] = Variable<int>(track);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || bitRate != null) {
      map['bit_rate'] = Variable<int>(bitRate);
    }
    map['play_count'] = Variable<int>(playCount);
    if (!nullToAbsent || userRating != null) {
      map['user_rating'] = Variable<int>(userRating);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<DateTime>(created);
    }
    if (!nullToAbsent || played != null) {
      map['played'] = Variable<DateTime>(played);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || replayGainJson != null) {
      map['replay_gain_json'] = Variable<String>(replayGainJson);
    }
    return map;
  }

  SongEntriesCompanion toCompanion(bool nullToAbsent) {
    return SongEntriesCompanion(
      owner: Value(owner),
      id: Value(id),
      title: Value(title),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      coverArt: coverArt == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArt),
      duration: Value(duration),
      track:
          track == null && nullToAbsent ? const Value.absent() : Value(track),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      suffix:
          suffix == null && nullToAbsent ? const Value.absent() : Value(suffix),
      starred: Value(starred),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      bitRate: bitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitRate),
      playCount: Value(playCount),
      userRating: userRating == null && nullToAbsent
          ? const Value.absent()
          : Value(userRating),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      played:
          played == null && nullToAbsent ? const Value.absent() : Value(played),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      replayGainJson: replayGainJson == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainJson),
    );
  }

  factory SongEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongEntry(
      owner: serializer.fromJson<String>(json['owner']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      album: serializer.fromJson<String?>(json['album']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artist: serializer.fromJson<String?>(json['artist']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      coverArt: serializer.fromJson<String?>(json['coverArt']),
      duration: serializer.fromJson<int>(json['duration']),
      track: serializer.fromJson<int?>(json['track']),
      year: serializer.fromJson<int?>(json['year']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      starred: serializer.fromJson<bool>(json['starred']),
      genre: serializer.fromJson<String?>(json['genre']),
      bitRate: serializer.fromJson<int?>(json['bitRate']),
      playCount: serializer.fromJson<int>(json['playCount']),
      userRating: serializer.fromJson<int?>(json['userRating']),
      created: serializer.fromJson<DateTime?>(json['created']),
      played: serializer.fromJson<DateTime?>(json['played']),
      size: serializer.fromJson<int?>(json['size']),
      replayGainJson: serializer.fromJson<String?>(json['replayGainJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'album': serializer.toJson<String?>(album),
      'albumId': serializer.toJson<String?>(albumId),
      'artist': serializer.toJson<String?>(artist),
      'artistId': serializer.toJson<String?>(artistId),
      'coverArt': serializer.toJson<String?>(coverArt),
      'duration': serializer.toJson<int>(duration),
      'track': serializer.toJson<int?>(track),
      'year': serializer.toJson<int?>(year),
      'suffix': serializer.toJson<String?>(suffix),
      'starred': serializer.toJson<bool>(starred),
      'genre': serializer.toJson<String?>(genre),
      'bitRate': serializer.toJson<int?>(bitRate),
      'playCount': serializer.toJson<int>(playCount),
      'userRating': serializer.toJson<int?>(userRating),
      'created': serializer.toJson<DateTime?>(created),
      'played': serializer.toJson<DateTime?>(played),
      'size': serializer.toJson<int?>(size),
      'replayGainJson': serializer.toJson<String?>(replayGainJson),
    };
  }

  SongEntry copyWith(
          {String? owner,
          String? id,
          String? title,
          Value<String?> album = const Value.absent(),
          Value<String?> albumId = const Value.absent(),
          Value<String?> artist = const Value.absent(),
          Value<String?> artistId = const Value.absent(),
          Value<String?> coverArt = const Value.absent(),
          int? duration,
          Value<int?> track = const Value.absent(),
          Value<int?> year = const Value.absent(),
          Value<String?> suffix = const Value.absent(),
          bool? starred,
          Value<String?> genre = const Value.absent(),
          Value<int?> bitRate = const Value.absent(),
          int? playCount,
          Value<int?> userRating = const Value.absent(),
          Value<DateTime?> created = const Value.absent(),
          Value<DateTime?> played = const Value.absent(),
          Value<int?> size = const Value.absent(),
          Value<String?> replayGainJson = const Value.absent()}) =>
      SongEntry(
        owner: owner ?? this.owner,
        id: id ?? this.id,
        title: title ?? this.title,
        album: album.present ? album.value : this.album,
        albumId: albumId.present ? albumId.value : this.albumId,
        artist: artist.present ? artist.value : this.artist,
        artistId: artistId.present ? artistId.value : this.artistId,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        duration: duration ?? this.duration,
        track: track.present ? track.value : this.track,
        year: year.present ? year.value : this.year,
        suffix: suffix.present ? suffix.value : this.suffix,
        starred: starred ?? this.starred,
        genre: genre.present ? genre.value : this.genre,
        bitRate: bitRate.present ? bitRate.value : this.bitRate,
        playCount: playCount ?? this.playCount,
        userRating: userRating.present ? userRating.value : this.userRating,
        created: created.present ? created.value : this.created,
        played: played.present ? played.value : this.played,
        size: size.present ? size.value : this.size,
        replayGainJson:
            replayGainJson.present ? replayGainJson.value : this.replayGainJson,
      );
  SongEntry copyWithCompanion(SongEntriesCompanion data) {
    return SongEntry(
      owner: data.owner.present ? data.owner.value : this.owner,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      album: data.album.present ? data.album.value : this.album,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artist: data.artist.present ? data.artist.value : this.artist,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      duration: data.duration.present ? data.duration.value : this.duration,
      track: data.track.present ? data.track.value : this.track,
      year: data.year.present ? data.year.value : this.year,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      starred: data.starred.present ? data.starred.value : this.starred,
      genre: data.genre.present ? data.genre.value : this.genre,
      bitRate: data.bitRate.present ? data.bitRate.value : this.bitRate,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      userRating:
          data.userRating.present ? data.userRating.value : this.userRating,
      created: data.created.present ? data.created.value : this.created,
      played: data.played.present ? data.played.value : this.played,
      size: data.size.present ? data.size.value : this.size,
      replayGainJson: data.replayGainJson.present
          ? data.replayGainJson.value
          : this.replayGainJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongEntry(')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artist: $artist, ')
          ..write('artistId: $artistId, ')
          ..write('coverArt: $coverArt, ')
          ..write('duration: $duration, ')
          ..write('track: $track, ')
          ..write('year: $year, ')
          ..write('suffix: $suffix, ')
          ..write('starred: $starred, ')
          ..write('genre: $genre, ')
          ..write('bitRate: $bitRate, ')
          ..write('playCount: $playCount, ')
          ..write('userRating: $userRating, ')
          ..write('created: $created, ')
          ..write('played: $played, ')
          ..write('size: $size, ')
          ..write('replayGainJson: $replayGainJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        owner,
        id,
        title,
        album,
        albumId,
        artist,
        artistId,
        coverArt,
        duration,
        track,
        year,
        suffix,
        starred,
        genre,
        bitRate,
        playCount,
        userRating,
        created,
        played,
        size,
        replayGainJson
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongEntry &&
          other.owner == this.owner &&
          other.id == this.id &&
          other.title == this.title &&
          other.album == this.album &&
          other.albumId == this.albumId &&
          other.artist == this.artist &&
          other.artistId == this.artistId &&
          other.coverArt == this.coverArt &&
          other.duration == this.duration &&
          other.track == this.track &&
          other.year == this.year &&
          other.suffix == this.suffix &&
          other.starred == this.starred &&
          other.genre == this.genre &&
          other.bitRate == this.bitRate &&
          other.playCount == this.playCount &&
          other.userRating == this.userRating &&
          other.created == this.created &&
          other.played == this.played &&
          other.size == this.size &&
          other.replayGainJson == this.replayGainJson);
}

class SongEntriesCompanion extends UpdateCompanion<SongEntry> {
  final Value<String> owner;
  final Value<String> id;
  final Value<String> title;
  final Value<String?> album;
  final Value<String?> albumId;
  final Value<String?> artist;
  final Value<String?> artistId;
  final Value<String?> coverArt;
  final Value<int> duration;
  final Value<int?> track;
  final Value<int?> year;
  final Value<String?> suffix;
  final Value<bool> starred;
  final Value<String?> genre;
  final Value<int?> bitRate;
  final Value<int> playCount;
  final Value<int?> userRating;
  final Value<DateTime?> created;
  final Value<DateTime?> played;
  final Value<int?> size;
  final Value<String?> replayGainJson;
  final Value<int> rowid;
  const SongEntriesCompanion({
    this.owner = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artist = const Value.absent(),
    this.artistId = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.duration = const Value.absent(),
    this.track = const Value.absent(),
    this.year = const Value.absent(),
    this.suffix = const Value.absent(),
    this.starred = const Value.absent(),
    this.genre = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.playCount = const Value.absent(),
    this.userRating = const Value.absent(),
    this.created = const Value.absent(),
    this.played = const Value.absent(),
    this.size = const Value.absent(),
    this.replayGainJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongEntriesCompanion.insert({
    required String owner,
    required String id,
    required String title,
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artist = const Value.absent(),
    this.artistId = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.duration = const Value.absent(),
    this.track = const Value.absent(),
    this.year = const Value.absent(),
    this.suffix = const Value.absent(),
    this.starred = const Value.absent(),
    this.genre = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.playCount = const Value.absent(),
    this.userRating = const Value.absent(),
    this.created = const Value.absent(),
    this.played = const Value.absent(),
    this.size = const Value.absent(),
    this.replayGainJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : owner = Value(owner),
        id = Value(id),
        title = Value(title);
  static Insertable<SongEntry> custom({
    Expression<String>? owner,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? album,
    Expression<String>? albumId,
    Expression<String>? artist,
    Expression<String>? artistId,
    Expression<String>? coverArt,
    Expression<int>? duration,
    Expression<int>? track,
    Expression<int>? year,
    Expression<String>? suffix,
    Expression<bool>? starred,
    Expression<String>? genre,
    Expression<int>? bitRate,
    Expression<int>? playCount,
    Expression<int>? userRating,
    Expression<DateTime>? created,
    Expression<DateTime>? played,
    Expression<int>? size,
    Expression<String>? replayGainJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (album != null) 'album': album,
      if (albumId != null) 'album_id': albumId,
      if (artist != null) 'artist': artist,
      if (artistId != null) 'artist_id': artistId,
      if (coverArt != null) 'cover_art': coverArt,
      if (duration != null) 'duration': duration,
      if (track != null) 'track': track,
      if (year != null) 'year': year,
      if (suffix != null) 'suffix': suffix,
      if (starred != null) 'starred': starred,
      if (genre != null) 'genre': genre,
      if (bitRate != null) 'bit_rate': bitRate,
      if (playCount != null) 'play_count': playCount,
      if (userRating != null) 'user_rating': userRating,
      if (created != null) 'created': created,
      if (played != null) 'played': played,
      if (size != null) 'size': size,
      if (replayGainJson != null) 'replay_gain_json': replayGainJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongEntriesCompanion copyWith(
      {Value<String>? owner,
      Value<String>? id,
      Value<String>? title,
      Value<String?>? album,
      Value<String?>? albumId,
      Value<String?>? artist,
      Value<String?>? artistId,
      Value<String?>? coverArt,
      Value<int>? duration,
      Value<int?>? track,
      Value<int?>? year,
      Value<String?>? suffix,
      Value<bool>? starred,
      Value<String?>? genre,
      Value<int?>? bitRate,
      Value<int>? playCount,
      Value<int?>? userRating,
      Value<DateTime?>? created,
      Value<DateTime?>? played,
      Value<int?>? size,
      Value<String?>? replayGainJson,
      Value<int>? rowid}) {
    return SongEntriesCompanion(
      owner: owner ?? this.owner,
      id: id ?? this.id,
      title: title ?? this.title,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      coverArt: coverArt ?? this.coverArt,
      duration: duration ?? this.duration,
      track: track ?? this.track,
      year: year ?? this.year,
      suffix: suffix ?? this.suffix,
      starred: starred ?? this.starred,
      genre: genre ?? this.genre,
      bitRate: bitRate ?? this.bitRate,
      playCount: playCount ?? this.playCount,
      userRating: userRating ?? this.userRating,
      created: created ?? this.created,
      played: played ?? this.played,
      size: size ?? this.size,
      replayGainJson: replayGainJson ?? this.replayGainJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (coverArt.present) {
      map['cover_art'] = Variable<String>(coverArt.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (track.present) {
      map['track'] = Variable<int>(track.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (bitRate.present) {
      map['bit_rate'] = Variable<int>(bitRate.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (userRating.present) {
      map['user_rating'] = Variable<int>(userRating.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (played.present) {
      map['played'] = Variable<DateTime>(played.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (replayGainJson.present) {
      map['replay_gain_json'] = Variable<String>(replayGainJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongEntriesCompanion(')
          ..write('owner: $owner, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artist: $artist, ')
          ..write('artistId: $artistId, ')
          ..write('coverArt: $coverArt, ')
          ..write('duration: $duration, ')
          ..write('track: $track, ')
          ..write('year: $year, ')
          ..write('suffix: $suffix, ')
          ..write('starred: $starred, ')
          ..write('genre: $genre, ')
          ..write('bitRate: $bitRate, ')
          ..write('playCount: $playCount, ')
          ..write('userRating: $userRating, ')
          ..write('created: $created, ')
          ..write('played: $played, ')
          ..write('size: $size, ')
          ..write('replayGainJson: $replayGainJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncMeta =
      const VerificationMeta('lastSync');
  @override
  late final GeneratedColumn<DateTime> lastSync = GeneratedColumn<DateTime>(
      'last_sync', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [owner, lastSync];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(Insertable<SyncState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('last_sync')) {
      context.handle(_lastSyncMeta,
          lastSync.isAcceptableOrUnknown(data['last_sync']!, _lastSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      lastSync: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync']),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String owner;
  final DateTime? lastSync;
  const SyncState({required this.owner, this.lastSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    if (!nullToAbsent || lastSync != null) {
      map['last_sync'] = Variable<DateTime>(lastSync);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      owner: Value(owner),
      lastSync: lastSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSync),
    );
  }

  factory SyncState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      owner: serializer.fromJson<String>(json['owner']),
      lastSync: serializer.fromJson<DateTime?>(json['lastSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'lastSync': serializer.toJson<DateTime?>(lastSync),
    };
  }

  SyncState copyWith(
          {String? owner, Value<DateTime?> lastSync = const Value.absent()}) =>
      SyncState(
        owner: owner ?? this.owner,
        lastSync: lastSync.present ? lastSync.value : this.lastSync,
      );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      owner: data.owner.present ? data.owner.value : this.owner,
      lastSync: data.lastSync.present ? data.lastSync.value : this.lastSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('owner: $owner, ')
          ..write('lastSync: $lastSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(owner, lastSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.owner == this.owner &&
          other.lastSync == this.lastSync);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> owner;
  final Value<DateTime?> lastSync;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.owner = const Value.absent(),
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String owner,
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : owner = Value(owner);
  static Insertable<SyncState> custom({
    Expression<String>? owner,
    Expression<DateTime>? lastSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (lastSync != null) 'last_sync': lastSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith(
      {Value<String>? owner, Value<DateTime?>? lastSync, Value<int>? rowid}) {
    return SyncStatesCompanion(
      owner: owner ?? this.owner,
      lastSync: lastSync ?? this.lastSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (lastSync.present) {
      map['last_sync'] = Variable<DateTime>(lastSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('owner: $owner, ')
          ..write('lastSync: $lastSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongEntriesTable songEntries = $SongEntriesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [songEntries, syncStates];
}

typedef $$SongEntriesTableCreateCompanionBuilder = SongEntriesCompanion
    Function({
  required String owner,
  required String id,
  required String title,
  Value<String?> album,
  Value<String?> albumId,
  Value<String?> artist,
  Value<String?> artistId,
  Value<String?> coverArt,
  Value<int> duration,
  Value<int?> track,
  Value<int?> year,
  Value<String?> suffix,
  Value<bool> starred,
  Value<String?> genre,
  Value<int?> bitRate,
  Value<int> playCount,
  Value<int?> userRating,
  Value<DateTime?> created,
  Value<DateTime?> played,
  Value<int?> size,
  Value<String?> replayGainJson,
  Value<int> rowid,
});
typedef $$SongEntriesTableUpdateCompanionBuilder = SongEntriesCompanion
    Function({
  Value<String> owner,
  Value<String> id,
  Value<String> title,
  Value<String?> album,
  Value<String?> albumId,
  Value<String?> artist,
  Value<String?> artistId,
  Value<String?> coverArt,
  Value<int> duration,
  Value<int?> track,
  Value<int?> year,
  Value<String?> suffix,
  Value<bool> starred,
  Value<String?> genre,
  Value<int?> bitRate,
  Value<int> playCount,
  Value<int?> userRating,
  Value<DateTime?> created,
  Value<DateTime?> played,
  Value<int?> size,
  Value<String?> replayGainJson,
  Value<int> rowid,
});

class $$SongEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SongEntriesTable> {
  $$SongEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get track => $composableBuilder(
      column: $table.track, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userRating => $composableBuilder(
      column: $table.userRating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get created => $composableBuilder(
      column: $table.created, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get played => $composableBuilder(
      column: $table.played, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replayGainJson => $composableBuilder(
      column: $table.replayGainJson,
      builder: (column) => ColumnFilters(column));
}

class $$SongEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SongEntriesTable> {
  $$SongEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get track => $composableBuilder(
      column: $table.track, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userRating => $composableBuilder(
      column: $table.userRating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get created => $composableBuilder(
      column: $table.created, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get played => $composableBuilder(
      column: $table.played, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replayGainJson => $composableBuilder(
      column: $table.replayGainJson,
      builder: (column) => ColumnOrderings(column));
}

class $$SongEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongEntriesTable> {
  $$SongEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get coverArt =>
      $composableBuilder(column: $table.coverArt, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get bitRate =>
      $composableBuilder(column: $table.bitRate, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get userRating => $composableBuilder(
      column: $table.userRating, builder: (column) => column);

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<DateTime> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get replayGainJson => $composableBuilder(
      column: $table.replayGainJson, builder: (column) => column);
}

class $$SongEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SongEntriesTable,
    SongEntry,
    $$SongEntriesTableFilterComposer,
    $$SongEntriesTableOrderingComposer,
    $$SongEntriesTableAnnotationComposer,
    $$SongEntriesTableCreateCompanionBuilder,
    $$SongEntriesTableUpdateCompanionBuilder,
    (SongEntry, BaseReferences<_$AppDatabase, $SongEntriesTable, SongEntry>),
    SongEntry,
    PrefetchHooks Function()> {
  $$SongEntriesTableTableManager(_$AppDatabase db, $SongEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> owner = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int?> track = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<int> playCount = const Value.absent(),
            Value<int?> userRating = const Value.absent(),
            Value<DateTime?> created = const Value.absent(),
            Value<DateTime?> played = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<String?> replayGainJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SongEntriesCompanion(
            owner: owner,
            id: id,
            title: title,
            album: album,
            albumId: albumId,
            artist: artist,
            artistId: artistId,
            coverArt: coverArt,
            duration: duration,
            track: track,
            year: year,
            suffix: suffix,
            starred: starred,
            genre: genre,
            bitRate: bitRate,
            playCount: playCount,
            userRating: userRating,
            created: created,
            played: played,
            size: size,
            replayGainJson: replayGainJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String owner,
            required String id,
            required String title,
            Value<String?> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int?> track = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<int> playCount = const Value.absent(),
            Value<int?> userRating = const Value.absent(),
            Value<DateTime?> created = const Value.absent(),
            Value<DateTime?> played = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<String?> replayGainJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SongEntriesCompanion.insert(
            owner: owner,
            id: id,
            title: title,
            album: album,
            albumId: albumId,
            artist: artist,
            artistId: artistId,
            coverArt: coverArt,
            duration: duration,
            track: track,
            year: year,
            suffix: suffix,
            starred: starred,
            genre: genre,
            bitRate: bitRate,
            playCount: playCount,
            userRating: userRating,
            created: created,
            played: played,
            size: size,
            replayGainJson: replayGainJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SongEntriesTable, SongEntry>(table),
                    BaseReferences<_$AppDatabase, $SongEntriesTable, SongEntry>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SongEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SongEntriesTable,
    SongEntry,
    $$SongEntriesTableFilterComposer,
    $$SongEntriesTableOrderingComposer,
    $$SongEntriesTableAnnotationComposer,
    $$SongEntriesTableCreateCompanionBuilder,
    $$SongEntriesTableUpdateCompanionBuilder,
    (SongEntry, BaseReferences<_$AppDatabase, $SongEntriesTable, SongEntry>),
    SongEntry,
    PrefetchHooks Function()>;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String owner,
  Value<DateTime?> lastSync,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> owner,
  Value<DateTime?> lastSync,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnFilters(column));
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSync => $composableBuilder(
      column: $table.lastSync, builder: (column) => ColumnOrderings(column));
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSync =>
      $composableBuilder(column: $table.lastSync, builder: (column) => column);
}

class $$SyncStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()> {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> owner = const Value.absent(),
            Value<DateTime?> lastSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion(
            owner: owner,
            lastSync: lastSync,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String owner,
            Value<DateTime?> lastSync = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion.insert(
            owner: owner,
            lastSync: lastSync,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncStatesTable, SyncState>(table),
                    BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongEntriesTableTableManager get songEntries =>
      $$SongEntriesTableTableManager(_db, _db.songEntries);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
