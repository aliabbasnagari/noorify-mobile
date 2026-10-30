// Plain data models for the Subsonic / OpenSubsonic API.

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

double? _dbl(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

List<Map<String, dynamic>> _maps(Object? v) =>
    (v as List? ?? const []).cast<Map<String, dynamic>>();

/// OpenSubsonic `replayGain` block (all values optional, gains in dB).
class ReplayGainInfo {
  const ReplayGainInfo({
    this.trackGain,
    this.albumGain,
    this.trackPeak,
    this.albumPeak,
    this.baseGain,
    this.fallbackGain,
  });

  final double? trackGain;
  final double? albumGain;
  final double? trackPeak;
  final double? albumPeak;
  final double? baseGain;
  final double? fallbackGain;

  factory ReplayGainInfo.fromJson(Map<String, dynamic> j) => ReplayGainInfo(
        trackGain: _dbl(j['trackGain']),
        albumGain: _dbl(j['albumGain']),
        trackPeak: _dbl(j['trackPeak']),
        albumPeak: _dbl(j['albumPeak']),
        baseGain: _dbl(j['baseGain']),
        fallbackGain: _dbl(j['fallbackGain']),
      );

  Map<String, dynamic> toJson() => {
        if (trackGain != null) 'trackGain': trackGain,
        if (albumGain != null) 'albumGain': albumGain,
        if (trackPeak != null) 'trackPeak': trackPeak,
        if (albumPeak != null) 'albumPeak': albumPeak,
        if (baseGain != null) 'baseGain': baseGain,
        if (fallbackGain != null) 'fallbackGain': fallbackGain,
      };
}

class Song {
  const Song({
    required this.id,
    required this.title,
    this.album,
    this.albumId,
    this.artist,
    this.artistId,
    this.coverArt,
    this.duration = 0,
    this.track,
    this.year,
    this.suffix,
    this.starred = false,
    this.genre,
    this.bitRate,
    this.playCount = 0,
    this.userRating,
    this.created,
    this.played,
    this.size,
    this.replayGain,
  });

  final String id;
  final String title;
  final String? album;
  final String? albumId;
  final String? artist;
  final String? artistId;
  final String? coverArt;

  /// Duration in seconds.
  final int duration;
  final int? track;
  final int? year;
  final String? suffix;
  final bool starred;
  final String? genre;

  /// kbps
  final int? bitRate;
  final int playCount;

  /// 1..5
  final int? userRating;

  /// When the song was added to the server library.
  final DateTime? created;

  /// When the song was last played (OpenSubsonic / Navidrome).
  final DateTime? played;
  final int? size;
  final ReplayGainInfo? replayGain;

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: '${j['id']}',
        title: (j['title'] ?? j['name'] ?? 'Unknown') as String,
        album: j['album'] as String?,
        albumId: j['albumId']?.toString(),
        artist: j['artist'] as String?,
        artistId: j['artistId']?.toString(),
        coverArt: j['coverArt']?.toString(),
        duration: _int(j['duration']),
        track: j['track'] == null ? null : _int(j['track']),
        year: j['year'] == null ? null : _int(j['year']),
        suffix: j['suffix'] as String?,
        starred: j['starred'] != null && j['starred'] != false,
        genre: j['genre'] as String?,
        bitRate: j['bitRate'] == null ? null : _int(j['bitRate']),
        playCount: _int(j['playCount']),
        userRating: j['userRating'] == null ? null : _int(j['userRating']),
        created: DateTime.tryParse('${j['created'] ?? ''}'),
        played: DateTime.tryParse('${j['played'] ?? ''}'),
        size: j['size'] == null ? null : _int(j['size']),
        replayGain: j['replayGain'] is Map<String, dynamic>
            ? ReplayGainInfo.fromJson(j['replayGain'] as Map<String, dynamic>)
            : null,
      );

  /// Same shape as the API, so [Song.fromJson] can read cached copies.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (album != null) 'album': album,
        if (albumId != null) 'albumId': albumId,
        if (artist != null) 'artist': artist,
        if (artistId != null) 'artistId': artistId,
        if (coverArt != null) 'coverArt': coverArt,
        'duration': duration,
        if (track != null) 'track': track,
        if (year != null) 'year': year,
        if (suffix != null) 'suffix': suffix,
        if (starred) 'starred': true,
        if (genre != null) 'genre': genre,
        if (bitRate != null) 'bitRate': bitRate,
        'playCount': playCount,
        if (userRating != null) 'userRating': userRating,
        if (created != null) 'created': created!.toIso8601String(),
        if (played != null) 'played': played!.toIso8601String(),
        if (size != null) 'size': size,
        if (replayGain != null) 'replayGain': replayGain!.toJson(),
      };
}

class Album {
  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.genre,
    this.songs = const [],
  });

  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int songCount;
  final int duration;
  final int? year;
  final String? genre;
  final List<Song> songs;

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: '${j['id']}',
        name: (j['name'] ?? j['title'] ?? 'Unknown') as String,
        artist: j['artist'] as String?,
        artistId: j['artistId']?.toString(),
        coverArt: j['coverArt']?.toString(),
        songCount: _int(j['songCount']),
        duration: _int(j['duration']),
        year: j['year'] == null ? null : _int(j['year']),
        genre: j['genre'] as String?,
        songs: _maps(j['song']).map(Song.fromJson).toList(),
      );
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount = 0,
    this.albums = const [],
  });

  final String id;
  final String name;
  final String? coverArt;
  final int albumCount;
  final List<Album> albums;

  factory Artist.fromJson(Map<String, dynamic> j) => Artist(
        id: '${j['id']}',
        name: (j['name'] ?? 'Unknown') as String,
        coverArt: j['coverArt']?.toString(),
        albumCount: _int(j['albumCount']),
        albums: _maps(j['album']).map(Album.fromJson).toList(),
      );
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.songCount = 0,
    this.duration = 0,
    this.coverArt,
    this.songs = const [],
  });

  final String id;
  final String name;
  final int songCount;
  final int duration;
  final String? coverArt;
  final List<Song> songs;

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: '${j['id']}',
        name: (j['name'] ?? 'Playlist') as String,
        songCount: _int(j['songCount']),
        duration: _int(j['duration']),
        coverArt: j['coverArt']?.toString(),
        songs: _maps(j['entry']).map(Song.fromJson).toList(),
      );
}

class Genre {
  const Genre({required this.name, this.songCount = 0, this.albumCount = 0});

  final String name;
  final int songCount;
  final int albumCount;

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
        name: (j['value'] ?? j['name'] ?? '') as String,
        songCount: _int(j['songCount']),
        albumCount: _int(j['albumCount']),
      );
}

class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.homepageUrl,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String? homepageUrl;

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: '${j['id']}',
        name: (j['name'] ?? 'Radio station') as String,
        streamUrl: (j['streamUrl'] ?? '') as String,
        homepageUrl: j['homePageUrl'] as String?,
      );
}

class Bookmark {
  const Bookmark({
    required this.song,
    required this.position,
    this.comment,
    this.created,
    this.changed,
  });

  final Song song;

  /// Playback position in milliseconds.
  final int position;
  final String? comment;
  final DateTime? created;
  final DateTime? changed;

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        song: Song.fromJson(
            (j['entry'] as Map?)?.cast<String, dynamic>() ?? const {}),
        position: _int(j['position']),
        comment: (j['comment'] as String?)?.isEmpty ?? true
            ? null
            : j['comment'] as String?,
        created: DateTime.tryParse('${j['created'] ?? ''}'),
        changed: DateTime.tryParse('${j['changed'] ?? ''}'),
      );
}

/// One line of (optionally time-synced) lyrics.
class LyricLine {
  const LyricLine({this.startMs, required this.value});

  final int? startMs;
  final String value;

  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
        startMs: j['start'] == null ? null : _int(j['start']),
        value: (j['value'] ?? '') as String,
      );
}

class StructuredLyric {
  const StructuredLyric({
    this.displayArtist,
    this.displayTitle,
    this.lang,
    this.synced = false,
    this.lines = const [],
  });

  final String? displayArtist;
  final String? displayTitle;
  final String? lang;
  final bool synced;
  final List<LyricLine> lines;

  factory StructuredLyric.fromJson(Map<String, dynamic> j) => StructuredLyric(
        displayArtist: j['displayArtist'] as String?,
        displayTitle: j['displayTitle'] as String?,
        lang: j['lang'] as String?,
        synced: j['synced'] == true,
        lines: _maps(j['line']).map(LyricLine.fromJson).toList(),
      );
}

class SearchResults {
  const SearchResults({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });

  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> j) => SearchResults(
        artists: _maps(j['artist']).map(Artist.fromJson).toList(),
        albums: _maps(j['album']).map(Album.fromJson).toList(),
        songs: _maps(j['song']).map(Song.fromJson).toList(),
      );
}
